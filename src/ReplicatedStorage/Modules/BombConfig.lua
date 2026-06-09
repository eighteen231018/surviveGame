-- 炸弹配置文件 - 从统一 ItemConfig 读取（兼容层）
-- ⚠️  注意：新代码请直接使用 ItemConfig.Items[itemId] 或 ItemConfig.GetComponent(itemId, "Explosive")
local BombConfig = {}
local ItemConfig = require(script.Parent.ItemConfig)

-- 从统一配置构建炸弹列表（保持与旧结构兼容）
BombConfig.Bombs = {}
for id, item in pairs(ItemConfig.Items) do
	if item.Type == "Bomb" then
		local explosive = item.Components and item.Components.Explosive or {}
		BombConfig.Bombs[id] = {
			Name = item.Name,
			Damage = explosive.Damage or 0,
			Range = explosive.Range or 0,
		}
	end
end

function BombConfig.GetBombConfig(bombId)
	return BombConfig.Bombs[bombId]
end

return BombConfig
