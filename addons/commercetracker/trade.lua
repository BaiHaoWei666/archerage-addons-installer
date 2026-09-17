-- 路线比率与包的计算
-- 流程：选好路线 → Trade.Request(from, to) → X2Store:GetSpecialtyRatioBetween
--      → 事件 SPECIALTY_RATIO_BETWEEN_INFO 回传 { { itemInfo, ratio }, ... } → 整理成 Trade.packs → 通知主视窗
-- 每个包：
--   特产包：itemInfo.itemType → X2Craft:GetCraftTypeByItemType → CT.SPECIALTY_CRAFTS（配方编号 → 英文名称）
--           材料用 X2Craft:GetCraftMaterialInfo 实时读取
--   其他包：沿用 Folio105 的名称判断（英文客户端直接用名称；中文客户端用关键字 + 起始区域编号组出英文名称）
--   基础售价：CT.BASE_PRICES[交货区域][英文名称]
ADDON:ImportAPI(API_TYPE.STORE.id)
ADDON:ImportAPI(API_TYPE.CRAFT.id)
ADDON:ImportAPI(API_TYPE.ABILITY.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)

local T = CT.Text

local Trade = {}
CT.Trade = Trade

-- 临时诊断：第一次收到路线资料时，把第一个包的栏位与配方对应印到聊天框，确认后删除
local DEBUG_DUMP = true

local COOLDOWN_MS = 5200            -- 路线比率查询的冷却
local COMMERCE_BONUS_PER_POINT = 0.05 / 10000

-- 经商熟练度的各语系名称（技能 id 为 nil，只能用名称比对）
local COMMERCE_SKILL_NAMES = {
    ["Commerce"] = true,   -- en_us
    ["经商"] = true,        -- zh_cn
}

local language = X2Locale:GetLocale() or "en_us"

Trade.route = { continent = nil, from = nil, to = nil }
Trade.packs = {}             -- 目前路线的包（照回传顺序）
Trade.commerceSkill = 0
Trade.cooldownMs = 0

local zoneNames = {}         -- { [区域编号] = 游戏语系名称 }
local specialtyByName = {}   -- { [英文名称] = 配方编号 }
for craftType, name in pairs(CT.SPECIALTY_CRAFTS) do
    specialtyByName[name] = craftType
end
local materialCache = {}     -- { [配方编号] = { { name, itemType, amount }, ... } }
local waitingResult = false  -- 有送出查询、还没收到结果（其他插件的查询结果不处理）

-- ============================================
-- 区域与熟练度
-- ============================================
function Trade.LoadZoneNames()
    local ok, groups = pcall(function()
        return X2Store:GetProductionZoneGroups()
    end)
    if not ok or type(groups) ~= "table" then
        return
    end
    for _, group in pairs(groups) do
        if group.id ~= nil and group.zoneGroupName ~= nil then
            zoneNames[group.id] = group.zoneGroupName
        end
    end
end

function Trade.ZoneName(zoneId)
    if zoneId == nil then
        return ""
    end
    local zone = CT.ZONES[zoneId]
    return zoneNames[zoneId] or (zone and zone.name) or string.format(T("ZONE_FALLBACK"), zoneId)
end

function Trade.ContinentOf(key)
    for _, continent in ipairs(CT.CONTINENTS) do
        if continent.key == key then
            return continent
        end
    end
    return nil
end

function Trade.UpdateCommerceSkill()
    local skill = 0
    local ok, infos = pcall(function()
        return X2Ability:GetAllMyActabilityInfos()
    end)
    if ok and type(infos) == "table" then
        for _, info in pairs(infos) do
            if info and info.name and COMMERCE_SKILL_NAMES[info.name] then
                skill = (info.point or 0) + (info.modifyPoint or 0)
                break
            end
        end
    end
    Trade.commerceSkill = skill
    return skill
end

-- 经商熟练度的售价加成（百分比）
function Trade.CommerceBonusPercent()
    return Trade.commerceSkill * COMMERCE_BONUS_PER_POINT * 100
end

-- ============================================
-- 包的辨识
-- ============================================
-- 中文客户端：包名关键字 → 英文名称的种类（照顺序比对，先比长的）
local ZH_PACK_KINDS = {
    { keyword = "肥料特产", kind = "Fertilizer Specialty" },
    { keyword = "传统特产", kind = "Local Specialty" },
    { keyword = "特制特产", kind = "Gilda Specialty" },
    { keyword = "特产", kind = "Specialty" },
    { keyword = "发酵蜂蜜", kind = "Aged Honey" },
    { keyword = "发酵奶酪", kind = "Aged Cheese" },
    { keyword = "发酵药材", kind = "Aged Salve" },
}

-- 名称 → Folio105 价格表用的英文名称；认不出来就回传原名称
local function CanonicalNameFromText(name, fromZone)
    if name == nil or name == "" then
        return name
    end
    -- 英文客户端的名称本身就是价格表的 key
    if string.find(name, "Specialty", 1, true) or string.find(name, "Aged ", 1, true)
        or string.find(name, " Pack", 1, true) then
        return name
    end
    local zone = CT.ZONES[fromZone]
    if language ~= "zh_cn" or zone == nil or zone.base == nil then
        return name
    end
    for _, rule in ipairs(ZH_PACK_KINDS) do
        if string.find(name, rule.keyword, 1, true) then
            return string.format("%s %s %s", zone.base, zone.tier, rule.kind)
        end
    end
    if string.find(name, "蓝盐商会", 1, true) and string.find(name, "运输", 1, true) then
        return zone.base .. " Pack"
    end
    return name
end

local function FindSpecialtyCraft(itemInfo)
    local itemType = tonumber(itemInfo.itemType or itemInfo.item_type or itemInfo.type)
    if itemType == nil then
        return nil
    end
    local ok, craftType = pcall(function()
        return X2Craft:GetCraftTypeByItemType(itemType)
    end)
    craftType = ok and tonumber(craftType) or nil
    if craftType ~= nil and CT.SPECIALTY_CRAFTS[craftType] ~= nil then
        return craftType
    end
    return nil
end

-- 配方的材料清单（配方资料不会变，读到后就记住）
local function GetMaterials(craftType)
    local cached = materialCache[craftType]
    if cached ~= nil then
        return cached
    end
    local list = {}
    local ok, materials = pcall(function()
        return X2Craft:GetCraftMaterialInfo(craftType)
    end)
    for _, material in ipairs(ok and type(materials) == "table" and materials or {}) do
        local itemInfo = material.item_info
        if itemInfo ~= nil and itemInfo.name ~= nil then
            list[#list + 1] = {
                name = itemInfo.name,
                itemType = tonumber(itemInfo.itemType),
                amount = tonumber(material.amount) or 0,
            }
        end
    end
    if #list > 0 then
        materialCache[craftType] = list
    end
    return list
end

local function FreshnessMultiplier(canonicalName, toZone)
    local byDestination = CT.FRESHNESS_BY_DESTINATION[toZone]
    if byDestination ~= nil then
        return byDestination
    end
    for tier, multiplier in pairs(CT.FRESHNESS_BY_TIER) do
        if canonicalName and string.find(canonicalName, tier, 1, true) then
            return multiplier
        end
    end
    return 1
end

-- 回传 { name, icon, ratio, canonicalName, craftType, isSpecialty, basePrice, freshness, materials }
local function AnalyzePack(entry, fromZone, toZone)
    local itemInfo = entry.itemInfo or {}
    local craftType = FindSpecialtyCraft(itemInfo)
    local canonicalName = craftType and CT.SPECIALTY_CRAFTS[craftType]
        or CanonicalNameFromText(itemInfo.name, fromZone)
    if craftType == nil then
        craftType = specialtyByName[canonicalName]
    end
    local prices = CT.BASE_PRICES[toZone]
    return {
        name = itemInfo.name or "",
        icon = itemInfo.icon,
        ratio = tonumber(entry.ratio) or 0,
        canonicalName = canonicalName,
        craftType = craftType,
        isSpecialty = craftType ~= nil,
        basePrice = prices and prices[canonicalName],
        freshness = FreshnessMultiplier(canonicalName, toZone),
        materials = craftType and GetMaterials(craftType) or {},
    }
end

-- 最高新鲜度下的售价（铜）；没有基础售价时回传 nil
function Trade.SalePrice(pack)
    if pack.basePrice == nil then
        return nil
    end
    local commerceBonus = 1 + Trade.commerceSkill * COMMERCE_BONUS_PER_POINT
    return math.floor(pack.basePrice * pack.ratio * commerceBonus * pack.freshness)
end

function Trade.CanQueryMaterial(material)
    return not (material.itemType and CT.AUCTION_EXCLUDED_ITEMS[material.itemType])
end

-- ============================================
-- 路线比率查询
-- ============================================
function Trade.Clear()
    Trade.packs = {}
end

function Trade.IsCoolingDown()
    return Trade.cooldownMs > 0
end

-- 回传是否有送出
function Trade.Request()
    local route = Trade.route
    -- 同一区域互查会让游戏出错，直接略过
    if route.from == nil or route.to == nil or route.from == route.to or Trade.IsCoolingDown() then
        return false
    end
    Trade.UpdateCommerceSkill()
    Trade.Clear()
    Trade.cooldownMs = COOLDOWN_MS
    waitingResult = true
    local ok, sent = pcall(function()
        return X2Store:GetSpecialtyRatioBetween(route.from, route.to)
    end)
    if not ok or not sent then
        CT.Chat(T("REQUEST_FAILED"))
        Trade.cooldownMs = 0
        waitingResult = false
        return false
    end
    return true
end

function Trade.Tick(dt)
    if Trade.cooldownMs > 0 then
        Trade.cooldownMs = math.max(0, Trade.cooldownMs - (tonumber(dt) or 0))
    end
end

local function DumpFirstPack(entries)
    if not DEBUG_DUMP then
        return
    end
    DEBUG_DUMP = false
    local entry = entries[1]
    local itemInfo = entry and entry.itemInfo
    if type(itemInfo) ~= "table" then
        CT.Chat("[CT debug] no itemInfo")
        return
    end
    local parts = {}
    for key, value in pairs(itemInfo) do
        if type(value) ~= "table" and key ~= "description" then
            parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
        end
    end
    table.sort(parts)
    CT.Chat("[CT debug] ratio=" .. tostring(entry.ratio) .. " " .. table.concat(parts, ", "))
    for _, e in ipairs(entries) do
        local pack = e.itemInfo and AnalyzePack(e, Trade.route.from, Trade.route.to)
        if pack then
            CT.Chat(string.format("[CT debug] %s -> craft=%s en=%s base=%s mats=%d",
                tostring(pack.name), tostring(pack.craftType), tostring(pack.canonicalName),
                tostring(pack.basePrice), #pack.materials))
        end
    end
end

local function OnRatioResult(result)
    if not waitingResult then
        return   -- 其他插件（例如 Folio105）送出的查询
    end
    waitingResult = false
    if type(result) ~= "table" then
        CT.Chat(T("RESULT_MISSING"))
        return
    end
    -- 回传的 key 不一定连续，照 key 排序保持固定顺序
    local keys = {}
    for key, entry in pairs(result) do
        if type(entry) == "table" and entry.itemInfo ~= nil then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na ~= nil and nb ~= nil then
            return na < nb
        end
        return tostring(a) < tostring(b)
    end)
    local entries = {}
    for _, key in ipairs(keys) do
        entries[#entries + 1] = result[key]
    end
    DumpFirstPack(entries)

    local packs = {}
    for _, entry in ipairs(entries) do
        packs[#packs + 1] = AnalyzePack(entry, Trade.route.from, Trade.route.to)
    end
    Trade.packs = packs
    CT.MainWindow.Refresh()
end

UIParent:SetEventHandler(UIEVENT_TYPE.SPECIALTY_RATIO_BETWEEN_INFO, OnRatioResult)
