-- 设定与存档（存档 key：itv2_settings）
-- 其他模组一律透过 ITV2.Settings.xxx 读写状态（Load 会整个换掉表格，不要另存区域变数）
local CATEGORIES = ITV2.CATEGORIES
local Items = ITV2.Items

local SAVE_KEY = "itv2_settings"
local SAVE_VERSION = 2
local COORD_SPACE_EFFECTIVE = "effective"
local LEGACY_HEADER_HEIGHT = 26   -- 旧存档（记本体位置）换算用

local S = {}
ITV2.Settings = S

-- 面板设定：存在 popout[key]，设定页依此顺序列出
S.PANEL_SETTINGS = {
    { key = "height", text = "PANEL_HEIGHT", default = 300, min = 100, max = 800, step = 20 },
    { key = "width", text = "PANEL_WIDTH", default = 240, min = 200, max = 500, step = 10 },
    { key = "fontTitle", text = "PANEL_FONT_TITLE", default = 14, min = 10, max = 24, step = 1 },
    { key = "fontItem", text = "PANEL_FONT_ITEM", default = 14, min = 10, max = 24, step = 1 },
    { key = "fontSub", text = "PANEL_FONT_SUB", default = 12, min = 8, max = 22, step = 1 },
    { key = "bgAlpha", text = "PANEL_BG_ALPHA", default = 80, min = 0, max = 100, step = 10 },
}

S.tracked = {}        -- { [itemKey] = true }：在悬浮窗追踪
S.orderByCat = {}     -- { [catKey] = { itemKey, ... } }：项目顺序
S.pageOrder = {}      -- { CATEGORIES 索引, ... }：分类顺序（设定窗口页签与悬浮窗切页共用）
S.pageDisabled = {}   -- { [catKey] = true }：面板设定关掉的分类（悬浮窗切页时跳过）
S.popoutPage = 1      -- 悬浮窗目前的分类（CATEGORIES 索引）
S.popoutPosX = nil    -- 悬浮窗标题栏位置（effective 座标）
S.popoutPosY = nil
S.squadInvite = false -- 建立战队询问窗的「邀请队伍成员」，记住上次的选择
S.panel = {}          -- { [PANEL_SETTINGS.key] = 数值 }

for _, def in ipairs(S.PANEL_SETTINGS) do
    S.panel[def.key] = def.default
end
for index in ipairs(CATEGORIES) do
    S.pageOrder[index] = index
end

-- ============================================
-- 追踪项目
-- ============================================
function S.IsTracked(key)
    return S.tracked[key] == true
end

-- 回传是否有改变
function S.SetTracked(key, on)
    if key == nil or S.IsTracked(key) == on then
        return false
    end
    S.tracked[key] = on or nil
    return true
end

function S.TrackAll(keys)
    for _, key in ipairs(keys) do
        S.tracked[key] = true
    end
end

-- 回传是否有移动
function S.MoveItem(catKey, fromIndex, delta)
    local order = S.orderByCat[catKey]
    local toIndex = fromIndex + delta
    if order == nil or toIndex < 1 or toIndex > #order then
        return false
    end
    order[fromIndex], order[toIndex] = order[toIndex], order[fromIndex]
    return true
end

-- 以预设顺序为底，套用存档顺序；删掉已不存在的项目、补上新增的
local function NormalizeOrder(cat, saved)
    local out, seen = {}, {}
    if type(saved) == "table" then
        for _, key in ipairs(saved) do
            if Items.catByKey[key] == cat and not seen[key] then
                out[#out + 1] = key
                seen[key] = true
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
-- 分类（页面）顺序与开关
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

-- 回传是否有移动
function S.MovePage(index, delta)
    local from = PagePosition(index)
    local to = from + delta
    if to < 1 or to > #S.pageOrder then
        return false
    end
    S.pageOrder[from], S.pageOrder[to] = S.pageOrder[to], S.pageOrder[from]
    return true
end

-- 照显示顺序，从 from 往 delta 方向找下一个开着的分类（from 本身不算，不绕回头尾）；找不到回传 from
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

-- 悬浮窗目前的分类被关掉时，改到后面开着的分类，后面没有就往前找
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

-- 至少留一个开着的分类
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

-- 以存档的分类 key 顺序为底，补上新增的分类
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
-- 面板外观
-- ============================================
local function ClampPanelValue(def, value)
    return math.max(def.min, math.min(def.max, value))
end

-- 调整一格，并对齐到 step 的倍数（旧存档可能不在间隔上，例如不透明度 75 → 80 / 70）
-- 回传是否有改变
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
-- 存档
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

-- 存档时已经存在的项目照存档；之后才新增的项目（或第一次使用）预设追踪
local function LoadTracked(saved)
    -- version 1 的存档没有 known，当时只有任务项目
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
    -- 旧存档记的是本体左上角；现在记标题栏，往上移一个标题栏高度保持画面位置不变
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
