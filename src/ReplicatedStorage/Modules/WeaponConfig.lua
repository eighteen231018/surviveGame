-- 武器配置文件 - 从统一 ItemConfig 读取（兼容层）
-- ⚠️  注意：新代码请直接使用 ItemConfig.Items[itemId] 或 ItemConfig.GetComponent(itemId, "Attacker")
local WeaponConfig = {}
local ItemConfig = require(script.Parent.ItemConfig)

-- 从统一配置构建武器列表（保持与旧结构兼容）
WeaponConfig.Weapons = {}
for id, item in pairs(ItemConfig.Items) do
	if item.Type == "Weapon" then
		local attacker = item.Components and item.Components.Attacker or {}
		WeaponConfig.Weapons[id] = {
			Name = item.Name,
			DamageBonus = attacker.DamageBonus or 0,
			RangeBonus = attacker.RangeBonus or 0,
			SpeedMultiplier = attacker.SpeedMultiplier or 1.0,
		}
	end
end

function WeaponConfig.GetWeaponBonuses(weaponId)
	return ItemConfig.GetWeaponBonuses(weaponId)
end

function WeaponConfig.RollRandomWeapon()
	return ItemConfig.RollRandomWeapon()
end

return WeaponConfig
