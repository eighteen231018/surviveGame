-- 主服务端脚本 - 模块入口
-- 职责：创建 RemoteEvent、加载模块、初始化各系统、管理世界数据持久化

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ============================================================
-- 第一阶段：创建所有 RemoteEvent
-- ============================================================

local playerAttackEvent = Instance.new("RemoteEvent")
playerAttackEvent.Name = "PlayerAttackEvent"
playerAttackEvent.Parent = ReplicatedStorage

local playerAttackNestEvent = Instance.new("RemoteEvent")
playerAttackNestEvent.Name = "PlayerAttackNestEvent"
playerAttackNestEvent.Parent = ReplicatedStorage

local equipWeaponEvent = Instance.new("RemoteEvent")
equipWeaponEvent.Name = "EquipWeaponEvent"
equipWeaponEvent.Parent = ReplicatedStorage

local usePotionEvent = Instance.new("RemoteEvent")
usePotionEvent.Name = "UsePotionEvent"
usePotionEvent.Parent = ReplicatedStorage

local detonateBombEvent = Instance.new("RemoteEvent")
detonateBombEvent.Name = "DetonateBombEvent"
detonateBombEvent.Parent = ReplicatedStorage

local throwBombEvent = Instance.new("RemoteEvent")
throwBombEvent.Name = "ThrowBombEvent"
throwBombEvent.Parent = ReplicatedStorage

local useHealthPotionEvent = Instance.new("RemoteEvent")
useHealthPotionEvent.Name = "UseHealthPotionEvent"
useHealthPotionEvent.Parent = ReplicatedStorage

local useInvisibilityPotionEvent = Instance.new("RemoteEvent")
useInvisibilityPotionEvent.Name = "UseInvisibilityPotionEvent"
useInvisibilityPotionEvent.Parent = ReplicatedStorage

local playerHitEvent = Instance.new("RemoteEvent")
playerHitEvent.Name = "PlayerHitEvent"
playerHitEvent.Parent = ReplicatedStorage

local openChestEvent = Instance.new("RemoteEvent")
openChestEvent.Name = "OpenChestEvent"
openChestEvent.Parent = ReplicatedStorage

local storeToChestEvent = Instance.new("RemoteEvent")
storeToChestEvent.Name = "StoreToChestEvent"
storeToChestEvent.Parent = ReplicatedStorage

local takeFromChestEvent = Instance.new("RemoteEvent")
takeFromChestEvent.Name = "TakeFromChestEvent"
takeFromChestEvent.Parent = ReplicatedStorage

local chestUpdateEvent = Instance.new("RemoteEvent")
chestUpdateEvent.Name = "ChestUpdateEvent"
chestUpdateEvent.Parent = ReplicatedStorage

local pickupChestEvent = Instance.new("RemoteEvent")
pickupChestEvent.Name = "PickupChestEvent"
pickupChestEvent.Parent = ReplicatedStorage

local placeChestEvent = Instance.new("RemoteEvent")
placeChestEvent.Name = "PlaceChestEvent"
placeChestEvent.Parent = ReplicatedStorage

-- ============================================================
-- 第二阶段：加载所有模块
-- ============================================================

local Modules = ReplicatedStorage.Modules
local PlayerStats = require(Modules.PlayerStats)
local MonsterConfig = require(Modules.MonsterConfig)
local ItemConfig = require(Modules.ItemConfig)
local WeaponSystem = require(Modules.WeaponSystem)
local PotionSystem = require(Modules.PotionSystem)
local BombSystem = require(Modules.BombSystem)
local HitEffectSystem = require(Modules.HitEffectSystem)

local DataPersistence = require(ServerStorage.DataPersistence)
local NestSystem = require(ServerStorage.NestSystem)
local ChestSystem = require(ServerStorage.ChestSystem)
local PlayerLifecycleManager = require(ServerStorage.PlayerLifecycleManager)
local CombatSystem = require(ServerStorage.CombatSystem)
local ItemUsageSystem = require(ServerStorage.ItemUsageSystem)
local ChestInteractionManager = require(ServerStorage.ChestInteractionManager)

-- ============================================================
-- 第三阶段：加载世界数据（箱子+巢穴）
-- ============================================================

local worldData = DataPersistence.LoadWorldData()
local savedChests = worldData and worldData.Chests or nil
local savedNests = worldData and worldData.Nests or nil

if worldData then
    print("🌍 [Main] 已加载世界数据 - 箱子:", #savedChests, "巢穴:", #savedNests)
else
    print("🌍 [Main] 没有保存的世界数据，将进行默认生成")
end

-- ============================================================
-- 第四阶段：初始化各功能系统
-- ============================================================

PlayerLifecycleManager.Init(Players, PlayerStats, DataPersistence, WeaponSystem)

CombatSystem.Init(
    PlayerStats,
    require(Modules.PlayerConfig),
    MonsterConfig,
    WeaponSystem,
    NestSystem,
    ItemConfig,
    HitEffectSystem,
    PotionSystem,
    ReplicatedStorage
)

ItemUsageSystem.Init(
    PlayerStats,
    require(Modules.PlayerConfig),
    PotionSystem,
    BombSystem,
    NestSystem,
    MonsterConfig,
    HitEffectSystem,
    ReplicatedStorage
)

ChestInteractionManager.Init(
    PlayerStats,
    ChestSystem,
    ItemConfig,
    ReplicatedStorage,
    Workspace
)

-- ============================================================
-- 第五阶段：恢复箱子（先于巢穴初始化，避免箱子位置与巢穴冲突）
-- ============================================================

if savedChests and #savedChests > 0 then
    ChestSystem.RestoreAllChestsFromSave(savedChests)
end

-- 巢穴系统初始化（有保存数据则恢复，无保存数据则随机生成）
NestSystem.Init(savedNests)

-- ============================================================
-- 第六阶段：世界数据持久化（定期保存 + 关闭时保存）
-- ============================================================

-- 每120秒保存一次世界数据（减少DataStore请求频率）
local WORLD_SAVE_INTERVAL = 120
local lastWorldSaveTime = tick()

local function saveWorldData()
    local chestData = ChestSystem.GetAllChestsForSave()
    local nestData = NestSystem.GetAllNestsForSave()
    DataPersistence.SaveWorldData({ Chests = chestData, Nests = nestData })
end

-- 主循环：更新巢穴AI + 定期保存世界数据
local lastUpdateTime = tick()
RunService.Heartbeat:Connect(function(deltaTime)
    local currentTime = tick()

    -- 巢穴系统更新
    local nestUpdateInterval = 0.1
    if currentTime - lastUpdateTime >= nestUpdateInterval then
        NestSystem.Update(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
    end

    -- 世界数据定期保存
    if currentTime - lastWorldSaveTime >= WORLD_SAVE_INTERVAL then
        saveWorldData()
        lastWorldSaveTime = currentTime
    end
end)

-- 服务器关闭时保存世界数据
game:BindToClose(function()
    print("🌍 [Main] 服务器关闭，保存世界数据...")
    saveWorldData()
    print("✅ [Main] 世界数据已保存")
end)

print("✅ 主服务端脚本已启动!")
