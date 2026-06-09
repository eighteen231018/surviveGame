-- 箱子系统 - 服务端逻辑
-- 负责箱子的创建、存取、数据持久化
local ChestSystem = {}
local ItemConfig = require(game:GetService("ReplicatedStorage").Modules.ItemConfig)

-- 从统一配置中获取箱子属性（使用默认ID = "WoodenChest"
local chestStorage, chestVisual = ItemConfig.GetChestStorageConfig("WoodenChest")
local CHEST_SLOT_COUNT = chestStorage.SlotCount
local CHEST_DROP_CHANCE = chestStorage.DropChance
local CHEST_VISUAL = chestVisual

local DataStoreService = game:GetService("DataStoreService")
local chestDataStore = nil
local dataStoreReady = false

-- 尝试初始化 DataStore
local success, ds = pcall(function()
	return DataStoreService:GetDataStore("ChestData")
end)
if success then
	chestDataStore = ds
	dataStoreReady = true
	print("📦 箱子 DataStore 初始化成功")
else
	print("⚠️ 箱子 DataStore 不可用，将在内存中保存数据（重启后丢失）")
end

-- 内存中的箱子数据缓存（键=chestId, 值={slots={...}}）
local chestDataCache = {}
-- 脏数据标记：记录需要同步到 DataStore 的箱子ID
local dirtyChests = {}
-- 待删除的箱子ID（延迟清理）
local pendingRemovals = {}
local CHEST_SYNC_INTERVAL = 60  -- 每60秒批量同步一次
local syncThreadStarted = false

-- 同步所有脏箱子到 DataStore（一次批量处理，避免频繁请求）
local function syncDirtyChests()
    if not dataStoreReady then return end
    local count = 0
    for chestId, isDirty in pairs(dirtyChests) do
        if isDirty and chestDataCache[chestId] then
            local success, err = pcall(function()
                chestDataStore:SetAsync(chestId, chestDataCache[chestId])
            end)
            if success then
                dirtyChests[chestId] = false
                count = count + 1
            else
                warn("⚠️  箱子数据同步失败:", chestId, err)
            end
            task.wait(0.1)
        end
    end
    -- 批量删除
    local removed = 0
    for chestId, _ in pairs(pendingRemovals) do
        local success, err = pcall(function()
            chestDataStore:RemoveAsync(chestId)
        end)
        if success then
            pendingRemovals[chestId] = nil
            removed = removed + 1
        else
            warn("⚠️  箱子数据删除失败:", chestId, err)
        end
        task.wait(0.1)
    end
    if count > 0 or removed > 0 then
        print("📦 [ChestSystem] 已批量同步", count, "个箱子, 删除", removed, "个箱子")
    end
end

-- 启动后台同步线程
local function startSyncThread()
    if syncThreadStarted then return end
    syncThreadStarted = true
    task.spawn(function()
        while true do
            task.wait(CHEST_SYNC_INTERVAL)
            syncDirtyChests()
        end
    end)
    -- 服务器关闭时强制同步
    game:BindToClose(function()
        syncDirtyChests()
    end)
end

-- 尝试保存箱子数据（现在只更新缓存并标记为脏，由后台线程批量同步）
local function saveChestData(chestId, data)
    chestDataCache[chestId] = data
    dirtyChests[chestId] = true
    if dataStoreReady then
        startSyncThread()
    end
end

local function generateChestId()
	return "Chest_" .. tick() .. "_" .. math.random(10000, 99999)
end

-- 创建空的箱子数据（10个空槽位）
local function createEmptyChestData()
	local slots = {}
	for i = 1, CHEST_SLOT_COUNT do
		slots[i] = nil  -- nil = 空
	end
	return { Slots = slots }
end

-- 尝试保存箱子数据
local function saveChestData(chestId, data)
	chestDataCache[chestId] = data
	if dataStoreReady then
		pcall(function()
			chestDataStore:SetAsync(chestId, data)
		end)
	end
end

-- 尝试加载箱子数据
local function loadChestData(chestId)
	-- 先从缓存取
	if chestDataCache[chestId] then
		return chestDataCache[chestId]
	end
	-- 从 DataStore 加载
	if dataStoreReady then
		local success, data = pcall(function()
			return chestDataStore:GetAsync(chestId)
		end)
		if success and data then
			chestDataCache[chestId] = data
			return data
		end
	end
	return nil
end

-- ============================================================
-- 公开 API
-- ============================================================

-- 生成箱子的视觉模型
local function createChestModel(position)
	local model = Instance.new("Model")
	model.Name = "Chest"

	-- 主箱体
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = CHEST_VISUAL.BoxSize
	box.Position = position
	box.Color = CHEST_VISUAL.BoxColor
	box.Material = Enum.Material.Wood
	box.Anchored = true
	box.CanCollide = true
	box.Parent = model

	-- 箱盖
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = CHEST_VISUAL.LidSize
	lid.Position = position + Vector3.new(0, CHEST_VISUAL.BoxSize.Y / 2 + CHEST_VISUAL.LidSize.Y / 2, 0)
	lid.Color = CHEST_VISUAL.LidColor
	lid.Material = Enum.Material.Wood
	lid.Anchored = true
	lid.CanCollide = true
	lid.Parent = model

	-- 锁扣装饰
	local lock = Instance.new("Part")
	lock.Name = "Lock"
	lock.Size = Vector3.new(0.6, 0.3, 0.6)
	lock.Position = lid.Position + Vector3.new(0, 0.5, CHEST_VISUAL.LidSize.Z / 2 - 0.3)
	lock.Color = Color3.fromRGB(255, 215, 0)
	lock.Material = Enum.Material.Metal
	lock.Anchored = true
	lock.CanCollide = false
	lock.Parent = model

	-- 名称标签
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 8, 0, 3)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "📦 箱子"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	-- 放置到世界
	model.PrimaryPart = box
	model.Parent = workspace

	return model
end

-- 在指定位置生成一个箱子掉落
-- initialData: 可选，箱子初始内容（用于拾取后重新放置时恢复数据）
function ChestSystem.SpawnChestDrop(position, initialData)
	local model = createChestModel(position)
	local chestId = generateChestId()

	-- 在模型上存储 ID
	local idValue = Instance.new("StringValue")
	idValue.Name = "ChestId"
	idValue.Value = chestId
	idValue.Parent = model

	-- 初始化数据（使用传入的数据或创建空数据）
	local data = initialData or createEmptyChestData()
	saveChestData(chestId, data)

	print("📦 箱子已生成:", chestId, "位置:", position, "是否有初始数据:", tostring(initialData ~= nil))
	return model, chestId
end

-- 取走箱子内容（用于拾取箱子时保存数据）
-- 返回内容数据，同时从缓存中移除
function ChestSystem.TakeChestContents(chestId)
	local data = loadChestData(chestId)
	if not data then
		return nil
	end

	-- 从缓存中移除
	chestDataCache[chestId] = nil
	dirtyChests[chestId] = nil

	-- 延迟删除（加入批量同步队列）
	if dataStoreReady then
		pendingRemovals[chestId] = true
		startSyncThread()
	end

	print("📦 [ChestSystem] 箱子内容已标记为待删除:", chestId)
	return data  -- 返回 { Slots = {...} }
end

-- 获取箱子的内容
function ChestSystem.GetChestContents(chestId)
	local data = loadChestData(chestId)
	if not data then return nil end
	return data.Slots
end

-- 存入物品到箱子
-- itemData: { Type="Weapon"/"HealthPotion"/"InvisibilityPotion"/"Bomb", Name="...", Count=1 }
function ChestSystem.StoreItem(chestId, itemData, slotIndex)
	local data = loadChestData(chestId)
	if not data then return false, "箱子数据不存在" end
	print("📦 [ChestSystem] 存入物品, 箱子:", chestId, "类型:", itemData.Type, "指定槽位:", tostring(slotIndex))

	if slotIndex then
		-- 指定槽位
		if slotIndex < 1 or slotIndex > CHEST_SLOT_COUNT then
			return false, "无效的槽位"
		end
		data.Slots[slotIndex] = itemData
		print("📦 [ChestSystem] 存入指定槽位:", slotIndex)
	else
		-- 自动放入第一个空槽位
		local placed = false
		for i = 1, CHEST_SLOT_COUNT do
			if not data.Slots[i] then
				data.Slots[i] = itemData
				placed = true
				slotIndex = i
				break
			end
		end
		if not placed then
			return false, "箱子已满"
		end
		print("📦 [ChestSystem] 自动存入槽位:", slotIndex)
	end

	saveChestData(chestId, data)
	print("📦 [ChestSystem] 数据已保存")
	return true, slotIndex
end

-- 从箱子取出物品
function ChestSystem.TakeItem(chestId, slotIndex)
	local data = loadChestData(chestId)
	if not data then return nil, "箱子数据不存在" end
	if slotIndex < 1 or slotIndex > CHEST_SLOT_COUNT then
		return nil, "无效的槽位"
	end

	local item = data.Slots[slotIndex]
	if not item then
		return nil, "该槽位为空"
	end

	data.Slots[slotIndex] = nil
	saveChestData(chestId, data)
	return item, nil
end

-- 箱子是否已满
function ChestSystem.IsFull(chestId)
	local data = loadChestData(chestId)
	if not data then return true end
	for i = 1, CHEST_SLOT_COUNT do
		if not data.Slots[i] then
			return false
		end
	end
	return true
end

-- 获取空槽位数量
function ChestSystem.GetEmptySlotCount(chestId)
	local data = loadChestData(chestId)
	if not data then return 0 end
	local count = 0
	for i = 1, CHEST_SLOT_COUNT do
		if not data.Slots[i] then
			count = count + 1
		end
	end
	return count
end

-- ============================================================
-- 世界级持久化（启动时恢复，关闭时保存）
-- ============================================================

-- 扫描 workspace 中的所有箱子，收集位置+内容用于全量保存
-- 返回: { { ChestId=..., Position={X=...,Y=...,Z=...}, Slots={...} }, ... }
function ChestSystem.GetAllChestsForSave()
	local saved = {}
	for _, model in ipairs(workspace:GetChildren()) do
		if model.Name == "Chest" then
			local idVal = model:FindFirstChild("ChestId")
			if idVal then
				local pos = model:GetPivot().Position
				local data = loadChestData(idVal.Value)
				if data then
					table.insert(saved, {
						ChestId = idVal.Value,
						Position = { X = pos.X, Y = pos.Y, Z = pos.Z },
						Slots = data.Slots,
					})
				end
			end
		end
	end
	print("📦 [ChestSystem] 收集到", #saved, "个箱子用于保存")
	return saved
end

-- 从保存的数据中恢复所有箱子（在启动时调用）
-- 传入: GetAllChestsForSave 的返回数据
-- 返回: 恢复的箱子数量
function ChestSystem.RestoreAllChestsFromSave(savedChests)
	if not savedChests or #savedChests == 0 then
		print("📦 [ChestSystem] 没有保存的箱子需要恢复")
		return 0
	end

	local restored = 0
	for _, chestInfo in ipairs(savedChests) do
		local pos = Vector3.new(chestInfo.Position.X, chestInfo.Position.Y, chestInfo.Position.Z)
		local model = createChestModel(pos)

		-- 使用保存的 ChestId 或生成新 ID
		local chestId = chestInfo.ChestId or generateChestId()
		local idValue = Instance.new("StringValue")
		idValue.Name = "ChestId"
		idValue.Value = chestId
		idValue.Parent = model

		-- 恢复箱子内容
		local data = { Slots = chestInfo.Slots or {} }
		saveChestData(chestId, data)

		restored = restored + 1
	end

	print("📦 [ChestSystem] 已恢复", restored, "个箱子")
	return restored
end

-- 清除 workspace 中所有箱子（用于重新加载前）
function ChestSystem.ClearAllChests()
	local removed = 0
	for _, model in ipairs(workspace:GetChildren()) do
		if model.Name == "Chest" then
			local idVal = model:FindFirstChild("ChestId")
			if idVal then
				model:Destroy()
				removed = removed + 1
			end
		end
	end
	if removed > 0 then
		print("📦 [ChestSystem] 已清除", removed, "个箱子模型")
	end
	return removed
end

return ChestSystem