-- 箱子交互管理器
-- 负责：打开箱子、存入物品、取出物品、拾取箱子、放置箱子

local ChestInteractionManager = {}

-- 给玩家物品的辅助函数
local function giveItemToPlayer(player, item, PlayerStats, ReplicatedStorage)
    if item.Type == "Weapon" then
        local WeaponSystem = require(ReplicatedStorage.Modules.WeaponSystem)
        local char = player.Character
        local pos = char and char:GetPivot().Position or Vector3.new(0, 5, 0)
        WeaponSystem.SpawnWeaponDrop(pos, item.Name)
    elseif item.Type == "Bomb" then
        PlayerStats.AddBomb(player)
    elseif item.Type == "HealthPotion" then
        PlayerStats.AddHealthPotion(player)
    elseif item.Type == "InvisibilityPotion" then
        PlayerStats.AddInvisibilityPotion(player)
    end
end

-- 查找 workspace 中指定 ID 的箱子模型
local function findChestModel(chestId, workspace)
    for _, model in ipairs(workspace:GetChildren()) do
        if model.Name == "Chest" then
            local idVal = model:FindFirstChild("ChestId")
            if idVal and idVal.Value == chestId then
                return model
            end
        end
    end
    return nil
end

-- 向客户端发送箱子内容更新
local function sendChestUpdate(player, chestId, ChestSystem, ReplicatedStorage)
    local contents = ChestSystem.GetChestContents(chestId)
    if contents then
        local updateEvent = ReplicatedStorage:FindFirstChild("ChestUpdateEvent")
        if updateEvent then
            updateEvent:FireClient(player, chestId, contents)
        end
    end
end

-- 初始化箱子交互系统
-- 参数：
--   PlayerStats: 玩家属性模块
--   ChestSystem: 箱子系统模块
--   ItemConfig: 统一物品配置模块
--   ReplicatedStorage: ReplicatedStorage 服务
--   workspace: workspace 服务
function ChestInteractionManager.Init(
    PlayerStats,
    ChestSystem,
    ItemConfig,
    ReplicatedStorage,
    workspace
)

    -- 从统一配置中获取箱子交互距离
    local _chestStorage, _ = ItemConfig.GetChestStorageConfig("WoodenChest")
    local CHEST_INTERACT_DISTANCE = _chestStorage.InteractDistance or 8

    -- ============ 获取 RemoteEvents ============
    local openChestEvent = ReplicatedStorage:WaitForChild("OpenChestEvent")
    local storeToChestEvent = ReplicatedStorage:WaitForChild("StoreToChestEvent")
    local takeFromChestEvent = ReplicatedStorage:WaitForChild("TakeFromChestEvent")
    local pickupChestEvent = ReplicatedStorage:WaitForChild("PickupChestEvent")
    local placeChestEvent = ReplicatedStorage:WaitForChild("PlaceChestEvent")

    -- ============ 打开箱子（获取内容） ============
    openChestEvent.OnServerEvent:Connect(function(player, chestId)
        if not chestId then return end

        local character = player.Character
        if not character then return end
        local playerRoot = character:FindFirstChild("HumanoidRootPart")
        if not playerRoot then return end

        local targetChest = findChestModel(chestId, workspace)
        if not targetChest then
            print("❌ 箱子不存在:", chestId)
            return
        end

        -- 检查距离
        local chestPos = targetChest:GetPivot().Position
        local dist = (playerRoot.Position - chestPos).Magnitude
        if dist > CHEST_INTERACT_DISTANCE then
            print("❌ 距离太远，无法打开箱子")
            return
        end

        -- 获取箱子内容并发送给客户端
        sendChestUpdate(player, chestId, ChestSystem, ReplicatedStorage)
    end)

    -- ============ 存入物品到箱子 ============
    storeToChestEvent.OnServerEvent:Connect(function(player, chestId, itemData, slotIndex)
        if not chestId or not itemData then return end

        print("📦 [服务器] 收到存入请求, 玩家:", player.Name, "箱子:", chestId, "物品类型:", itemData.Type, "物品名:", tostring(itemData.Name))

        -- 先从玩家库存扣除
        local deducted = false
        if itemData.Type == "Bomb" then
            deducted = PlayerStats.RemoveBomb(player)
            print("📦 [服务器] 尝试扣除炸弹, 结果:", deducted)
        elseif itemData.Type == "HealthPotion" then
            deducted = PlayerStats.RemoveHealthPotion(player)
            print("📦 [服务器] 尝试扣除生命药水, 结果:", deducted)
        elseif itemData.Type == "InvisibilityPotion" then
            deducted = PlayerStats.RemoveInvisibilityPotion(player)
            print("📦 [服务器] 尝试扣除隐形药水, 结果:", deducted)
        elseif itemData.Type == "Weapon" then
            -- 武器：卸下当前武器
            local weaponId = PlayerStats.GetWeapon(player)
            print("📦 [服务器] 尝试卸下武器, 当前武器:", tostring(weaponId))
            if weaponId then
                PlayerStats.UnequipWeapon(player)
                -- 移除角色手中的工具（如果有的话）
                local character = player.Character
                if character then
                    local tool = character:FindFirstChildOfClass("Tool")
                    if tool then tool:Destroy() end
                end
                deducted = true
                print("📦 [服务器] 武器已卸下")
            end
        end

        if not deducted then
            print("❌ 存入失败: 无法从玩家扣除物品:", itemData.Type)
            return
        end

        local success, result = ChestSystem.StoreItem(chestId, { Type = itemData.Type, Name = itemData.Name, Count = 1 }, slotIndex)
        if success then
            print("📦 [服务器] 存入成功, 箱子:", chestId)
            sendChestUpdate(player, chestId, ChestSystem, ReplicatedStorage)
        else
            -- 存入失败，退回物品
            if itemData.Type == "Bomb" then
                PlayerStats.AddBomb(player)
            elseif itemData.Type == "HealthPotion" then
                PlayerStats.AddHealthPotion(player)
            elseif itemData.Type == "InvisibilityPotion" then
                PlayerStats.AddInvisibilityPotion(player)
            elseif itemData.Type == "Weapon" then
                -- 重新装备武器：生成武器掉落让玩家拾取
                local WeaponSystem = require(ReplicatedStorage.Modules.WeaponSystem)
                local char = player.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local drop = WeaponSystem.SpawnWeaponDrop(root.Position + Vector3.new(0, 2, 0), itemData.Name)
                        if drop then
                            task.delay(0.1, function()
                                local ewe = ReplicatedStorage:FindFirstChild("EquipWeaponEvent")
                                if ewe then ewe:FireServer(drop) end
                            end)
                        end
                    end
                end
            end
            print("❌ 存入失败:", result)
        end
    end)

    -- ============ 从箱子取出物品 ============
    takeFromChestEvent.OnServerEvent:Connect(function(player, chestId, slotIndex)
        if not chestId or not slotIndex then return end

        local item, err = ChestSystem.TakeItem(chestId, slotIndex)
        if item then
            giveItemToPlayer(player, item, PlayerStats, ReplicatedStorage)
            sendChestUpdate(player, chestId, ChestSystem, ReplicatedStorage)
        else
            print("❌ 取出失败:", err)
        end
    end)

    -- ============ 拾取箱子（F键） ============
    pickupChestEvent.OnServerEvent:Connect(function(player, chestModel)
        if not chestModel or not chestModel:IsA("Model") then return end
        if chestModel.Name ~= "Chest" then return end

        local character = player.Character
        if not character then return end
        local playerRoot = character:FindFirstChild("HumanoidRootPart")
        if not playerRoot then return end

        -- 距离验证
        local chestPos = chestModel:GetPivot().Position
        local dist = (playerRoot.Position - chestPos).Magnitude
        if dist > 15 then return end

        -- 添加到玩家库存
        local success = PlayerStats.AddChest(player)
        if success then
            -- 获取箱子ID并保存内容
            local idValue = chestModel:FindFirstChild("ChestId")
            if idValue then
                local contents = ChestSystem.TakeChestContents(idValue.Value)
                if contents then
                    PlayerStats.SetChestContents(player, contents)
                    print("📦 箱子内容已保存到玩家库存:", player.Name)
                end
            end

            -- 删除世界中的箱子模型
            chestModel:Destroy()
            print("📦 玩家拾取箱子:", player.Name)
        end
    end)

    -- ============ 放置箱子（右键物品栏） ============
    placeChestEvent.OnServerEvent:Connect(function(player)
        local hasChest = PlayerStats.GetChestCount(player)
        if hasChest <= 0 then return end

        local character = player.Character
        if not character then return end
        local playerRoot = character:FindFirstChild("HumanoidRootPart")
        if not playerRoot then return end

        -- 计算放置位置：玩家面前8格
        local lookDir = playerRoot.CFrame.LookVector
        local placePos = playerRoot.Position + lookDir * 8
        placePos = Vector3.new(placePos.X, 0, placePos.Z)

        -- 检查位置：只防止与巢穴/其他箱子重叠，忽略地形
        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
        overlapParams.FilterDescendantsInstances = { character }
        local parts = workspace:GetPartBoundsInRadius(placePos, 2, overlapParams)
        local canPlace = true
        for _, part in ipairs(parts) do
            local model = part.Parent
            if model then
                if model:FindFirstChild("IsNest") or model.Name == "Chest" then
                    canPlace = false
                    break
                end
            end
        end

        if not canPlace then
            print("❌ 位置被阻挡，无法放置箱子")
            return
        end

        -- 创建箱子（检查是否有之前保存的内容需要恢复）
        local savedContents = PlayerStats.GetChestContents(player)
        ChestSystem.SpawnChestDrop(placePos, savedContents)

        -- 消耗库存
        PlayerStats.RemoveChest(player)
        print("📦 玩家放置箱子:", player.Name, "位置:", placePos, "是否恢复内容:", tostring(savedContents ~= nil))
    end)

    print("✅ ChestInteractionManager 已初始化")
end

return ChestInteractionManager
