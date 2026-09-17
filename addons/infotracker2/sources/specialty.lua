-- 特产挑战：挑战 → 特产配方 → 制作材料，以及双击材料时的拍卖场查询
-- 任务目标文字的原始内容是「制作@ITEM_NAME(31844)。……」（画面显示时才换成物品名称），
-- 用里面的物品编号对应特产配方的产品编号，与语系无关。
-- 目标文字只有任务在日志里（进行中）才读得到；对到后本次登入会记住。
ADDON:ImportAPI(API_TYPE.QUEST.id)
ADDON:ImportAPI(API_TYPE.CRAFT.id)
ADDON:ImportAPI(API_TYPE.AUCTION.id)

local T = ITV2.Text
local Util = ITV2.SourceUtil

local Specialty = {}
ITV2.Specialty = Specialty

-- 拍卖场刚打开时可能会自己重设查询，所以等一下再送出
local AUCTION_SEARCH_DELAY_MS = 300

local craftByProduct = nil   -- { [产品物品编号] = 配方编号 }
local craftByQuest = {}      -- { [questType] = 配方编号 | false（不是特产） }
local materialCache = {}     -- { [配方编号] = { { name, itemType, amount }, ... } }
local pendingSearch = nil    -- { name, wait }

local function GetCraftByProduct()
    if craftByProduct ~= nil then
        return craftByProduct
    end
    local map = {}
    local found = false
    for _, craftType in ipairs(ITV2.SPECIALTY_CRAFTS) do
        local products = X2Craft:GetCraftProductInfo(craftType)
        local product = type(products) == "table" and products[1] or nil
        local itemType = product ~= nil and tonumber(product.itemType) or nil
        if itemType ~= nil then
            map[itemType] = craftType
            found = true
        end
    end
    -- 一个都读不到（例如还没进入世界）就下次再读
    if found then
        craftByProduct = map
    end
    return map
end

-- 回传：配方编号；目标文字读到了但不是特产回传 false；读不到回传 nil
local function FindCraft(questType, ctx)
    local journal = Util.GetJournalIndexMap(ctx)[questType]
    if journal == nil then
        return nil
    end
    local objective = X2Quest:GetQuestJournalObjectiveText(journal, 1)
    local summary = type(objective) == "table" and objective.summary or objective
    if type(summary) ~= "string" or summary == "" then
        return nil
    end
    local crafts = GetCraftByProduct()
    for itemType in string.gmatch(summary, "@ITEM_NAME%((%d+)%)") do
        local craftType = crafts[tonumber(itemType)]
        if craftType ~= nil then
            return craftType
        end
    end
    return false
end

-- 挑战对应的特产配方编号；不是特产或还读不到回传 nil
function Specialty.GetCraft(questType, ctx)
    local craftType = craftByQuest[questType]
    if craftType == nil then
        -- 同一次刷新里查过就不再查
        ctx.specialtyChecked = ctx.specialtyChecked or {}
        if ctx.specialtyChecked[questType] then
            return nil
        end
        ctx.specialtyChecked[questType] = true
        craftType = FindCraft(questType, ctx)
        -- 配方对照表还没读到时，false 可能是误判，不记住
        if craftType ~= nil and craftByProduct ~= nil then
            craftByQuest[questType] = craftType
        end
    end
    return craftType or nil
end

-- 配方的材料清单（配方资料不会变，读到后就记住）
function Specialty.GetMaterials(craftType)
    local cached = materialCache[craftType]
    if cached ~= nil then
        return cached
    end
    local list = {}
    local materials = X2Craft:GetCraftMaterialInfo(craftType)
    for _, material in ipairs(type(materials) == "table" and materials or {}) do
        local itemInfo = material.item_info
        if itemInfo ~= nil and itemInfo.name ~= nil then
            list[#list + 1] = {
                name = itemInfo.name,
                itemType = tonumber(itemInfo.itemType),
                amount = material.amount,
            }
        end
    end
    if #list > 0 then
        materialCache[craftType] = list
    end
    return list
end

function Specialty.CanSearchAuction(material)
    return material.itemType == nil or not ITV2.AUCTION_EXCLUDED_ITEMS[material.itemType]
end

-- 打开拍卖场，稍后用名称送出查询（见 Tick）
function Specialty.SearchAuction(name)
    local ok, err = pcall(function()
        ADDON:ShowContent(UIC_AUCTION, true)
    end)
    if not ok then
        ITV2.Chat(string.format(T("AUCTION_OPEN_FAILED"), tostring(err)))
    end
    pendingSearch = { name = name, wait = AUCTION_SEARCH_DELAY_MS }
end

function Specialty.Tick(dt)
    if pendingSearch == nil then
        return
    end
    pendingSearch.wait = pendingSearch.wait - (tonumber(dt) or 0)
    if pendingSearch.wait > 0 then
        return
    end
    local name = pendingSearch.name
    pendingSearch = nil
    -- 参数：页数、最低等级、最高等级、品质、分类、完全符合、关键字、最低价、最高价（同 Folio105）
    local ok, err = pcall(function()
        X2Auction:SearchAuctionArticle(1, 0, 999, 1, 0, false, name, "0", "0")
    end)
    if not ok then
        ITV2.Chat(string.format(T("AUCTION_SEARCH_FAILED"), tostring(err)))
    end
end
