-- 玩家 HUD - 左上角属性面板 + 底部物品栏
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Modules.ItemConfig)

-- 物品栏使用的 RemoteEvent（右键点击按钮触发）
local throwBombEvent = ReplicatedStorage:WaitForChild("ThrowBombEvent")
local useHealthPotionEvent = ReplicatedStorage:WaitForChild("UseHealthPotionEvent")
local useInvisibilityPotionEvent = ReplicatedStorage:WaitForChild("UseInvisibilityPotionEvent")
local placeChestEvent = ReplicatedStorage:WaitForChild("PlaceChestEvent")

local PlayerConfig = require(ReplicatedStorage.Modules.PlayerConfig)

-- 禁用 Roblox 默认右上角绿色血量显示
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

-- 辅助函数：找视野内最近的怪物/巢穴（投掷炸弹用）
local function getBombTargetPosition()
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	local playerRoot = character:FindFirstChild("HumanoidRootPart")
	if not playerRoot then return nil end

	local leaderstats = player:FindFirstChild("leaderstats")
	local agility = leaderstats and leaderstats:FindFirstChild("Agility") and leaderstats.Agility.Value or 10
	local attackRange = 10 + agility * 0.5

	local camera = workspace.CurrentCamera
	local camPos, camLook = camera.CFrame.Position, camera.CFrame.LookVector
	if not camPos then return nil end

	local bestTarget, bestPos, bestAngle = nil, nil, math.huge
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") then
			local targetPos = nil
			-- 检查是否是怪物
			if obj:FindFirstChild("OwningNestId") then
				local root = obj:FindFirstChild("HumanoidRootPart")
				if root then
					local dist = (root.Position - playerRoot.Position).Magnitude
					if dist <= attackRange then
						targetPos = root.Position
					end
				end
			-- 检查是否是巢穴
			elseif obj:FindFirstChild("NestId") then
				local nestPart = obj:FindFirstChild("NestPart")
				if nestPart then
					local dist = (nestPart.Position - playerRoot.Position).Magnitude
					if dist <= attackRange then
						targetPos = nestPart.Position
					end
				end
			end
			if targetPos then
				local dir = (targetPos - camPos).Unit
				local dot = camLook:Dot(dir)
				if dot > 0.3 then
					local angle = math.acos(dot)
					if angle < bestAngle then
						bestAngle = angle
						bestPos = targetPos
					end
				end
			end
		end
	end
	return bestPos
end

print("🎮 HUD 脚本启动!")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerHud"
screenGui.Parent = script.Parent

-- ============ 左上角属性面板 ============

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 210)
mainFrame.Position = UDim2.new(0, 20, 0, 20)
mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
mainFrame.BackgroundTransparency = 0.5
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.Size = UDim2.new(1, -20, 0, 30)
levelLabel.Position = UDim2.new(0, 10, 0, 10)
levelLabel.BackgroundTransparency = 1
levelLabel.TextColor3 = Color3.new(1, 1, 1)
levelLabel.TextSize = 20
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextXAlignment = Enum.TextXAlignment.Left
levelLabel.Text = "等级: 1"
levelLabel.Parent = mainFrame

local healthBarFrame = Instance.new("Frame")
healthBarFrame.Name = "HealthBarFrame"
healthBarFrame.Size = UDim2.new(1, -20, 0, 30)
healthBarFrame.Position = UDim2.new(0, 10, 0, 50)
healthBarFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
healthBarFrame.Parent = mainFrame

local healthBarCorner = Instance.new("UICorner")
healthBarCorner.CornerRadius = UDim.new(0, 4)
healthBarCorner.Parent = healthBarFrame

local healthBar = Instance.new("Frame")
healthBar.Name = "HealthBar"
healthBar.Size = UDim2.new(1, 0, 1, 0)
healthBar.BackgroundColor3 = Color3.new(1, 0.2, 0.2)
healthBar.Parent = healthBarFrame

local healthBarCorner2 = Instance.new("UICorner")
healthBarCorner2.CornerRadius = UDim.new(0, 4)
healthBarCorner2.Parent = healthBar

local healthLabel = Instance.new("TextLabel")
healthLabel.Name = "HealthLabel"
healthLabel.Size = UDim2.new(1, 0, 1, 0)
healthLabel.BackgroundTransparency = 1
healthLabel.TextColor3 = Color3.new(1, 1, 1)
healthLabel.TextSize = 14
healthLabel.Font = Enum.Font.Gotham
healthLabel.ZIndex = 2
healthLabel.Text = "100 / 100"
healthLabel.TextXAlignment = Enum.TextXAlignment.Center
healthLabel.Parent = healthBarFrame

local expBarFrame = Instance.new("Frame")
expBarFrame.Name = "ExpBarFrame"
expBarFrame.Size = UDim2.new(1, -20, 0, 20)
expBarFrame.Position = UDim2.new(0, 10, 0, 90)
expBarFrame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
expBarFrame.Parent = mainFrame

local expBarCorner = Instance.new("UICorner")
expBarCorner.CornerRadius = UDim.new(0, 4)
expBarCorner.Parent = expBarFrame

local expBar = Instance.new("Frame")
expBar.Name = "ExpBar"
expBar.Size = UDim2.new(0, 0, 1, 0)
expBar.BackgroundColor3 = Color3.new(0.2, 0.8, 0.2)
expBar.Parent = expBarFrame

local expBarCorner2 = Instance.new("UICorner")
expBarCorner2.CornerRadius = UDim.new(0, 4)
expBarCorner2.Parent = expBar

local expLabel = Instance.new("TextLabel")
expLabel.Name = "ExpLabel"
expLabel.Size = UDim2.new(1, 0, 1, 0)
expLabel.BackgroundTransparency = 1
expLabel.TextColor3 = Color3.new(1, 1, 1)
expLabel.TextSize = 12
expLabel.Font = Enum.Font.Gotham
expLabel.ZIndex = 2
expLabel.Text = "0 / 100"
expLabel.TextXAlignment = Enum.TextXAlignment.Center
expLabel.Parent = expBarFrame

local agilityLabel = Instance.new("TextLabel")
agilityLabel.Name = "AgilityLabel"
agilityLabel.Size = UDim2.new(1, -20, 0, 20)
agilityLabel.Position = UDim2.new(0, 10, 0, 120)
agilityLabel.BackgroundTransparency = 1
agilityLabel.TextColor3 = Color3.new(0.3, 0.6, 1)
agilityLabel.TextSize = 14
agilityLabel.Font = Enum.Font.Gotham
agilityLabel.TextXAlignment = Enum.TextXAlignment.Left
agilityLabel.Text = "敏捷: 10"
agilityLabel.Parent = mainFrame

local intelligenceLabel = Instance.new("TextLabel")
intelligenceLabel.Name = "IntelligenceLabel"
intelligenceLabel.Size = UDim2.new(1, -20, 0, 20)
intelligenceLabel.Position = UDim2.new(0, 10, 0, 145)
intelligenceLabel.BackgroundTransparency = 1
intelligenceLabel.TextColor3 = Color3.new(0.8, 0.4, 1)
intelligenceLabel.TextSize = 14
intelligenceLabel.Font = Enum.Font.Gotham
intelligenceLabel.TextXAlignment = Enum.TextXAlignment.Left
intelligenceLabel.Text = "智力: 10"
intelligenceLabel.Parent = mainFrame

-- ============ 底部物品栏 ============

local SLOT_SIZE = 50
local SLOT_GAP = 8
local BAR_PADDING = 10
local WEAPON_NAME_WIDTH = 75

-- 计算总宽度: 左侧武器(50+75) + 分隔 + 4个物品格（炸弹/生命药水/隐形药水/箱子）
local INV_WIDTH = BAR_PADDING + SLOT_SIZE + WEAPON_NAME_WIDTH + 10 + 2 + 10 + (SLOT_SIZE * 4 + SLOT_GAP * 3) + BAR_PADDING
local INV_HEIGHT = 70

local inventoryBar = Instance.new("Frame")
inventoryBar.Name = "InventoryBar"
inventoryBar.Size = UDim2.new(0, INV_WIDTH, 0, INV_HEIGHT)
inventoryBar.Position = UDim2.new(0.5, -INV_WIDTH / 2, 1, -INV_HEIGHT - 20)
inventoryBar.BackgroundColor3 = Color3.new(0, 0, 0)
inventoryBar.BackgroundTransparency = 0.45
inventoryBar.Parent = screenGui

local invBarCorner = Instance.new("UICorner")
invBarCorner.CornerRadius = UDim.new(0, 10)
invBarCorner.Parent = inventoryBar

-- 武器槽位（左侧）
local weaponSlotBg = Instance.new("Frame")
weaponSlotBg.Name = "WeaponSlotBg"
weaponSlotBg.Size = UDim2.new(0, SLOT_SIZE + WEAPON_NAME_WIDTH, 0, SLOT_SIZE)
weaponSlotBg.Position = UDim2.new(0, BAR_PADDING, 0.5, -SLOT_SIZE / 2)
weaponSlotBg.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
weaponSlotBg.BackgroundTransparency = 0.3
weaponSlotBg.BorderSizePixel = 1
weaponSlotBg.BorderColor3 = Color3.new(0.4, 0.4, 0.4)
weaponSlotBg.Parent = inventoryBar

local weaponSlotCorner = Instance.new("UICorner")
weaponSlotCorner.CornerRadius = UDim.new(0, 6)
weaponSlotCorner.Parent = weaponSlotBg

local weaponSlotIcon = Instance.new("Frame")
weaponSlotIcon.Name = "WeaponSlotIcon"
weaponSlotIcon.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
weaponSlotIcon.Position = UDim2.new(0, 0, 0, 0)
weaponSlotIcon.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
weaponSlotIcon.Parent = weaponSlotBg

local weaponIconCorner = Instance.new("UICorner")
weaponIconCorner.CornerRadius = UDim.new(0, 6)
weaponIconCorner.Parent = weaponSlotIcon

local weaponIconLabel = Instance.new("TextLabel")
weaponIconLabel.Name = "WeaponIcon"
weaponIconLabel.Size = UDim2.new(1, 0, 1, 0)
weaponIconLabel.BackgroundTransparency = 1
weaponIconLabel.TextColor3 = Color3.new(0.9, 0.7, 0.2)
weaponIconLabel.TextSize = 24
weaponIconLabel.Font = Enum.Font.GothamBold
weaponIconLabel.Text = "⚔"
weaponIconLabel.Parent = weaponSlotIcon

local weaponNameLabel = Instance.new("TextLabel")
weaponNameLabel.Name = "WeaponName"
weaponNameLabel.Size = UDim2.new(0, WEAPON_NAME_WIDTH, 1, 0)
weaponNameLabel.Position = UDim2.new(0, SLOT_SIZE + 5, 0, 0)
weaponNameLabel.BackgroundTransparency = 1
weaponNameLabel.TextColor3 = Color3.new(0.9, 0.7, 0.2)
weaponNameLabel.TextSize = 14
weaponNameLabel.Font = Enum.Font.GothamBold
weaponNameLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponNameLabel.Text = "无"
weaponNameLabel.Parent = weaponSlotBg

-- 分隔线
local dividerStart = BAR_PADDING + SLOT_SIZE + WEAPON_NAME_WIDTH + 10
local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.Size = UDim2.new(0, 2, 0, SLOT_SIZE - 10)
divider.Position = UDim2.new(0, dividerStart, 0.5, -(SLOT_SIZE - 10) / 2)
divider.BackgroundColor3 = Color3.new(0.4, 0.4, 0.4)
divider.BackgroundTransparency = 0.5
divider.BorderSizePixel = 0
divider.Parent = inventoryBar

-- 物品槽位数据
local slotConfigs = {
	{
		Name = "BombSlot",
		Icon = "💣",
		Color = Color3.new(1, 0.5, 0),
		ColorDim = Color3.new(0.5, 0.3, 0.1),
		BgColorActive = Color3.new(0.25, 0.15, 0.05),
		BgColorInactive = Color3.new(0.15, 0.15, 0.15),
		StatName = "Bombs",
		MaxStack = 3
	},
	{
		Name = "HealthPotionSlot",
		Icon = "❤️",
		Color = Color3.new(1, 0.3, 0.3),
		ColorDim = Color3.new(0.5, 0.15, 0.15),
		BgColorActive = Color3.new(0.25, 0.08, 0.08),
		BgColorInactive = Color3.new(0.15, 0.15, 0.15),
		StatName = "HealthPotions",
		MaxStack = 10
	},
	{
		Name = "InvisPotionSlot",
		Icon = "👻",
		Color = Color3.new(0.7, 0.3, 1),
		ColorDim = Color3.new(0.35, 0.15, 0.5),
		BgColorActive = Color3.new(0.18, 0.08, 0.25),
		BgColorInactive = Color3.new(0.15, 0.15, 0.15),
		StatName = "InvisibilityPotions",
		MaxStack = 5
	},
	{
		Name = "ChestSlot",
		Icon = "📦",
		Color = Color3.new(1, 0.8, 0.2),
		ColorDim = Color3.new(0.5, 0.4, 0.1),
		BgColorActive = Color3.new(0.25, 0.2, 0.05),
		BgColorInactive = Color3.new(0.15, 0.15, 0.15),
		StatName = "Chest",
		MaxStack = 1
	}
}

local inventorySlots = {}

for i, cfg in ipairs(slotConfigs) do
	local slotX = dividerStart + 12 + (i - 1) * (SLOT_SIZE + SLOT_GAP)

	local slotFrame = Instance.new("TextButton")
	slotFrame.Name = cfg.Name
	slotFrame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slotFrame.Position = UDim2.new(0, slotX, 0.5, -SLOT_SIZE / 2)
	slotFrame.BackgroundColor3 = cfg.BgColorInactive
	slotFrame.BorderSizePixel = 1
	slotFrame.BorderColor3 = Color3.new(0.3, 0.3, 0.3)
	slotFrame.Text = ""  -- 清除按钮文字
	slotFrame.AutoButtonColor = false
	slotFrame.Parent = inventoryBar

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 6)
	slotCorner.Parent = slotFrame

	-- 图标
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0.7, 0)
	icon.Position = UDim2.new(0, 0, 0, 2)
	icon.BackgroundTransparency = 1
	icon.TextColor3 = cfg.ColorDim
	icon.TextSize = 22
	icon.Font = Enum.Font.GothamBold
	icon.Text = cfg.Icon
	icon.Parent = slotFrame

	-- 数量/最大
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(1, 0, 0, 16)
	countLabel.Position = UDim2.new(0, 0, 1, -16)
	countLabel.BackgroundTransparency = 1
	countLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)
	countLabel.TextSize = 11
	countLabel.Font = Enum.Font.Gotham
	countLabel.Text = "0/" .. cfg.MaxStack
	countLabel.Parent = slotFrame

	-- 右键点击事件
	slotFrame.MouseButton2Down:Connect(function()
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then return end
		local statValue = leaderstats:FindFirstChild(cfg.StatName)
		local count = statValue and statValue.Value or 0
		if count <= 0 then return end

		if cfg.StatName == "Bombs" then
			-- 炸弹：找目标位置投掷
			local targetPos = getBombTargetPosition()
			if targetPos then
				throwBombEvent:FireServer(targetPos)
			end
		elseif cfg.StatName == "HealthPotions" then
			useHealthPotionEvent:FireServer()
		elseif cfg.StatName == "InvisibilityPotions" then
			useInvisibilityPotionEvent:FireServer()
		elseif cfg.StatName == "Chest" then
			-- 箱子：放置在玩家面前
			placeChestEvent:FireServer()
		end
	end)

	inventorySlots[cfg.StatName] = {
		Frame = slotFrame,
		Icon = icon,
		CountLabel = countLabel,
		Config = cfg
	}
end

-- 物品栏快捷键提示
local hotkeyTips = Instance.new("TextLabel")
hotkeyTips.Name = "HotkeyTips"
hotkeyTips.Size = UDim2.new(1, -20, 0, 18)
hotkeyTips.Position = UDim2.new(0, 10, 1, 5)
hotkeyTips.BackgroundTransparency = 1
hotkeyTips.TextColor3 = Color3.new(0.6, 0.6, 0.6)
hotkeyTips.TextSize = 11
hotkeyTips.Font = Enum.Font.Gotham
hotkeyTips.Text = "右键物品栏使用  F拾取"
hotkeyTips.TextXAlignment = Enum.TextXAlignment.Left
hotkeyTips.Parent = inventoryBar

print("✅ HUD UI 创建成功!")

-- ============ HUD 更新逻辑 ============

local function getRequiredExp(level)
	return 100 * math.pow(1.5, level - 1)
end

local function updateHUD()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local healthValue = leaderstats:FindFirstChild("Health")
	local maxHealthValue = leaderstats:FindFirstChild("MaxHealth")
	local levelValue = leaderstats:FindFirstChild("Level")
	local experienceValue = leaderstats:FindFirstChild("Experience")
	local agilityValue = leaderstats:FindFirstChild("Agility")
	local intelligenceValue = leaderstats:FindFirstChild("Intelligence")
	local weaponValue = leaderstats:FindFirstChild("Weapon")

	local health = healthValue and healthValue.Value or 100
	local maxHealth = maxHealthValue and maxHealthValue.Value or 100
	local level = levelValue and levelValue.Value or 1
	local experience = experienceValue and experienceValue.Value or 0
	local agility = agilityValue and agilityValue.Value or 10
	local intelligence = intelligenceValue and intelligenceValue.Value or 10
	local requiredExp = getRequiredExp(level)

	-- 左上属性面板
	levelLabel.Text = "等级: " .. level

	local healthPercent = math.clamp(health / maxHealth, 0, 1)
	healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
	healthLabel.Text = math.floor(health) .. " / " .. maxHealth

	local expPercent = math.clamp(experience / requiredExp, 0, 1)
	expBar.Size = UDim2.new(expPercent, 0, 1, 0)
	expLabel.Text = math.floor(experience) .. " / " .. math.floor(requiredExp)

	agilityLabel.Text = "敏捷: " .. agility
	intelligenceLabel.Text = "智力: " .. intelligence

	-- 底部物品栏 - 武器槽
	if weaponValue and weaponValue.Value ~= "" then
		local weaponData = ItemConfig.Items[weaponValue.Value]
		if weaponData then
			weaponNameLabel.Text = weaponData.Name
		else
			weaponNameLabel.Text = weaponValue.Value
		end
		weaponSlotIcon.BackgroundColor3 = Color3.new(0.4, 0.35, 0.2)
	else
		weaponNameLabel.Text = "无"
		weaponSlotIcon.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
	end

	-- 底部物品栏 - 物品槽
	for statName, slotData in pairs(inventorySlots) do
		local statValue = leaderstats:FindFirstChild(statName)
		local count = statValue and statValue.Value or 0
		local cfg = slotData.Config

		slotData.CountLabel.Text = count .. "/" .. cfg.MaxStack

		if count > 0 then
			slotData.Frame.BackgroundColor3 = cfg.BgColorActive
			slotData.Icon.TextColor3 = cfg.Color
		else
			slotData.Frame.BackgroundColor3 = cfg.BgColorInactive
			slotData.Icon.TextColor3 = cfg.ColorDim
		end
	end
end

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

humanoid.HealthChanged:Connect(function()
	task.wait()
	updateHUD()
end)

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	humanoid.HealthChanged:Connect(function()
		task.wait()
		updateHUD()
	end)
end)

print("🔄 开始 HUD 更新循环...")
while task.wait(0.1) do
	updateHUD()
end