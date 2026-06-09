-- 药水配置文件 - 从统一 ItemConfig 读取（兼容层）
-- ⚠️  注意：新代码请直接使用 ItemConfig.Items[itemId] 或 ItemConfig.GetComponent(itemId, "Healer")
local PotionConfig = {}
local ItemConfig = require(script.Parent.ItemConfig)

-- 从统一配置构建药水列表（保持与旧结构兼容）
PotionConfig.Potions = {}
for id, item in pairs(ItemConfig.Items) do
	if item.Type == "Potion" then
		local visual = item.Visual or {}
		PotionConfig.Potions[id] = {
			Name = item.Name,
			Color = visual.Color,
			LightColor = visual.LightColor,
			TextColor = visual.TextColor,
			LabelText = visual.LabelText or ("【" .. item.Name .. "】按F拾取"),
		}
	end
end

function PotionConfig.GetPotionConfig(potionId)
	return PotionConfig.Potions[potionId]
end

return PotionConfig
