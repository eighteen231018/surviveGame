-- 炸弹系统 - 逻辑实现（属性配置详见统一 ItemConfig）
local BombSystem = {}
local ItemConfig = require(script.Parent.ItemConfig)

function BombSystem.GetBombConfig(bombId)
	bombId = bombId or "Bomb"
	local item = ItemConfig.GetItem(bombId)
	if not item then return nil end
	local explosive = item.Components and item.Components.Explosive or {}
	-- 返回扁平结构，保持与旧 API 兼容
	return {
		Id = item.Id,
		Name = item.Name,
		Damage = explosive.Damage or 60,
		Range = explosive.Range or 15,
		FuseTime = explosive.FuseTime or 3,
		Icon = item.Icon,
	}
end

function BombSystem.SpawnBombDrop(position, bombId)
	bombId = bombId or "Bomb"
	local item = ItemConfig.GetItem(bombId)
	if not item then
		print("❌ 未知炸弹类型:", bombId)
		return
	end

	local model = Instance.new("Model")
	model.Name = "BombDrop"

	-- 炸弹主体（黑色球体）
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(1.5, 1.5, 1.5)
	body.Position = position + Vector3.new(0, 1, 0)
	body.BrickColor = BrickColor.new("Black")
	body.Material = Enum.Material.Metal
	body.Shape = Enum.PartType.Ball
	body.Anchored = true
	body.CanCollide = true
	body.Parent = model

	-- 引信
	local fuse = Instance.new("Part")
	fuse.Name = "Fuse"
	fuse.Size = Vector3.new(0.15, 0.8, 0.15)
	fuse.Position = position + Vector3.new(0, 2, 0)
	fuse.BrickColor = BrickColor.new("Brown")
	fuse.Material = Enum.Material.Wood
	fuse.Anchored = true
	fuse.CanCollide = false
	fuse.Parent = model

	-- 火花
	local spark = Instance.new("Part")
	spark.Name = "Spark"
	spark.Size = Vector3.new(0.3, 0.3, 0.3)
	spark.Position = position + Vector3.new(0, 2.5, 0)
	spark.BrickColor = BrickColor.new("Bright red")
	spark.Material = Enum.Material.Neon
	spark.Anchored = true
	spark.CanCollide = false
	spark.Parent = model

	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.new(1, 0.3, 0)
	pointLight.Range = 6
	pointLight.Brightness = 1
	pointLight.Parent = spark

	-- 危险条纹
	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Size = Vector3.new(1.6, 0.2, 0.2)
	stripe.Position = position + Vector3.new(0, 1, 0)
	stripe.BrickColor = BrickColor.new("Bright red")
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.Parent = model

	-- 设置PrimaryPart
	model.PrimaryPart = body

	-- 标签
	local tag = Instance.new("StringValue")
	tag.Name = "IsBombDrop"
	tag.Value = "true"
	tag.Parent = model

	local idTag = Instance.new("StringValue")
	idTag.Name = "BombId"
	idTag.Value = bombId
	idTag.Parent = model

	-- 名称GUI
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameGui"
	gui.Size = UDim2.new(0, 100, 0, 24)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.new(1, 0.5, 0)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = "【" .. item.Name .. "】按F拾取"
	nameLabel.Parent = gui

	model.Parent = game.Workspace
	print("💣 掉落炸弹:", item.Name, "在:", position)
end

return BombSystem
