
-- 巢穴配置文件 - 定义各种巢穴的属性和生成规则
local NestConfig = {}

NestConfig.Types = {
	SpiderNest = {
		Name = "蜘蛛巢穴",
		Health = 200,
		MaxHealth = 200,
		SpawnInterval = 15,
		MaxMonsters = 3,
		SpawnRadius = 10,
		AlertRadius = 30,
		MonsterTypes = {
			{Type = "Spider", Weight = 1}
		},
		SpawnMode = "Weighted",
		Color = Color3.new(0.2, 0.2, 0.2),
		Size = Vector3.new(6, 5, 6),
		MaxCount = 2
	},
	
	ScorpionNest = {
		Name = "蝎子巢穴",
		Health = 200,
		MaxHealth = 200,
		SpawnInterval = 15,
		MaxMonsters = 3,
		SpawnRadius = 10,
		AlertRadius = 30,
		MonsterTypes = {
			{Type = "Scorpion", Weight = 1}
		},
		SpawnMode = "Weighted",
		Color = Color3.new(0.7, 0.5, 0.2),
		Size = Vector3.new(6, 5, 6),
		MaxCount = 2
	},
	
	SkeletonBossNest = {
		Name = "骷髅BOSS巢穴",
		Health = 500,
		MaxHealth = 500,
		SpawnInterval = 15,
		MaxMonsters = 1,
		SpawnRadius = 15,
		AlertRadius = 40,
		MonsterTypes = {
			{Type = "SkeletonBoss", Weight = 1}
		},
		SpawnMode = "Weighted",
		Color = Color3.new(0.9, 0.9, 0.9),
		Size = Vector3.new(10, 8, 10),
		MaxCount = 2
	}
}

-- 地图随机生成范围
NestConfig.SpawnArea = {
	MinX = -60,
	MaxX = 60,
	MinZ = -60,
	MaxZ = 60,
	MinDistance = 20  -- 巢穴之间的最小距离
}

return NestConfig
