
-- 巢穴系统 - 服务端（只用简单模型版）
local NestSystem = {}
local Players = game:GetService("Players")
local NestConfig = require(game:GetService("ReplicatedStorage").Modules.NestConfig)
local MonsterConfig = require(game:GetService("ReplicatedStorage").Modules.MonsterConfig)
local WeaponSystem = require(game:GetService("ReplicatedStorage").Modules.WeaponSystem)
local BombSystem = require(game:GetService("ReplicatedStorage").Modules.BombSystem)
local PlayerStats = require(game:GetService("ReplicatedStorage").Modules.PlayerStats)
local HitEffectSystem = require(game:GetService("ReplicatedStorage").Modules.HitEffectSystem)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerHitEvent = ReplicatedStorage:WaitForChild("PlayerHitEvent")

local activeNests = {}
local nestCount = {}  -- 每种巢穴的数量统计
local lastNestSpawnTime = 0
local NEST_SPAWN_CHECK_INTERVAL = 15  -- 每15秒检查一次是否需要生成新巢穴
local pendingRespawns = {}

-- 初始化巢穴数量统计
local function initNestCount()
	for nestType, _ in pairs(NestConfig.Types) do
		nestCount[nestType] = 0
	end
end

-- 检查是否可以生成新巢穴
local function canSpawnNest(nestType)
	local config = NestConfig.Types[nestType]
	if not config then
		return false
	end
	return nestCount[nestType] < config.MaxCount
end

-- 检查位置是否可用（距离其他巢穴太近）
local function isPositionValid(pos)
	for _, nest in pairs(activeNests) do
		local distance = (nest.Position - pos).Magnitude
		if distance < NestConfig.SpawnArea.MinDistance then
			return false
		end
	end
	return true
end

-- 生成随机位置
local function getRandomPosition()
	local area = NestConfig.SpawnArea
	local x = math.random(area.MinX, area.MaxX)
	local z = math.random(area.MinZ, area.MaxZ)
	return Vector3.new(x, 0, z)
end

-- 尝试找到一个可用的随机位置
local function findValidPosition()
	for attempts = 1, 50 do
		local pos = getRandomPosition()
		if isPositionValid(pos) then
			return pos
		end
	end
	return nil
end

-- 随机选择一种可以生成的巢穴类型
local function selectRandomNestType()
	local availableTypes = {}
	for nestType, config in pairs(NestConfig.Types) do
		if canSpawnNest(nestType) then
			table.insert(availableTypes, nestType)
		end
	end
	
	if #availableTypes == 0 then
		return nil
	end
	
	return availableTypes[math.random(1, #availableTypes)]
end

-- ============ 洞穴外观创建函数 ============

-- 创建血条GUI（通用）
local function createHealthGUI(parent, name, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthGui"
	gui.Size = UDim2.new(0, 80, 0, 20)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "HealthLabel"
	healthLabel.Size = UDim2.new(1, 0, 1, 0)
	healthLabel.BackgroundTransparency = 0.5
	healthLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	healthLabel.TextColor3 = Color3.new(1, 1, 1)
	healthLabel.TextSize = 14
	healthLabel.Text = name
	healthLabel.Parent = gui

	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 0.3, 0)
	healthBar.Position = UDim2.new(0, 0, 0.7, 0)
	healthBar.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
	healthBar.Parent = gui

	return gui
end

-- 创建蜘蛛洞穴（黑暗岩石+蛛网）
local function createSpiderCaveVisual(config, position)
	local nestModel = Instance.new("Model")
	nestModel.Name = config.Name

	local s = config.Size
	local hw, hh, hd = s.X / 2, s.Y, s.Z / 2
	local rockColor = BrickColor.new("Dark stone grey")
	local darkColor = BrickColor.new("Black")

	local floor = Instance.new("Part")
	floor.Name = "NestPart"
	floor.Size = Vector3.new(s.X, 1, s.Z)
	floor.Position = position + Vector3.new(0, -0.5, 0)
	floor.BrickColor = darkColor
	floor.Anchored = true
	floor.Parent = nestModel

	local backWall = Instance.new("Part")
	backWall.Size = Vector3.new(s.X * 0.85, hh, 1.5)
	backWall.Position = position + Vector3.new(0, hh / 2 - 0.5, -hd + 0.75)
	backWall.BrickColor = rockColor
	backWall.Anchored = true
	backWall.Parent = nestModel

	local leftWall = Instance.new("Part")
	leftWall.Size = Vector3.new(1.5, hh, s.Z * 0.85)
	leftWall.Position = position + Vector3.new(-hw + 0.75, hh / 2 - 0.5, 0)
	leftWall.BrickColor = rockColor
	leftWall.Anchored = true
	leftWall.Parent = nestModel

	local rightWall = Instance.new("Part")
	rightWall.Size = Vector3.new(1.5, hh, s.Z * 0.85)
	rightWall.Position = position + Vector3.new(hw - 0.75, hh / 2 - 0.5, 0)
	rightWall.BrickColor = rockColor
	rightWall.Anchored = true
	rightWall.Parent = nestModel

	-- 左拱形顶部
	local leftArch = Instance.new("WedgePart")
	leftArch.Size = Vector3.new(hw * 0.7, hh * 0.35, 2)
	leftArch.Position = position + Vector3.new(-hw * 0.35, hh - hh * 0.175 - 0.5, -hd + 2.5)
	leftArch.BrickColor = rockColor
	leftArch.Anchored = true
	leftArch.Orientation = Vector3.new(0, 0, 90)
	leftArch.Parent = nestModel

	local rightArch = Instance.new("WedgePart")
	rightArch.Size = Vector3.new(hw * 0.7, hh * 0.35, 2)
	rightArch.Position = position + Vector3.new(hw * 0.35, hh - hh * 0.175 - 0.5, -hd + 2.5)
	rightArch.BrickColor = rockColor
	rightArch.Anchored = true
	rightArch.Orientation = Vector3.new(0, 0, -90)
	rightArch.Parent = nestModel

	local roof = Instance.new("Part")
	roof.Size = Vector3.new(hw * 1.2, 0.5, 2.5)
	roof.Position = position + Vector3.new(0, hh - 0.5, -hd + 2.5)
	roof.BrickColor = rockColor
	roof.Anchored = true
	roof.Parent = nestModel

	-- 蛛网（纵向丝线）
	for i = 1, 6 do
		local strand = Instance.new("Part")
		strand.Name = "WebV" .. i
		strand.Size = Vector3.new(0.12, 0.12, hd * 1.4)
		strand.Position = position + Vector3.new(-hw * 0.6 + (i - 1) * hw * 0.24, hh * 0.5, -hd * 0.1)
		strand.BrickColor = BrickColor.new("White")
		strand.Transparency = 0.45
		strand.Anchored = true
		strand.Parent = nestModel
	end

	-- 蛛网（横向丝线）
	for i = 1, 4 do
		local strand = Instance.new("Part")
		strand.Name = "WebH" .. i
		strand.Size = Vector3.new(hw * 1.3, 0.12, 0.12)
		strand.Position = position + Vector3.new(0, hh * 0.15 + (i - 1) * hh * 0.2, -hd * 0.1)
		strand.BrickColor = BrickColor.new("White")
		strand.Transparency = 0.45
		strand.Anchored = true
		strand.Parent = nestModel
	end

	-- 周围装饰石块
	for i = 1, 8 do
		local rock = Instance.new("Part")
		rock.Name = "Rock" .. i
		local rx = 1 + math.random() * 2.5
		local ry = 0.5 + math.random() * 1.5
		local rz = 1 + math.random() * 2.5
		rock.Size = Vector3.new(rx, ry, rz)
		local angle = (i / 8) * math.pi * 2
		local radius = hw + 1.8 + math.random() * 1.5
		rock.Position = position + Vector3.new(
			math.cos(angle) * radius,
			ry / 2,
			math.sin(angle) * radius
		)
		rock.BrickColor = rockColor
		rock.Anchored = true
		rock.Parent = nestModel
	end

	createHealthGUI(floor, config.Name, hh + 1)

	nestModel.Parent = game.Workspace
	return nestModel
end

-- 创建蝎子洞穴（砂岩洞穴）
local function createScorpionCaveVisual(config, position)
	local nestModel = Instance.new("Model")
	nestModel.Name = config.Name

	local s = config.Size
	local hw, hh, hd = s.X / 2, s.Y, s.Z / 2
	local sandColor = BrickColor.new("Bright yellow")
	local darkSand = BrickColor.new("Sand blue")

	local floor = Instance.new("Part")
	floor.Name = "NestPart"
	floor.Size = Vector3.new(s.X, 1, s.Z)
	floor.Position = position + Vector3.new(0, -0.5, 0)
	floor.BrickColor = sandColor
	floor.Anchored = true
	floor.Parent = nestModel

	local backWall = Instance.new("Part")
	backWall.Size = Vector3.new(s.X, hh * 0.6, 1.5)
	backWall.Position = position + Vector3.new(0, hh * 0.3 - 0.5, -hd + 0.75)
	backWall.BrickColor = darkSand
	backWall.Anchored = true
	backWall.Parent = nestModel

	-- 左侧岩石墙（用散落石块组成）
	for i = 1, 3 do
		local rock = Instance.new("Part")
		rock.Name = "LeftRock" .. i
		local rw = 1.5 + math.random() * 1.5
		local rh = 1 + math.random() * 2
		local rd = 1.5 + math.random() * 1.5
		rock.Size = Vector3.new(rw, rh, rd)
		rock.Position = position + Vector3.new(
			-hw + rw / 2,
			rh / 2 - 0.5,
			-hd + 1 + (i - 1) * (s.Z - 2) / 2
		)
		rock.BrickColor = sandColor
		rock.Anchored = true
		rock.Parent = nestModel
	end

	-- 右侧岩石墙
	for i = 1, 3 do
		local rock = Instance.new("Part")
		rock.Name = "RightRock" .. i
		local rw = 1.5 + math.random() * 1.5
		local rh = 1 + math.random() * 2
		local rd = 1.5 + math.random() * 1.5
		rock.Size = Vector3.new(rw, rh, rd)
		rock.Position = position + Vector3.new(
			hw - rw / 2,
			rh / 2 - 0.5,
			-hd + 1 + (i - 1) * (s.Z - 2) / 2
		)
		rock.BrickColor = sandColor
		rock.Anchored = true
		rock.Parent = nestModel
	end

	-- 顶部拱形（沙丘风格）
	local arch = Instance.new("Part")
	arch.Size = Vector3.new(hw * 1.6, 0.5, s.Z * 0.8)
	arch.Position = position + Vector3.new(0, hh * 0.5 - 0.5, 0)
	arch.BrickColor = darkSand
	arch.Anchored = true
	arch.Parent = nestModel

	-- 入口两侧柱
	for _, xSign in ipairs({-1, 1}) do
		local pillar = Instance.new("Part")
		pillar.Name = (xSign > 0) and "PillarR" or "PillarL"
		pillar.Size = Vector3.new(2, hh * 0.6, 2)
		pillar.Position = position + Vector3.new(xSign * (hw - 1.5), hh * 0.3 - 0.5, hd - 1)
		pillar.BrickColor = sandColor
		pillar.Anchored = true
		pillar.Parent = nestModel
	end

	-- 周围小石块
	for i = 1, 6 do
		local rock = Instance.new("Part")
		rock.Name = "Rock" .. i
		local rx = 0.8 + math.random() * 2
		local ry = 0.3 + math.random() * 1
		local rz = 0.8 + math.random() * 2
		rock.Size = Vector3.new(rx, ry, rz)
		local angle = (i / 6) * math.pi * 2
		local radius = hw + 2 + math.random() * 2
		rock.Position = position + Vector3.new(
			math.cos(angle) * radius,
			ry / 2,
			math.sin(angle) * radius
		)
		rock.BrickColor = sandColor
		rock.Anchored = true
		rock.Parent = nestModel
	end

	createHealthGUI(floor, config.Name, hh * 0.6 + 1)

	nestModel.Parent = game.Workspace
	return nestModel
end

-- 创建骷髅BOSS洞穴（大型石墓+白骨装饰）
local function createSkeletonCaveVisual(config, position)
	local nestModel = Instance.new("Model")
	nestModel.Name = config.Name

	local s = config.Size
	local hw, hh, hd = s.X / 2, s.Y, s.Z / 2
	local stoneColor = BrickColor.new("Medium stone grey")
	local boneColor = BrickColor.new("Institutional white")

	local floor = Instance.new("Part")
	floor.Name = "NestPart"
	floor.Size = Vector3.new(s.X, 1.5, s.Z)
	floor.Position = position + Vector3.new(0, -0.75, 0)
	floor.BrickColor = stoneColor
	floor.Anchored = true
	floor.Parent = nestModel

	local backWall = Instance.new("Part")
	backWall.Size = Vector3.new(s.X, hh, 2)
	backWall.Position = position + Vector3.new(0, hh / 2 - 0.75, -hd + 1)
	backWall.BrickColor = stoneColor
	backWall.Anchored = true
	backWall.Parent = nestModel

	local leftWall = Instance.new("Part")
	leftWall.Size = Vector3.new(2, hh, s.Z * 0.85)
	leftWall.Position = position + Vector3.new(-hw + 1, hh / 2 - 0.75, 0)
	leftWall.BrickColor = stoneColor
	leftWall.Anchored = true
	leftWall.Parent = nestModel

	local rightWall = Instance.new("Part")
	rightWall.Size = Vector3.new(2, hh, s.Z * 0.85)
	rightWall.Position = position + Vector3.new(hw - 1, hh / 2 - 0.75, 0)
	rightWall.BrickColor = stoneColor
	rightWall.Anchored = true
	rightWall.Parent = nestModel

	-- 大门柱（左侧）
	local leftPillar = Instance.new("Part")
	leftPillar.Size = Vector3.new(3, hh, 3)
	leftPillar.Position = position + Vector3.new(-hw + 2.5, hh / 2 - 0.75, hd - 2)
	leftPillar.BrickColor = stoneColor
	leftPillar.Anchored = true
	leftPillar.Parent = nestModel

	-- 大门柱（右侧）
	local rightPillar = Instance.new("Part")
	rightPillar.Size = Vector3.new(3, hh, 3)
	rightPillar.Position = position + Vector3.new(hw - 2.5, hh / 2 - 0.75, hd - 2)
	rightPillar.BrickColor = stoneColor
	rightPillar.Anchored = true
	rightPillar.Parent = nestModel

	-- 横梁（门楣）
	local lintel = Instance.new("Part")
	lintel.Size = Vector3.new(hw * 1.2, 1.5, 3)
	lintel.Position = position + Vector3.new(0, hh - 0.75, hd - 2)
	lintel.BrickColor = stoneColor
	lintel.Anchored = true
	lintel.Parent = nestModel

	-- 左柱白骨装饰
	for i = 1, 3 do
		local bone = Instance.new("Part")
		bone.Name = "BoneL" .. i
		bone.Size = Vector3.new(0.6, 1.2, 0.6)
		bone.Position = position + Vector3.new(-hw + 2.5, 1 + (i - 1) * ((hh - 3) / 2), hd - 1)
		bone.BrickColor = boneColor
		bone.Anchored = true
		bone.Shape = Enum.PartType.Cylinder
		bone.Parent = nestModel
	end

	-- 右柱白骨装饰
	for i = 1, 3 do
		local bone = Instance.new("Part")
		bone.Name = "BoneR" .. i
		bone.Size = Vector3.new(0.6, 1.2, 0.6)
		bone.Position = position + Vector3.new(hw - 2.5, 1 + (i - 1) * ((hh - 3) / 2), hd - 1)
		bone.BrickColor = boneColor
		bone.Anchored = true
		bone.Shape = Enum.PartType.Cylinder
		bone.Parent = nestModel
	end

	-- 顶部骷髅标志
	local skullBase = Instance.new("Part")
	skullBase.Size = Vector3.new(2, 1.5, 1.5)
	skullBase.Position = position + Vector3.new(0, hh + 1, hd - 2)
	skullBase.BrickColor = boneColor
	skullBase.Anchored = true
	skullBase.Parent = nestModel

	-- 周围立柱
	for i = 1, 4 do
		local pillar = Instance.new("Part")
		pillar.Name = "DecoPillar" .. i
		pillar.Size = Vector3.new(1.5, 2 + math.random() * 2, 1.5)
		local angle = (i / 4) * math.pi * 2
		local radius = hw + 3
		pillar.Position = position + Vector3.new(
			math.cos(angle) * radius,
			1,
			math.sin(angle) * radius
		)
		pillar.BrickColor = stoneColor
		pillar.Anchored = true
		pillar.Parent = nestModel
	end

	createHealthGUI(floor, config.Name, hh + 2)

	nestModel.Parent = game.Workspace
	return nestModel
end

-- 创建巢穴可视化（主入口 - 根据类型分发到不同的洞穴创建函数）
local function createNestVisual(nestConfig, position, nestType)
	if nestType == "SpiderNest" then
		return createSpiderCaveVisual(nestConfig, position)
	elseif nestType == "ScorpionNest" then
		return createScorpionCaveVisual(nestConfig, position)
	elseif nestType == "SkeletonBossNest" then
		return createSkeletonCaveVisual(nestConfig, position)
	end

	-- 回退方案：保持原本的简单方块
	local nestModel = Instance.new("Model")
	nestModel.Name = nestConfig.Name

	local mainPart = Instance.new("Part")
	mainPart.Name = "NestPart"
	mainPart.Size = nestConfig.Size
	mainPart.Position = position
	mainPart.BrickColor = BrickColor.new(nestConfig.Color)
	mainPart.Anchored = true
	mainPart.Parent = nestModel

	local topPart = Instance.new("Part")
	topPart.Name = "TopPart"
	topPart.Size = Vector3.new(nestConfig.Size.X * 0.8, 1, nestConfig.Size.Z * 0.8)
	topPart.Position = position + Vector3.new(0, nestConfig.Size.Y / 2, 0)
	topPart.BrickColor = BrickColor.new(nestConfig.Color)
	topPart.Anchored = true
	topPart.Parent = nestModel

	createHealthGUI(mainPart, nestConfig.Name, nestConfig.Size.Y)

	nestModel.Parent = game.Workspace
	return nestModel
end

-- 根据权重选择怪物类型
local function selectMonsterByWeight(monsterTypes)
	local totalWeight = 0
	for _, monster in ipairs(monsterTypes) do
		totalWeight = totalWeight + monster.Weight
	end
	
	local random = math.random() * totalWeight
	local current = 0
	
	for _, monster in ipairs(monsterTypes) do
		current = current + monster.Weight
		if random <= current then
			return monster.Type
		end
	end
	
	return monsterTypes[1].Type
end

-- 数一下某个巢穴现在有多少活着的怪物（超级直接版）
local function countAliveMonsters(nest)
	local count = 0
	for _, child in ipairs(game.Workspace:GetChildren()) do
		if child:IsA("Model") then
			local nestIdValue = child:FindFirstChild("OwningNestId")
			if nestIdValue and nestIdValue.Value == nest.Id then
				count = count + 1
			end
		end
	end
	return count
end

-- 创建蜘蛛模型
local function createSpiderModel(position, color)
	local monsterModel = Instance.new("Model")
	
	-- 蜘蛛的主身体
	local mainBody = Instance.new("Part")
	mainBody.Name = "MainBody"
	mainBody.Size = Vector3.new(2, 1.5, 2.5)
	mainBody.Position = position + Vector3.new(0, 1, 0)
	mainBody.BrickColor = BrickColor.new(color)
	mainBody.Anchored = false
	mainBody.Parent = monsterModel
	
	-- 蜘蛛的头部
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.2, 1.5)
	head.Position = position + Vector3.new(0, 1.8, 1.5)
	head.BrickColor = BrickColor.new(color)
	head.Anchored = false
	head.Parent = monsterModel
	
	-- 焊接头部到身体
	local weldHead = Instance.new("WeldConstraint")
	weldHead.Part0 = mainBody
	weldHead.Part1 = head
	weldHead.Parent = mainBody
	
	-- 添加8条腿
	local legAngles = {0, 45, 90, 135, 180, 225, 270, 315} -- 8条腿的角度
	for i, angle in ipairs(legAngles) do
		local leg = Instance.new("Part")
		leg.Name = "Leg" .. i
		leg.Size = Vector3.new(0.3, 0.3, 2.5) -- 细长的腿
		leg.BrickColor = BrickColor.new(color)
		leg.Anchored = false
		leg.Parent = monsterModel
		
		-- 计算腿的位置和方向
		local radAngle = math.rad(angle)
		local legOffset = Vector3.new(math.sin(radAngle) * 1.5, 0.5, math.cos(radAngle) * 1.5)
		leg.Position = position + legOffset
		
		-- 旋转腿以对应角度
		leg.Orientation = Vector3.new(0, angle, 45)
		
		-- 焊接腿到身体
		local weldLeg = Instance.new("WeldConstraint")
		weldLeg.Part0 = mainBody
		weldLeg.Part1 = leg
		weldLeg.Parent = mainBody
	end
	
	-- 添加一些小的装饰（眼睛）
	local eye1 = Instance.new("Part")
	eye1.Name = "Eye1"
	eye1.Size = Vector3.new(0.3, 0.3, 0.3)
	eye1.Position = position + Vector3.new(-0.4, 2.2, 2.2)
	eye1.BrickColor = BrickColor.new("Red")
	eye1.Anchored = false
	eye1.Parent = monsterModel
	
	local weldEye1 = Instance.new("WeldConstraint")
	weldEye1.Part0 = head
	weldEye1.Part1 = eye1
	weldEye1.Parent = head
	
	local eye2 = Instance.new("Part")
	eye2.Name = "Eye2"
	eye2.Size = Vector3.new(0.3, 0.3, 0.3)
	eye2.Position = position + Vector3.new(0.4, 2.2, 2.2)
	eye2.BrickColor = BrickColor.new("Red")
	eye2.Anchored = false
	eye2.Parent = monsterModel
	
	local weldEye2 = Instance.new("WeldConstraint")
	weldEye2.Part0 = head
	weldEye2.Part1 = eye2
	weldEye2.Parent = head
	
	return monsterModel
end

-- 创建蝎子模型（由一节节组成）
local function createScorpionModel(position, color)
	local monsterModel = Instance.new("Model")

	local pos = position
	local scpColor = color
	local stingerColor = "Bright red"

	-- 头胸部（前体）
	local cephalothorax = Instance.new("Part")
	cephalothorax.Name = "Cephalothorax"
	cephalothorax.Size = Vector3.new(2.6, 0.9, 1.6)
	cephalothorax.Position = pos + Vector3.new(0, 0.8, 0.6)
	cephalothorax.BrickColor = BrickColor.new(scpColor)
	cephalothorax.Anchored = false
	cephalothorax.Parent = monsterModel

	-- 腹部体节（中体，4节）
	local mesoSegs = {}
	local mesoPositions = {
		{x = 0, y = 0.75, z = -0.35, sx = 2.3, sy = 0.7, sz = 0.7},
		{x = 0, y = 0.7, z = -0.95, sx = 2.0, sy = 0.6, sz = 0.7},
		{x = 0, y = 0.65, z = -1.5, sx = 1.6, sy = 0.55, sz = 0.65},
		{x = 0, y = 0.6, z = -2.0, sx = 1.2, sy = 0.5, sz = 0.6},
	}
	for i, mp in ipairs(mesoPositions) do
		local seg = Instance.new("Part")
		seg.Name = "Meso" .. i
		seg.Size = Vector3.new(mp.sx, mp.sy, mp.sz)
		seg.Position = pos + Vector3.new(mp.x, mp.y, mp.z)
		seg.BrickColor = BrickColor.new(scpColor)
		seg.Anchored = false
		seg.Parent = monsterModel
		mesoSegs[i] = seg
	end

	-- 焊接腹部体节
	local weldMeso1 = Instance.new("WeldConstraint")
	weldMeso1.Part0 = cephalothorax
	weldMeso1.Part1 = mesoSegs[1]
	weldMeso1.Parent = cephalothorax
	for i = 1, #mesoSegs - 1 do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = mesoSegs[i]
		weld.Part1 = mesoSegs[i + 1]
		weld.Parent = mesoSegs[i]
	end

	-- 尾巴体节（后体，5节，逐渐向上弯曲）
	local tailSegs = {}
	local tailPositions = {
		{x = 0, y = 0.65, z = -2.5, sy = 0.5},
		{x = 0, y = 1.0, z = -2.8, sy = 0.45},
		{x = 0, y = 1.5, z = -2.8, sy = 0.45},
		{x = 0, y = 2.0, z = -2.55, sy = 0.4},
		{x = 0, y = 2.4, z = -2.2, sy = 0.35},
	}
	local tailThickness = {0.55, 0.5, 0.45, 0.4, 0.35}
	for i, tp in ipairs(tailPositions) do
		local seg = Instance.new("Part")
		seg.Name = "Tail" .. i
		seg.Size = Vector3.new(tailThickness[i], tp.sy, tailThickness[i])
		seg.Position = pos + Vector3.new(tp.x, tp.y, tp.z)
		seg.BrickColor = BrickColor.new(scpColor)
		seg.Anchored = false
		seg.Shape = Enum.PartType.Cylinder
		seg.Parent = monsterModel
		tailSegs[i] = seg
	end

	local weldTail = Instance.new("WeldConstraint")
	weldTail.Part0 = mesoSegs[#mesoSegs]
	weldTail.Part1 = tailSegs[1]
	weldTail.Parent = mesoSegs[#mesoSegs]
	for i = 1, #tailSegs - 1 do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = tailSegs[i]
		weld.Part1 = tailSegs[i + 1]
		weld.Parent = tailSegs[i]
	end

	-- 毒刺
	local stinger = Instance.new("Part")
	stinger.Name = "Stinger"
	stinger.Size = Vector3.new(0.5, 0.5, 0.6)
	stinger.Position = pos + Vector3.new(0, 2.7, -1.8)
	stinger.BrickColor = BrickColor.new(stingerColor)
	stinger.Anchored = false
	stinger.Parent = monsterModel

	local weldStinger = Instance.new("WeldConstraint")
	weldStinger.Part0 = tailSegs[#tailSegs]
	weldStinger.Part1 = stinger
	weldStinger.Parent = tailSegs[#tailSegs]

	local stingerTip = Instance.new("Part")
	stingerTip.Name = "StingerTip"
	stingerTip.Size = Vector3.new(0.25, 0.25, 0.35)
	stingerTip.Position = pos + Vector3.new(0, 2.6, -1.5)
	stingerTip.BrickColor = BrickColor.new(stingerColor)
	stingerTip.Anchored = false
	stingerTip.Parent = monsterModel

	local weldStingerTip = Instance.new("WeldConstraint")
	weldStingerTip.Part0 = stinger
	weldStingerTip.Part1 = stingerTip
	weldStingerTip.Parent = stinger

	-- 大钳子（螯肢）
	local clawData = {
		{side = -1, prefix = "Left"},
		{side = 1, prefix = "Right"},
	}
	for _, cd in ipairs(clawData) do
		local s = cd.side
		local p = cd.prefix

		local clawArm = Instance.new("Part")
		clawArm.Name = p .. "ClawArm"
		clawArm.Size = Vector3.new(0.7, 0.5, 1.3)
		clawArm.Position = pos + Vector3.new(s * 1.7, 1.2, 1.9)
		clawArm.BrickColor = BrickColor.new(scpColor)
		clawArm.Anchored = false
		clawArm.Parent = monsterModel

		local clawPincer = Instance.new("Part")
		clawPincer.Name = p .. "ClawPincer"
		clawPincer.Size = Vector3.new(0.6, 0.5, 0.9)
		clawPincer.Position = pos + Vector3.new(s * 2.35, 1.5, 2.6)
		clawPincer.BrickColor = BrickColor.new(scpColor)
		clawPincer.Anchored = false
		clawPincer.Parent = monsterModel

		local pincerUpper = Instance.new("Part")
		pincerUpper.Name = p .. "PincerUpper"
		pincerUpper.Size = Vector3.new(0.5, 0.4, 0.5)
		pincerUpper.Position = pos + Vector3.new(s * 2.7, 1.8, 3.0)
		pincerUpper.BrickColor = BrickColor.new(scpColor)
		pincerUpper.Anchored = false
		pincerUpper.Parent = monsterModel

		local pincerLower = Instance.new("Part")
		pincerLower.Name = p .. "PincerLower"
		pincerLower.Size = Vector3.new(0.4, 0.3, 0.5)
		pincerLower.Position = pos + Vector3.new(s * 2.5, 1.35, 3.0)
		pincerLower.BrickColor = BrickColor.new(scpColor)
		pincerLower.Anchored = false
		pincerLower.Parent = monsterModel

		local w1 = Instance.new("WeldConstraint")
		w1.Part0 = cephalothorax
		w1.Part1 = clawArm
		w1.Parent = cephalothorax

		local w2 = Instance.new("WeldConstraint")
		w2.Part0 = clawArm
		w2.Part1 = clawPincer
		w2.Parent = clawArm

		local w3 = Instance.new("WeldConstraint")
		w3.Part0 = clawPincer
		w3.Part1 = pincerUpper
		w3.Parent = clawPincer

		local w4 = Instance.new("WeldConstraint")
		w4.Part0 = clawPincer
		w4.Part1 = pincerLower
		w4.Parent = clawPincer
	end

	-- 8条腿（4对）
	local legPairs = {
		{attachZ = 1.3, spread = 1.1, angle = 0.7},
		{attachZ = 0.6, spread = 1.2, angle = 0.3},
		{attachZ = -0.15, spread = 1.3, angle = -0.1},
		{attachZ = -0.85, spread = 1.2, angle = -0.5},
	}
	local legIndex = 0
	for _, lp in ipairs(legPairs) do
		for _, side in ipairs({-1, 1}) do
			legIndex = legIndex + 1

			local femur = Instance.new("Part")
			femur.Name = "Leg" .. legIndex .. "Femur"
			femur.Size = Vector3.new(0.3, 0.9, 0.3)
			femur.Position = pos + Vector3.new(side * lp.spread, 0.4, lp.attachZ)
			femur.BrickColor = BrickColor.new(scpColor)
			femur.Anchored = false
			femur.Shape = Enum.PartType.Cylinder
			femur.Parent = monsterModel

			local tibia = Instance.new("Part")
			tibia.Name = "Leg" .. legIndex .. "Tibia"
			tibia.Size = Vector3.new(0.25, 0.7, 0.25)
			tibia.Position = pos + Vector3.new(side * (lp.spread + 0.3), -0.05, lp.attachZ + side * 0.15)
			tibia.BrickColor = BrickColor.new(scpColor)
			tibia.Anchored = false
			tibia.Shape = Enum.PartType.Cylinder
			tibia.Parent = monsterModel

			local wf = Instance.new("WeldConstraint")
			wf.Part0 = cephalothorax
			wf.Part1 = femur
			wf.Parent = cephalothorax

			local wt = Instance.new("WeldConstraint")
			wt.Part0 = femur
			wt.Part1 = tibia
			wt.Parent = femur
		end
	end

	return monsterModel
end

-- 创建骨骼部件辅助函数
local function createBonePart(name, pos, size, color, parent, partType)
	local bone = Instance.new("Part")
	bone.Name = name
	bone.Size = size
	bone.Position = pos
	bone.BrickColor = BrickColor.new(color)
	bone.Anchored = false
	bone.CanCollide = false
	bone.Massless = true
	bone.Parent = parent
	if partType == "Cylinder" then
		bone.Shape = Enum.PartType.Cylinder
	end
	return bone
end

local function weldBones(part0, part1)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
	return weld
end

-- 创建骷髅BOSS模型（由一根根骨头组成）
local function createSkeletonBossModel(position, color)
	local monsterModel = Instance.new("Model")

	local pos = position
	local boneColor = "Institutional white"
	local eyeColor = "Really red"

	-- === 头部（头骨） ===
	local cranium = createBonePart("Cranium", pos + Vector3.new(0, 5.5, 0), Vector3.new(2, 2.2, 2.2), boneColor, monsterModel)
	local jaw = createBonePart("Jaw", pos + Vector3.new(0, 4.5, 0.3), Vector3.new(1.4, 0.7, 1.6), boneColor, monsterModel)
	weldBones(cranium, jaw)

	-- 红色眼睛
	local leftEye = createBonePart("LeftEye", pos + Vector3.new(-0.55, 5.8, 0.8), Vector3.new(0.5, 0.5, 0.5), eyeColor, monsterModel)
	local rightEye = createBonePart("RightEye", pos + Vector3.new(0.55, 5.8, 0.8), Vector3.new(0.5, 0.5, 0.5), eyeColor, monsterModel)
	weldBones(cranium, leftEye)
	weldBones(cranium, rightEye)

	-- === 脊柱（一节节椎骨） ===
	local vertebrae = {}
	local spineY = {4.1, 3.5, 2.9, 2.3, 1.7}
	for i, y in ipairs(spineY) do
		vertebrae[i] = createBonePart("Spine" .. i, pos + Vector3.new(0, y, 0), Vector3.new(0.6, 0.5, 0.5), boneColor, monsterModel, "Cylinder")
	end
	weldBones(cranium, vertebrae[1])
	for i = 1, #vertebrae - 1 do
		weldBones(vertebrae[i], vertebrae[i + 1])
	end

	-- === 肋骨（胸腔） ===
	local ribPairs = {
		{y = 3.9, halfWidth = 1.0, halfDown = 0.4},
		{y = 3.5, halfWidth = 1.2, halfDown = 0.5},
		{y = 3.1, halfWidth = 1.3, halfDown = 0.5},
		{y = 2.7, halfWidth = 1.2, halfDown = 0.4},
	}

	for i, rib in ipairs(ribPairs) do
		local spineVert = vertebrae[i]
		local leftRib = createBonePart("LeftRib" .. i,
			pos + Vector3.new(-rib.halfWidth, rib.y - rib.halfDown, 0),
			Vector3.new(rib.halfWidth * 2, 0.3, 0.3),
			boneColor, monsterModel)
		local rightRib = createBonePart("RightRib" .. i,
			pos + Vector3.new(rib.halfWidth, rib.y - rib.halfDown, 0),
			Vector3.new(rib.halfWidth * 2, 0.3, 0.3),
			boneColor, monsterModel)
		weldBones(spineVert, leftRib)
		weldBones(spineVert, rightRib)
	end

	-- === 骨盆 ===
	local pelvis = createBonePart("Pelvis", pos + Vector3.new(0, 1.2, 0), Vector3.new(2.4, 0.5, 1.4), boneColor, monsterModel)
	weldBones(vertebrae[#vertebrae], pelvis)

	-- === 左臂 ===
	local leftShoulder = createBonePart("LeftShoulder", pos + Vector3.new(-1.3, 4.0, 0), Vector3.new(0.5, 0.5, 0.5), boneColor, monsterModel)
	weldBones(vertebrae[1], leftShoulder)

	local leftHumerus = createBonePart("LeftHumerus", pos + Vector3.new(-1.8, 3.0, 0), Vector3.new(0.45, 0.45, 2.2), boneColor, monsterModel, "Cylinder")
	weldBones(leftShoulder, leftHumerus)

	local leftRadius = createBonePart("LeftRadius", pos + Vector3.new(-1.8, 1.3, 0.1), Vector3.new(0.35, 0.35, 1.8), boneColor, monsterModel, "Cylinder")
	weldBones(leftHumerus, leftRadius)

	local leftUlna = createBonePart("LeftUlna", pos + Vector3.new(-1.8, 1.3, -0.1), Vector3.new(0.25, 0.25, 1.8), boneColor, monsterModel, "Cylinder")
	weldBones(leftHumerus, leftUlna)

	local leftHand = createBonePart("LeftHand", pos + Vector3.new(-1.8, 0.0, 0), Vector3.new(0.6, 0.3, 0.4), boneColor, monsterModel)
	weldBones(leftRadius, leftHand)
	weldBones(leftUlna, leftHand)

	-- === 右臂 ===
	local rightShoulder = createBonePart("RightShoulder", pos + Vector3.new(1.3, 4.0, 0), Vector3.new(0.5, 0.5, 0.5), boneColor, monsterModel)
	weldBones(vertebrae[1], rightShoulder)

	local rightHumerus = createBonePart("RightHumerus", pos + Vector3.new(1.8, 3.0, 0), Vector3.new(0.45, 0.45, 2.2), boneColor, monsterModel, "Cylinder")
	weldBones(rightShoulder, rightHumerus)

	local rightRadius = createBonePart("RightRadius", pos + Vector3.new(1.8, 1.3, 0.1), Vector3.new(0.35, 0.35, 1.8), boneColor, monsterModel, "Cylinder")
	weldBones(rightHumerus, rightRadius)

	local rightUlna = createBonePart("RightUlna", pos + Vector3.new(1.8, 1.3, -0.1), Vector3.new(0.25, 0.25, 1.8), boneColor, monsterModel, "Cylinder")
	weldBones(rightHumerus, rightUlna)

	local rightHand = createBonePart("RightHand", pos + Vector3.new(1.8, 0.0, 0), Vector3.new(0.6, 0.3, 0.4), boneColor, monsterModel)
	weldBones(rightRadius, rightHand)
	weldBones(rightUlna, rightHand)

	-- === 左腿 ===
	local leftHip = createBonePart("LeftHip", pos + Vector3.new(-0.9, 1.0, 0), Vector3.new(0.6, 0.6, 0.6), boneColor, monsterModel)
	weldBones(pelvis, leftHip)

	local leftFemur = createBonePart("LeftFemur", pos + Vector3.new(-0.9, 0.0, 0), Vector3.new(0.5, 0.5, 2.0), boneColor, monsterModel, "Cylinder")
	weldBones(leftHip, leftFemur)

	local leftTibia = createBonePart("LeftTibia", pos + Vector3.new(-0.9, -1.5, 0.1), Vector3.new(0.38, 0.38, 1.8), boneColor, monsterModel, "Cylinder")
	weldBones(leftFemur, leftTibia)

	local leftFibula = createBonePart("LeftFibula", pos + Vector3.new(-0.9, -1.5, -0.1), Vector3.new(0.25, 0.25, 1.6), boneColor, monsterModel, "Cylinder")
	weldBones(leftFemur, leftFibula)

	local leftFoot = createBonePart("LeftFoot", pos + Vector3.new(-0.9, -2.8, 0.25), Vector3.new(1.0, 0.35, 0.5), boneColor, monsterModel)
	weldBones(leftTibia, leftFoot)
	weldBones(leftFibula, leftFoot)

	-- === 右腿 ===
	local rightHip = createBonePart("RightHip", pos + Vector3.new(0.9, 1.0, 0), Vector3.new(0.6, 0.6, 0.6), boneColor, monsterModel)
	weldBones(pelvis, rightHip)

	local rightFemur = createBonePart("RightFemur", pos + Vector3.new(0.9, 0.0, 0), Vector3.new(0.5, 0.5, 2.0), boneColor, monsterModel, "Cylinder")
	weldBones(rightHip, rightFemur)

	local rightTibia = createBonePart("RightTibia", pos + Vector3.new(0.9, -1.5, 0.1), Vector3.new(0.38, 0.38, 1.8), boneColor, monsterModel, "Cylinder")
	weldBones(rightFemur, rightTibia)

	local rightFibula = createBonePart("RightFibula", pos + Vector3.new(0.9, -1.5, -0.1), Vector3.new(0.25, 0.25, 1.6), boneColor, monsterModel, "Cylinder")
	weldBones(rightFemur, rightFibula)

	local rightFoot = createBonePart("RightFoot", pos + Vector3.new(0.9, -2.8, 0.25), Vector3.new(1.0, 0.35, 0.5), boneColor, monsterModel)
	weldBones(rightTibia, rightFoot)
	weldBones(rightFibula, rightFoot)

	return monsterModel
end

-- 创建怪物模型（根据类型选择）
local function createSimpleMonster(monsterType, position, color)
	if monsterType == "Spider" then
		return createSpiderModel(position, color)
	elseif monsterType == "Scorpion" then
		return createScorpionModel(position, color)
	elseif monsterType == "SkeletonBoss" then
		return createSkeletonBossModel(position, color)
	else
		-- 默认回退到简单模型
		local monsterModel = Instance.new("Model")
		
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(2, 3, 2)
		body.Position = position + Vector3.new(0, 1, 0)
		body.BrickColor = BrickColor.new(color)
		body.Anchored = false
		body.CanCollide = false
		body.Massless = true
		body.Parent = monsterModel
		
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1.5, 1.5, 1.5)
		head.Position = position + Vector3.new(0, 3, 0)
		head.BrickColor = BrickColor.new(color)
		head.Anchored = false
		head.CanCollide = false
		head.Massless = true
		head.Parent = monsterModel
		
		return monsterModel
	end
end

-- 创建怪物（最简单版）
local function createMonster(nest, monsterType)
	local monsterConfig = MonsterConfig.Types[monsterType]
	if not monsterConfig then
		return
	end

	-- 先检查数量
	local currentCount = countAliveMonsters(nest)
	if currentCount >= nest.Config.MaxMonsters then
		print("📊 怪物数量已满:", currentCount, "/", nest.Config.MaxMonsters)
		return
	end

	-- 生成位置
	local spawnOffset = Vector3.new(
		(math.random() - 0.5) * nest.Config.SpawnRadius,
		0,
		(math.random() - 0.5) * nest.Config.SpawnRadius
	)
	local position = nest.Position + spawnOffset + Vector3.new(0, 2, 0)

	-- 创建简单模型
	local monsterModel = createSimpleMonster(monsterType, position, monsterConfig.Color)
	monsterModel.Name = monsterConfig.Name

	-- 添加巢穴ID（关键！）
	local nestIdValue = Instance.new("StringValue")
	nestIdValue.Name = "OwningNestId"
	nestIdValue.Value = nest.Id
	nestIdValue.Parent = monsterModel

	-- 添加怪物类型标记（用于AI识别）
	local monsterTypeValue = Instance.new("StringValue")
	monsterTypeValue.Name = "MonsterType"
	monsterTypeValue.Value = monsterType
	monsterTypeValue.Parent = monsterModel

	-- 记录出生位置（用于超出追击范围后返回）
	local spawnPosValue = Instance.new("Vector3Value")
	spawnPosValue.Name = "SpawnPosition"
	spawnPosValue.Value = nest.Position
	spawnPosValue.Parent = monsterModel

	-- 记录上次攻击时间（用于攻击冷却）
	local lastAttackValue = Instance.new("NumberValue")
	lastAttackValue.Name = "LastAttackTime"
	lastAttackValue.Value = 0
	lastAttackValue.Parent = monsterModel

	-- 添加Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = monsterConfig.MaxHealth
	humanoid.Health = monsterConfig.Health
	humanoid.WalkSpeed = monsterConfig.Speed
	humanoid.AutoRotate = false
	humanoid.Parent = monsterModel

	-- 添加HumanoidRootPart（作为碰撞体，防止穿模）
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 2)
	rootPart.Position = position
	rootPart.Transparency = 1
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.Parent = monsterModel

	-- 设置PrimaryPart
	monsterModel.PrimaryPart = rootPart

	-- 将所有可见身体部件焊接到HumanoidRootPart（用于MoveTo移动）
	local mainBody = monsterModel:FindFirstChild("MainBody")
		or monsterModel:FindFirstChild("Cephalothorax")
		or monsterModel:FindFirstChild("Cranium")
		or monsterModel:FindFirstChild("Body")
		or monsterModel:FindFirstChild("Head")
	if mainBody then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootPart
		weld.Part1 = mainBody
		weld.Parent = rootPart
	end

	-- 统一设置所有怪物部件的物理属性
	-- 只有HumanoidRootPart参与碰撞（防止穿模），其他部件无碰撞无质量
	for _, part in ipairs(monsterModel:GetDescendants()) do
		if part:IsA("Part") or part:IsA("WedgePart") then
			if part.Name == "HumanoidRootPart" then
				part.CanCollide = true
				part.Massless = false
			else
				part.CanCollide = false
				part.Massless = true
			end
		end
	end

	-- 添加名字GUI和血条GUI
	local gui = Instance.new("BillboardGui")
	gui.Name = "MonsterGui"
	gui.Size = UDim2.new(0, 100, 0, 45)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	
	-- 找到一个合适的Part来放GUI
	local targetPart = monsterModel:FindFirstChild("MainBody") 
		or monsterModel:FindFirstChild("Body") 
		or monsterModel:FindFirstChild("Head") 
		or monsterModel:FindFirstChildWhichIsA("BasePart")
	
	if targetPart then
		gui.Parent = targetPart
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 18)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = monsterConfig.Name
	nameLabel.Parent = gui

	local healthBg = Instance.new("Frame")
	healthBg.Name = "HealthBg"
	healthBg.Size = UDim2.new(1, -10, 0, 14)
	healthBg.Position = UDim2.new(0, 5, 0, 20)
	healthBg.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	healthBg.BorderSizePixel = 0
	healthBg.Parent = gui

	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.new(0.3, 0.9, 0.3)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBg

	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.TextColor3 = Color3.new(1, 1, 1)
	healthText.TextSize = 11
	healthText.Font = Enum.Font.GothamBold
	healthText.Text = monsterConfig.Health .. "/" .. monsterConfig.MaxHealth
	healthText.Parent = healthBg

	-- 血量变化时更新血条
	humanoid.HealthChanged:Connect(function()
		local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		healthFill.Size = UDim2.new(healthPercent, 0, 1, 0)
		healthText.Text = math.floor(humanoid.Health) .. "/" .. humanoid.MaxHealth
		if healthPercent > 0.5 then
			healthFill.BackgroundColor3 = Color3.new(0.3, 0.9, 0.3)
		elseif healthPercent > 0.25 then
			healthFill.BackgroundColor3 = Color3.new(0.9, 0.9, 0.2)
		else
			healthFill.BackgroundColor3 = Color3.new(0.9, 0.3, 0.3)
		end
	end)

	-- 血量归零时清理模型（兜底，防止怪物0血不死）
	humanoid.Died:Connect(function()
		monsterModel:Destroy()
	end)

	-- 生成到Workspace
	monsterModel.Parent = game.Workspace

	print("✅ 生成怪物:", monsterType, "当前数量:", countAliveMonsters(nest), "/", nest.Config.MaxMonsters)
end

-- 更新巢穴血条
local function updateNestHealth(nest)
	local healthPercent = nest.Health / nest.Config.MaxHealth
	local healthBar = nest.Model.NestPart.HealthGui.HealthBar
	local healthLabel = nest.Model.NestPart.HealthGui.HealthLabel

	healthBar.Size = UDim2.new(healthPercent, 0, 0.3, 0)
	healthLabel.Text = nest.Config.Name .. " (" .. math.floor(nest.Health) .. "/" .. nest.Config.MaxHealth .. ")"
end

-- 创建新巢穴
function NestSystem.CreateNest(nestType, position)
	local config = NestConfig.Types[nestType]
	if not config then
		warn("找不到巢穴类型:", nestType)
		return nil
	end

	local nestId = game:GetService("HttpService"):GenerateGUID(false)
	local model = createNestVisual(config, position, nestType)

	local nest = {
		Id = nestId,
		Config = config,
		NestType = nestType,
		Model = model,
		Position = position,
		Health = config.Health,
		LastSpawnTime = 0
	}

	activeNests[nestId] = nest
	nestCount[nestType] = nestCount[nestType] + 1
	updateNestHealth(nest)
	print("🏰 生成巢穴:", config.Name, "在", position, "(当前数量:", nestCount[nestType], "/", config.MaxCount, ")")

	-- 添加巢穴唯一标识（用于客户端攻击检测）
	local nestIdValue = Instance.new("StringValue")
	nestIdValue.Name = "NestId"
	nestIdValue.Value = nestId
	nestIdValue.Parent = model

	-- 立即生成初始怪物
	for i = 1, math.min(2, config.MaxMonsters) do
		task.wait(0.3)
		local monsterType = selectMonsterByWeight(config.MonsterTypes)
		createMonster(nest, monsterType)
	end
	
	return nestId
end

-- 获取指定范围内的巢穴列表
function NestSystem.GetNestsInRange(position, range)
	local nests = {}
	for _, nest in pairs(activeNests) do
		local dist = (nest.Position - position).Magnitude
		if dist <= range then
			table.insert(nests, nest)
		end
	end
	return nests
end

-- 攻击巢穴（由服务端攻击处理器调用）
function NestSystem.DamageNest(nestId, damage)
	local nest = activeNests[nestId]
	if not nest then
		return false
	end
	nest.Health = math.max(0, nest.Health - damage)
	updateNestHealth(nest)

	-- 受击反应（闪红 + 音效 + 火花）
	HitEffectSystem.NestHitEffect(nest.Model, nest.Position)

	if nest.Health <= 0 then
		local dropPos = nest.Position + Vector3.new(0, 2, 0)
		local destroyedType = nest.NestType

		-- 摧毁特效
		HitEffectSystem.NestDestroyEffect(nest.Position)
		nest.Model:Destroy()
		activeNests[nestId] = nil
		nestCount[nest.NestType] = nestCount[nest.NestType] - 1
		print("💥 巢穴被摧毁:", nest.Config.Name)

		table.insert(pendingRespawns, { timer = tick() + 30, nestType = destroyedType })

		local randomValue = math.random()
		print("🎲 掉落概率检查: random=", randomValue)
		if randomValue < 0.35 then
			-- 35% 掉落武器
			local weaponId = WeaponSystem.RollRandomWeapon()
			if weaponId then
				print("🎲 掉落武器:", weaponId, "位置:", dropPos)
				WeaponSystem.SpawnWeaponDrop(dropPos, weaponId)
			else
				print("❌ RollRandomWeapon返回nil")
			end
		elseif randomValue < 0.55 then
			-- 20% 掉落炸弹
			print("🎲 掉落炸弹, 位置:", dropPos)
			BombSystem.SpawnBombDrop(dropPos)
		elseif randomValue < 0.75 then
			-- 20% 掉落箱子
			print("🎲 掉落箱子, 位置:", dropPos)
			local ChestSystem = require(game:GetService("ServerStorage").ChestSystem)
			ChestSystem.SpawnChestDrop(dropPos)
		else
			-- 25% 无掉落
			print("🎲 未掉落物品")
		end

		return true
	end
	return false
end

-- 尝试随机生成新巢穴
local function trySpawnRandomNest()
	local nestType = selectRandomNestType()
	if not nestType then
		return false
	end

	local position = findValidPosition()
	if not position then
		return false
	end

	NestSystem.CreateNest(nestType, position)
	return true
end

-- 初始化巢穴系统
function NestSystem.Init()
	initNestCount()
	print("🏰 巢穴系统已初始化，开始随机生成巢穴...")
	
	-- 初始先尝试生成一些巢穴
	for i = 1, 3 do
		trySpawnRandomNest()
		task.wait(0.3)
	end
end

-- 更新函数
function NestSystem.Update(deltaTime)
	local currentTime = tick()

	-- 检查巢穴重生计时
	for i = #pendingRespawns, 1, -1 do
		if currentTime >= pendingRespawns[i].timer then
			local nestType = pendingRespawns[i].nestType
			table.remove(pendingRespawns, i)
			if canSpawnNest(nestType) then
				local position = findValidPosition()
				if position then
					NestSystem.CreateNest(nestType, position)
				end
			end
		end
	end

	-- 更新现有巢穴的怪物生成
	for _, nest in pairs(activeNests) do
		local aliveCount = countAliveMonsters(nest)
		
		if aliveCount < nest.Config.MaxMonsters then
			if currentTime - nest.LastSpawnTime >= nest.Config.SpawnInterval then
				local monsterType = selectMonsterByWeight(nest.Config.MonsterTypes)
				createMonster(nest, monsterType)
				nest.LastSpawnTime = currentTime
			end
		end
	end
	
	-- 检查是否需要生成新巢穴
	if currentTime - lastNestSpawnTime >= NEST_SPAWN_CHECK_INTERVAL then
		if trySpawnRandomNest() then
			lastNestSpawnTime = currentTime
		end
	end
	
	-- 怪物AI：每隔0.5秒扫描并追踪附近的玩家
	local AI_UPDATE_INTERVAL = 0.5
	if not NestSystem._lastAiUpdate or currentTime - NestSystem._lastAiUpdate >= AI_UPDATE_INTERVAL then
		NestSystem._lastAiUpdate = currentTime

		-- 清理血量≤0的残留怪物（兜底）
		for _, monsterModel in ipairs(game.Workspace:GetChildren()) do
			if monsterModel:IsA("Model") and monsterModel:FindFirstChild("OwningNestId") then
				local humanoid = monsterModel:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health <= 0 then
					monsterModel:Destroy()
				end
			end
		end

		for _, monsterModel in ipairs(game.Workspace:GetChildren()) do
			if monsterModel:IsA("Model") and monsterModel:FindFirstChild("OwningNestId") then
				local humanoid = monsterModel:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health > 0 then
					local monsterTypeValue = monsterModel:FindFirstChild("MonsterType")
					if monsterTypeValue then
						local monsterConfig = MonsterConfig.Types[monsterTypeValue.Value]
						if monsterConfig then
							local monsterRoot = monsterModel:FindFirstChild("HumanoidRootPart")
							if monsterRoot then
								-- 寻找最近的存活玩家
								local nearestPlayer = nil
								local nearestDist = math.huge
								
								for _, player in ipairs(Players:GetPlayers()) do
									local character = player.Character
									if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
										local playerRoot = character:FindFirstChild("HumanoidRootPart")
										if playerRoot then
											-- 跳过隐身玩家
											if PlayerStats.IsPlayerInvisible(player) then
												continue
											end
											local dist = (playerRoot.Position - monsterRoot.Position).Magnitude
											if dist < nearestDist then
												nearestPlayer = player
												nearestDist = dist
											end
										end
									end
								end
								
								local chaseRange = monsterConfig.ChaseRange or 35

								-- 如果发现玩家在追击范围内，向玩家移动
								if nearestPlayer and nearestDist <= chaseRange then
									local targetRoot = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")
									if targetRoot then
										humanoid:MoveTo(targetRoot.Position)

										-- 使用BodyGyro使尾部朝向玩家（物理力旋转，不干扰MoveTo）
										local gyro = monsterRoot:FindFirstChild("TailGyro")
										if not gyro then
											gyro = Instance.new("BodyGyro")
											gyro.Name = "TailGyro"
											gyro.MaxTorque = Vector3.new(5000, 5000, 5000)
											gyro.P = 5000
											gyro.D = 500
											gyro.Parent = monsterRoot
										end
										local dir = (targetRoot.Position - monsterRoot.Position)
										if dir.Magnitude > 0.5 then
											gyro.CFrame = CFrame.lookAt(
												monsterRoot.Position,
												monsterRoot.Position - dir
											)
										end
									end

									-- 攻击判定：在攻击范围内且冷却已过则攻击
									if nearestDist <= monsterConfig.AttackRange then
										local lastAttackValue = monsterModel:FindFirstChild("LastAttackTime")
										if lastAttackValue and currentTime - lastAttackValue.Value >= monsterConfig.AttackInterval then
											local character = nearestPlayer.Character
											if character then
												local playerHumanoid = character:FindFirstChild("Humanoid")
												if playerHumanoid and playerHumanoid.Health > 0 then
													playerHumanoid.Health = playerHumanoid.Health - monsterConfig.Damage
													lastAttackValue.Value = currentTime
													-- 同步更新leaderstats，让HUD血量显示刷新
													local leaderstats = nearestPlayer:FindFirstChild("leaderstats")
													if leaderstats then
														local healthValue = leaderstats:FindFirstChild("Health")
														if healthValue then
															healthValue.Value = playerHumanoid.Health
														end
													end

													-- 玩家受击反应（音效 + 客户端屏幕闪红）
													HitEffectSystem.PlayerHitEffect(nearestPlayer, monsterRoot.Position)
													playerHitEvent:FireClient(nearestPlayer)

													-- 受到伤害解除隐身
													if PlayerStats.IsPlayerInvisible(nearestPlayer) then
														PlayerStats.SetInvisible(nearestPlayer, false)
														-- 重置角色透明度
														for _, part in ipairs(character:GetDescendants()) do
															if part:IsA("BasePart") then
																part.Transparency = 0
															end
														end
													end
												end
											end
										end
									end
								-- 玩家太远或没有玩家→返回巢穴
								else
									local gyro = monsterRoot:FindFirstChild("TailGyro")
									if gyro then
										gyro:Destroy()
									end
									local spawnPosValue = monsterModel:FindFirstChild("SpawnPosition")
									if spawnPosValue then
										local distToSpawn = (spawnPosValue.Value - monsterRoot.Position).Magnitude
										if distToSpawn > 3 then
											humanoid:MoveTo(spawnPosValue.Value)
										else
											humanoid:MoveTo(monsterRoot.Position)
										end
									else
										humanoid:MoveTo(monsterRoot.Position)
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

-- ============================================================
-- 世界级持久化（启动时恢复，关闭时保存）
-- ============================================================

-- 收集所有巢穴数据用于全量保存
-- 返回: { { NestType=..., Position={X=...,Y=...,Z=...}, Health=... }, ... }
function NestSystem.GetAllNestsForSave()
	local saved = {}
	for _, nest in pairs(activeNests) do
		table.insert(saved, {
			NestType = nest.NestType,
			Position = { X = nest.Position.X, Y = nest.Position.Y, Z = nest.Position.Z },
			Health = nest.Health,
		})
	end
	print("🏰 [NestSystem] 收集到", #saved, "个巢穴用于保存")
	return saved
end

-- 从保存的数据中恢复所有巢穴（在启动时调用，替代随机生成）
-- 返回: 恢复的巢穴数量
function NestSystem.RestoreAllNestsFromSave(savedNests)
	if not savedNests or #savedNests == 0 then
		print("🏰 [NestSystem] 没有保存的巢穴需要恢复")
		return 0
	end

	local restored = 0
	for _, nestInfo in ipairs(savedNests) do
		local pos = Vector3.new(nestInfo.Position.X, nestInfo.Position.Y, nestInfo.Position.Z)

		-- 创建巢穴模型（使用 CreateNest 的核心逻辑，但不重新生成初始怪物）
		local config = NestConfig.Types[nestInfo.NestType]
		if config then
			local nestId = game:GetService("HttpService"):GenerateGUID(false)
			local model = createNestVisual(config, pos, nestInfo.NestType)

			local nest = {
				Id = nestId,
				Config = config,
				NestType = nestInfo.NestType,
				Model = model,
				Position = pos,
				Health = nestInfo.Health or config.Health,
				LastSpawnTime = 0
			}

			activeNests[nestId] = nest
			nestCount[nestInfo.NestType] = nestCount[nestInfo.NestType] + 1

			-- 更新血条显示
			updateNestHealth(nest)

			-- 添加巢穴唯一标识
			local nestIdValue = Instance.new("StringValue")
			nestIdValue.Name = "NestId"
			nestIdValue.Value = nestId
			nestIdValue.Parent = model

			restored = restored + 1
			print("🏰 [NestSystem] 恢复巢穴:", config.Name, "在", pos, "血量:", nest.Health)
		end
	end

	print("🏰 [NestSystem] 已恢复", restored, "个巢穴")
	return restored
end

-- 清除所有巢穴（用于重新加载前）
function NestSystem.ClearAllNests()
	local removed = 0
	for nestId, nest in pairs(activeNests) do
		if nest.Model then
			nest.Model:Destroy()
		end
		activeNests[nestId] = nil
		nestCount[nest.NestType] = nestCount[nest.NestType] - 1
		removed = removed + 1
	end
	if removed > 0 then
		print("🏰 [NestSystem] 已清除", removed, "个巢穴")
	end
	return removed
end

-- 修改 Init 支持从保存数据恢复
-- savedNests: 可选，保存的巢穴数据。如果提供，则从保存数据恢复，否则随机生成
local _originalInit = NestSystem.Init
function NestSystem.Init(savedNests)
	initNestCount()

	if savedNests and #savedNests > 0 then
		print("🏰 巢穴系统已初始化，从保存数据恢复巢穴...")
		NestSystem.RestoreAllNestsFromSave(savedNests)
	else
		print("🏰 巢穴系统已初始化，开始随机生成巢穴...")
		-- 初始先尝试生成一些巢穴
		for i = 1, 3 do
			trySpawnRandomNest()
			task.wait(0.3)
		end
	end
end

return NestSystem
