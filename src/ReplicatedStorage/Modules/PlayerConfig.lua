
-- 玩家配置文件 - 集中管理所有玩家相关配置
local PlayerConfig = {}

-- 初始属性值
PlayerConfig.InitialStats = {
	Health = 100,
	MaxHealth = 100,
	Strength = 10,
	Agility = 10,
	Intelligence = 10,
	Level = 1,
	Experience = 0
}

-- 升级属性成长值
PlayerConfig.StatGrowth = {
	Health = 20,
	Strength = 3,
	Agility = 2,
	Intelligence = 2
}

-- 经验配置
function PlayerConfig.GetRequiredExp(level)
	return 100 * math.pow(1.5, level - 1)
end

-- 攻击相关配置
PlayerConfig.Attack = {
	BaseDamage = 10,           -- 基础伤害
	StrengthDamageMultiplier = 1.5,  -- 力量伤害系数
	BaseRange = 10,            -- 基础攻击范围
	AgilityRangeMultiplier = 0.5,    -- 敏捷范围系数
	BaseInterval = 1.5,        -- 基础攻击间隔（秒）
	AgilityIntervalMultiplier = 0.03, -- 敏捷攻击间隔系数（每点敏捷减少0.03秒）
	MinInterval = 0.2          -- 最小攻击间隔（秒）
}

-- 巢穴击杀经验奖励配置
PlayerConfig.NestExpReward = {
	BaseExp = 30,      -- 基础经验
	LevelBonus = 5     -- 每级额外经验
}

-- 药水回复配置
PlayerConfig.Potion = {
	BaseHeal = 30,              -- 药水基础回复量
	IntelligenceHealMultiplier = 3,  -- 每点智力额外回复量
}

-- 生命药水配置
PlayerConfig.HealthPotion = {
	BaseHeal = 30,
	IntelligenceHealMultiplier = 3,
	UseTime = 1,
	MaxStack = 10
}

-- 隐形药水配置
PlayerConfig.InvisibilityPotion = {
	Duration = 10,
	UseTime = 1,
	MaxStack = 5
}

return PlayerConfig

