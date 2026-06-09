-- 物品使用系统管理器
-- 负责：药水拾取/使用、隐形药水管理、炸弹拾取/投掷

local ItemUsageSystem = {}

-- 设置角色透明
local function setCharacterTransparency(character, transparency)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Transparency = transparency
        end
    end
end

-- 初始化物品使用系统
-- 参数：
--   PlayerStats: 玩家属性模块
--   PlayerConfig: 玩家配置（药水配置等）
--   PotionSystem: 药水系统模块
--   BombSystem: 炸弹系统模块
--   NestSystem: 巢穴系统模块（用于炸弹伤害巢穴）
--   MonsterConfig: 怪物配置（用于炸弹击杀经验奖励）
--   HitEffectSystem: 受击特效系统
--   ReplicatedStorage: ReplicatedStorage 服务
function ItemUsageSystem.Init(
    PlayerStats,
    PlayerConfig,
    PotionSystem,
    BombSystem,
    NestSystem,
    MonsterConfig,
    HitEffectSystem,
    ReplicatedStorage
)

    -- 药水冷却常量
    local POTION_COOLDOWN = 5

    -- 全局状态表
    local playerPotionCooldown = {}
    local invisiblePlayers = {}  -- player.UserId -> expiry time

    -- ============ 获取 RemoteEvents ============
    local usePotionEvent = ReplicatedStorage:WaitForChild("UsePotionEvent")
    local useHealthPotionEvent = ReplicatedStorage:WaitForChild("UseHealthPotionEvent")
    local useInvisibilityPotionEvent = ReplicatedStorage:WaitForChild("UseInvisibilityPotionEvent")
    local detonateBombEvent = ReplicatedStorage:WaitForChild("DetonateBombEvent")
    local throwBombEvent = ReplicatedStorage:WaitForChild("ThrowBombEvent")
    local playerAttackEvent = ReplicatedStorage:WaitForChild("PlayerAttackEvent")
    local playerAttackNestEvent = ReplicatedStorage:WaitForChild("PlayerAttackNestEvent")

    -- ============ 辅助：解除隐身 ============
    local function removeInvisibility(player, reason)
        if not PlayerStats.IsPlayerInvisible(player) then return end

        PlayerStats.SetInvisible(player, false)
        invisiblePlayers[player.UserId] = nil

        local character = player.Character
        if character then
            setCharacterTransparency(character, 0)
        end
        print("👻 隐身解除:", player.Name, "原因:", reason)
    end

    -- ============ 拾取药水（存入库存） ============
    usePotionEvent.OnServerEvent:Connect(function(player, potionObj)
        print("🧪 服务端收到药水拾取请求:", player.Name, potionObj and potionObj.Name or "nil")

        if not potionObj then
            print("❌ 药水对象为空")
            return
        end
        if not potionObj:FindFirstChild("IsPotionDrop") then
            print("❌ 不是药水掉落物")
            return
        end

        local character = player.Character
        if not character then
            print("❌ 玩家没有角色")
            return
        end

        local playerRoot = character:FindFirstChild("HumanoidRootPart")
        if not playerRoot then
            print("❌ 玩家没有HumanoidRootPart")
            return
        end

        local objPos = potionObj:IsA("Model") and potionObj:GetPivot().Position or potionObj.Position
        local dist = (playerRoot.Position - objPos).Magnitude
        print("🧪 距离检查:", dist, "/ 15")
        if dist > 15 then
            print("❌ 距离太远")
            return
        end

        local potionIdValue = potionObj:FindFirstChild("PotionId")
        if not potionIdValue then
            print("❌ 没有药水ID")
            return
        end

        local potionId = potionIdValue.Value
        local success = false

        if potionId == "HealthPotion" then
            success = PlayerStats.AddHealthPotion(player)
        elseif potionId == "InvisibilityPotion" then
            success = PlayerStats.AddInvisibilityPotion(player)
        else
            print("❌ 未知药水类型:", potionId)
            return
        end

        if success then
            potionObj:Destroy()
            print("🧪 药水已存入库存:", potionId)
        else
            print("❌ 药水库存已满，无法拾取:", potionId)
        end
    end)

    -- ============ 使用生命药水（右键物品栏） ============
    useHealthPotionEvent.OnServerEvent:Connect(function(player)
        print("❤️ 服务端收到使用生命药水请求:", player.Name)

        local character = player.Character
        if not character then
            print("❌ 玩家没有角色")
            return
        end

        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            print("❌ 玩家没有Humanoid")
            return
        end

        -- 检查冷却
        local lastUse = playerPotionCooldown[player.UserId] or 0
        if tick() - lastUse < POTION_COOLDOWN then
            print("❌ 药水冷却中")
            return
        end

        -- 检查库存
        if not PlayerStats.RemoveHealthPotion(player) then
            print("❌ 没有生命药水库存")
            return
        end

        -- 计算回复量
        local leaderstats = player:FindFirstChild("leaderstats")
        if not leaderstats then return end

        local maxHealthValue = leaderstats:FindFirstChild("MaxHealth")
        local healthValue = leaderstats:FindFirstChild("Health")
        if not healthValue or not maxHealthValue then return end

        local stats = PlayerStats.GetStats(player)
        local intelligence = (stats and stats.Intelligence) or 10
        local healAmount = PlayerConfig.HealthPotion.BaseHeal + intelligence * PlayerConfig.HealthPotion.IntelligenceHealMultiplier
        local newHealth = math.min(maxHealthValue.Value, healthValue.Value + healAmount)

        humanoid.Health = newHealth
        healthValue.Value = newHealth
        PlayerStats.SetStat(player, "Health", newHealth)

        playerPotionCooldown[player.UserId] = tick()
        print("💚 使用生命药水, 智力:", intelligence, "回复:", healAmount, "当前血量:", newHealth, "/", maxHealthValue.Value)
    end)

    -- ============ 使用隐形药水 ============
    useInvisibilityPotionEvent.OnServerEvent:Connect(function(player)
        print("👻 服务端收到使用隐形药水请求:", player.Name)

        local character = player.Character
        if not character then
            print("❌ 玩家没有角色")
            return
        end

        -- 检查冷却
        local lastUse = playerPotionCooldown[player.UserId] or 0
        if tick() - lastUse < POTION_COOLDOWN then
            print("❌ 药水冷却中")
            return
        end

        -- 检查库存
        if not PlayerStats.RemoveInvisibilityPotion(player) then
            print("❌ 没有隐形药水库存")
            return
        end

        local duration = PlayerConfig.InvisibilityPotion.Duration
        invisiblePlayers[player.UserId] = tick() + duration
        PlayerStats.SetInvisible(player, true)

        setCharacterTransparency(character, 0.85)

        playerPotionCooldown[player.UserId] = tick()
        print("👻 玩家隐身:", player.Name, "持续:", duration, "秒")

        -- 自动到期解除隐身
        task.delay(duration, function()
            if invisiblePlayers[player.UserId] and tick() >= invisiblePlayers[player.UserId] then
                removeInvisibility(player, "时间到期")
            end
        end)
    end)

    -- ============ 攻击时解除隐身 ============
    playerAttackEvent.OnServerEvent:Connect(function(player, monsterModel)
        if PlayerStats.IsPlayerInvisible(player) then
            removeInvisibility(player, "攻击怪物")
        end
    end)

    playerAttackNestEvent.OnServerEvent:Connect(function(player, nestModel)
        if PlayerStats.IsPlayerInvisible(player) then
            removeInvisibility(player, "攻击巢穴")
        end
    end)

    -- ============ 拾取炸弹（存入库存） ============
    detonateBombEvent.OnServerEvent:Connect(function(player, bombObj)
        print("💣 服务端收到炸弹拾取请求:", player.Name)

        if not bombObj then
            print("❌ 炸弹对象为空")
            return
        end
        if not bombObj:FindFirstChild("IsBombDrop") then
            print("❌ 不是炸弹掉落物")
            return
        end

        local character = player.Character
        if not character then
            print("❌ 玩家没有角色")
            return
        end

        local playerRoot = character:FindFirstChild("HumanoidRootPart")
        if not playerRoot then
            print("❌ 玩家没有HumanoidRootPart")
            return
        end

        -- 检查距离
        local bombPos = bombObj:IsA("Model") and bombObj:GetPivot().Position or bombObj.Position
        local dist = (playerRoot.Position - bombPos).Magnitude
        if dist > 15 then
            print("❌ 炸弹距离太远:", dist)
            return
        end

        -- 存入玩家库存
        local success = PlayerStats.AddBomb(player)
        if success then
            bombObj:Destroy()
            print("💣 炸弹已存入库存")
        else
            print("❌ 炸弹库存已满，无法拾取")
        end
    end)

    -- ============ 投掷炸弹（库存消耗，范围伤害） ============
    throwBombEvent.OnServerEvent:Connect(function(player, targetPosition)
        print("💣 服务端收到炸弹投掷请求:", player.Name, "目标:", targetPosition)

        if not targetPosition then
            print("❌ 目标位置为空")
            return
        end

        local character = player.Character
        if not character then
            print("❌ 玩家没有角色")
            return
        end

        -- 检查玩家是否有炸弹
        if not PlayerStats.RemoveBomb(player) then
            print("❌ 没有炸弹库存")
            return
        end

        local bombConfig = BombSystem.GetBombConfig("Bomb")
        if not bombConfig then
            print("❌ 未知炸弹类型")
            return
        end

        print("💥 炸弹投掷! 目标:", targetPosition, "伤害:", bombConfig.Damage, "范围:", bombConfig.Range)

        local bombPos = targetPosition

        -- ====== 创建爆炸视觉效果 ======
        local explosionPart = Instance.new("Part")
        explosionPart.Name = "BombExplosion"
        explosionPart.Size = Vector3.new(1, 1, 1)
        explosionPart.Position = bombPos
        explosionPart.Shape = Enum.PartType.Ball
        explosionPart.BrickColor = BrickColor.new("Bright red")
        explosionPart.Material = Enum.Material.Neon
        explosionPart.Transparency = 0.2
        explosionPart.Anchored = true
        explosionPart.CanCollide = false
        explosionPart.Parent = game.Workspace

        local explosionGlow = Instance.new("PointLight")
        explosionGlow.Color = Color3.new(1, 0.5, 0)
        explosionGlow.Range = bombConfig.Range * 2
        explosionGlow.Brightness = 5
        explosionGlow.Parent = explosionPart

        -- 扩展爆炸效果（由小到大再消失）
        local explosionSize = 2
        for i = 1, 5 do
            explosionSize = explosionSize + 1.5
            explosionPart.Size = Vector3.new(explosionSize, explosionSize, explosionSize)
            explosionPart.Transparency = 0.2 + (i - 1) * 0.15
            task.wait(0.08)
        end
        explosionPart:Destroy()

        -- ====== 对范围内怪物造成伤害 ======
        for _, monsterModel in ipairs(game.Workspace:GetChildren()) do
            if monsterModel:IsA("Model") and monsterModel:FindFirstChild("OwningNestId") then
                local humanoid = monsterModel:FindFirstChild("Humanoid")
                local root = monsterModel:FindFirstChild("HumanoidRootPart")
                if humanoid and humanoid.Health > 0 and root then
                    local monDist = (root.Position - bombPos).Magnitude
                    if monDist <= bombConfig.Range then
                        print("💥 炸弹命中怪物:", monsterModel.Name, "距离:", monDist)
                        humanoid.Health = math.max(0, humanoid.Health - bombConfig.Damage)

                        -- 受击反应
                        HitEffectSystem.MonsterHitEffect(monsterModel, root.Position)

                        if humanoid.Health <= 0 then
                            local monsterTypeValue = monsterModel:FindFirstChild("MonsterType")
                            if monsterTypeValue then
                                local monsterConfig = MonsterConfig.Types[monsterTypeValue.Value]
                                if monsterConfig and monsterConfig.ExpReward then
                                    PlayerStats.AddExperience(player, monsterConfig.ExpReward)
                                    print("✅ 炸弹击杀怪物, 奖励经验:", monsterConfig.ExpReward)
                                end
                            end
                            -- 死亡特效
                            HitEffectSystem.MonsterDeathEffect(monsterModel, root.Position)
                            monsterModel:Destroy()
                        end
                    end
                end
            end
        end

        -- ====== 对范围内巢穴造成伤害 ======
        local nearbyNests = NestSystem.GetNestsInRange(bombPos, bombConfig.Range)
        for _, nest in ipairs(nearbyNests) do
            print("💥 炸弹命中巢穴:", nest.Config.Name, "距离:", (nest.Position - bombPos).Magnitude)
            NestSystem.DamageNest(nest.Id, bombConfig.Damage)
        end

        print("💣 炸弹投掷完成!")
    end)

    print("✅ ItemUsageSystem 已初始化")
end

return ItemUsageSystem
