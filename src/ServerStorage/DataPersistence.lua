
-- 数据持久化模块
-- 支持：玩家数据、世界物品（箱子）、怪物巢穴 的保存/加载
-- 特性：批量写入、指数退避重试、Studio 模式自动回退
local DataPersistence = {}
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore = nil
local WorldDataStore = nil

local AUTOSAVE_INTERVAL = 120  -- 玩家数据自动保存：120秒
local WORLD_DATA_KEY = "WorldData_v1"
local isStudio = RunService:IsStudio()

-- 统一内存缓存（DataStore 不可用时的回退方案）
local memoryCache = {}

-- 重试配置：指数退避（Throttled 错误时重试）
local MAX_RETRIES = 3
local RETRY_BASE_DELAY = 2  -- 第1次失败后2秒，第2次4秒，第3次8秒

-- 带指数退避的重试包装器
local function withRetry(operation, label)
    local lastErr = nil
    for attempt = 1, MAX_RETRIES do
        local success, result = pcall(operation)
        if success then
            return true, result
        end
        lastErr = result
        local errStr = tostring(result) or ""
        if string.find(errStr, "Throttled") or string.find(errStr, "throttled") or
           string.find(errStr, "Queue") or string.find(errStr, "queue") then
            local delay = RETRY_BASE_DELAY * (2 ^ (attempt - 1))
            warn("⚠️  [", label, "] 第", attempt, "次请求被限流，", delay, "秒后重试:", errStr)
            task.wait(delay)
        else
            -- 非限流错误，不重试
            return false, result
        end
    end
    return false, lastErr or "max retries exceeded"
end

-- 总是尝试初始化 DataStore（Studio 中也可使用）
-- 前提：在 Game Settings → Security 中启用 "Enable Studio Access to API Services"
-- 如果不可用，自动回退到内存缓存
local p1, r1 = pcall(function()
    return DataStoreService:GetDataStore("PlayerData")
end)
if p1 then
    PlayerDataStore = r1
    print("✅ PlayerDataStore 初始化成功")
else
    warn("⚠️  PlayerDataStore 不可用，使用内存缓存:", r1)
end

local p2, r2 = pcall(function()
    return DataStoreService:GetDataStore("WorldData")
end)
if p2 then
    WorldDataStore = r2
    print("✅ WorldDataStore 初始化成功")
else
    warn("⚠️  WorldDataStore 不可用，使用内存缓存:", r2)
end

if isStudio and (not PlayerDataStore or not WorldDataStore) then
    print("🏠 提示：在 Game Settings → Security 中启用 \"Enable Studio Access to API Services\" 以在 Studio 中使用 DataStore")
end

local function getPlayerKey(player)
    return "Player_" .. player.UserId
end

-- ============================================================
-- 玩家数据（属性、装备、背包、位置）
-- ============================================================

function DataPersistence.LoadPlayerData(player)
    if not PlayerDataStore then
        print("📂 PlayerDataStore 不可用 - 检查内存缓存")
        return memoryCache[player.UserId] and memoryCache[player.UserId].Data or nil
    end

    local key = getPlayerKey(player)
    local success, result = withRetry(function()
        return PlayerDataStore:GetAsync(key)
    end, "LoadPlayer:" .. player.Name)

    if success then
        if result then
            print("📂 已加载玩家数据:", player.Name)
        end
        return result
    else
        warn("❌ 加载玩家数据失败:", player.Name, result)
        -- 回退到内存缓存
        return memoryCache[player.UserId] and memoryCache[player.UserId].Data or nil
    end
end

function DataPersistence.SavePlayerData(player, data)
    -- 始终更新内存缓存（双重保障）
    if not memoryCache[player.UserId] then memoryCache[player.UserId] = {} end
    memoryCache[player.UserId].Data = data

    if not PlayerDataStore then
        print("💾 PlayerDataStore 不可用 - 已保存到内存缓存:", player.Name)
        return
    end

    local key = getPlayerKey(player)
    local success, err = withRetry(function()
        PlayerDataStore:SetAsync(key, data)
    end, "SavePlayer:" .. player.Name)

    if success then
        print("💾 已保存玩家数据:", player.Name)
    else
        warn("❌ 保存玩家数据失败:", player.Name, err)
    end
end

function DataPersistence.StartAutoSave(player, getDataCallback)
    local thread = task.spawn(function()
        while player:IsDescendantOf(game) do
            task.wait(AUTOSAVE_INTERVAL)
            if player:IsDescendantOf(game) then
                local data = getDataCallback()
                if data then
                    DataPersistence.SavePlayerData(player, data)
                end
            end
        end
    end)
    return thread
end

-- ============================================================
-- 世界数据（箱子位置+内容、巢穴位置+状态）
-- ============================================================

function DataPersistence.LoadWorldData()
    if not WorldDataStore then
        if memoryCache.WorldData then
            print("📂 从内存缓存加载世界数据")
            return memoryCache.WorldData
        end
        print("📂 WorldDataStore 不可用 - 使用默认生成")
        return nil
    end

    local success, result = withRetry(function()
        return WorldDataStore:GetAsync(WORLD_DATA_KEY)
    end, "LoadWorld")

    if success then
        if result then
            print("📂 已加载世界数据, 箱子:", #(result.Chests or {}), "巢穴:", #(result.Nests or {}))
        else
            print("📂 世界数据为空（首次运行）")
        end
        return result
    else
        warn("❌ 加载世界数据失败:", result)
        return memoryCache.WorldData or nil
    end
end

function DataPersistence.SaveWorldData(worldData)
    -- 始终更新内存缓存
    memoryCache.WorldData = worldData

    if not WorldDataStore then
        local chestCount = worldData and worldData.Chests and #worldData.Chests or 0
        local nestCount = worldData and worldData.Nests and #worldData.Nests or 0
        print("💾 WorldDataStore 不可用 - 世界数据已存入内存缓存, 箱子:", chestCount, "巢穴:", nestCount)
        return
    end

    local success, err = withRetry(function()
        WorldDataStore:SetAsync(WORLD_DATA_KEY, worldData)
    end, "SaveWorld")

    if success then
        local chestCount = worldData and worldData.Chests and #worldData.Chests or 0
        local nestCount = worldData and worldData.Nests and #worldData.Nests or 0
        print("💾 已保存世界数据, 箱子:", chestCount, "巢穴:", nestCount)
    else
        warn("❌ 保存世界数据失败:", err)
    end
end

function DataPersistence.ClearWorldData()
    memoryCache.WorldData = nil
    if not WorldDataStore then
        print("🗑️  WorldDataStore 不可用 - 已清空内存世界数据缓存")
        return
    end

    local success, err = withRetry(function()
        WorldDataStore:RemoveAsync(WORLD_DATA_KEY)
    end, "ClearWorld")

    if success then
        print("🗑️  已清除世界数据")
    else
        warn("❌ 清除世界数据失败:", err)
    end
end

return DataPersistence
