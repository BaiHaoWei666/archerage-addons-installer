-- 特產挑戰：挑戰 → 特產配方 → 製作材料，以及雙擊材料時的拍賣場查詢
-- 所有任務狀態統一依名稱比對；配方名稱索引與材料資料保留記憶體快取。
ADDON:ImportAPI(API_TYPE.CRAFT.id)
ADDON:ImportAPI(API_TYPE.AUCTION.id)

local T = ITV2.Text
local Util = ITV2.SourceUtil

local Specialty = {}
ITV2.Specialty = Specialty

-- 拍賣場剛打開時可能會自己重設查詢，所以等一下再送出
local AUCTION_SEARCH_DELAY_MS = 300

local craftByName = nil      -- { [產品名稱] = 配方編號 | false（同名配方有歧義） }
local materialCache = {}     -- { [配方編號] = { { name, itemType, amount }, ... } }

local function GetCraftByName(ctx)
    if craftByName ~= nil then return craftByName end
    if ctx.specialtyNames ~= nil then return ctx.specialtyNames end
    local names = {}
    local complete = true
    for _, craftType in ipairs(ITV2.SPECIALTY_CRAFTS) do
        local products = X2Craft:GetCraftProductInfo(craftType)
        local product = type(products) == "table" and products[1] or nil
        local name = product and (product.item_name or product.name)
        if type(name) == "string" and name ~= "" then
            if names[name] == nil then
                names[name] = craftType
            elseif names[name] ~= craftType then
                names[name] = false
            end
        else
            complete = false
        end
    end
    -- 未齊的資料僅於本次重新整理重用，下次重試，避免永久漏掉配方。
    ctx.specialtyNames = names
    if complete and next(names) ~= nil then craftByName = names end
    return names
end

-- 任務名稱先完整比對；中文再依地區簡稱與特產種類找唯一配方。
function Specialty.GetCraft(questType, ctx)
    local title = Util.GetQuestTitle(questType)
    local productTitle = title and string.match(title, "^%[[^%]]+%]%s*(.+)$")
    if productTitle == nil then return nil end
    local names = GetCraftByName(ctx)
    if names[productTitle] ~= nil then return names[productTitle] or nil end
    -- 任務為「地區的種類」，產品為「[地區簡稱]種類」。
    -- 地區簡稱須為任務地區的前綴，種類完全相同，多個候選時不選擇。
    local region, kind = string.match(productTitle, "^(.-)的(.+)$")
    if region == nil or region == "" then return nil end
    local candidate = nil
    for name, craftType in pairs(names) do
        local productRegion, productKind = string.match(name, "^%[([^%]]+)%]%s*(.+)$")
        if productRegion and productKind == kind
            and string.sub(region, 1, #productRegion) == productRegion then
            if craftType == false or (candidate ~= nil and candidate ~= craftType) then
                return nil
            end
            candidate = craftType
        end
    end
    return candidate
end

-- 配方的材料清單（配方資料不會變，讀到後就記住）
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

-- 打開拍賣場，稍後用名稱送出查詢（僅在有查詢時排程）
function Specialty.SearchAuction(name)
    local ok, err = pcall(function()
        ADDON:ShowContent(UIC_AUCTION, true)
    end)
    if not ok then
        ITV2.Chat(string.format(T("AUCTION_OPEN_FAILED"), tostring(err)))
    end
    ITV2.Schedule("specialtyAuction", AUCTION_SEARCH_DELAY_MS, function()
        -- 同 Folio105；同一等待期間只送出最後選取的材料。
        local success, reason = pcall(function()
            X2Auction:SearchAuctionArticle(1, 0, 999, 1, 0, false, name, "0", "0")
        end)
        if not success then
            ITV2.Chat(string.format(T("AUCTION_SEARCH_FAILED"), tostring(reason)))
        end
    end)
end
