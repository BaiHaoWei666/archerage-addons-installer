-- 材料拍卖查价（按「查价」手动开始，与路线比率查询分开）
-- 目前路线所有特产包的材料去重后排队，每 THROTTLE_MS 送出一笔；
-- 事件 AUCTION_ITEM_SEARCHED 回传后，取名称相符的第一笔（没有就取第一笔）的单价
ADDON:ImportAPI(API_TYPE.AUCTION.id)

local Auction = {}
CT.Auction = Auction

local THROTTLE_MS = 1200

local prices = {}       -- { [材料 key] = 单价（铜） }
local queue = {}        -- { material, ... }
local active = nil      -- 已送出、等待结果的材料
local running = false
local waitMs = 0

-- 有物品编号就用编号，没有才用名称
local function KeyOf(material)
    return material.itemType or material.name
end

-- 已知单价；还没查到回传 0
function Auction.PriceOf(material)
    return prices[KeyOf(material)] or 0
end

function Auction.IsRunning()
    return running
end

local function Finish()
    queue = {}
    active = nil
    running = false
    CT.MainWindow.OnAuctionStateChanged()
end

function Auction.Cancel()
    if running then
        Finish()
    end
end

local function SendNext()
    local material = table.remove(queue, 1)
    if material == nil then
        Finish()
        return
    end
    active = material
    waitMs = THROTTLE_MS
    -- 参数：页数、最低等级、最高等级、品质、分类、完全符合、关键字、最低价、最高价（同 Folio105）
    local ok = pcall(function()
        X2Auction:SearchAuctionArticle(1, 0, 999, 1, 0, false, material.name, "0", "0")
    end)
    if not ok then
        active = nil
    end
end

-- 查询目前路线所有特产包的材料（非卖品除外）
function Auction.StartForPacks(packs)
    prices = {}
    queue = {}
    active = nil
    local seen = {}
    for _, pack in ipairs(packs) do
        if pack.isSpecialty then
            for _, material in ipairs(pack.materials) do
                local key = KeyOf(material)
                if not seen[key] and CT.Trade.CanQueryMaterial(material) then
                    seen[key] = true
                    queue[#queue + 1] = material
                end
            end
        end
    end
    if #queue == 0 then
        Finish()
        return
    end
    running = true
    CT.MainWindow.OnAuctionStateChanged()
    SendNext()
end

function Auction.Tick(dt)
    if not running then
        return
    end
    waitMs = waitMs - (tonumber(dt) or 0)
    if waitMs <= 0 then
        SendNext()
    end
end

-- 拍卖回传的单价：数值栏位优先，没有就从「x金x银x铜」文字解析（沿用 Folio105）
local function ParseUnitPrice(itemInfo)
    if itemInfo == nil then
        return 0
    end
    for _, value in ipairs({ itemInfo.bidPrice, itemInfo.price, itemInfo.unitPrice }) do
        local number = tonumber(value)
        if number and number > 0 then
            return math.floor(number)
        end
    end
    local nums = {}
    for number in string.gmatch(itemInfo.bidPriceStr or itemInfo.priceStr or "", "%d+") do
        nums[#nums + 1] = tonumber(number)
    end
    if #nums >= 3 then
        return nums[1] * 10000 + nums[2] * 100 + nums[3]
    elseif #nums == 2 then
        return nums[1] * 10000 + nums[2] * 100
    elseif #nums == 1 then
        return nums[1]
    end
    return 0
end

local function OnSearched()
    local material = active
    if material == nil then
        return   -- 不是这个插件送出的查询
    end
    active = nil
    local count = tonumber(X2Auction:GetSearchedItemCount()) or 0
    if count <= 0 then
        return
    end
    local chosen = nil
    for index = 1, count do
        local info = X2Auction:GetSearchedItemInfo(index)
        if info ~= nil and info.name == material.name then
            chosen = info
            break
        end
    end
    chosen = chosen or X2Auction:GetSearchedItemInfo(1)
    prices[KeyOf(material)] = ParseUnitPrice(chosen)
    CT.MainWindow.Refresh()
end

UIParent:SetEventHandler(UIEVENT_TYPE.AUCTION_ITEM_SEARCHED, OnSearched)
