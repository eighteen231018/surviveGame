-- 武器系统 - 逻辑实现（属性配置详见统一 ItemConfig）
local WeaponSystem = {}
local ItemConfig = require(script.Parent.ItemConfig)

function WeaponSystem.GetWeaponBonuses(weaponId)
	return ItemConfig.GetWeaponBonuses(weaponId)
end

function WeaponSystem.RollRandomWeapon()
	return ItemConfig.RollRandomWeapon()
end

function WeaponSystem.SpawnWeaponDrop(position, weaponId)
	local config = ItemConfig.GetItem(weaponId)
	if not config then
		print("❌ 未知武器类型:", weaponId)
		return
	end

	local model = Instance.new("Model")
	model.Name = "WeaponDrop"

	if weaponId == "Longsword" then
		local blade = Instance.new("Part")
		blade.Name = "Blade"
		blade.Size = Vector3.new(0.5, 4.5, 0.1)
		blade.Position = position + Vector3.new(0, 1.5, 0)
		blade.BrickColor = BrickColor.new("Light stone grey")
		blade.Material = Enum.Material.Metal
		blade.Anchored = true
		blade.CanCollide = true
		blade.Parent = model

		local bladeTip = Instance.new("WedgePart")
		bladeTip.Name = "BladeTip"
		bladeTip.Size = Vector3.new(0.5, 0.8, 0.1)
		bladeTip.Position = position + Vector3.new(0, 4.15, 0)
		bladeTip.BrickColor = BrickColor.new("Light stone grey")
		bladeTip.Material = Enum.Material.Metal
		bladeTip.Anchored = true
		bladeTip.CanCollide = true
		bladeTip.Parent = model

		local guard = Instance.new("Part")
		guard.Name = "Guard"
		guard.Size = Vector3.new(1.8, 0.15, 0.3)
		guard.Position = position + Vector3.new(0, 1.4, 0)
		guard.BrickColor = BrickColor.new("Dark grey")
		guard.Material = Enum.Material.Metal
		guard.Anchored = true
		guard.CanCollide = true
		guard.Parent = model

		local grip = Instance.new("Part")
		grip.Name = "Grip"
		grip.Size = Vector3.new(0.25, 1.2, 0.25)
		grip.Position = position + Vector3.new(0, 0.6, 0)
		grip.BrickColor = BrickColor.new("Brown")
		grip.Material = Enum.Material.Wood
		grip.Shape = Enum.PartType.Cylinder
		grip.Anchored = true
		grip.CanCollide = true
		grip.Parent = model

		local pommel = Instance.new("Part")
		pommel.Name = "Pommel"
		pommel.Size = Vector3.new(0.4, 0.3, 0.4)
		pommel.Position = position + Vector3.new(0, 1.3, 0)
		pommel.BrickColor = BrickColor.new("Bright yellow")
		pommel.Material = Enum.Material.Metal
		pommel.Anchored = true
		pommel.CanCollide = true
		pommel.Parent = model

		local glow = Instance.new("Part")
		glow.Name = "Glow"
		glow.Size = Vector3.new(1, 6, 1)
		glow.Position = position + Vector3.new(0, 2.8, 0)
		glow.Transparency = 0.75
		glow.BrickColor = BrickColor.new("Cyan")
		glow.Material = Enum.Material.Neon
		glow.Anchored = true
		glow.CanCollide = false
		glow.Parent = model

		local pointLight = Instance.new("PointLight")
		pointLight.Color = Color3.new(0, 0.6, 1)
		pointLight.Range = 10
		pointLight.Brightness = 2
		pointLight.Parent = glow

		model.PrimaryPart = blade

	elseif weaponId == "Hammer" then
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.5, 3.5, 0.5)
		handle.Position = position + Vector3.new(0, 1.5, 0)
		handle.BrickColor = BrickColor.new("Brown")
		handle.Material = Enum.Material.Wood
		handle.Anchored = true
		handle.CanCollide = true
		handle.Parent = model

		local handleGrip = Instance.new("Part")
		handleGrip.Name = "HandleGrip"
		handleGrip.Size = Vector3.new(0.6, 1.2, 0.6)
		handleGrip.Position = position + Vector3.new(0, 0.5, 0)
		handleGrip.BrickColor = BrickColor.new("Dark brown")
		handleGrip.Material = Enum.Material.Wood
		handleGrip.Anchored = true
		handleGrip.CanCollide = true
		handleGrip.Parent = model

		local hammerHead = Instance.new("Part")
		hammerHead.Name = "HammerHead"
		hammerHead.Size = Vector3.new(2.5, 1.5, 1.5)
		hammerHead.Position = position + Vector3.new(0, 3.2, 0)
		hammerHead.BrickColor = BrickColor.new("Dark grey")
		hammerHead.Material = Enum.Material.Metal
		hammerHead.Anchored = true
		hammerHead.CanCollide = true
		hammerHead.Parent = model

		local headLeft = Instance.new("Part")
		headLeft.Name = "HeadLeft"
		headLeft.Size = Vector3.new(0.8, 0.6, 1.2)
		headLeft.Position = position + Vector3.new(-1.65, 3.2, 0)
		headLeft.BrickColor = BrickColor.new("Dark grey")
		headLeft.Material = Enum.Material.Metal
		headLeft.Anchored = true
		headLeft.CanCollide = true
		headLeft.Parent = model

		local headRight = Instance.new("Part")
		headRight.Name = "HeadRight"
		headRight.Size = Vector3.new(0.8, 0.6, 1.2)
		headRight.Position = position + Vector3.new(1.65, 3.2, 0)
		headRight.BrickColor = BrickColor.new("Dark grey")
		headRight.Material = Enum.Material.Metal
		headRight.Anchored = true
		headRight.CanCollide = true
		headRight.Parent = model

		local glow = Instance.new("Part")
		glow.Name = "Glow"
		glow.Size = Vector3.new(2, 1.5, 1.5)
		glow.Position = position + Vector3.new(0, 3.2, 0)
		glow.Transparency = 0.75
		glow.BrickColor = BrickColor.new("Bright red")
		glow.Material = Enum.Material.Neon
		glow.Anchored = true
		glow.CanCollide = false
		glow.Parent = model

		local pointLight = Instance.new("PointLight")
		pointLight.Color = Color3.new(1, 0.3, 0)
		pointLight.Range = 12
		pointLight.Brightness = 2.5
		pointLight.Parent = glow

		model.PrimaryPart = hammerHead
	end

	local touchBox = Instance.new("Part")
	touchBox.Name = "TouchBox"
	touchBox.Size = Vector3.new(4, 5, 4)
	touchBox.Position = position + Vector3.new(0, 2, 0)
	touchBox.Transparency = 0.95
	touchBox.Anchored = true
	touchBox.CanCollide = false
	touchBox.Parent = model

	local tag = Instance.new("StringValue")
	tag.Name = "IsWeaponDrop"
	tag.Value = "true"
	tag.Parent = model

	local idTag = Instance.new("StringValue")
	idTag.Name = "WeaponId"
	idTag.Value = weaponId
	idTag.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "NameGui"
	gui.Size = UDim2.new(0, 120, 0, 24)
	gui.StudsOffset = Vector3.new(0, 7.5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.new(0.9, 0.7, 0.2)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = "【" .. config.Name .. "】按F拾取"
	nameLabel.Parent = gui

	model.Parent = game.Workspace
	print("🗡️ 掉落武器:", config.Name, "在:", position)
end

return WeaponSystem
