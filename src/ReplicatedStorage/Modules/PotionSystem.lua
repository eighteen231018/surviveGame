-- 药水系统 - 逻辑实现（属性配置详见统一 ItemConfig）
local PotionSystem = {}
local ItemConfig = require(script.Parent.ItemConfig)

function PotionSystem.GetPotionConfig(potionId)
	return ItemConfig.GetItem(potionId)
end

function PotionSystem.SpawnPotionDrop(position, potionId)
	local item = ItemConfig.GetItem(potionId)
	if not item then
		print("❌ 未知药水类型:", potionId)
		return
	end
	local visual = item.Visual or {}

	local model = Instance.new("Model")
	model.Name = "PotionDrop"

	-- 药水瓶身
	local bottle = Instance.new("Part")
	bottle.Name = "Bottle"
	bottle.Size = Vector3.new(1, 1.5, 1)
	bottle.Position = position + Vector3.new(0, 1, 0)
	bottle.BrickColor = visual.Color or BrickColor.new("Bright green")
	bottle.Material = Enum.Material.Glass
	bottle.Transparency = 0.3
	bottle.Anchored = true
	bottle.CanCollide = false
	bottle.Parent = model

	-- 瓶盖
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Size = Vector3.new(0.8, 0.4, 0.8)
	cap.Position = position + Vector3.new(0, 2.2, 0)
	cap.BrickColor = BrickColor.new("Dark stone grey")
	cap.Material = Enum.Material.Metal
	cap.Anchored = true
	cap.CanCollide = false
	cap.Parent = model

	-- 发光效果
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Size = Vector3.new(0.8, 1.2, 0.8)
	glow.Position = position + Vector3.new(0, 1, 0)
	glow.Transparency = 0.5
	glow.BrickColor = visual.Color or BrickColor.new("Bright green")
	glow.Material = Enum.Material.Neon
	glow.Anchored = true
	glow.CanCollide = false
	glow.Parent = model

	local pointLight = Instance.new("PointLight")
	pointLight.Color = visual.LightColor or Color3.new(0.2, 1, 0.2)
	pointLight.Range = 8
	pointLight.Brightness = 1.5
	pointLight.Parent = glow

	-- 设置PrimaryPart
	model.PrimaryPart = bottle

	-- 标签
	local tag = Instance.new("StringValue")
	tag.Name = "IsPotionDrop"
	tag.Value = "true"
	tag.Parent = model

	local idTag = Instance.new("StringValue")
	idTag.Name = "PotionId"
	idTag.Value = potionId
	idTag.Parent = model

	-- 名称GUI
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameGui"
	gui.Size = UDim2.new(0, 120, 0, 24)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = visual.TextColor or Color3.new(0.3, 1, 0.3)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = visual.LabelText or ("【" .. item.Name .. "】按F拾取")
	nameLabel.Parent = gui

	model.Parent = game.Workspace
	print("🧪 掉落药水:", item.Name, "在:", position)
end

return PotionSystem
