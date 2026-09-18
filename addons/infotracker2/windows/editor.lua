-- 設定視窗
-- 頁籤：各分類（勾選追蹤、調整順序、展開細項）+ 最後的「面板設定」（懸浮窗外觀、頁面開關與順序）
local T = ITV2.Text
local CATEGORIES = ITV2.CATEGORIES
local SOURCES = ITV2.SOURCES
local Items = ITV2.Items
local S = ITV2.Settings
local UI = ITV2.UI

local Editor = {}
ITV2.Editor = Editor

-- 核對用：任務頁出現「輸出本頁ID」，平時隱藏；要用時改成 true
local SHOW_DUMP_BUTTON = false

local WIDTH = 430
local HEIGHT = 560
local PADDING = 20
local REFRESH_MS = 1000

local ITEM_FONT_SIZE = 14
local SUB_FONT_SIZE = ITEM_FONT_SIZE - 1
-- 任務清單沿用懸浮窗的列高公式；只有展開群組尾端保留額外留白。
local ROW_HEIGHT = ITEM_FONT_SIZE + 8
local SUB_ROW_HEIGHT = SUB_FONT_SIZE + 6
local EXPANDED_GAP = 2
local ROW_GAP = 2
local SORT_UP = { style = UI.ICON_UP.style, width = 16, height = 10 }
local SORT_DOWN = { style = UI.ICON_DOWN.style, width = 16, height = 10 }
local SUB_INDENT = 12
local ITEM_LABEL_WIDTH = 240
local CHECK_OFFSET = math.floor((ROW_HEIGHT - UI.CHECK_HEIGHT) / 2)
local LABEL_AFTER_CHECK = UI.CHECK_WIDTH + 6

local TAB_WIDTH = 90
local TAB_HEIGHT = 24
local TAB_GAP = 4
local TABS_PER_ROW = 4
local TABS_TOP = 40
local ACTION_BUTTON_WIDTH = 110

local expanded = {}              -- { [itemKey] = true }（只存在本次遊戲中）
local activeTab = 1
local refreshPending = false     -- 下一幀再重新整理一次

local window = UI.CreateDialog("itv2EditorWindow", WIDTH, HEIGHT)

local title = UI.CreateCaption(window, "itv2EditorTitle", WIDTH - PADDING * 2, 22, 16, T("EDITOR_TITLE"))
title:AddAnchor("TOPLEFT", window, PADDING, 10)

local closeButton = window:CreateChildWidget("button", "itv2EditorClose", 0, true)
closeButton:AddAnchor("TOPRIGHT", window, 3, -3)
closeButton:SetStyle("btn_close_default")
UI.OnLeftClick(closeButton, function()
    window:Show(false)
end)

-- 設定視窗裡的勾選框：勾選框會在點選後自己再切換一次，下一幀再重新整理讓畫面以資料為準
local function CreateCheckBox(parent, id, fn)
    return UI.CreateCheckBox(parent, id, function(self, doubleClick)
        fn(self, doubleClick)
        refreshPending = true
    end)
end

local function SaveAndRefresh()
    S.Save()
    ITV2.RefreshAll()
end

-- ============================================
-- 頁籤
-- ============================================
local PANEL_TAB = #CATEGORIES + 1

local tabButtons = {}
do
    -- 目前頁籤以停用（按下）狀態標示，文字維持一般顏色不變灰
    local textColor = { 1, 1, 1, 1 }
    local ok, color = pcall(function()
        return UIParent:GetFontColor("btn")
    end)
    if ok and type(color) == "table" and color[1] ~= nil then
        textColor = { color[1], color[2], color[3], color[4] or 1 }
    end

    local labels = {}
    for index, cat in ipairs(CATEGORIES) do
        labels[index] = cat.label
    end
    labels[PANEL_TAB] = "CAT_PANEL"

    for index, label in ipairs(labels) do
        local tab = UI.CreateTextButton(window, "itv2Tab" .. index, T(label), TAB_WIDTH, TAB_HEIGHT)
        tab.tabIndex = index
        if tab.SetDisabledTextColor ~= nil then
            tab:SetDisabledTextColor(textColor[1], textColor[2], textColor[3], textColor[4])
        end
        tabButtons[index] = tab
    end
end

-- 頁籤位置照分類顯示順序，「面板設定」固定最後
local function LayoutTabs()
    local slots = {}
    for _, index in ipairs(S.pageOrder) do
        slots[#slots + 1] = index
    end
    slots[#slots + 1] = PANEL_TAB
    for slot, index in ipairs(slots) do
        local col = (slot - 1) % TABS_PER_ROW
        local row = math.floor((slot - 1) / TABS_PER_ROW)
        local tab = tabButtons[index]
        tab:RemoveAllAnchors()
        tab:AddAnchor("TOPLEFT", window,
            PADDING + col * (TAB_WIDTH + TAB_GAP), TABS_TOP + row * (TAB_HEIGHT + TAB_GAP))
        tab:Enable(index ~= activeTab)
    end
end

-- ============================================
-- 頁簽下方的動作列
-- ============================================
local ACTION_ROW_TOP = TABS_TOP + math.ceil(#tabButtons / TABS_PER_ROW) * (TAB_HEIGHT + TAB_GAP) + 4
local LIST_TOP = ACTION_ROW_TOP + 32

local summaryLabel = UI.CreateCaption(window, "itv2EditorSummary", 170, 22, 13)
summaryLabel:AddAnchor("TOPLEFT", window, PADDING, ACTION_ROW_TOP + 2)

local trackAllButton = UI.CreateTextButton(window, "itv2TrackAllButton", T("TRACK_ALL"), ACTION_BUTTON_WIDTH, 24)
trackAllButton:AddAnchor("TOPRIGHT", window, -PADDING, ACTION_ROW_TOP)

-- 本頁專屬按鈕（放在「本頁全部追蹤」左邊）：收入頁 = 重置，任務頁 = 輸出ID（隱藏）
local pageButtonRight = -PADDING - ACTION_BUTTON_WIDTH - 4

local resetIncomeButton = UI.CreateTextButton(window, "itv2ResetIncomeButton", T("INCOME_RESET"), ACTION_BUTTON_WIDTH, 24)
resetIncomeButton:AddAnchor("TOPRIGHT", window, pageButtonRight, ACTION_ROW_TOP)

local dumpButton = UI.CreateTextButton(window, "itv2DumpButton", T("DUMP"), ACTION_BUTTON_WIDTH, 24)
dumpButton:AddAnchor("TOPRIGHT", window, pageButtonRight, ACTION_ROW_TOP)

-- ============================================
-- 清單（可捲動）
-- ============================================
local LIST_WIDTH = WIDTH - PADDING * 2 - UI.SCROLL_BAR_GAP - UI.SCROLL_BAR_WIDTH
local area
area = UI.CreateScrollArea(window, "itv2EditorList", function()
    area:Reposition()
end)
area:SetView(PADDING, LIST_TOP, LIST_WIDTH, HEIGHT - LIST_TOP - PADDING)
local listParent = area.content

-- ============================================
-- 分類頁：項目行與細項行（依需要建立，重複使用）
-- ============================================
local itemRows = {}
local subRows = {}

local function EnsureItemRows(count)
    for index = #itemRows + 1, count do
        local row = {}

        -- 最前面的勾選框：是否在懸浮窗追蹤
        row.check = CreateCheckBox(listParent, "itv2Track" .. index, function(self)
            local key = self.itemKey
            if key ~= nil and S.SetTracked(key, not S.IsTracked(key)) then
                SaveAndRefresh()
            end
        end)

        -- 點名稱：展開 / 收起
        row.label = UI.CreateLabel(listParent, "itv2ItemLabel" .. index, ITEM_LABEL_WIDTH, ROW_HEIGHT, ITEM_FONT_SIZE)
        row.label.style:SetShadow(true)
        row.label:EnablePick(true)
        area:BindWheel(row.label)
        UI.OnLeftClick(row.label, function(self)
            local key = self.itemKey
            if key == nil or not Items.CanExpand(key, Items.NewContext()) then
                return
            end
            expanded[key] = not expanded[key] or nil
            Editor.Refresh()
        end)

        local function Move(self, delta)
            if S.MoveItem(self.catKey, self.orderIndex, delta) then
                SaveAndRefresh()
            end
        end
        row.down = UI.CreateIconButton(listParent, "itv2Down" .. index, SORT_DOWN, function(self)
            Move(self, 1)
        end)
        row.up = UI.CreateIconButton(listParent, "itv2Up" .. index, SORT_UP, function(self)
            Move(self, -1)
        end)

        itemRows[index] = row
    end
end

local function EnsureSubRows(count)
    for index = #subRows + 1, count do
        local label = UI.CreateLabel(listParent, "itv2SubLabel" .. index,
            LIST_WIDTH - LABEL_AFTER_CHECK, SUB_ROW_HEIGHT, SUB_FONT_SIZE)
        label.style:SetShadow(true)
        label:EnablePick(false)
        area:BindWheel(label)
        UI.OnLeftClick(label, UI.RunSubRowAction)
        subRows[index] = label
    end
end

local function HideItemRows(fromIndex)
    for index = fromIndex, #itemRows do
        local row = itemRows[index]
        row.check:Show(false)
        row.label:Show(false)
        row.up:Show(false)
        row.down:Show(false)
    end
end

local function HideSubRows(fromIndex)
    for index = fromIndex, #subRows do
        subRows[index]:Show(false)
    end
end

-- 每次只取得一份顯示資料；結構未變時僅更新文字與操作。
local listSignature = nil
local function ReadList(cat)
    local ctx = Items.NewContext()
    local entries, signature = {}, {}
    for _, key in ipairs(S.orderByCat[cat.key]) do
        local canExpand = Items.CanExpand(key, ctx)
        local isExpanded = canExpand and expanded[key]
        local children = isExpanded and Items.Children(key, ctx) or {}
        entries[#entries + 1] = {
            key = key, view = Items.View(key, ctx), canExpand = canExpand,
            isExpanded = isExpanded, children = children,
        }
        signature[#signature + 1] = key .. ":" .. tostring(canExpand) .. ":" .. tostring(isExpanded) .. ":" .. #children
    end
    return entries, table.concat(signature, "|")
end

local function LayoutItemList(cat, entries, dataOnly)
    local order = S.orderByCat[cat.key]

    EnsureItemRows(#order)

    local y = 0
    local subIndex = 0
    local trackedCount = 0

    for orderIndex, key in ipairs(order) do
        local row = itemRows[orderIndex]
        if S.IsTracked(key) then
            trackedCount = trackedCount + 1
        end

        local labelX = LABEL_AFTER_CHECK
        if not dataOnly then
            row.check.itemKey = key
            row.check:SetChecked(S.IsTracked(key))
            area:Place(row.check, 0, y + CHECK_OFFSET, UI.CHECK_HEIGHT)

            -- 右邊由右到左：上箭頭、下箭頭。
            row.up.catKey, row.up.orderIndex = cat.key, orderIndex
            row.down.catKey, row.down.orderIndex = cat.key, orderIndex
            local right = area:PlaceIcon(row.up, LIST_WIDTH, y, ROW_HEIGHT)
            area:PlaceIcon(row.down, right, y, ROW_HEIGHT)
        end

        -- 主項只用顏色表示狀態（同懸浮窗），能展開的項目前面用三角形標示展開狀態
        local entry = entries[orderIndex]
        local view = entry.view
        local canExpand = entry.canExpand
        local isExpanded = entry.isExpanded
        local text = view.text
        if canExpand then
            text = (isExpanded and "▼ " or "▶ ") .. text
        end
        row.label.itemKey = key
        UI.SetStatusText(row.label, text, view.status)
        if not dataOnly then area:Place(row.label, labelX, y, ROW_HEIGHT) end

        y = y + ROW_HEIGHT

        if isExpanded then
            local children = entry.children
            EnsureSubRows(subIndex + #children)
            for _, child in ipairs(children) do
                subIndex = subIndex + 1
                local label = subRows[subIndex]
                UI.SetStatusText(label, "· " .. child.text, child.status)
                UI.SetSubRowAction(label, child.action)
                -- 細項相對主項文字縮排，與懸浮窗一致。
                if not dataOnly then
                    local childX = labelX + UI.ChildIndent(row.label, ITEM_FONT_SIZE)
                    label:SetExtent(LIST_WIDTH - childX, SUB_ROW_HEIGHT)
                    area:Place(label, childX, y, SUB_ROW_HEIGHT)
                end
                y = y + SUB_ROW_HEIGHT
            end
            y = y + EXPANDED_GAP
        end
    end

    if not dataOnly then
        HideItemRows(#order + 1)
        HideSubRows(subIndex + 1)
        summaryLabel:SetText(string.format(T("TRACKED_SUMMARY"), trackedCount, #order))
    end
    return y
end

-- ============================================
-- 面板設定頁（也放在捲動區裡）
--   外觀：PANEL_SETTINGS 每項一行「名稱: 數值」，右邊 － ＋
--   頁面：每個分類一個勾選框與上下箭頭；關掉的分類不會出現在懸浮窗的切頁裡
-- ============================================
local sizeSectionLabel = UI.CreateCaption(listParent, "itv2PanelSizeSection", LIST_WIDTH, ROW_HEIGHT, 14,
    T("PANEL_SECTION_SIZE"))
local pagesSectionLabel = UI.CreateCaption(listParent, "itv2PanelPagesSection", LIST_WIDTH, ROW_HEIGHT, 14,
    T("PANEL_SECTION_PAGES"))
local dragHint = UI.CreateCaption(listParent, "itv2PanelDragHint", LIST_WIDTH, ROW_HEIGHT, 12,
    T("PANEL_DRAG_HINT"))

local panelRows = {}
for index, def in ipairs(S.PANEL_SETTINGS) do
    local row = { def = def }
    row.label = UI.CreateCaption(listParent, "itv2PanelLabel" .. index, 240, ROW_HEIGHT, 13)
    local function Step(delta)
        if S.StepPanelValue(def, delta) then
            S.Save()
            ITV2.Popout.ApplyLayout()
            ITV2.RefreshAll()
        end
    end
    row.minus = UI.CreateIconButton(listParent, "itv2PanelMinus" .. index, UI.ICON_MINUS, function()
        Step(-def.step)
    end)
    row.plus = UI.CreateIconButton(listParent, "itv2PanelPlus" .. index, UI.ICON_PLUS, function()
        Step(def.step)
    end)
    panelRows[index] = row
end

local pageRows = {}
for index, cat in ipairs(CATEGORIES) do
    local row = {}
    row.check = CreateCheckBox(listParent, "itv2PageToggle" .. index, function()
        S.SetPageEnabled(index, not S.IsPageEnabled(index))
        SaveAndRefresh()
    end)
    row.label = UI.CreateCaption(listParent, "itv2PageLabel" .. index, 240, ROW_HEIGHT, 13, T(cat.label))
    local function Move(delta)
        if S.MovePage(index, delta) then
            SaveAndRefresh()
        end
    end
    row.down = UI.CreateIconButton(listParent, "itv2PageDown" .. index, SORT_DOWN, function()
        Move(1)
    end)
    row.up = UI.CreateIconButton(listParent, "itv2PageUp" .. index, SORT_UP, function()
        Move(-1)
    end)
    pageRows[index] = row
end

local function HidePanelPage()
    sizeSectionLabel:Show(false)
    pagesSectionLabel:Show(false)
    dragHint:Show(false)
    for _, row in ipairs(panelRows) do
        row.label:Show(false)
        row.minus:Show(false)
        row.plus:Show(false)
    end
    for _, row in ipairs(pageRows) do
        row.check:Show(false)
        row.label:Show(false)
        row.up:Show(false)
        row.down:Show(false)
    end
end

local function LayoutPanelPage()
    local y = 0

    area:Place(sizeSectionLabel, 0, y, ROW_HEIGHT)
    y = y + ROW_HEIGHT + ROW_GAP
    -- 右邊由右到左：＋、－
    for _, row in ipairs(panelRows) do
        local def = row.def
        local value = S.panel[def.key]
        row.label:SetText(string.format(T(def.text), value))
        area:Place(row.label, SUB_INDENT, y, ROW_HEIGHT)

        row.plus:Enable(value < def.max)
        row.minus:Enable(value > def.min)
        local right = area:PlaceIcon(row.plus, LIST_WIDTH, y, ROW_HEIGHT)
        area:PlaceIcon(row.minus, right, y, ROW_HEIGHT)

        y = y + ROW_HEIGHT + ROW_GAP
    end

    y = y + ROW_GAP * 2
    area:Place(pagesSectionLabel, 0, y, ROW_HEIGHT)
    y = y + ROW_HEIGHT + ROW_GAP
    -- 照顯示順序列出；右邊由右到左：上箭頭、下箭頭
    for _, pageIndex in ipairs(S.pageOrder) do
        local row = pageRows[pageIndex]
        row.check:SetChecked(S.IsPageEnabled(pageIndex))
        row.check:Enable(S.CanDisablePage(pageIndex))
        area:Place(row.check, SUB_INDENT, y + CHECK_OFFSET, UI.CHECK_HEIGHT)
        area:Place(row.label, SUB_INDENT + LABEL_AFTER_CHECK, y, ROW_HEIGHT)

        local right = area:PlaceIcon(row.up, LIST_WIDTH, y, ROW_HEIGHT)
        area:PlaceIcon(row.down, right, y, ROW_HEIGHT)

        y = y + ROW_HEIGHT + ROW_GAP
    end

    y = y + ROW_GAP
    area:Place(dragHint, 0, y, ROW_HEIGHT)
    return y + ROW_HEIGHT
end

-- ============================================
-- 重新整理與操作
-- ============================================
function Editor.Refresh(dataOnly)
    if not window:IsVisible() then
        return
    end

    local isPanel = activeTab == PANEL_TAB
    if dataOnly and isPanel then return end
    local entries, signature
    if not isPanel then
        entries, signature = ReadList(CATEGORIES[activeTab])
        if dataOnly and signature == listSignature then
            LayoutItemList(CATEGORIES[activeTab], entries, true)
            return
        end
    end
    listSignature = signature
    LayoutTabs()
    area:BeginLayout()
    local cat = CATEGORIES[activeTab]
    local isList = not isPanel

    summaryLabel:Show(isList)
    trackAllButton:Show(isList)
    resetIncomeButton:Show(not isPanel and cat.kind == "income")
    dumpButton:Show(not isPanel and SHOW_DUMP_BUTTON and cat.kind == "quest")

    local function Layout()
        if isPanel then
            HideItemRows(1)
            HideSubRows(1)
            return LayoutPanelPage()
        end
        HidePanelPage()
        return LayoutItemList(cat, entries, false)
    end

    if area:SetContentHeight(Layout()) then
        area:Reposition()
    end
end

local function SelectTab(index)
    if activeTab ~= index then
        activeTab = index
        area:ScrollToTop()
    end
    Editor.Refresh()
end

-- 開關設定視窗；開啟時切到 page 分類（懸浮窗目前的分類）
function Editor.Toggle(page)
    window:Show(not window:IsVisible())
    if window:IsVisible() then
        window:Raise()
        SelectTab(page or activeTab)
    end
end

for _, tab in ipairs(tabButtons) do
    UI.OnLeftClick(tab, function(self)
        SelectTab(self.tabIndex)
    end)
end

UI.OnLeftClick(trackAllButton, function()
    local cat = CATEGORIES[activeTab]
    if cat ~= nil then
        S.TrackAll(S.orderByCat[cat.key])
        SaveAndRefresh()
    end
end)

UI.OnLeftClick(resetIncomeButton, function()
    SOURCES.income.Reset()
    ITV2.RefreshAll()
end)

UI.OnLeftClick(dumpButton, function()
    local cat = CATEGORIES[activeTab]
    if cat ~= nil then
        Items.Dump(S.orderByCat[cat.key])
    end
end)

local elapsed = 0
window:SetHandler("OnUpdate", function(self, dt)
    if not self:IsVisible() then return end
    elapsed = elapsed + dt
    if elapsed < REFRESH_MS and not refreshPending then
        return
    end
    elapsed = 0
    local dataOnly = not refreshPending
    refreshPending = false
    Editor.Refresh(dataOnly)
end)
