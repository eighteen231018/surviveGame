-- 受击反应配置文件 - 集中管理所有受击效果参数
local HitEffectConfig = {}

-- ================ 通用受击效果 ================
HitEffectConfig.HitFlash = {
	FlashColor = Color3.new(1, 0, 0),       -- 闪红颜色
	MonsterFlashDuration = 0.2,              -- 怪物闪红持续时间（秒）
	NestFlashDuration = 0.3,                 -- 巢穴闪红持续时间（秒）
	PlayerFlashDuration = 0.15,              -- 玩家闪红持续时间（秒）
}

-- ================ 受击音效 ================
-- 填入你的音效资源ID（格式：rbxassetid://数字）
-- 留空则静音
HitEffectConfig.HitSound = {
	Volume = 0.6,                            -- 音效音量
	Pitch = 1.0,                             -- 音效音调
	MonsterHit = "",                         -- 怪物受击音效（例："rbxassetid://1234567890"）
	NestHit = "",                            -- 巢穴受击音效
	PlayerHit = "",                          -- 玩家受击音效
	MonsterDeath = "",                       -- 怪物死亡音效
	NestDestroy = "",                        -- 巢穴摧毁音效
}

-- ================ 受击粒子/视觉特效 ================
HitEffectConfig.HitParticles = {
	Enabled = true,                          -- 是否启用粒子特效
	SparksCount = 6,                         -- 火花数量
	SparksSpeed = 8,                         -- 火花速度
	SparksLifetime = 0.5,                    -- 火花存在时间
	SparkSize = Vector3.new(0.3, 0.3, 0.3), -- 火花大小
	SparkColor = Color3.new(1, 0.8, 0.2),   -- 火花颜色
}

-- ================ 玩家屏幕效果 ================
HitEffectConfig.PlayerScreenEffect = {
	Enabled = true,                          -- 是否启用屏幕效果
	ScreenFlashColor = Color3.new(1, 0, 0), -- 屏幕闪红颜色
	ScreenFlashDuration = 0.15,              -- 屏幕闪红持续时间（秒）
	ScreenFlashTransparency = 0.5,           -- 屏幕闪红透明度
	CameraShakeEnabled = true,               -- 是否启用镜头震动
	CameraShakeMagnitude = 0.3,              -- 镜头震动幅度
	CameraShakeDuration = 0.15,              -- 镜头震动持续时间（秒）
}

-- ================ 击退效果 ================
HitEffectConfig.Knockback = {
	Enbled = true,                           -- 是否启用击退
	MonsterKnockbackForce = 8,               -- 怪物击退力
	PlayerKnockbackForce = 10,               -- 玩家击退力
}

return HitEffectConfig