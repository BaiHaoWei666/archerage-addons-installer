-- 設定與存檔（存檔 key：itv2_settings）
-- 其他模組一律透過 ITV2.Settings.xxx 讀寫狀態（Load 會整個換掉表格，不要另存區域變數）
local CATEGORIES = ITV2.CATEGORIES
local Items = ITV2.Items

local SAVE_KEY = "itv2_settings"
local SAVE_VERSION = 2
local COORD_SPACE_EFFECTIVE = "effective"
local LEGACY_HEADER_HEIGHT = 26   -- 舊存檔（記本體位置）換算用

local S = {}
ITV2.Settings = S

-- 面板設定：存在 popout[key]，設定頁依此順序列出
S.PANEL_SETTINGS = {
    { key = "height", text = "PANEL_HEIGHT", default = 260, min = 100, max = 800, step = 20 },
    { key = "width", text = "PANEL_WIDTH", default = 220, min = 200, max = 500, step = 10 },
    { key = "fontTitle", text = "PANEL_FONT_TITLE", default = 15, min = 10, max = 24, step = 1 },
    { key = "fontItem", text = "PANEL_FONT_ITEM", default = 14, min = 10, max = 24, step = 1 },
    { key = "fontSub", text = "PANEL_FONT_SUB", default = 13, min = 8, max = 22, step = 1 },
    { key = "bgAlpha", text = "PANEL_BG_ALPHA", default = 60, min = 0, max = 100, step = 10 },
}

S.tracked = {}        -- { [itemKey] = true }：在懸浮窗追蹤
S.orderByCat = {}     -- { [catKey] = { itemKey, ... } }：項目順序
S.pageOrder = {}      -- { CATEGORIES 索引, ... }：分類順序（設定窗口頁籤與懸浮窗切頁共用）
S.pageDisabled = {}   -- { [catKey] = true }：面板設定關掉的分類（懸浮窗切頁時跳過）
S.popoutPage = 1      -- 懸浮窗目前的分類（CATEGORIES 索引）
S.popoutPosX = nil    -- 懸浮窗標題欄位置（effective 座標）
S.popoutPosY = nil
S.squadInvite = false -- 建立戰隊詢問窗的「邀請隊伍成員」，記住上次的選擇
S.panel = {}          -- { [PANEL_SETTINGS.key] = 數值 }

for _, def in ipairs(S.PANEL_SETTINGS) do
    S.panel[def.key] = def.default
end
for index in ipairs(CATEGORIES) do
    S.pageOrder[index] = index
end

-- ============================================
-- 追蹤項目
-- ============================================
function S.IsTracked(key)
    return S.tracked[key] == true
end

-- 回傳是否有改變
function S.SetTracked(key, on)
    if key == nil or S.IsTracked(key) == on then
        return false
    end
    S.tracked[key] = on or nil
    return true
end

function S.TrackAll(keys, on)
    if on == nil then on = true end
    for _, key in ipairs(keys) do
        S.SetTracked(key, on)
    end
end

-- 回傳是否有移動
function S.MoveItem(catKey, fromIndex, delta)
    local order = S.orderByCat[catKey]
    local toIndex = fromIndex + delta
    if order == nil or toIndex < 1 or toIndex > #order then
        return false
    end
    order[fromIndex], order[toIndex] = order[toIndex], order[fromIndex]
    return true
end

-- 以預設順序為底，套用存檔順序；刪掉已不存在的項目、補上新增的
local function NormalizeOrder(cat, saved)
    local out, seen = {}, {}
    local hasBsb60 = false
    for _, key in ipairs(type(saved) == "table" and saved or {}) do
        if key == "BSB60" then hasBsb60 = true end
    end
    if type(saved) == "table" then
        for _, key in ipairs(saved) do
            if Items.catByKey[key] == cat and not seen[key] then
                out[#out + 1] = key
                seen[key] = true
                -- 舊債券拆組後相鄰排列；已分別排序的存檔保持原順序。
                if key == "BSB" and not hasBsb60 and Items.catByKey.BSB60 == cat then
                    out[#out + 1] = "BSB60"
                    seen.BSB60 = true
                end
            end
        end
    end
    for _, item in ipairs(cat.items) do
        if not seen[item.key] then
            out[#out + 1] = item.key
        end
    end
    return out
end

-- ============================================
-- 分類（頁面）順序與開關
-- ============================================
function S.IsPageEnabled(index)
    local cat = CATEGORIES[index]
    return cat ~= nil and not S.pageDisabled[cat.key]
end

function S.EnabledPageCount()
    local count = 0
    for index in ipairs(CATEGORIES) do
        if S.IsPageEnabled(index) then
            count = count + 1
        end
    end
    return count
end

local function PagePosition(index)
    for position, pageIndex in ipairs(S.pageOrder) do
        if pageIndex == index then
            return position
        end
    end
    return 1
end

-- 回傳是否有移動
function S.MovePage(index, delta)
    local from = PagePosition(index)
    local to = from + delta
    if to < 1 or to > #S.pageOrder then
        return false
    end
    S.pageOrder[from], S.pageOrder[to] = S.pageOrder[to], S.pageOrder[from]
    return true
end

-- 照顯示順序，從 from 往 delta 方向找下一個開著的分類（from 本身不算，不繞回頭尾）；找不到回傳 from
function S.NextEnabledPage(from, delta)
    local position = PagePosition(from) + delta
    while position >= 1 and position <= #S.pageOrder do
        local index = S.pageOrder[position]
        if S.IsPageEnabled(index) then
            return index
        end
        position = position + delta
    end
    return from
end

-- 懸浮窗目前的分類被關掉時，改到後面開著的分類，後面沒有就往前找
local function EnsurePopoutPageEnabled()
    if S.IsPageEnabled(S.popoutPage) then
        return
    end
    local page = S.NextEnabledPage(S.popoutPage, 1)
    if page == S.popoutPage then
        page = S.NextEnabledPage(S.popoutPage, -1)
    end
    S.popoutPage = page
end

-- 至少留一個開著的分類
function S.CanDisablePage(index)
    return not S.IsPageEnabled(index) or S.EnabledPageCount() > 1
end

function S.SetPageEnabled(index, enabled)
    local cat = CATEGORIES[index]
    if cat == nil or (not enabled and not S.CanDisablePage(index)) then
        return
    end
    S.pageDisabled[cat.key] = (not enabled) or nil
    EnsurePopoutPageEnabled()
end

-- 以存檔的分類 key 順序為底，補上新增的分類
local function LoadPageOrder(savedKeys)
    local indexByKey = {}
    for index, cat in ipairs(CATEGORIES) do
        indexByKey[cat.key] = index
    end
    local out, seen = {}, {}
    if type(savedKeys) == "table" then
        for _, key in ipairs(savedKeys) do
            local index = indexByKey[key]
            if index ~= nil and not seen[index] then
                out[#out + 1] = index
                seen[index] = true
            end
        end
    end
    for index in ipairs(CATEGORIES) do
        if not seen[index] then
            out[#out + 1] = index
        end
    end
    S.pageOrder = out
end

-- ============================================
-- 面板外觀
-- ============================================
local function ClampPanelValue(def, value)
    return math.max(def.min, math.min(def.max, value))
end

-- 調整一格，並對齊到 step 的倍數（舊存檔可能不在間隔上，例如不透明度 75 → 80 / 70）
-- 回傳是否有改變
function S.StepPanelValue(def, delta)
    local current = S.panel[def.key]
    local target = current + delta
    local snapped = (delta > 0 and math.floor(target / def.step) or math.ceil(target / def.step)) * def.step
    if snapped == current then
        snapped = target
    end
    local value = ClampPanelValue(def, snapped)
    if value == current then
        return false
    end
    S.panel[def.key] = value
    return true
end

-- ============================================
-- 存檔
-- ============================================
local function KeysOf(set)
    local list = {}
    for key, on in pairs(set) do
        if on then
            list[#list + 1] = key
        end
    end
    return list
end

function S.Save()
    local pageOrderKeys = {}
    for _, index in ipairs(S.pageOrder) do
        pageOrderKeys[#pageOrderKeys + 1] = CATEGORIES[index].key
    end
    local popoutSave = {
        page = S.popoutPage,
        pageOrder = pageOrderKeys,
        disabledPages = KeysOf(S.pageDisabled),
        x = S.popoutPosX,
        y = S.popoutPosY,
        coordSpace = COORD_SPACE_EFFECTIVE,
        anchor = "header",
    }
    for _, def in ipairs(S.PANEL_SETTINGS) do
        popoutSave[def.key] = S.panel[def.key]
    end
    ADDON:ClearData(SAVE_KEY)
    ADDON:SaveData(SAVE_KEY, {
        version = SAVE_VERSION,
        tracked = KeysOf(S.tracked),
        known = KeysOf(Items.byKey),
        order = S.orderByCat,
        popout = popoutSave,
        squadInvite = S.squadInvite,
    })
end

-- 存檔時已經存在的項目照存檔；之後才新增的項目（或第一次使用）預設追蹤
local function LoadTracked(saved)
    -- version 1 的存檔沒有 known，當時只有任務項目
    local known = {}
    if type(saved.known) == "table" then
        for _, key in ipairs(saved.known) do
            known[key] = true
        end
    elseif type(saved.tracked) == "table" then
        for key, cat in pairs(Items.catByKey) do
            if cat.kind == "quest" then
                known[key] = true
            end
        end
    end

    -- 舊債券的勾選狀態同時沿用到 20 與 60 組，之後可各自調整。
    local splitBonds = known.BSB and (not known.BSB60 or type(saved.known) ~= "table")
    if splitBonds then known.BSB60 = true end
    S.tracked = {}
    for key in pairs(Items.byKey) do
        if not known[key] then
            S.tracked[key] = true
        end
    end
    if type(saved.tracked) == "table" then
        for _, key in ipairs(saved.tracked) do
            if Items.byKey[key] ~= nil then
                S.tracked[key] = true
            end
        end
    end
    if splitBonds then S.tracked.BSB60 = S.tracked.BSB end
end

local function LoadPopout(popout)
    local page = tonumber(popout.page)
    if page ~= nil and CATEGORIES[page] ~= nil then
        S.popoutPage = page
    end

    LoadPageOrder(popout.pageOrder)
    S.pageDisabled = {}
    if type(popout.disabledPages) == "table" then
        for _, key in ipairs(popout.disabledPages) do
            S.pageDisabled[key] = true
        end
    end
    if S.EnabledPageCount() == 0 then
        S.pageDisabled = {}
    end
    EnsurePopoutPageEnabled()

    for _, def in ipairs(S.PANEL_SETTINGS) do
        local value = tonumber(popout[def.key])
        if value ~= nil then
            S.panel[def.key] = ClampPanelValue(def, value)
        end
    end

    S.popoutPosX = tonumber(popout.x)
    S.popoutPosY = tonumber(popout.y)
    -- 舊存檔記的是本體左上角；現在記標題欄，往上移一個標題欄高度保持畫面位置不變
    if popout.anchor ~= "header" and S.popoutPosY ~= nil then
        S.popoutPosY = S.popoutPosY - LEGACY_HEADER_HEIGHT * ITV2.GetUiScale()
    end
end

function S.Load()
    local saved = ADDON:LoadData(SAVE_KEY)
    if type(saved) ~= "table" then
        saved = {}
    end

    LoadTracked(saved)
    S.squadInvite = saved.squadInvite == true

    local savedOrder = type(saved.order) == "table" and saved.order or {}
    for _, cat in ipairs(CATEGORIES) do
        S.orderByCat[cat.key] = NormalizeOrder(cat, savedOrder[cat.key])
    end

    if type(saved.popout) == "table" then
        LoadPopout(saved.popout)
    end
end
