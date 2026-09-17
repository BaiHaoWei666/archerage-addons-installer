-- 设定窗口
-- 页签：各分类（勾选追踪、调整顺序、展开细项）+ 最后的「面板设定」（悬浮窗外观、页面开关与顺序）
local T = ITV2.Text
local CATEGORIES = ITV2.CATEGORIES
local SOURCES = ITV2.SOURCES
local Items = ITV2.Items
local S = ITV2.Settings
local UI = ITV2.UI

local Editor = {}
ITV2.Editor = Editor

-- 核对用：任务页出现「输出本页ID」，平时隐藏；要用时改成 true
local SHOW_DUMP_BUTTON = false

local WIDTH = 430
local HEIGHT = 560
local PADDING = 20
local REFRESH_MS = 1000

local ROW_HEIGHT = 26
local ROW_GAP = 4
local SUB_ROW_HEIGHT = 22
local SUB_ROW_GAP = 2
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

local expanded = {}              -- { [itemKey] = true }（只存在本次游戏中）
local activeTab = 1
local refreshPending = false     -- 下一帧再刷新一次

local window = UI.CreateDialog("itv2EditorWindow", WIDTH, HEIGHT)

local title = UI.CreateCaption(window, "itv2EditorTitle", WIDTH - PADDING * 2, 22, 16, T("EDITOR_TITLE"))
title:AddAnchor("TOPLEFT", window, PADDING, 10)

local closeButton = window:CreateChildWidget("button", "itv2EditorClose", 0, true)
closeButton:AddAnchor("TOPRIGHT", window, 3, -3)
closeButton:SetStyle("btn_close_default")
UI.OnLeftClick(closeButton, function()
    window:Show(false)
end)

-- 设定窗口里的勾选框：勾选框会在点击后自己再切换一次，下一帧再刷新让画面以资料为准
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
-- 页签
-- ============================================
local PANEL_TAB = #CATEGORIES + 1

local tabButtons = {}
do
    -- 目前页签以停用（按下）状态标示，文字维持一般颜色不变灰
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

-- 页签位置照分类显示顺序，「面板设定」固定最后
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
-- 页签下方的动作列
-- ============================================
local ACTION_ROW_TOP = TABS_TOP + math.ceil(#tabButtons / TABS_PER_ROW) * (TAB_HEIGHT + TAB_GAP) + 4
local LIST_TOP = ACTION_ROW_TOP + 32

local summaryLabel = UI.CreateCaption(window, "itv2EditorSummary", 170, 22, 13)
summaryLabel:AddAnchor("TOPLEFT", window, PADDING, ACTION_ROW_TOP + 2)

local trackAllButton = UI.CreateTextButton(window, "itv2TrackAllButton", T("TRACK_ALL"), ACTION_BUTTON_WIDTH, 24)
trackAllButton:AddAnchor("TOPRIGHT", window, -PADDING, ACTION_ROW_TOP)

-- 本页专属按钮（放在「本页全部追踪」左边）：收入页 = 重置，任务页 = 输出ID（隐藏）
local pageButtonRight = -PADDING - ACTION_BUTTON_WIDTH - 4

local resetIncomeButton = UI.CreateTextButton(window, "itv2ResetIncomeButton", T("INCOME_RESET"), ACTION_BUTTON_WIDTH, 24)
resetIncomeButton:AddAnchor("TOPRIGHT", window, pageButtonRight, ACTION_ROW_TOP)

local dumpButton = UI.CreateTextButton(window, "itv2DumpButton", T("DUMP"), ACTION_BUTTON_WIDTH, 24)
dumpButton:AddAnchor("TOPRIGHT", window, pageButtonRight, ACTION_ROW_TOP)

-- ============================================
-- 清单（可卷动）
-- ============================================
local LIST_WIDTH = WIDTH - PADDING * 2 - UI.SCROLL_BAR_GAP - UI.SCROLL_BAR_WIDTH
local area = UI.CreateScrollArea(window, "itv2EditorList", function()
    Editor.Refresh()
end)
area:SetView(PADDING, LIST_TOP, LIST_WIDTH, HEIGHT - LIST_TOP - PADDING)
local listParent = area.content

-- ============================================
-- 分类页：项目行与细项行（依需要建立，重复使用）
-- ============================================
local itemRows = {}
local subRows = {}

local function EnsureItemRows(count)
    for index = #itemRows + 1, count do
        local row = {}

        -- 最前面的勾选框：是否在悬浮窗追踪
        row.check = CreateCheckBox(listParent, "itv2Track" .. index, function(self)
            local key = self.itemKey
            if key ~= nil and S.SetTracked(key, not S.IsTracked(key)) then
                SaveAndRefresh()
            end
        end)

        -- 点名称：展开 / 收起
        row.label = UI.CreateLabel(listParent, "itv2ItemLabel" .. index, ITEM_LABEL_WIDTH, ROW_HEIGHT, 13)
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
        row.down = UI.CreateIconButton(listParent, "itv2Down" .. index, UI.ICON_DOWN, function(self)
            Move(self, 1)
        end)
        row.up = UI.CreateIconButton(listParent, "itv2Up" .. index, UI.ICON_UP, function(self)
            Move(self, -1)
        end)

        itemRows[index] = row
    end
end

local function EnsureSubRows(count)
    for index = #subRows + 1, count do
        local label = UI.CreateLabel(listParent, "itv2SubLabel" .. index,
            LIST_WIDTH - LABEL_AFTER_CHECK - SUB_INDENT, SUB_ROW_HEIGHT, 12)
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

local function LayoutItemList(cat)
    local order = S.orderByCat[cat.key]
    local ctx = Items.NewContext()

    EnsureItemRows(#order)

    local y = 0
    local subIndex = 0
    local trackedCount = 0

    for orderIndex, key in ipairs(order) do
        local row = itemRows[orderIndex]
        if S.IsTracked(key) then
            trackedCount = trackedCount + 1
        end

        -- fixed 分类（每日挑战）固定全部显示：没有勾选框与排序箭头，文字靠左
        local labelX = LABEL_AFTER_CHECK
        if cat.fixed then
            labelX = 0
            row.check:Show(false)
            row.up:Show(false)
            row.down:Show(false)
        else
            row.check.itemKey = key
            row.check:SetChecked(S.IsTracked(key))
            area:Place(row.check, 0, y + CHECK_OFFSET, UI.CHECK_HEIGHT)

            -- 右边由右到左：上箭头、下箭头
            row.up.catKey, row.up.orderIndex = cat.key, orderIndex
            row.down.catKey, row.down.orderIndex = cat.key, orderIndex
            local right = area:PlaceIcon(row.up, LIST_WIDTH, y, ROW_HEIGHT)
            area:PlaceIcon(row.down, right, y, ROW_HEIGHT)
        end

        -- 主项只用颜色表示状态（同悬浮窗），能展开的项目后面标示展开状态
        local view = Items.View(key, ctx)
        local canExpand = Items.CanExpand(key, ctx)
        local isExpanded = canExpand and expanded[key]
        local text = view.text
        if canExpand then
            text = text .. (isExpanded and " [-]" or " [+]")
        end
        row.label.itemKey = key
        row.label:SetText(text)
        UI.SetTextColor(row.label, UI.StatusColor(view.status))
        area:Place(row.label, labelX, y, ROW_HEIGHT)

        y = y + ROW_HEIGHT + ROW_GAP

        if isExpanded then
            local children = Items.Children(key, ctx)
            EnsureSubRows(subIndex + #children)
            for _, child in ipairs(children) do
                subIndex = subIndex + 1
                local label = subRows[subIndex]
                label:SetText((ITV2.STATUS_PREFIX[child.status] or "") .. child.text)
                UI.SetTextColor(label, UI.StatusColor(child.status))
                UI.SetSubRowAction(label, child.action)
                -- 缩排跟着主项文字走
                area:Place(label, labelX + SUB_INDENT, y, SUB_ROW_HEIGHT)
                y = y + SUB_ROW_HEIGHT + SUB_ROW_GAP
            end
            y = y + ROW_GAP
        end
    end

    HideItemRows(#order + 1)
    HideSubRows(subIndex + 1)

    summaryLabel:SetText(string.format(T("TRACKED_SUMMARY"), trackedCount, #order))
    return y - ROW_GAP
end

-- ============================================
-- 面板设定页（也放在卷动区里）
--   外观：PANEL_SETTINGS 每项一行「名称: 数值」，右边 － ＋
--   页面：每个分类一个勾选框与上下箭头；关掉的分类不会出现在悬浮窗的切页里
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
    row.down = UI.CreateIconButton(listParent, "itv2PageDown" .. index, UI.ICON_DOWN, function()
        Move(1)
    end)
    row.up = UI.CreateIconButton(listParent, "itv2PageUp" .. index, UI.ICON_UP, function()
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
    -- 右边由右到左：＋、－
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
    -- 照显示顺序列出；右边由右到左：上箭头、下箭头
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
-- 刷新与操作
-- ============================================
function Editor.Refresh()
    if not window:IsVisible() then
        return
    end

    LayoutTabs()

    local isPanel = activeTab == PANEL_TAB
    local cat = CATEGORIES[activeTab]
    local isList = not isPanel and not cat.fixed

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
        return LayoutItemList(cat)
    end

    if area:SetContentHeight(Layout()) then
        Layout()
    end
end

local function SelectTab(index)
    if activeTab ~= index then
        activeTab = index
        area:ScrollToTop()
    end
    Editor.Refresh()
end

-- 开关设定窗口；打开时切到 page 分类（悬浮窗目前的分类）
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
    elapsed = elapsed + dt
    if elapsed < REFRESH_MS and not refreshPending then
        return
    end
    elapsed = 0
    refreshPending = false
    Editor.Refresh()
end)
