-- 战斗系统管理器
-- 负责：玩家攻击怪物、玩家攻击巢穴、武器装备拾取

local CombatSystem = {}

-- 获取玩家武器加成
local function getWeaponBonuses(player, PlayerStats, WeaponSystem)
    local weaponId = PlayerStats.GetWeapon(player)
    if not weaponId then return 0, 0, 1.0 end
    return WeaponSystem.GetWeaponBonuses(weaponId)
end

-- 初始化战斗系统
-- 参数：
--   PlayerStats: 玩家属性模块
--   PlayerConfig: 玩家配置（攻击属性、经验奖励等）
--   MonsterConfig: 怪物配置
--   WeaponSystem: 武器系统
--   NestSystem: 巢穴系统
--   ItemConfig: 统一物品配置
--   HitEffectSystem: 受击特效系统
--   PotionSystem: 药水系统（用于怪物死亡掉落）
--   ReplicatedStorage: ReplicatedStorage 服务
function CombatSystem.Init(
    PlayerStats,
    PlayerConfig,
    MonsterConfig,
    WeaponSystem,
    NestSystem,
    ItemConfig,
    HitEffectSystem,
    PotionSystem,
    ReplicatedStorage
)

    local playerAttackEvent = ReplicatedStorage:WaitForChild("PlayerAttackEvent")
    local playerAttackNestEvent = ReplicatedStorage:WaitForChild("PlayerAttackNestEvent")
    local equipWeaponEvent = ReplicatedStorage:WaitForChild("EquipWeaponEvent")

    -- ============ 攻击怪物 ============
    playerAttackEvent.OnServerEvent:Connect(function(player, monsterModel)
        if not monsterModel or not monsterModel:IsA("Model") then
            print("❌ 攻击验证失败: 不是有效的Model")
            return
        end
        if not monsterModel:FindFirstChild("OwningNestId") then
            print("❌ 攻击验证失败: 没有OwningNestId")
            return
        end
        if not monsterModel:FindFirstChild("HumanoidRootPart") then
            print("❌ 攻击验证失败: 没有HumanoidRootPart")
            return
        end

        local humanoid = monsterModel:FindFirstChild("Humanoid")
        if not humanoid then
            print("❌ 攻击验证失败: 没有Humanoid")
            return
        end
        if humanoid.Health <= 0 then
            print("❌ 攻击验证失败: 怪物已死亡")
            return
        end

        local character = player.Character
        if not character then
            print("❌ 攻击验证失败: 玩家没有角色")
            return
        end

        local playerRoot = character:FindFirstChild("HumanoidRootPart")
        local monsterRoot = monsterModel:FindFirstChild("HumanoidRootPart")
        if not playerRoot then
            print("❌ 攻击验证失败: 玩家没有HumanoidRootPart")
            return
        end

        local dist = (playerRoot.Position - monsterRoot.Position).Magnitude

        local stats = PlayerStats.GetStats(player)
        if not stats then
            print("❌ 攻击验证失败: 找不到玩家属性")
            return
        end

        local attackConfig = PlayerConfig.Attack
        local attackRange = attackConfig.BaseRange + stats.Agility * attackConfig.AgilityRangeMultiplier
        local weaponDmg, weaponRange, weaponSpeed = getWeaponBonuses(player, PlayerStats, WeaponSystem)
        attackRange = attackRange + weaponRange
        if dist > attackRange then
            print("❌ 攻击验证失败: 超出攻击范围", dist, attackRange)
            return
        end

        local attackInterval = math.max(attackConfig.MinInterval, (attackConfig.BaseInterval - stats.Agility * attackConfig.AgilityIntervalMultiplier) * weaponSpeed)
        local lastAttackValue = monsterModel:FindFirstChild("LastPlayerAttackTime")
        if not lastAttackValue then
            lastAttackValue = Instance.new("NumberValue")
            lastAttackValue.Name = "LastPlayerAttackTime"
            lastAttackValue.Value = 0
            lastAttackValue.Parent = monsterModel
        end

        local currentTime = tick()
        if currentTime - lastAttackValue.Value < attackInterval then
            print("❌ 攻击验证失败: 攻击冷却中")
            return
        end

        local damage = attackConfig.BaseDamage + stats.Strength * attackConfig.StrengthDamageMultiplier + weaponDmg
        print("✅ 攻击命中! 伤害:", damage, "怪物剩余血量:", humanoid.Health - damage)
        humanoid.Health = math.max(0, humanoid.Health - damage)
        lastAttackValue.Value = currentTime

        -- 受击反应（闪红 + 音效 + 火花）
        local hitPos = monsterRoot and monsterRoot.Position or monsterModel:GetPivot().Position
        HitEffectSystem.MonsterHitEffect(monsterModel, hitPos)

        if humanoid.Health <= 0 then
            local monsterTypeValue = monsterModel:FindFirstChild("MonsterType")
            if monsterTypeValue then
                local monsterConfig = MonsterConfig.Types[monsterTypeValue.Value]
                if monsterConfig and monsterConfig.ExpReward then
                    PlayerStats.AddExperience(player, monsterConfig.ExpReward)
                    print("✅ 怪物死亡, 奖励经验:", monsterConfig.ExpReward)
                end
            end

            -- 掉落判定：25%掉落药水（生命/隐形各半随机）
            local dropMonsterRoot = monsterModel:FindFirstChild("HumanoidRootPart")
            local dropPos = dropMonsterRoot and dropMonsterRoot.Position or monsterModel:GetPivot().Position

            if math.random() < 0.25 then
                local potionType = (math.random() < 0.5) and "HealthPotion" or "InvisibilityPotion"
                PotionSystem.SpawnPotionDrop(dropPos + Vector3.new(0, 2, 0), potionType)
            end

            -- 受击反应：死亡特效
            HitEffectSystem.MonsterDeathEffect(monsterModel, dropPos)

            monsterModel:Destroy()
        end
    end)

    -- ============ 攻击巢穴 ============
    playerAttackNestEvent.OnServerEvent:Connect(function(player, nestModel)
        if not nestModel or not nestModel:IsA("Model") then
            return
        end

        local nestIdValue = nestModel:FindFirstChild("NestId")
        if not nestIdValue then
            return
        end

        local character = player.Character
        if not character then
            return
        end

        local playerRoot = character:FindFirstChild("HumanoidRootPart")
        if not playerRoot then
            return
        end

        local dist = (playerRoot.Position - nestModel:GetPivot().Position).Magnitude

        local stats = PlayerStats.GetStats(player)
        if not stats then
            return
        end

        local attackConfig = PlayerConfig.Attack
        local attackRange = attackConfig.BaseRange + stats.Agility * attackConfig.AgilityRangeMultiplier
        local weaponDmg, weaponRange, weaponSpeed = getWeaponBonuses(player, PlayerStats, WeaponSystem)
        attackRange = attackRange + weaponRange
        if dist > attackRange then
            return
        end

        local attackInterval = math.max(attackConfig.MinInterval, (attackConfig.BaseInterval - stats.Agility * attackConfig.AgilityIntervalMultiplier) * weaponSpeed)
        local lastNestAttackValue = nestModel:FindFirstChild("LastPlayerAttackTime")
        if not lastNestAttackValue then
            lastNestAttackValue = Instance.new("NumberValue")
            lastNestAttackValue.Name = "LastPlayerAttackTime"
            lastNestAttackValue.Value = 0
            lastNestAttackValue.Parent = nestModel
        end

        local currentTime = tick()
        if currentTime - lastNestAttackValue.Value < attackInterval then
            return
        end

        local damage = attackConfig.BaseDamage + stats.Strength * attackConfig.StrengthDamageMultiplier + weaponDmg
        lastNestAttackValue.Value = currentTime

        local destroyed = NestSystem.DamageNest(nestIdValue.Value, damage)
        if destroyed then
            local levelValue = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Level")
            if levelValue then
                local nestExpConfig = PlayerConfig.NestExpReward
                local expReward = nestExpConfig.BaseExp + levelValue.Value * nestExpConfig.LevelBonus
                PlayerStats.AddExperience(player, expReward)
            end
        end
    end)

    -- ============ 装备武器（拾取掉落的武器） ============
    equipWeaponEvent.OnServerEvent:Connect(function(player, weaponObj)
        if not weaponObj then return end
        if not weaponObj:FindFirstChild("IsWeaponDrop") then return end

        local character = player.Character
        if not character then return end

        local playerRoot = character:FindFirstChild("HumanoidRootPart")
        if not playerRoot then return end

        local objPos = weaponObj:IsA("Model") and weaponObj:GetPivot().Position or weaponObj.Position
        local dist = (playerRoot.Position - objPos).Magnitude
        if dist > 15 then return end

        local weaponIdValue = weaponObj:FindFirstChild("WeaponId")
        if not weaponIdValue then return end

        local currentWeapon = PlayerStats.GetWeapon(player)
        if currentWeapon then
            PlayerStats.UnequipWeapon(player)
            print("🔄 玩家卸下武器:", currentWeapon)
        end

        local success = PlayerStats.EquipWeapon(player, weaponIdValue.Value)
        if success then
            weaponObj:Destroy()
            local weaponConfig = ItemConfig.Items[weaponIdValue.Value]
            print("⚔️ 玩家装备武器:", weaponConfig and weaponConfig.Name or weaponIdValue.Value, player.Name)
        end
    end)

    print("✅ CombatSystem 已初始化")
end

return CombatSystem
