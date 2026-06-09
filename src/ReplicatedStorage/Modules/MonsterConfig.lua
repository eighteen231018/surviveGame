
-- 怪物配置文件 - 定义各种怪物的属性
local MonsterConfig = {}

MonsterConfig.Types = {
	Scorpion = {
		Name = "蝎子",
		Health = 50,
		MaxHealth = 50,
		Damage = 10,
		Speed = 8,
		AttackRange = 5,
		AttackInterval = 1.5,
		ExpReward = 20,
		Color = Color3.new(0.7, 0.5, 0.2),
		AlertRange = 22,
		ChaseRange = 35
	},
	
	Spider = {
		Name = "蜘蛛",
		Health = 30,
		MaxHealth = 30,
		Damage = 8,
		Speed = 12,
		AttackRange = 4,
		AttackInterval = 1,
		ExpReward = 15,
		Color = Color3.new(0.2, 0.2, 0.2),
		AlertRange = 20,
		ChaseRange = 30
	},
	
	SkeletonBoss = {
		Name = "骷髅BOSS",
		Health = 200,
		MaxHealth = 200,
		Damage = 25,
		Speed = 6,
		AttackRange = 8,
		AttackInterval = 2,
		ExpReward = 100,
		Color = Color3.new(0.9, 0.9, 0.9),
		AlertRange = 25,
		ChaseRange = 40
	}
}

return MonsterConfig
