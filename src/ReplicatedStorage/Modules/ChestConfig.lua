-- 箱子配置文件 - 从统一 ItemConfig 读取（兼容层）
-- ⚠️  注意：新代码请直接使用 ItemConfig.Items[itemId] 或 ItemConfig.GetComponent(itemId, "Storage")
local ChestConfig = {}
local ItemConfig = require(script.Parent.ItemConfig)

-- 从统一配置中读取箱子属性
local storage, visual = ItemConfig.GetChestStorageConfig("WoodenChest")
ChestConfig.SlotCount = storage.SlotCount
ChestConfig.InteractDistance = storage.InteractDistance
ChestConfig.DropChance = storage.DropChance
ChestConfig.Visual = {
	BoxSize = visual.BoxSize or Vector3.new(4, 3, 4),
	BoxColor = visual.BoxColor or Color3.fromRGB(139, 90, 43),
	LidSize = visual.LidSize or Vector3.new(4.2, 0.4, 4.2),
	LidColor = visual.LidColor or Color3.fromRGB(160, 110, 55),
	HighlightColor = visual.HighlightColor or Color3.fromRGB(255, 215, 0),
}

function ChestConfig.GetChestConfig(chestId)
	local s, v = ItemConfig.GetChestStorageConfig(chestId or "WoodenChest")
	return s, v
end

return ChestConfig
