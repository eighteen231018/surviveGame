-- 箱子交互客户端脚本
-- 按E键打开/关闭附近箱子，显示箱子UI
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

print("📦 [ChestUI] 脚本开始加载...")

local openChestEvent = ReplicatedStorage:WaitForChild("OpenChestEvent")
local storeToChestEvent = ReplicatedStorage:WaitForChild("StoreToChestEvent")
local takeFromChestEvent = ReplicatedStorage:WaitForChild("TakeFromChestEvent")
local chestUpdateEvent = ReplicatedStorage:WaitForChild("ChestUpdateEvent")
print("📦 [ChestUI] RemoteEvents 获取成功")

-- 加载统一物品配置 ItemConfig
local ItemConfig = nil
local configSuccess, configResult = pcall(function()
	return require(ReplicatedStorage.Modules.ItemConfig)
end)
if configSuccess then
	ItemConfig = configResult
	local weaponList = ItemConfig.GetItemsByType("Weapon")
	local weaponCount = 0
	for _, _ in pairs(weaponList) do weaponCount = weaponCount + 1 end
	print("📦 [ChestUI] ItemConfig 加载成功, 武器数量:", weaponCount)
else
	print("❌ [ChestUI] ItemConfig 加载失败:", configResult)
	ItemConfig = { Items = {} }
end

local CHEST_INTERACT_DISTANCE = 8

-- ============================================================
-- UI 创建
-- ============================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChestUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 背景遮罩
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.BackgroundTransparency = 0.5
bg.BorderSizePixel = 0
bg.Parent = screenGui

-- 主面板
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 620, 0, 420)
mainFrame.Position = UDim2.new(0.5, -310, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
mainFrame.BorderSizePixel = 2
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

-- 标题
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "📦 箱子物品"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- 关闭按钮
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.AutoButtonColor = false
closeBtn.Parent = mainFrame

closeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

-- 分隔线
local divider1 = Instance.new("Frame")
divider1.Name = "Divider1"
divider1.Size = UDim2.new(0.9, 0, 0, 2)
divider1.Position = UDim2.new(0.05, 0, 0, 40)
divider1.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
divider1.BorderSizePixel = 0
divider1.Parent = mainFrame

-- 左边：箱子库存标签
local chestLabel = Instance.new("TextLabel")
chestLabel.Name = "ChestLabel"
chestLabel.Size = UDim2.new(0.5, 0, 0, 25)
chestLabel.Position = UDim2.new(0, 10, 0, 48)
chestLabel.BackgroundTransparency = 1
chestLabel.Text = "箱子库存"
chestLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
chestLabel.TextScaled = true
chestLabel.Font = Enum.Font.GothamBold
chestLabel.TextXAlignment = Enum.TextXAlignment.Left
chestLabel.Parent = mainFrame

-- 右边：我的物品标签
local myLabel = Instance.new("TextLabel")
myLabel.Name = "MyLabel"
myLabel.Size = UDim2.new(0.5, 0, 0, 25)
myLabel.Position = UDim2.new(0.5, 10, 0, 48)
myLabel.BackgroundTransparency = 1
myLabel.Text = "我的物品"
myLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
myLabel.TextScaled = true
myLabel.Font = Enum.Font.GothamBold
myLabel.TextXAlignment = Enum.TextXAlignment.Left
myLabel.Parent = mainFrame

-- 箱子格子的容器（左边）
local chestSlotContainer = Instance.new("Frame")
chestSlotContainer.Name = "ChestSlots"
chestSlotContainer.Size = UDim2.new(0, 330, 0, 130)
chestSlotContainer.Position = UDim2.new(0, 15, 0, 80)
chestSlotContainer.BackgroundTransparency = 1
chestSlotContainer.Parent = mainFrame

-- 竖分隔线
local vDivider = Instance.new("Frame")
vDivider.Name = "VDivider"
vDivider.Size = UDim2.new(0, 2, 0, 320)
vDivider.Position = UDim2.new(0, 350, 0, 80)
vDivider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
vDivider.BorderSizePixel = 0
vDivider.Parent = mainFrame

-- 玩家物品容器（右边）
local playerSlotContainer = Instance.new("Frame")
playerSlotContainer.Name = "PlayerSlots"
playerSlotContainer.Size = UDim2.new(0, 240, 0, 320)
playerSlotContainer.Position = UDim2.new(0, 360, 0, 80)
playerSlotContainer.BackgroundTransparency = 1
playerSlotContainer.Parent = mainFrame

print("📦 [ChestUI] 容器创建完成")

-- 创建格子
local function createSlot(parent, position, size)
	local slot = Instance.new("TextButton")
	slot.Name = "Slot"
	slot.Size = size or UDim2.new(0, 90, 0, 70)
	slot.Position = position
	slot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	slot.BorderColor3 = Color3.fromRGB(100, 100, 100)
	slot.Text = "-"
	slot.TextColor3 = Color3.new(1, 1, 1)
	slot.TextSize = 14
	slot.Font = Enum.Font.Gotham
	slot.AutoButtonColor = false
	slot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = slot

	return slot
end

-- 初始化箱子格子（10个，2行×5列）
local chestSlots = {}
local chestSlotW = 60
local chestSlotH = 58
local chestGapX = 6
local chestGapY = 6
local chestStartX = 4
local chestStartY = 4

for i = 1, 10 do
	local slotIndex = i  -- 捕获当前循环值，避免闭包共享问题
	local col = (i - 1) % 5
	local row = math.floor((i - 1) / 5)
	local pos = UDim2.new(0, chestStartX + col * (chestSlotW + chestGapX), 0, chestStartY + row * (chestSlotH + chestGapY))
	local slot = createSlot(chestSlotContainer, pos, UDim2.new(0, chestSlotW, 0, chestSlotH))
	slot.Name = "ChestSlot_" .. i
	slot.Text = ""

	-- 取出物品
	slot.MouseButton1Click:Connect(function()
		local chestId = screenGui:FindFirstChild("CurrentChestId")
		if chestId then
			takeFromChestEvent:FireServer(chestId.Value, slotIndex)
		end
	end)

	chestSlots[slotIndex] = slot
end

print("📦 [ChestUI] 箱子格子创建完成, 数量:", #chestSlots)

-- 初始化玩家物品格子（4个：武器、炸弹、生命药水、隐形药水）
local playerSlots = {}

-- 玩家物品格子尺寸和位置
local playerSlotW = 220
local playerSlotH = 65
local playerGapY = 10
local playerStartX = 10
local playerStartY = 10

for i = 1, 4 do
	local slotIndex = i  -- 捕获当前循环值，避免闭包共享问题
	local pos = UDim2.new(0, playerStartX, 0, playerStartY + (i - 1) * (playerSlotH + playerGapY))
	local slot = createSlot(playerSlotContainer, pos, UDim2.new(0, playerSlotW, 0, playerSlotH))
	slot.Name = "PlayerSlot_" .. i
	slot.Text = ""  -- 空文本，updatePlayerSlots 会立即填充

	-- 存入物品到箱子
	slot.MouseButton1Click:Connect(function()
		local chestId = screenGui:FindFirstChild("CurrentChestId")
		if not chestId then return end

		local itemData = getPlayerItemData(slotIndex)
		if itemData then
			storeToChestEvent:FireServer(chestId.Value, itemData)
			print("📦 [ChestUI] 存入物品, slot:", slotIndex, "类型:", itemData.Type)
		else
			print("📦 [ChestUI] 没有可存入的物品, slot:", slotIndex)
		end
	end)

	playerSlots[slotIndex] = slot
end

print("📦 [ChestUI] 玩家物品格子创建完成, 数量:", #playerSlots)

-- ============================================================
-- 获取玩家当前物品数据（与 HUD 保持一致的读取逻辑）
-- ============================================================
function getPlayerItemData(slotIndex)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		print("❌ [ChestUI] 找不到 leaderstats")
		return nil
	end

	if slotIndex == 1 then
		-- 武器：从 leaderstats.Weapon(StringValue) 读取武器 ID
		local weaponVal = leaderstats:FindFirstChild("Weapon")
		if weaponVal and weaponVal.Value ~= "" then
			return { Type = "Weapon", Name = weaponVal.Value, Count = 1 }
		end
		return nil
	else
		-- 炸弹/药水：从 leaderstats 读取数量
		local statMap = {
			[2] = { StatName = "Bombs", TypeName = "Bomb" },
			[3] = { StatName = "HealthPotions", TypeName = "HealthPotion" },
			[4] = { StatName = "InvisibilityPotions", TypeName = "InvisibilityPotion" },
		}
		local mapping = statMap[slotIndex]
		if mapping then
			local val = leaderstats:FindFirstChild(mapping.StatName)
			local count = val and val.Value or 0
			if count > 0 then
				return { Type = mapping.TypeName, Count = 1 }  -- 每次只存入1个
			end
		end
		return nil
	end
end

-- ============================================================
-- 更新玩家物品显示（与 HUD 保持一致的读取逻辑）
-- ============================================================
local function updatePlayerSlots()
	local leaderstats = player:FindFirstChild("leaderstats")

	-- 武器槽（从 leaderstats.Weapon 读取，与 HUD 保持一致）
	local weaponText = "⚔ 无"
	local weaponActive = false
	if leaderstats then
		local weaponValue = leaderstats:FindFirstChild("Weapon")
		if weaponValue and weaponValue.Value ~= "" then
			if ItemConfig and ItemConfig.Items then
				local weaponData = ItemConfig.Items[weaponValue.Value]
				if weaponData then
					weaponText = "⚔ " .. weaponData.Name
				else
					weaponText = "⚔ " .. weaponValue.Value
				end
			else
				weaponText = "⚔ " .. weaponValue.Value
			end
			weaponActive = true
		end
	end
	playerSlots[1].Text = weaponText
	playerSlots[1].BackgroundColor3 = weaponActive and Color3.fromRGB(50, 70, 50) or Color3.fromRGB(50, 50, 50)

	-- 炸弹/药水：从 leaderstats 读取数量（与 HUD 保持一致）
	if leaderstats then
		local function getCount(name)
			local v = leaderstats:FindFirstChild(name)
			return v and v.Value or 0
		end

		local bombCount = getCount("Bombs")
		local hpCount = getCount("HealthPotions")
		local ipCount = getCount("InvisibilityPotions")
		print("📦 [ChestUI] updatePlayerSlots: 炸弹=" .. bombCount .. ", 生命药水=" .. hpCount .. ", 隐形药水=" .. ipCount)

		playerSlots[2].Text = "💣 炸弹 x" .. bombCount
		playerSlots[2].BackgroundColor3 = (bombCount > 0) and Color3.fromRGB(70, 50, 30) or Color3.fromRGB(50, 50, 50)

		playerSlots[3].Text = "❤️ 生命药水 x" .. hpCount
		playerSlots[3].BackgroundColor3 = (hpCount > 0) and Color3.fromRGB(70, 30, 30) or Color3.fromRGB(50, 50, 50)

		playerSlots[4].Text = "👻 隐形药水 x" .. ipCount
		playerSlots[4].BackgroundColor3 = (ipCount > 0) and Color3.fromRGB(50, 30, 70) or Color3.fromRGB(50, 50, 50)
	else
		-- leaderstats 尚不可用，显示占位
		for i = 2, 4 do
			playerSlots[i].Text = "加载中..."
			playerSlots[i].BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		end
		print("❌ [ChestUI] updatePlayerSlots: 找不到 leaderstats")
	end
end

print("📦 [ChestUI] updatePlayerSlots 函数已定义")

-- ============================================================
-- 更新UI
-- ============================================================
local currentChestId = nil

local function updateChestUI(chestId, contents)
	currentChestId = chestId

	-- 存储当前箱子ID
	local idStore = screenGui:FindFirstChild("CurrentChestId")
	if not idStore then
		idStore = Instance.new("StringValue")
		idStore.Name = "CurrentChestId"
		idStore.Parent = screenGui
	end
	idStore.Value = chestId or ""

	-- 更新箱子格子
	print("📦 [ChestUI] 更新箱子UI, 内容数:", contents and #contents or 0)
	for i = 1, 10 do
		local slot = chestSlots[i]
		local item = contents and contents[i]
		if item then
			-- 根据类型显示中文名称
			local displayText = item.Type
			if item.Type == "Weapon" then
				-- 武器：从 ItemConfig 取中文名称
				local itemConfig = ItemConfig and ItemConfig.Items and ItemConfig.Items[item.Name]
				if itemConfig then
					displayText = itemConfig.Name
				else
					displayText = item.Name or "武器"
				end
			elseif item.Type == "HealthPotion" then
				displayText = "生命药水"
			elseif item.Type == "InvisibilityPotion" then
				displayText = "隐形药水"
			elseif item.Type == "Bomb" then
				displayText = "炸弹"
			else
				displayText = item.Name or item.Type
			end
			if item.Count and item.Count > 1 then
				displayText = displayText .. " x" .. item.Count
			end
			slot.Text = displayText
			slot.BackgroundColor3 = Color3.fromRGB(70, 50, 30)
			print("📦 [ChestUI] 槽位" .. i .. ": " .. displayText)
		else
			slot.Text = ""
			slot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		end
	end

	-- 更新玩家物品格子
	updatePlayerSlots()
end

print("📦 [ChestUI] updateChestUI 函数已定义")

-- ============================================================
-- 监听服务器发来的箱子内容更新
-- ============================================================
chestUpdateEvent.OnClientEvent:Connect(function(chestId, contents)
	print("📦 [ChestUI] 收到服务器箱子内容更新, chestId:", chestId, "有内容:", contents ~= nil, "currentChestId:", tostring(currentChestId), "UI启用:", screenGui.Enabled)
	if contents then
		for i = 1, 10 do
			if contents[i] then
				print("📦 [ChestUI]  槽位" .. i .. ": 类型=" .. tostring(contents[i].Type) .. ", 名称=" .. tostring(contents[i].Name) .. ", 数量=" .. tostring(contents[i].Count))
			end
		end
	end
	if screenGui.Enabled and currentChestId == chestId then
		updateChestUI(chestId, contents)
		print("📦 [ChestUI] UI已更新")
	else
		print("❌ [ChestUI] 条件不满足，未更新UI (Enabled=" .. tostring(screenGui.Enabled) .. ", match=" .. tostring(currentChestId == chestId) .. ")")
	end
end)

-- ============================================================
-- 交互逻辑：按E键打开/关闭箱子
-- ============================================================

local function findNearestChest()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local nearestChest = nil
	local nearestDist = CHEST_INTERACT_DISTANCE + 1

	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "Chest" then
			local idVal = obj:FindFirstChild("ChestId")
			if idVal then
				local chestPos = obj:GetPivot().Position
				local dist = (root.Position - chestPos).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestChest = obj
				end
			end
		end
	end

	return nearestChest, nearestDist
end

-- E键切换箱子UI
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E then
		-- 如果UI已打开，关闭
		if screenGui.Enabled then
			screenGui.Enabled = false
			_G.chestUIDebugPrinted = false
			return
		end

		-- 尝试打开箱子
		local chest, dist = findNearestChest()
		if chest and dist <= CHEST_INTERACT_DISTANCE then
			local idVal = chest:FindFirstChild("ChestId")
			if idVal then
				screenGui.Enabled = true
				-- 立即设置当前箱子ID（不等待服务器响应）
				currentChestId = idVal.Value
				local idStore = screenGui:FindFirstChild("CurrentChestId")
				if not idStore then
					idStore = Instance.new("StringValue")
					idStore.Name = "CurrentChestId"
					idStore.Parent = screenGui
				end
				idStore.Value = idVal.Value
				print("📦 [ChestUI] 已设置 CurrentChestId:", idVal.Value)
				-- 立即更新玩家物品
				updatePlayerSlots()
				openChestEvent:FireServer(idVal.Value)
				print("📦 [ChestUI] UI已打开, 请求箱子内容")
			end
		else
			print("📦 [ChestUI] 附近没有箱子")
		end
	end
end)

-- 点击背景关闭
bg.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
	_G.chestUIDebugPrinted = false
end)

-- 定期更新玩家物品（当UI打开时）
RunService.Heartbeat:Connect(function()
	if screenGui.Enabled then
		updatePlayerSlots()
	end
end)

print("✅ [ChestUI] 脚本加载完成!")
