-- 受击反应系统 - 服务端/共享端逻辑
-- 提供通用的受击视觉、音效、特效函数
local HitEffectSystem = {}
local HitEffectConfig = require(script.Parent.HitEffectConfig)

-- ============================================================
-- 通用辅助函数
-- ============================================================

-- 获取Model中所有可见的BasePart
local function getVisibleParts(model)
	local parts = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			table.insert(parts, part)
		end
	end
	return parts
end

-- 保存并恢复Model中所有可见Part的颜色（闪红效果）
function HitEffectSystem.FlashModelRed(model, duration)
	local parts = getVisibleParts(model)
	if #parts == 0 then return end

	-- 保存原始颜色/材质
	local originals = {}
	for _, part in ipairs(parts) do
		table.insert(originals, {
			Part = part,
			Color = part.Color,
			BrickColor = part.BrickColor,
		})
		-- 设为红色
		local success, err = pcall(function()
			part.Color = HitEffectConfig.HitFlash.FlashColor
		end)
		if not success then
			part.BrickColor = BrickColor.Red()
		end
	end

	-- 等待后还原
	task.delay(duration or 0.2, function()
		for _, orig in ipairs(originals) do
			local p = orig.Part
			if p and p.Parent then
				pcall(function()
					p.Color = orig.Color
					p.BrickColor = orig.BrickColor
				end)
			end
		end
	end)
end

-- 在指定位置播放音效（如果 SoundId 为空则静音）
function HitEffectSystem.PlayHitSound(position, soundId, volume, pitch)
	local sid = soundId or HitEffectConfig.HitSound.MonsterHit
	if not sid or sid == "" then return end  -- 没有配置音效ID，静音跳过

	local success, sound = pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = sid
		s.Volume = volume or HitEffectConfig.HitSound.Volume
		s.Pitch = pitch or HitEffectConfig.HitSound.Pitch
		return s
	end)

	if not success or not sound then return end

	-- 把Sound放到靠近位置的地方
	local soundPart = Instance.new("Part")
	soundPart.Name = "TempSoundPart"
	soundPart.Size = Vector3.new(1, 1, 1)
	soundPart.Position = position
	soundPart.Transparency = 1
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.Parent = workspace

	sound.Parent = soundPart

	sound:Play()

	-- 播放完毕后清理
	local conn
	conn = sound.Ended:Connect(function()
		sound:Destroy()
		soundPart:Destroy()
		conn:Disconnect()
	end)

	-- 安全兜底：5秒后强制清理
	task.delay(5, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
		if soundPart and soundPart.Parent then
			soundPart:Destroy()
		end
	end)
end

-- 创建受击火花粒子特效
function HitEffectSystem.CreateHitParticles(position)
	if not HitEffectConfig.HitParticles.Enabled then return end

	local config = HitEffectConfig.HitParticles
	local count = config.SparksCount
	local speed = config.SparksSpeed

	for i = 1, count do
		local spark = Instance.new("Part")
		spark.Size = config.SparkSize
		spark.Position = position
		spark.Color = config.SparkColor
		spark.Material = Enum.Material.Neon
		spark.Shape = Enum.PartType.Ball
		spark.Anchored = false
		spark.CanCollide = false
		spark.Parent = workspace

		-- 随机方向
		local dir = Vector3.new(
			(math.random() - 0.5) * 2,
			(math.random() - 0.5) * 2,
			(math.random() - 0.5) * 2
		).Unit

		-- 添加 BodyVelocity 让火花飞出去
		local bv = Instance.new("BodyVelocity")
		bv.Velocity = dir * speed
		bv.MaxForce = Vector3.new(10000, 10000, 10000)
		bv.Parent = spark

		-- 上抛力
		local bg = Instance.new("BodyPosition")
		bg.Position = spark.Position + Vector3.new(0, speed * 0.3, 0)
		bg.MaxForce = Vector3.new(0, 10000, 0)
		bg.P = 5000
		task.delay(0.05, function()
			bg:Destroy()
		end)

		-- 逐渐消失并删除
		local startTime = tick()
		local conn
		conn = game:GetService("RunService").Heartbeat:Connect(function()
			local elapsed = tick() - startTime
			local lifetime = config.SparksLifetime
			if elapsed >= lifetime or not spark.Parent then
				if conn then conn:Disconnect() end
				if spark and spark.Parent then
					spark:Destroy()
				end
				return
			end
			spark.Transparency = elapsed / lifetime
			spark.Size = config.SparkSize * (1 - elapsed / lifetime * 0.5)
		end)
	end
end

-- ============================================================
-- 高级组合效果
-- ============================================================

-- 怪物受击
function HitEffectSystem.MonsterHitEffect(monsterModel, hitPosition)
	if not monsterModel then return end
	HitEffectSystem.FlashModelRed(monsterModel, HitEffectConfig.HitFlash.MonsterFlashDuration)
	HitEffectSystem.PlayHitSound(hitPosition, HitEffectConfig.HitSound.MonsterHit)
	HitEffectSystem.CreateHitParticles(hitPosition)
end

-- 怪物死亡
function HitEffectSystem.MonsterDeathEffect(monsterModel, hitPosition)
	if not monsterModel then return end
	HitEffectSystem.PlayHitSound(hitPosition, HitEffectConfig.HitSound.MonsterDeath)
	-- 死亡时创建更多粒子
	for i = 1, 8 do
		local particlePos = hitPosition + Vector3.new(
			(math.random() - 0.5) * 2,
			math.random() * 2,
			(math.random() - 0.5) * 2
		)
		HitEffectSystem.CreateHitParticles(particlePos)
		if i < 8 then
			task.wait(0.03)
		end
	end
end

-- 巢穴受击
function HitEffectSystem.NestHitEffect(nestModel, hitPosition)
	if not nestModel then return end
	HitEffectSystem.FlashModelRed(nestModel, HitEffectConfig.HitFlash.NestFlashDuration)
	HitEffectSystem.PlayHitSound(hitPosition, HitEffectConfig.HitSound.NestHit)
	HitEffectSystem.CreateHitParticles(hitPosition)
end

-- 巢穴摧毁
function HitEffectSystem.NestDestroyEffect(nestPosition)
	HitEffectSystem.PlayHitSound(nestPosition, HitEffectConfig.HitSound.NestDestroy)
	for i = 1, 12 do
		local particlePos = nestPosition + Vector3.new(
			(math.random() - 0.5) * 4,
			math.random() * 3,
			(math.random() - 0.5) * 4
		)
		HitEffectSystem.CreateHitParticles(particlePos)
		if i < 12 then
			task.wait(0.05)
		end
	end
end

-- 玩家受击（服务端触发，通过RemoteEvent通知客户端）
function HitEffectSystem.PlayerHitEffect(player, hitPosition)
	HitEffectSystem.PlayHitSound(hitPosition, HitEffectConfig.HitSound.PlayerHit)
end

return HitEffectSystem