
-- 玩家属性管理模块
local PlayerStats = {}
local PlayerConfig = require(script.Parent.PlayerConfig)

local playerData = {}

function PlayerStats.InitializePlayer(player, savedStats)
	local stats = {}
	
	if savedStats then
		for k, v in pairs(savedStats) do
			stats[k] = v
		end
	else
		for k, v in pairs(PlayerConfig.InitialStats) do
			stats[k] = v
		end
	end
	
	playerData[player.UserId] = stats
	
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local statNames = { "Health", "MaxHealth", "Strength", "Agility", "Intelligence", "Level", "Experience", "Bombs", "HealthPotions", "InvisibilityPotions", "Chest" }
	
	for _, statName in ipairs(statNames) do
		local value = stats[statName] or 0
		local statValue = Instance.new("NumberValue")
		statValue.Name = statName
		statValue.Value = value
		statValue.Parent = leaderstats
		print("📊 创建属性:", statName, "=", value)
	end
	
	print("✅ 玩家属性已初始化:", player.Name)
	
	return stats
end

function PlayerStats.GetStats(player)
	return playerData[player.UserId]
end

-- ============================================================
-- 位置持久化
-- ============================================================

function PlayerStats.SetPosition(player, position)
	local stats = playerData[player.UserId]
	if not stats then return end
	stats.Position = {
		X = position.X,
		Y = position.Y,
		Z = position.Z,
	}
end

function PlayerStats.GetPosition(player)
	local stats = playerData[player.UserId]
	if not stats or not stats.Position then return nil end
	return Vector3.new(stats.Position.X, stats.Position.Y, stats.Position.Z)
end

-- ============================================================
-- 持久化数据过滤（排除临时/会话状态）
-- ============================================================

-- 不应该持久化的字段（临时会话状态）
local TRANSIENT_FIELDS = {
	"Snapshot",        -- 死亡快照（仅在会话中使用）
	"Invisible",       -- 隐身状态（会话中临时）
	"ChestContents",   -- 箱子临时内容（拾取后放置前的临时数据）
}

function PlayerStats.GetPersistentStats(player)
	local stats = playerData[player.UserId]
	if not stats then return nil end

	-- 深拷贝并排除临时字段
	local persistent = {}
	for key, value in pairs(stats) do
		local isTransient = false
		for _, field in ipairs(TRANSIENT_FIELDS) do
			if key == field then
				isTransient = true
				break
			end
		end
		if not isTransient then
			persistent[key] = value
		end
	end
	return persistent
end

function PlayerStats.GetStat(player, statName)
	local stats = playerData[player.UserId]
	return stats and stats[statName]
end

function PlayerStats.SetStat(player, statName, value)
	local stats = playerData[player.UserId]
	if not stats then return end
	
	stats[statName] = value
	
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local statValue = leaderstats:FindFirstChild(statName)
		if statValue then
			statValue.Value = value
		end
	end
	
	-- 同步更新角色 Humanoid 的血量，防止 HealthChanged 事件覆盖回旧值
	if statName == "Health" or statName == "MaxHealth" then
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				if statName == "MaxHealth" then
					humanoid.MaxHealth = value
				elseif statName == "Health" then
					-- 只在 Humanoid 血量更低时才同步（避免把受伤后的低血量覆盖成满血）
					if value > humanoid.Health then
						humanoid.Health = value
					end
				end
			end
		end
	end
end

function PlayerStats.AddExperience(player, amount)
	local stats = playerData[player.UserId]
	if not stats then return end
	
	stats.Experience = stats.Experience + amount
	PlayerStats.SetStat(player, "Experience", stats.Experience)
	
	while stats.Experience >= PlayerConfig.GetRequiredExp(stats.Level) do
		stats.Experience = stats.Experience - PlayerConfig.GetRequiredExp(stats.Level)
		stats.Level = stats.Level + 1
		
		stats.MaxHealth = stats.MaxHealth + PlayerConfig.StatGrowth.Health
		stats.Health = stats.MaxHealth
		stats.Strength = stats.Strength + PlayerConfig.StatGrowth.Strength
		stats.Agility = stats.Agility + PlayerConfig.StatGrowth.Agility
		stats.Intelligence = stats.Intelligence + PlayerConfig.StatGrowth.Intelligence
		
		PlayerStats.SetStat(player, "Level", stats.Level)
		PlayerStats.SetStat(player, "Experience", stats.Experience)
		PlayerStats.SetStat(player, "MaxHealth", stats.MaxHealth)
		PlayerStats.SetStat(player, "Health", stats.Health)
		PlayerStats.SetStat(player, "Strength", stats.Strength)
		PlayerStats.SetStat(player, "Agility", stats.Agility)
		PlayerStats.SetStat(player, "Intelligence", stats.Intelligence)
		
		print("🎉 升级!", player.Name, "等级:", stats.Level)
	end
end

function PlayerStats.RemovePlayer(player)
	playerData[player.UserId] = nil
end

function PlayerStats.EquipWeapon(player, weaponId)
	local stats = playerData[player.UserId]
	if not stats then return false end
	stats.EquippedWeapon = weaponId
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local weaponValue = leaderstats:FindFirstChild("Weapon")
		if not weaponValue then
			weaponValue = Instance.new("StringValue")
			weaponValue.Name = "Weapon"
			weaponValue.Parent = leaderstats
		end
		weaponValue.Value = weaponId
	end
	return true
end

function PlayerStats.UnequipWeapon(player)
	local stats = playerData[player.UserId]
	if not stats then return false end
	stats.EquippedWeapon = nil
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local weaponValue = leaderstats:FindFirstChild("Weapon")
		if weaponValue then
			weaponValue:Destroy()
		end
	end
	return true
end

function PlayerStats.GetWeapon(player)
	local stats = playerData[player.UserId]
	if not stats or not stats.EquippedWeapon then return nil end
	return stats.EquippedWeapon
end

function PlayerStats.ResetPlayer(player)
	local stats = playerData[player.UserId]
	if not stats then return end
	
	-- 重置为初始属性
	for k, v in pairs(PlayerConfig.InitialStats) do
		stats[k] = v
	end
	
	-- 清除武器
	stats.EquippedWeapon = nil
	
	-- 更新 leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local statNames = { "Health", "MaxHealth", "Strength", "Agility", "Intelligence", "Level", "Experience", "Bombs", "HealthPotions", "InvisibilityPotions", "Chest" }
		for _, statName in ipairs(statNames) do
			local statValue = leaderstats:FindFirstChild(statName)
			if statValue then
				statValue.Value = stats[statName] or 0
			end
		end
		
		-- 移除武器值
		local weaponValue = leaderstats:FindFirstChild("Weapon")
		if weaponValue then
			weaponValue:Destroy()
		end
	end
	
	print("🔄 玩家属性已重置:", player.Name)
end

-- 储存玩家快照（死亡前保存，复活后恢复）
local playerSnapshots = {}

function PlayerStats.SaveSnapshot(player)
	local stats = playerData[player.UserId]
	if not stats then return nil end
	
	local snapshot = {}
	for k, v in pairs(stats) do
		snapshot[k] = v
	end
	playerSnapshots[player.UserId] = snapshot
	print("💾 保存玩家快照:", player.Name, "等级:", snapshot.Level)
	return snapshot
end

function PlayerStats.RestoreSnapshot(player)
	local snapshot = playerSnapshots[player.UserId]
	if not snapshot then
		print("⚠️ 没有快照，使用初始属性")
		return false
	end
	
	local stats = playerData[player.UserId]
	if not stats then return false end
	
	-- 恢复所有属性（包括武器）
	for k, v in pairs(snapshot) do
		stats[k] = v
	end
	
	-- 清除快照
	playerSnapshots[player.UserId] = nil
	
	-- 更新 leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local statNames = { "Health", "MaxHealth", "Strength", "Agility", "Intelligence", "Level", "Experience", "Bombs", "HealthPotions", "InvisibilityPotions", "Chest" }
		for _, statName in ipairs(statNames) do
			local statValue = leaderstats:FindFirstChild(statName)
			if statValue then
				statValue.Value = stats[statName] or 0
			end
		end
		
		-- 恢复武器标记
		if snapshot.EquippedWeapon then
			local weaponValue = leaderstats:FindFirstChild("Weapon")
			if not weaponValue then
				weaponValue = Instance.new("StringValue")
				weaponValue.Name = "Weapon"
				weaponValue.Parent = leaderstats
			end
			weaponValue.Value = snapshot.EquippedWeapon
		end
	end
	
	print("🔄 恢复玩家快照:", player.Name, "等级:", snapshot.Level)
	return true
end

-- ============ 炸弹库存管理 ============

local MAX_BOMBS = 3

function PlayerStats.AddBomb(player)
	local stats = playerData[player.UserId]
	if not stats then return false end
	local bombs = stats.Bombs or 0
	if bombs >= MAX_BOMBS then
		print("💣 炸弹已满 (最大3个)")
		return false
	end
	stats.Bombs = bombs + 1
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local bombValue = leaderstats:FindFirstChild("Bombs")
		if bombValue then
			bombValue.Value = stats.Bombs
		end
	end
	print("💣 拾取炸弹, 当前数量:", stats.Bombs)
	return true
end

function PlayerStats.RemoveBomb(player)
	local stats = playerData[player.UserId]
	if not stats then return false end
	local bombs = stats.Bombs or 0
	if bombs <= 0 then return false end
	stats.Bombs = bombs - 1
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local bombValue = leaderstats:FindFirstChild("Bombs")
		if bombValue then
			bombValue.Value = stats.Bombs
		end
	end
	return true
end

function PlayerStats.GetBombCount(player)
	local stats = playerData[player.UserId]
	if not stats then return 0 end
	return stats.Bombs or 0
end

-- ============ 药水库存管理 ============

local MAX_HEALTH_POTIONS = 10
local MAX_INVIS_POTIONS = 5

function PlayerStats.AddHealthPotion(player)
	local stats = playerData[player.UserId]
	if not stats then return false end
	local count = stats.HealthPotions or 0
	if count >= MAX_HEALTH_POTIONS then
		print("❤️ 生命药水已满 (最大10个)")
		return false
	end
	stats.HealthPotions = count + 1
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local val = leaderstats:FindFirstChild("HealthPotions")
		if val then val.Value = stats.HealthPotions end
	end
	print("❤️ 拾取生命药水, 当前:", stats.HealthPotions)
	return true
end

function PlayerStats.RemoveHealthPotion(player)
	local stats = playerData[player.UserId]
	if not stats then return false end
	local count = stats.HealthPotions or 0
	if count <= 0 then return false end
	stats.HealthPotions = count - 1
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local val = leaderstats:FindFirstChild("HealthPotions")
		if val then val.Value = stats.HealthPotions end
	end
	return true
end

function PlayerStats.GetHealthPotionCount(player)
	local stats = playerData[player.UserId]
	if not stats then return 0 end
	return stats.HealthPotions or 0
end

function PlayerStats.AddInvisibilityPotion(player)
	local stats = playerData[player.UserId]
	if not stats then return false end
	local count = stats.InvisibilityPotions or 0
	if count >= MAX_INVIS_POTIONS then
		print("👻 隐形药水已满 (最大5个)")
		return false
	end
	stats.InvisibilityPotions = count + 1
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local val = leaderstats:FindFirstChild("InvisibilityPotions")
		if val then val.Value = stats.InvisibilityPotions end
	end
	print("👻 拾取隐形药水, 当前:", stats.InvisibilityPotions)
	return true
end

function PlayerStats.RemoveInvisibilityPotion(player)
	local stats = playerData[player.UserId]
	if not stats then return false end
	local count = stats.InvisibilityPotions or 0
	if count <= 0 then return false end
	stats.InvisibilityPotions = count - 1
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local val = leaderstats:FindFirstChild("InvisibilityPotions")
		if val then val.Value = stats.InvisibilityPotions end
	end
	return true
end

function PlayerStats.GetInvisibilityPotionCount(player)
	local stats = playerData[player.UserId]
	if not stats then return 0 end
	return stats.InvisibilityPotions or 0
end

-- ============ 箱子库存管理（最多1个） ============

local MAX_CHEST = 1

function PlayerStats.AddChest(player)
	local stats = playerData[player.UserId]
	if not stats then return false end
	local chests = stats.Chest or 0
	if chests >= MAX_CHEST then
		print("📦 箱子已满 (最多1个)")
		return false
	end
	stats.Chest = chests + 1
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local val = leaderstats:FindFirstChild("Chest")
		if val then val.Value = stats.Chest end
	end
	print("📦 拾取箱子, 当前:", stats.Chest)
	return true
end

function PlayerStats.RemoveChest(player)
	local stats = playerData[player.UserId]
	if not stats then return false end
	local chests = stats.Chest or 0
	if chests <= 0 then return false end
	stats.Chest = chests - 1
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local val = leaderstats:FindFirstChild("Chest")
		if val then val.Value = stats.Chest end
	end
	return true
end

function PlayerStats.GetChestCount(player)
	local stats = playerData[player.UserId]
	if not stats then return 0 end
	return stats.Chest or 0
end

-- 保存拾取箱子的内容（用于重新放置时恢复）
function PlayerStats.SetChestContents(player, contents)
	local stats = playerData[player.UserId]
	if not stats then return false end
	stats.ChestContents = contents
	print("📦 [PlayerStats] 保存箱子内容, 玩家:", player.Name)
	return true
end

-- 获取并清除保存的箱子内容
function PlayerStats.GetChestContents(player)
	local stats = playerData[player.UserId]
	if not stats then return nil end
	local contents = stats.ChestContents
	stats.ChestContents = nil
	if contents then
		print("📦 [PlayerStats] 获取箱子内容, 玩家:", player.Name)
	end
	return contents
end

-- ============ 隐身状态管理 ============

function PlayerStats.SetInvisible(player, invisible)
	local stats = playerData[player.UserId]
	if not stats then return end
	stats.IsInvisible = invisible
end

function PlayerStats.IsPlayerInvisible(player)
	local stats = playerData[player.UserId]
	if not stats then return false end
	return stats.IsInvisible or false
end

return PlayerStats

