-- 主视窗（版面沿用 Folio105）
--   上方：标题、载入提示、重新整理（冷却倒数）、查价 / 停止查价、收藏、关闭
--   中间：路线上的每个包：图示、名称、比率、售价；
--         特产包另列「材料 x数量」与各材料成本、每包成本、每包利润
--   下方：经商熟练度与加成、大陆 / 起始区域 / 交货区域选单
local T = CT.Text
local UI = CT.UI
local Trade = CT.Trade
local Auction = CT.Auction

local MainWindow = {}
CT.MainWindow = MainWindow

local WIDTH = 800
local INITIAL_HEIGHT = 575
local BASE_HEIGHT = 175          -- 包清单以外的高度（上方按钮列 + 下方资讯与选单）
local LIST_TOP = 80
local LIST_LEFT = 20
local PACK_HEIGHT = 40
local MATERIAL_LINE_HEIGHT = 15
local SPECIALTY_EXTRA_HEIGHT = 10
local ICON_SIZE = 35
local TEXT_LEFT = LIST_LEFT + 50            -- 包名、材料的 x
local RATIO_RIGHT = -50                     -- 比率右缘（相对视窗右边）
local SALE_PRICE_RIGHT = WIDTH - 120        -- 售价右缘
local MATERIAL_COST_RIGHT = 450             -- 各材料成本右缘
local SUMMARY_RIGHT = 680                   -- 每包成本 / 利润右缘
local SUMMARY_OFFSET_Y = -10
local LINE_LEFT = 10
local COMBO_WIDTH = 160
local COMBO_HEIGHT = 30
local ELLIPSIS_MS = 500

local COLOR_MATERIAL = { 0.7, 0.7, 1.0 }
local COLOR_COST = { 1, 0.5, 0 }
local COLOR_PROFIT = { 0, 1, 0 }
local COLOR_LOSS = { 1, 0, 0 }

-- 比率颜色：{ 最低比率, r, g, b }，由高到低比对
local RATIO_COLORS = {
    { 130, 0, 1, 0 },
    { 125, 0.4, 1, 0 },
    { 120, 0.7, 1, 0 },
    { 115, 1, 1, 0 },
    { 110, 1, 0.7, 0 },
    { 105, 1, 0.5, 0 },
    { 0, 1, 0, 0 },
}

local route = Trade.route

-- ============================================
-- 视窗与上方按钮
-- ============================================
local window = CreateEmptyWindow("ctMainWindow", "UIParent")
window:SetExtent(WIDTH, INITIAL_HEIGHT)
window:AddAnchor("CENTER", "UIParent", 0, 0)
window:SetCloseOnEscape(true)
window:EnableDrag(true)
window:SetHandler("OnDragStart", function(self)
    self:StartMoving()
end)
window:SetHandler("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)
window:Show(false)
MainWindow.window = window

local title = UI.CreateCaption(window, "ctTitle", 25, T("TITLE"), ALIGN_CENTER)
title:SetHeight(30)
title:AddAnchor("TOP", window, 0, 10)

local loadingLabel = UI.CreateText(window, "ctLoading", 16)
loadingLabel:AddAnchor("TOPLEFT", window, 20, 25)
loadingLabel.style:SetColor(0, 1, 0, 1)
loadingLabel:SetText(T("LOADING_PRICES"))
loadingLabel:Show(false)

local closeButton = UI.CreateTextButton(window, "ctClose", "X", 45, 30)
closeButton:AddAnchor("TOPRIGHT", window, -10, 10)
closeButton:SetHandler("OnClick", function()
    window:Show(false)
end)

local refreshButton = UI.CreateResetButton(window, "ctRefresh", 28)
refreshButton:AddAnchor("TOPRIGHT", window, -190, 11)

local countdownLabel = UI.CreateText(window, "ctCountdown", 16, ALIGN_CENTER)
countdownLabel:AddAnchor("RIGHT", refreshButton, -35, 0)
countdownLabel.style:SetColor(1, 0, 0, 1)
countdownLabel:Show(false)

local queryButton = UI.CreateTextButton(window, "ctQuery", T("QUERY_PRICES"), 120, 28)
queryButton:AddAnchor("TOPRIGHT", window, -190, 41)

local favoritesButton = UI.CreateTextButton(window, "ctFavoritesButton", T("FAVORITES"), 120, 28)
favoritesButton:AddAnchor("TOPRIGHT", window, -60, 41)

-- ============================================
-- 下方：熟练度与路线选单
-- ============================================
local professionLabel = UI.CreateText(window, "ctProfession", 14)
professionLabel:AddAnchor("BOTTOMLEFT", window, 20, -55)
professionLabel.style:SetColor(0.55, 0.85, 1.0, 1)

local continentCaption = UI.CreateCaption(window, "ctContinentLabel", 15, T("CONTINENT_LABEL"))
continentCaption:AddAnchor("BOTTOMLEFT", window, 20, -25)
local fromCaption = UI.CreateCaption(window, "ctFromLabel", 15, T("FROM_LABEL"))
fromCaption:AddAnchor("BOTTOMLEFT", window, 280, -25)
local toCaption = UI.CreateCaption(window, "ctToLabel", 15, T("TO_LABEL"))
toCaption:AddAnchor("BOTTOMLEFT", window, 540, -25)

local continentCombo = UI.CreateComboBox(window, "ctContinentCombo", COMBO_WIDTH, COMBO_HEIGHT)
continentCombo.trigger:AddAnchor("BOTTOMLEFT", window, 105, -10)
local fromCombo = UI.CreateComboBox(window, "ctFromCombo", COMBO_WIDTH, COMBO_HEIGHT)
fromCombo.trigger:AddAnchor("BOTTOMLEFT", window, 370, -10)
local toCombo = UI.CreateComboBox(window, "ctToCombo", COMBO_WIDTH, COMBO_HEIGHT)
toCombo.trigger:AddAnchor("BOTTOMLEFT", window, 610, -10)

-- ============================================
-- 包清单（依需要建立，重复使用）
-- ============================================
local rows = {}
local topLine = UI.CreateLine(window, WIDTH - LINE_LEFT * 2, 3)
topLine:SetVisible(false)

local function EnsureMaterialLine(row, index)
    local line = row.materials[index]
    if line ~= nil then
        return line
    end
    local id = row.id .. "Mat" .. index
    line = {
        label = UI.CreateText(window, id, 12),
        cost = UI.CreateCurrency(window, id .. "Cost", 12),
    }
    line.label.style:SetColor(COLOR_MATERIAL[1], COLOR_MATERIAL[2], COLOR_MATERIAL[3], 1)
    UI.SetCurrencyColor(line.cost, COLOR_COST[1], COLOR_COST[2], COLOR_COST[3])
    row.materials[index] = line
    return line
end

local function EnsureRow(index)
    local row = rows[index]
    if row ~= nil then
        return row
    end
    local id = "ctPack" .. index
    row = { id = id, materials = {} }
    row.icon = UI.CreateIcon(window, nil, ICON_SIZE, ICON_SIZE)
    row.name = UI.CreateText(window, id .. "Name", 15)
    row.ratio = UI.CreateText(window, id .. "Ratio", 15, ALIGN_RIGHT)
    row.sale = UI.CreateCurrency(window, id .. "Sale", 15)
    row.packCost = UI.CreateCurrency(window, id .. "PackCost", 12)
    UI.SetCurrencyColor(row.packCost, COLOR_COST[1], COLOR_COST[2], COLOR_COST[3])
    row.profit = UI.CreateCurrency(window, id .. "Profit", 12)
    row.line = UI.CreateLine(window, WIDTH - LINE_LEFT * 2, 2)
    rows[index] = row
    return row
end

local function HideMaterialLines(row, fromIndex)
    for index = fromIndex, #row.materials do
        row.materials[index].label:Show(false)
        UI.HideCurrency(row.materials[index].cost)
    end
end

local function HideRow(row)
    row.icon:SetVisible(false)
    row.name:Show(false)
    row.ratio:Show(false)
    UI.HideCurrency(row.sale)
    UI.HideCurrency(row.packCost)
    UI.HideCurrency(row.profit)
    row.line:SetVisible(false)
    HideMaterialLines(row, 1)
end

local function ApplyRatioColor(label, ratio)
    for _, rule in ipairs(RATIO_COLORS) do
        if ratio >= rule[1] then
            label.style:SetColor(rule[2], rule[3], rule[4], 1)
            return
        end
    end
end

local function Place(widget, point, x, y)
    widget:RemoveAllAnchors()
    widget:AddAnchor(point, window, x, y)
end

-- 画一个包，回传这个包占的高度
local function LayoutPack(row, pack, y)
    UI.SetIconTexture(row.icon, pack.icon)
    Place(row.icon, "TOPLEFT", LIST_LEFT, y)
    row.icon:SetVisible(true)

    row.name:SetText(pack.name)
    Place(row.name, "TOPLEFT", TEXT_LEFT, y + 7)
    row.name:Show(true)

    ApplyRatioColor(row.ratio, pack.ratio)
    row.ratio:SetText(string.format("%s%%", tostring(pack.ratio)))
    Place(row.ratio, "TOPRIGHT", RATIO_RIGHT, y + 10)
    row.ratio:Show(true)

    local salePrice = Trade.SalePrice(pack)
    if salePrice ~= nil then
        UI.ShowCurrency(window, row.sale, SALE_PRICE_RIGHT, y + 10, salePrice, true)
    else
        UI.HideCurrency(row.sale)
    end

    local height = PACK_HEIGHT
    if pack.isSpecialty then
        local lineY = y + 30
        local totalCost = 0
        for index, material in ipairs(pack.materials) do
            local cost = material.amount * Auction.PriceOf(material)
            totalCost = totalCost + cost
            local line = EnsureMaterialLine(row, index)
            line.label:SetText(string.format(T("MATERIAL_LINE"), material.name, material.amount))
            Place(line.label, "TOPLEFT", TEXT_LEFT, lineY)
            line.label:Show(true)
            UI.ShowCurrency(window, line.cost, MATERIAL_COST_RIGHT, lineY, cost, true)
            lineY = lineY + MATERIAL_LINE_HEIGHT
        end
        HideMaterialLines(row, #pack.materials + 1)

        UI.ShowCurrency(window, row.packCost, SUMMARY_RIGHT, lineY + SUMMARY_OFFSET_Y, totalCost, true)
        local profit = (salePrice or 0) - totalCost
        local color = profit >= 0 and COLOR_PROFIT or COLOR_LOSS
        UI.SetCurrencyColor(row.profit, color[1], color[2], color[3])
        UI.ShowCurrency(window, row.profit, SUMMARY_RIGHT,
            lineY + MATERIAL_LINE_HEIGHT + SUMMARY_OFFSET_Y, profit, true)

        height = height + #pack.materials * MATERIAL_LINE_HEIGHT + SPECIALTY_EXTRA_HEIGHT
    else
        HideMaterialLines(row, 1)
        UI.HideCurrency(row.packCost)
        UI.HideCurrency(row.profit)
    end

    row.line:RemoveAllAnchors()
    row.line:AddAnchor("TOPLEFT", window, LINE_LEFT, y + height - 5)
    row.line:SetVisible(true)
    return height
end

local function UpdateProfessionLabel()
    professionLabel:SetText(string.format(T("COMMERCE_INFO"),
        Trade.commerceSkill, Trade.CommerceBonusPercent()))
end

function MainWindow.Refresh()
    if not window:IsVisible() then
        return
    end
    UpdateProfessionLabel()

    local packs = Trade.packs
    local y = LIST_TOP
    for index, pack in ipairs(packs) do
        y = y + LayoutPack(EnsureRow(index), pack, y)
    end
    for index = #packs + 1, #rows do
        HideRow(rows[index])
    end

    if #packs > 0 then
        topLine:RemoveAllAnchors()
        topLine:AddAnchor("TOPLEFT", window, LINE_LEFT, LIST_TOP - 10)
    end
    topLine:SetVisible(#packs > 0)

    window:SetExtent(WIDTH, BASE_HEIGHT + (y - LIST_TOP))
end

-- ============================================
-- 路线选择
-- ============================================
local function ZoneOptions(zoneIds, exclude)
    local options = {}
    for _, zoneId in ipairs(zoneIds) do
        if zoneId ~= exclude then
            options[#options + 1] = { text = Trade.ZoneName(zoneId), value = zoneId }
        end
    end
    return options
end

local function ClearPacks()
    Auction.Cancel()
    Trade.Clear()
end

local function RequestRatio()
    if Trade.Request() then
        MainWindow.Refresh()
    end
end

-- 交货区域选单：去掉起始区域；只有一个交货区域时自动选；原本的选择不再有效就清掉
local function UpdateToOptions()
    local continent = Trade.ContinentOf(route.continent)
    if continent == nil or route.from == nil then
        toCombo:SetOptions({})
        route.to = nil
        return
    end
    local options = ZoneOptions(continent.to, route.from)
    if #continent.to == 1 then
        route.to = continent.to[1]
    end
    local valid = false
    for _, option in ipairs(options) do
        if option.value == route.to then
            valid = true
        end
    end
    if not valid and route.to ~= nil then
        route.to = nil
        ClearPacks()
    end
    toCombo:SetOptions(options)
    toCombo:Select(route.to)
end

local function SetContinent(key)
    if route.continent == key then
        return
    end
    route.continent = key
    route.from = nil
    route.to = nil
    ClearPacks()
    local continent = Trade.ContinentOf(key)
    fromCombo:SetOptions(continent and ZoneOptions(continent.from) or {})
    continentCombo:Select(key)
    UpdateToOptions()
    MainWindow.Refresh()
end

local function SetFrom(zoneId)
    route.from = zoneId
    fromCombo:Select(zoneId)
    UpdateToOptions()
    RequestRatio()
    MainWindow.Refresh()
end

local function SetTo(zoneId)
    route.to = zoneId
    toCombo:Select(zoneId)
    RequestRatio()
end

do
    local options = {}
    for _, continent in ipairs(CT.CONTINENTS) do
        options[#options + 1] = { text = T(continent.label), value = continent.key }
    end
    continentCombo:SetOptions(options)
end
continentCombo.onSelect = SetContinent
fromCombo.onSelect = SetFrom
toCombo.onSelect = SetTo

-- 套用收藏的路线
function MainWindow.ApplyRoute(continentKey, fromZone, toZone)
    window:Show(true)
    SetContinent(continentKey)
    route.from = fromZone
    route.to = toZone
    fromCombo:Select(fromZone)
    UpdateToOptions()
    RequestRatio()
    MainWindow.Refresh()
end

-- ============================================
-- 按钮与冷却 / 查价状态
-- ============================================
refreshButton:SetHandler("OnClick", RequestRatio)

queryButton:SetHandler("OnClick", function()
    if Auction.IsRunning() then
        Auction.Cancel()
    elseif route.from ~= nil and route.to ~= nil then
        Auction.StartForPacks(Trade.packs)
    end
end)

favoritesButton:SetHandler("OnClick", function()
    CT.Favorites.Toggle()
end)

local loadingElapsed = 0
local loadingDots = 0

function MainWindow.OnAuctionStateChanged()
    local running = Auction.IsRunning()
    queryButton:SetText(T(running and "STOP_QUERY" or "QUERY_PRICES"))
    loadingLabel:Show(running)
    loadingElapsed = 0
    loadingDots = 0
    loadingLabel:SetText(T("LOADING_PRICES"))
end

function MainWindow.Tick(dt)
    -- 冷却中停用重新整理与选单，右边显示剩余秒数
    local coolingDown = Trade.IsCoolingDown()
    refreshButton:Enable(not coolingDown)
    continentCombo:Enable(not coolingDown)
    fromCombo:Enable(not coolingDown)
    toCombo:Enable(not coolingDown)
    countdownLabel:Show(coolingDown)
    if coolingDown then
        countdownLabel:SetText(tostring(math.ceil(Trade.cooldownMs / 1000)))
    end

    if Auction.IsRunning() then
        loadingElapsed = loadingElapsed + (tonumber(dt) or 0)
        if loadingElapsed >= ELLIPSIS_MS then
            loadingElapsed = 0
            loadingDots = loadingDots % 3 + 1
            loadingLabel:SetText(T("LOADING_PRICES") .. string.rep(".", loadingDots))
        end
    end
end

function MainWindow.Toggle()
    window:Show(not window:IsVisible())
end

window:SetHandler("OnShow", function()
    SettingWindowSkin(window)
    window:SetStartAnimation(true, true)
    Trade.UpdateCommerceSkill()
    CT.Favorites.Show()
    MainWindow.Refresh()
end)
