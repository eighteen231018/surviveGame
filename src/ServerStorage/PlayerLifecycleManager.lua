-- 玩家生命周期管理器
-- 负责：玩家加入/离开、角色生成/死亡/复活、数据持久化（属性+位置）

local PlayerLifecycleManager = {}

-- 初始化并启动玩家生命周期管理
-- 参数：
--   Players: game:GetService("Players")
--   PlayerStats: 玩家属性模块
--   DataPersistence: 数据持久化模块
--   WeaponSystem: 武器系统模块
function PlayerLifecycleManager.Init(Players, PlayerStats, DataPersistence, WeaponSystem)

    local function onPlayerAdded(player)
        print("👋 玩家加入:", player.Name)

        -- 加载保存的数据（包含 Stats + Position）
        local savedData = DataPersistence.LoadPlayerData(player)
        local savedStats = savedData and savedData.Stats
        local savedPosition = savedData and savedData.Position

        PlayerStats.InitializePlayer(player, savedStats)

        player.CharacterAdded:Connect(function(character)
            print("🎮 角色生成:", player.Name)

            local humanoid = character:WaitForChild("Humanoid")
            humanoid.AutoLoadDefaultToolAnimations = false

            -- 恢复保存的位置（如果有）
            if savedPosition then
                local rootPart = character:WaitForChild("HumanoidRootPart", 5)
                if rootPart then
                    local pos = Vector3.new(savedPosition.X, savedPosition.Y, savedPosition.Z)
                    rootPart.Position = pos
                    print("📍 恢复玩家位置:", player.Name, pos)
                end
                savedPosition = nil  -- 只在首次生成时恢复
            end

            -- 复活时恢复死亡前属性快照
            local snapshotRestored = PlayerStats.RestoreSnapshot(player)
            if not snapshotRestored then
                local stats = PlayerStats.GetStats(player)
                if stats then
                    humanoid.MaxHealth = stats.MaxHealth
                    humanoid.Health = stats.Health
                end
            else
                local stats = PlayerStats.GetStats(player)
                if stats then
                    stats.Health = stats.MaxHealth
                    PlayerStats.SetStat(player, "Health", stats.MaxHealth)
                    humanoid.MaxHealth = stats.MaxHealth
                    humanoid.Health = stats.MaxHealth
                    print("💚 玩家满血复活:", player.Name, "血量:", humanoid.Health)
                end
            end

            -- 监听血量变化，同步到 leaderstats
            humanoid.HealthChanged:Connect(function(newHealth)
                local currentStats = PlayerStats.GetStats(player)
                if currentStats then
                    currentStats.Health = newHealth
                    PlayerStats.SetStat(player, "Health", newHealth)
                end
            end)

            -- 定期保存玩家位置（每10秒）
            local posSaveThread = task.spawn(function()
                while player:IsDescendantOf(game) and character:IsDescendantOf(game) do
                    task.wait(10)
                    if character:IsDescendantOf(game) then
                        local root = character:FindFirstChild("HumanoidRootPart")
                        if root then
                            PlayerStats.SetPosition(player, root.Position)
                        end
                    end
                end
            end)

            humanoid.Died:Connect(function()
                print("💀 玩家死亡:", player.Name)

                PlayerStats.SaveSnapshot(player)

                local weaponId = PlayerStats.GetWeapon(player)
                if weaponId then
                    local rootPart = character:FindFirstChild("HumanoidRootPart")
                    local dropPos = rootPart and rootPart.Position or character:GetPivot().Position
                    WeaponSystem.SpawnWeaponDrop(dropPos + Vector3.new(0, 2, 0), weaponId)
                    PlayerStats.UnequipWeapon(player)
                    print("🗡️ 掉落死亡武器:", weaponId)
                end
            end)
        end)

        if player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                print("🎮 角色已存在:", player.Name)
            end
        end

        -- 自动保存（每60秒）：使用 GetPersistentStats 过滤临时字段，同时保存位置
        DataPersistence.StartAutoSave(player, function()
            local persistent = PlayerStats.GetPersistentStats(player)
            if persistent then
                local character = player.Character
                local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                if rootPart then
                    PlayerStats.SetPosition(player, rootPart.Position)
                end
                local currentStats = PlayerStats.GetStats(player)
                local pos = currentStats and currentStats.Position
                if pos then
                    return { Stats = persistent, Position = pos }
                else
                    return { Stats = persistent }
                end
            end
            return nil
        end)
    end

    local function onPlayerRemoving(player)
        print("👋 玩家离开:", player.Name)

        local persistent = PlayerStats.GetPersistentStats(player)
        if persistent then
            -- 保存当前位置
            local character = player.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                PlayerStats.SetPosition(player, rootPart.Position)
            end
            local currentStats = PlayerStats.GetStats(player)
            local pos = currentStats and currentStats.Position
            if pos then
                DataPersistence.SavePlayerData(player, { Stats = persistent, Position = pos })
            else
                DataPersistence.SavePlayerData(player, { Stats = persistent })
            end
        end

        PlayerStats.RemovePlayer(player)
    end

    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end

    print("✅ PlayerLifecycleManager 已初始化")
end

return PlayerLifecycleManager
