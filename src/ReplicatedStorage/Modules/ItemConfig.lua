-- 统一物品配置系统 - 符合 README 描述的配置驱动开发
-- 所有物品（武器、药水、炸弹、箱子）使用统一的配置结构
-- 通过 Components（组件）实现功能配置，通过 Tags 实现分类

local ItemConfig = {}

-- ============================================================
-- 物品字典 - 所有物品在这里定义
-- 通用字段说明（与 README 对应）：
--   Id         : 物品唯一标识符
--   Name       : 显示名称（中文）
--   Type       : 物品类型："Weapon" | "Potion" | "Bomb" | "Chest"
--   Icon       : UI 图标（emoji）
--   MaxStack   : 最大堆叠数（1=不可堆叠）
--   IsPickupable : 是否可拾取（F键）
--   IsEquippable : 是否可装备（装备到手上）
--   IsDroppable  : 是否可丢弃
--   Tags       : 标签数组，用于分类和识别
--   Components : 功能组件配置（如 Attacker=攻击, Healer=治疗, Explosive=爆炸, Invisibility=隐身, Storage=存储）
--   Visual     : 视觉配置（颜色、尺寸、模型 ID 等）
-- ============================================================

ItemConfig.Items = {

	-- ============ 武器 ============

	Longsword = {
		Id = "Longsword",
		Name = "长剑",
		Type = "Weapon",
		Icon = "⚔️",
		MaxStack = 1,
		IsPickupable = true,
		IsEquippable = true,
		IsDroppable = true,
		Tags = {"Weapon", "Melee"},
		Components = {
			Attacker = {
				DamageBonus = 15,      -- 伤害加成
				RangeBonus = 5,          -- 攻击范围加成
				SpeedMultiplier = 0.55,  -- 攻击速度系数（越小越快）
			}
		},
		Visual = {
			LabelColor = Color3.new(0.9, 0.7, 0.2),  -- 名称标签颜色
			GlowColor = Color3.new(0, 0.6, 1),        -- 拾取时发光颜色
		}
	},

	Hammer = {
		Id = "Hammer",
		Name = "大锤",
		Type = "Weapon",
		Icon = "🔨",
		MaxStack = 1,
		IsPickupable = true,
		IsEquippable = true,
		IsDroppable = true,
		Tags = {"Weapon", "Melee", "Heavy"},
		Components = {
			Attacker = {
				DamageBonus = 40,
				RangeBonus = 3,
				SpeedMultiplier = 1.8,
			}
		},
		Visual = {
			LabelColor = Color3.new(0.9, 0.7, 0.2),
			GlowColor = Color3.new(1, 0.3, 0),
		}
	},

	-- ============ 药水 ============

	HealthPotion = {
		Id = "HealthPotion",
		Name = "生命药水",
		Type = "Potion",
		Icon = "❤️",
		MaxStack = 10,
		IsPickupable = true,
		IsEquippable = false,
		IsDroppable = true,
		Tags = {"Potion", "Consumable", "Health"},
		Components = {
			Healer = {
				HealAmount = 30,        -- 基础治疗量
				UseTime = 1,              -- 使用时间
				Cooldown = 5,             -- 冷却时间
				ScalesWithIntellect = true,  -- 受智力属性影响
			}
		},
		Visual = {
			Color = BrickColor.new("Bright red"),
			LightColor = Color3.new(1, 0.2, 0.2),
			TextColor = Color3.new(1, 0.3, 0.3),
			LabelText = "【生命药水】按F拾取",
		}
	},

	InvisibilityPotion = {
		Id = "InvisibilityPotion",
		Name = "隐形药水",
		Type = "Potion",
		Icon = "👻",
		MaxStack = 5,
		IsPickupable = true,
		IsEquippable = false,
		IsDroppable = true,
		Tags = {"Potion", "Consumable", "Invisibility"},
		Components = {
			Invisibility = {
				Duration = 10,      -- 隐身持续时间（秒）
				UseTime = 1,         -- 使用时间
				Cooldown = 8,         -- 冷却时间
				BreaksOnAttack = true,  -- 攻击或受伤时解除隐身
				BreaksOnHit = true,     -- 受伤时解除隐身
			}
		},
		Visual = {
			Color = BrickColor.new("Bright violet"),
			LightColor = Color3.new(0.6, 0.2, 1),
			TextColor = Color3.new(0.7, 0.3, 1),
			LabelText = "【隐形药水】按F拾取",
		}
	},

	-- ============ 炸弹 ============

	Bomb = {
		Id = "Bomb",
		Name = "炸弹",
		Type = "Bomb",
		Icon = "💣",
		MaxStack = 3,
		IsPickupable = true,
		IsEquippable = false,
		IsDroppable = true,
		Tags = {"Bomb", "Explosive", "Consumable"},
		Components = {
			Explosive = {
				Damage = 60,          -- 爆炸伤害
				Range = 15,             -- 爆炸范围
				FuseTime = 3,            -- 引信时间
			}
		},
		Visual = {
			LabelColor = Color3.new(1, 0.5, 0),
			GlowColor = Color3.new(1, 0.3, 0),
			LabelText = "【炸弹】按F拾取",
		}
	},

	-- ============ 箱子（容器） ============

	WoodenChest = {
		Id = "WoodenChest",
		Name = "木箱",
		Type = "Chest",
		Icon = "📦",
		MaxStack = 1,
		IsPickupable = true,
		IsEquippable = false,
		IsDroppable = true,
		Tags = {"Chest", "Container"},
		Components = {
			Storage = {
				SlotCount = 10,          -- 格子数量
				InteractDistance = 8,   -- 交互距离
				DropChance = 0.2,       -- 巢穴掉落概率
			}
		},
		Visual = {
			BoxSize = Vector3.new(4, 3, 4),
			BoxColor = Color3.fromRGB(139, 90, 43),
			LidSize = Vector3.new(4.2, 0.4, 4.2),
			LidColor = Color3.fromRGB(160, 110, 55),
			HighlightColor = Color3.fromRGB(255, 215, 0),
		}
	},
}

-- ============================================================
-- 辅助函数 - 统一的查询接口
-- ============================================================

-- 根据物品 ID 获取完整配置
function ItemConfig.GetItem(itemId)
	if not itemId then return nil end
	return ItemConfig.Items[itemId]
end

-- 获取物品名称（中文）
function ItemConfig.GetName(itemId)
	local item = ItemConfig.Items[itemId]
	return item and item.Name or itemId
end

-- 获取物品显示名称（带图标）
function ItemConfig.GetDisplayName(itemId)
	local item = ItemConfig.Items[itemId]
	if not item then return itemId or "未知物品" end
	if item.Icon then
		return item.Icon .. " " .. item.Name
	end
	return item.Name
end

-- 获取物品类型
function ItemConfig.GetType(itemId)
	local item = ItemConfig.Items[itemId]
	return item and item.Type or nil
end

-- 获取最大堆叠数
function ItemConfig.GetMaxStack(itemId)
	local item = ItemConfig.Items[itemId]
	return item and item.MaxStack or 1
end

-- 获取组件配置（如 Attacker, Healer, Explosive 等）
function ItemConfig.GetComponent(itemId, componentName)
	local item = ItemConfig.Items[itemId]
	if not item or not item.Components then return nil end
	return item.Components[componentName]
end

-- 获取视觉配置
function ItemConfig.GetVisual(itemId)
	local item = ItemConfig.Items[itemId]
	return item and item.Visual or nil
end

-- 按类型筛选物品
function ItemConfig.GetItemsByType(itemType)
	local items = {}
	for id, item in pairs(ItemConfig.Items) do
		if item.Type == itemType then
			items[id] = item
		end
	end
	return items
end

-- 按标签筛选物品
function ItemConfig.GetItemsByTag(tag)
	local items = {}
	for id, item in pairs(ItemConfig.Items) do
		if item.Tags then
			for _, t in ipairs(item.Tags) do
				if t == tag then
					items[id] = item
					break
				end
			end
		end
	end
	return items
end

-- 随机获取指定类型的物品
function ItemConfig.RollRandomItemByType(itemType)
	local items = ItemConfig.GetItemsByType(itemType)
	local ids = {}
	for id, _ in pairs(items) do
		table.insert(ids, id)
	end
	if #ids == 0 then return nil end
	return ids[math.random(1, #ids)]
end

-- ============================================================
-- 兼容层 - 为旧的 WeaponConfig / PotionConfig / BombConfig / ChestConfig 提供兼容
-- 这些旧模块可以从 ItemConfig 读取数据，保持向后兼容
-- ============================================================

-- 兼容旧代码：获取武器列表
function ItemConfig.GetWeapons()
	return ItemConfig.GetItemsByType("Weapon")
end

-- 兼容旧代码：获取武器加成（返回 damageBonus, rangeBonus, speedMultiplier）
function ItemConfig.GetWeaponBonuses(weaponId)
	local attacker = ItemConfig.GetComponent(weaponId, "Attacker")
	if not attacker then return 0, 0, 1.0 end
	return attacker.DamageBonus or 0, attacker.RangeBonus or 0, attacker.SpeedMultiplier or 1.0
end

-- 兼容旧代码：获取药水配置
function ItemConfig.GetPotionConfig(potionId)
	return ItemConfig.Items[potionId]
end

-- 兼容旧代码：获取炸弹配置
function ItemConfig.GetBombConfig(bombId)
	return ItemConfig.Items[bombId]
end

-- 兼容旧代码：获取箱子配置
function ItemConfig.GetChestConfig(chestId)
	return ItemConfig.Items[chestId]
end

-- 兼容旧代码：随机武器
function ItemConfig.RollRandomWeapon()
	return ItemConfig.RollRandomItemByType("Weapon")
end

-- 兼容旧代码：获取箱子属性（用于 ChestSystem）
function ItemConfig.GetChestStorageConfig(chestId)
	local defaultId = chestId or "WoodenChest"
	local storage = ItemConfig.GetComponent(defaultId, "Storage")
	local visual = ItemConfig.GetVisual(defaultId)
	if not storage then
		return { SlotCount = 10, InteractDistance = 8, DropChance = 0.2 }, visual or {}
	end
	return storage, visual or {}
end

return ItemConfig
