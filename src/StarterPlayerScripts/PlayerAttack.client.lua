-- 玩家攻击系统 - 客户端
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local attackEvent = ReplicatedStorage:WaitForChild("PlayerAttackEvent")
local attackNestEvent = ReplicatedStorage:WaitForChild("PlayerAttackNestEvent")
local equipWeaponEvent = ReplicatedStorage:WaitForChild("EquipWeaponEvent")
local usePotionEvent = ReplicatedStorage:WaitForChild("UsePotionEvent")
local detonateBombEvent = ReplicatedStorage:WaitForChild("DetonateBombEvent")
local throwBombEvent = ReplicatedStorage:WaitForChild("ThrowBombEvent")
local useHealthPotionEvent = ReplicatedStorage:WaitForChild("UseHealthPotionEvent")
local useInvisibilityPotionEvent = ReplicatedStorage:WaitForChild("UseInvisibilityPotionEvent")
local pickupChestEvent = ReplicatedStorage:WaitForChild("PickupChestEvent")
local WeaponSystem = require(ReplicatedStorage.Modules.WeaponSystem)
local PlayerConfig = require(ReplicatedStorage.Modules.PlayerConfig)
local lastAttackTime = 0

print("🏹 玩家攻击脚本已加载")

local function getNearbyTargets(position, radius)
	local monsters = {}
	local nests = {}
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") then
			local nestIdValue = obj:FindFirstChild("NestId")
			if nestIdValue then
				local nestPart = obj:FindFirstChild("NestPart")
				if nestPart then
					local dist = (nestPart.Position - position).Magnitude
					if dist <= radius then
						table.insert(nests, {Model = obj, Distance = dist, NestPart = nestPart})
					end
				end
			elseif obj:FindFirstChild("OwningNestId") then
				local root = obj:FindFirstChild("HumanoidRootPart")
				if root then
					local dist = (root.Position - position).Magnitude
					if dist <= radius then
						table.insert(monsters, {Model = obj, Distance = dist, Root = root})
					end
				end
			end
		end
	end
	return monsters, nests
end

local function getCameraViewDirection()
	local camera = workspace.CurrentCamera
	if not camera then return nil, nil end
	return camera.CFrame.Position, camera.CFrame.LookVector
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	print("🖱️ 鼠标左键点击")

	local character = player.Character
	if not character then
		print("❌ 没有角色")
		return
	end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		print("❌ 角色已死亡")
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		print("❌ 没有leaderstats")
		return
	end

	local agilityValue = leaderstats:FindFirstChild("Agility")
	local agility = agilityValue and agilityValue.Value or 10

	local weaponSpeed = 1.0
	local weaponValue = leaderstats:FindFirstChild("Weapon")
	if weaponValue and weaponValue.Value ~= "" then
		local _, _, spd = WeaponSystem.GetWeaponBonuses(weaponValue.Value)
		weaponSpeed = spd
	end

	local attackConfig = PlayerConfig.Attack
	local attackInterval = math.max(attackConfig.MinInterval, (attackConfig.BaseInterval - agility * attackConfig.AgilityIntervalMultiplier) * weaponSpeed)

	local currentTime = tick()
	if currentTime - lastAttackTime < attackInterval then
		print("❌ 攻击冷却中")
		return
	end

	local playerRoot = character:FindFirstChild("HumanoidRootPart")
	if not playerRoot then
		print("❌ 没有玩家HumanoidRootPart")
		return
	end

	local attackRange = 10 + agility * 0.5
	local camPos, camLook = getCameraViewDirection()
	if not camPos then
		print("❌ 没有相机")
		return
	end

	print("🔍 搜索目标, 范围:", attackRange, "玩家位置:", playerRoot.Position)
	local nearbyMonsters, nearbyNests = getNearbyTargets(playerRoot.Position, attackRange)
	local totalTargets = #nearbyMonsters + #nearbyNests
	print("📊 附近怪物数量:", #nearbyMonsters, "巢穴数量:", #nearbyNests)

	if totalTargets == 0 then return end

	local bestTarget = nil
	local bestAngle = math.huge
	local isNestTarget = false

	local function checkTarget(targetModel, targetPos, isNest)
		local dirToTarget = (targetPos - camPos).Unit
		local dot = camLook:Dot(dirToTarget)
		if isNest then
			print("  🏠 巢穴:", targetModel.Name, "距离:", (targetPos - playerRoot.Position).Magnitude, "dot:", dot)
		else
			print("  🎯 怪物:", targetModel.Name, "距离:", (targetPos - playerRoot.Position).Magnitude, "dot:", dot)
		end
		if dot > 0.3 then
			local angle = math.acos(dot)
			if angle < bestAngle then
				bestAngle = angle
				bestTarget = targetModel
				isNestTarget = isNest
			end
		end
	end

	for _, entry in ipairs(nearbyMonsters) do
		if entry.Root then
			checkTarget(entry.Model, entry.Root.Position, false)
		end
	end

	for _, entry in ipairs(nearbyNests) do
		checkTarget(entry.Model, entry.NestPart.Position, true)
	end

	if bestTarget then
		if isNestTarget then
			print("✅ 选中巢穴:", bestTarget.Name, "发射攻击事件")
			lastAttackTime = currentTime
			attackNestEvent:FireServer(bestTarget)
		else
			print("✅ 选中目标:", bestTarget.Name, "发射攻击事件")
			lastAttackTime = currentTime
			attackEvent:FireServer(bestTarget)
		end
	else
		print("❌ 没有目标在视野内")
	end
end)

-- F键拾取（统一拾取武器/药水/炸弹，取最近的）
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.F then return end

	print("🔽 按下F键，尝试拾取附近物品")

	local character = player.Character
	if not character then return end

	local playerRoot = character:FindFirstChild("HumanoidRootPart")
	if not playerRoot then return end

	local nearestObj = nil
	local nearestDist = 15
	local objType = "" -- "weapon", "potion", "bomb"

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") then
			local objPos = obj:GetPivot().Position
			local dist = (objPos - playerRoot.Position).Magnitude
			if dist > nearestDist then continue end

			if obj:FindFirstChild("IsWeaponDrop") then
				nearestObj = obj
				nearestDist = dist
				objType = "weapon"
			elseif obj:FindFirstChild("IsPotionDrop") then
				nearestObj = obj
				nearestDist = dist
				objType = "potion"
			elseif obj:FindFirstChild("IsBombDrop") then
				nearestObj = obj
				nearestDist = dist
				objType = "bomb"
			elseif obj.Name == "Chest" and obj:FindFirstChild("ChestId") then
				nearestObj = obj
				nearestDist = dist
				objType = "chest"
			end
		end
	end

	if nearestObj then
		if objType == "weapon" then
			print("⚔️ 拾取武器:", nearestObj.Name)
			equipWeaponEvent:FireServer(nearestObj)
		elseif objType == "potion" then
			print("🧪 拾取药水:", nearestObj.Name)
			usePotionEvent:FireServer(nearestObj)
		elseif objType == "bomb" then
			print("💣 拾取炸弹:", nearestObj.Name)
			detonateBombEvent:FireServer(nearestObj)
		elseif objType == "chest" then
			print("📦 拾取箱子:", nearestObj.Name)
			pickupChestEvent:FireServer(nearestObj)
		end
	else
		print("❌ 附近没有可拾取的物品")
	end
end)

-- 右键使用物品：通过底部物品栏右键点击对应槽位触发
-- (E键投掷已移除，仅通过物品栏右键使用炸弹)
-- (全局右键回血和V键隐身已移除，改为物品栏右键点击使用)