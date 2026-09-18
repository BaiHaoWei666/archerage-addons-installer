-- 懸浮小窗
-- 標題欄：根視窗（位置存檔存它），常駐顯示目前分類；單擊展開分類選單；Shift + 左鍵拖動可移動；
--         左右切頁（到頭尾時停用，不繞回）與齒輪只在滑鼠懸停時出現
-- 本體：掛在標題欄下方，固定高度，列出目前分類裡已追蹤的項目，超出時捲動
-- 寬高、字體、不透明度來自面板設定，改變時由 Popout.ApplyLayout() 套用
local T = ITV2.Text
local CATEGORIES = ITV2.CATEGORIES
local Items = ITV2.Items
local S = ITV2.Settings
local UI = ITV2.UI

local Popout = {}
ITV2.Popout = Popout

local HEADER_MIN_HEIGHT = 26
local DEFAULT_X = 460
local DEFAULT_Y = 64
local PADDING_TOP = 4        -- 本體上方留白
local PADDING_BOTTOM = 10    -- 本體下方留白
local PADDING_LEFT = 10      -- 文字左邊留白
local TEXT_BAR_GAP = 10      -- 文字右邊到捲軸的留白
local BAR_RIGHT = 2          -- 捲軸到右邊框
local SUB_INDENT = 10
local EXPANDED_GAP = 2       -- 展開的細項下方留白
local ARROW_SIZE = 18
local EDIT_SIZE = 22
local BG_COLOR = { 0, 0, 0 } -- 本體與標題欄共用；不透明度來自面板設定 bgAlpha
local REFRESH_MS = 5000
local HOVER_LINGER_MS = 400

-- 由面板設定推算的版面尺寸
local function HeaderHeight()
    return math.max(HEADER_MIN_HEIGHT, S.panel.fontTitle + 12)
end
local function RowHeight()
    return S.panel.fontItem + 8
end
local function SubRowHeight()
    return S.panel.fontSub + 6
end
-- 左留白 | 文字 | 文字到捲軸留白 | 捲軸 | 右邊框
local function ListWidth()
    return S.panel.width - PADDING_LEFT - TEXT_BAR_GAP - UI.SCROLL_BAR_WIDTH - BAR_RIGHT
end

local function ToggleEditor()
    ITV2.Editor.Toggle(S.popoutPage)
end

-- ============================================
-- 標題欄
-- ============================================
local header = CreateEmptyWindow("itv2PopoutHeader", "UIParent")
header:SetCloseOnEscape(false)
header:Clickable(true)
header:SetUILayer("game")

local function AnchorHeader()
    header:RemoveAllAnchors()
    if S.popoutPosX ~= nil and S.popoutPosY ~= nil then
        header:AddAnchor("TOPLEFT", "UIParent",
            UI.EffectiveToAnchorOffset(S.popoutPosX), UI.EffectiveToAnchorOffset(S.popoutPosY))
    else
        header:AddAnchor("TOPLEFT", "UIParent", DEFAULT_X, DEFAULT_Y)
    end
end

-- 標題欄單擊（沒有拖動）時開關分類選單，拖動過就不算單擊
local headerDragged = false
local function CanDragHeader()
    headerDragged = true
    return UI.IsShiftDown()
end

UI.EnableWindowDrag(header, header, CanDragHeader, function(self)
    local x, y = self:GetEffectiveOffset()
    S.popoutPosX = tonumber(x) or S.popoutPosX
    S.popoutPosY = tonumber(y) or S.popoutPosY
    AnchorHeader()
    S.Save()
end)

local headerBg = header:CreateColorDrawable(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], 1, "background")
headerBg:AddAnchor("TOPLEFT", header, 0, 0)
headerBg:AddAnchor("BOTTOMRIGHT", header, 0, 0)

local title = header:CreateChildWidget("label", "itv2PopTitle", 0, true)
title:AddAnchor("TOPLEFT", header, 0, 0)
title.style:SetAlign(ALIGN_CENTER)
title.style:SetColor(1, 0.85, 0.55, 1)
title.style:SetShadow(true)
title:EnablePick(false)

local prevButton = header:CreateChildWidget("button", "itv2PopPrev", 0, true)
prevButton:SetStyle("left_arrow")
prevButton:SetExtent(ARROW_SIZE, ARROW_SIZE)
prevButton:AddAnchor("LEFT", header, 4, 0)

local editButton = header:CreateChildWidget("button", "itv2PopEdit", 0, true)
editButton:SetStyle("button_common_option")
editButton:SetExtent(EDIT_SIZE, EDIT_SIZE)
editButton:AddAnchor("RIGHT", header, -3, 0)
UI.OnLeftClick(editButton, ToggleEditor)

local nextButton = header:CreateChildWidget("button", "itv2PopNext", 0, true)
nextButton:SetStyle("right_arrow")
nextButton:SetExtent(ARROW_SIZE, ARROW_SIZE)
nextButton:AddAnchor("RIGHT", header, -(3 + EDIT_SIZE + 4), 0)

-- ============================================
-- 本體
-- ============================================
local body = CreateEmptyWindow("itv2PopoutWindow", "UIParent")
body:SetCloseOnEscape(false)
body:AddAnchor("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
body:Clickable(true)
body:SetUILayer("game")

local bodyBg = body:CreateColorDrawable(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], 1, "background")
bodyBg:AddAnchor("TOPLEFT", body, 0, 0)
bodyBg:AddAnchor("BOTTOMRIGHT", body, 0, 0)

local area = UI.CreateScrollArea(body, "itv2PopList", function()
    Popout.Refresh()
end)
local listParent = area.content

local expanded = {}   -- { [itemKey] = true }（只存在本次遊戲中）
local rows = {}
local subRows = {}

-- 沒有追蹤項目時的提示，點了打開設定窗口
local emptyHint = UI.CreateTextButton(listParent, "itv2PopEmpty", T("EMPTY_HINT"), 100, 22)
emptyHint.style:SetShadow(true)
UI.OnLeftClick(emptyHint, ToggleEditor)

local ShowPageMenu

local function SetPage(page)
    ShowPageMenu(false)
    if page == S.popoutPage or not S.IsPageEnabled(page) then
        return
    end
    S.popoutPage = page
    area:ScrollToTop()
    S.Save()
    Popout.Refresh()
end

UI.OnLeftClick(prevButton, function()
    SetPage(S.NextEnabledPage(S.popoutPage, -1))
end)
UI.OnLeftClick(nextButton, function()
    SetPage(S.NextEnabledPage(S.popoutPage, 1))
end)

-- ============================================
-- 分類選單：單擊標題欄展開在標題下方，列出開著的分類（目前分類綠色），點選切換
-- 獨立視窗，建立在本體之後並在顯示時 Raise，才會蓋在本體上面
-- ============================================
local menu = CreateEmptyWindow("itv2PopPageMenu", "UIParent")
menu:SetCloseOnEscape(false)
menu:Clickable(true)
menu:SetUILayer("game")
menu:AddAnchor("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
menu:Show(false)

local menuBg = menu:CreateColorDrawable(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], 0.95, "background")
menuBg:AddAnchor("TOPLEFT", menu, 0, 0)
menuBg:AddAnchor("BOTTOMRIGHT", menu, 0, 0)

local menuRows = {}

local function EnsureMenuRow(index)
    local label = menuRows[index]
    if label ~= nil then
        return label
    end
    label = UI.CreateEllipsisText(menu, "itv2PopPageMenuRow" .. index, S.panel.fontItem)
    label.style:SetShadow(true)
    label.style:SetAlign(ALIGN_CENTER)
    label:EnablePick(true)
    UI.OnLeftClick(label, function(self)
        if self.pageIndex ~= nil then
            SetPage(self.pageIndex)
        end
    end)
    menuRows[index] = label
    return label
end

local function LayoutPageMenu()
    local rowHeight = RowHeight()
    local count = 0
    for _, pageIndex in ipairs(S.pageOrder) do
        if S.IsPageEnabled(pageIndex) then
            count = count + 1
            local label = EnsureMenuRow(count)
            label.pageIndex = pageIndex
            label:SetExtent(S.panel.width, rowHeight)
            label.style:SetFontSize(S.panel.fontItem)
            UI.SetStatusText(label, T(CATEGORIES[pageIndex].label),
                pageIndex == S.popoutPage and "complete" or "neutral")
            label:RemoveAllAnchors()
            label:AddAnchor("TOPLEFT", menu, 0, PADDING_TOP + (count - 1) * rowHeight)
            label:Show(true)
        end
    end
    for index = count + 1, #menuRows do
        menuRows[index]:Show(false)
    end
    menu:SetExtent(S.panel.width, PADDING_TOP * 2 + count * rowHeight)
end

ShowPageMenu = function(visible)
    if visible then
        LayoutPageMenu()
        menu:Show(true)
        menu:Raise()
    elseif menu:IsVisible() then
        menu:Show(false)
    end
end

header:SetHandler("OnMouseDown", function()
    headerDragged = false
end)
header:SetHandler("OnMouseUp", function()
    if not headerDragged then
        ShowPageMenu(not menu:IsVisible())
    end
end)

local function StyleRow(label)
    label.style:SetShadow(true)
    label:SetExtent(ListWidth(), RowHeight())
    label.style:SetFontSize(S.panel.fontItem)
end

local function StyleSubRow(label)
    label.style:SetShadow(true)
    label:SetExtent(ListWidth() - SUB_INDENT, SubRowHeight())
    label.style:SetFontSize(S.panel.fontSub)
end

-- 項目行：能展開的單擊展開 / 收起；有動作的（副本）雙擊跳出詢問窗，單擊不動作避免誤觸
local function OnRowClick(self, doubleClick)
    local key = self.itemKey
    if key == nil then
        return
    end
    if Items.CanExpand(key, Items.NewContext()) then
        expanded[key] = not expanded[key] or nil
        Popout.Refresh(expanded[key] and key or nil)
    elseif doubleClick and Items.CanActivate(key) then
        ITV2.SquadConfirm.Show(key)
    end
end

local function EnsureRows(count)
    for index = #rows + 1, count do
        local label = UI.CreateEllipsisText(listParent, "itv2PopRow" .. index, S.panel.fontItem)
        StyleRow(label)
        label:EnablePick(true)
        area:BindWheel(label)
        UI.OnLeftClick(label, OnRowClick)
        rows[index] = label
    end
end

local function EnsureSubRows(count)
    for index = #subRows + 1, count do
        local label = UI.CreateEllipsisText(listParent, "itv2PopSubRow" .. index, S.panel.fontSub)
        StyleSubRow(label)
        label:EnablePick(false)
        area:BindWheel(label)
        UI.OnLeftClick(label, UI.RunSubRowAction)
        subRows[index] = label
    end
end

function Popout.ApplyLayout()
    local width = S.panel.width
    local headerHeight = HeaderHeight()

    local alpha = S.panel.bgAlpha / 100
    bodyBg:SetColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], alpha)
    headerBg:SetColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], alpha)

    header:SetExtent(width, headerHeight)
    title:SetExtent(width, headerHeight)
    title.style:SetFontSize(S.panel.fontTitle)

    body:SetExtent(width, S.panel.height)
    area:SetView(PADDING_LEFT, PADDING_TOP, ListWidth(),
        S.panel.height - PADDING_TOP - PADDING_BOTTOM, TEXT_BAR_GAP)

    UI.SetButtonSize(emptyHint, ListWidth(), RowHeight())

    for _, label in ipairs(rows) do
        StyleRow(label)
    end
    for _, label in ipairs(subRows) do
        StyleSubRow(label)
    end
end

-- ============================================
-- 懸停：顯示切頁 / 齒輪按鈕與捲軸
-- ============================================
local hovered = false
local leftFor = 0

-- 捲軸平時隱藏（位置仍保留，內容寬度不變），懸停且內容超出時才出現
local function UpdateBarVisible()
    area.bar:Show(hovered and area.scrollable == true)
end

local function SetHovered(visible)
    hovered = visible
    prevButton:Show(visible)
    nextButton:Show(visible)
    editButton:Show(visible)
    if not visible then
        ShowPageMenu(false)
    end
    UpdateBarVisible()
end

local function IsAnyMouseOver(labels)
    for _, label in ipairs(labels) do
        if label:IsVisible() and label:IsMouseOver() then
            return true
        end
    end
    return false
end

local function IsMouseOver()
    if body:IsMouseOver() or header:IsMouseOver()
        or area.content:IsMouseOver() or area.bar:IsMouseOver()
        or (menu:IsVisible() and menu:IsMouseOver()) then
        return true
    end
    -- 可點擊的行會接走滑鼠，另外檢查
    return IsAnyMouseOver(rows) or IsAnyMouseOver(subRows) or IsAnyMouseOver(menuRows)
end

-- ============================================
-- 排版與刷新
-- ============================================
local function Layout(cat, revealKey)
    local ctx = Items.NewContext()
    local rowHeight = RowHeight()
    local subRowHeight = SubRowHeight()

    local shown = 0
    local subShown = 0
    local y = 0
    local revealTop, revealBottom
    for _, key in ipairs(S.orderByCat[cat.key]) do
        if cat.fixed or S.IsTracked(key) then
            shown = shown + 1
            EnsureRows(shown)
            local view = Items.View(key, ctx)
            local isExpanded = expanded[key] and Items.CanExpand(key, ctx)
            local text = view.shortText or view.text
            if isExpanded then
                text = text .. " [-]"
            end
            if key == revealKey then revealTop = y end
            local label = rows[shown]
            label.itemKey = key
            UI.SetStatusText(label, text, view.status)
            area:Place(label, 0, y, rowHeight)
            y = y + rowHeight

            if isExpanded then
                local children = Items.Children(key, ctx)
                EnsureSubRows(subShown + #children)
                for _, child in ipairs(children) do
                    subShown = subShown + 1
                    local sub = subRows[subShown]
                    UI.SetStatusText(sub, (ITV2.STATUS_PREFIX[child.status] or "") .. child.text, child.status)
                    UI.SetSubRowAction(sub, child.action)
                    area:Place(sub, SUB_INDENT, y, subRowHeight)
                    y = y + subRowHeight
                end
                if key == revealKey then revealBottom = y end
                y = y + EXPANDED_GAP
            end
        end
    end
    for index = shown + 1, #rows do
        rows[index]:Show(false)
    end
    for index = subShown + 1, #subRows do
        subRows[index]:Show(false)
    end

    if shown == 0 then
        area:Place(emptyHint, 0, 0, rowHeight)
        y = rowHeight
    else
        emptyHint:Show(false)
    end
    return y, revealTop, revealBottom
end

function Popout.Refresh(revealKey)
    local cat = CATEGORIES[S.popoutPage]
    title:SetText(T(cat.label))
    prevButton:Enable(S.NextEnabledPage(S.popoutPage, -1) ~= S.popoutPage)
    nextButton:Enable(S.NextEnabledPage(S.popoutPage, 1) ~= S.popoutPage)
    local height, revealTop, revealBottom = Layout(cat, revealKey)
    local repositioned = area:SetContentHeight(height)
    -- 只在主動展開時顯示新內容；定期刷新與收起不搶走捲動位置。
    if revealTop ~= nil and revealBottom ~= nil then
        repositioned = area:RevealRange(revealTop, revealBottom) or repositioned
    end
    if repositioned then
        Layout(cat)
    end
    UpdateBarVisible()
    -- 分類的順序、開關或面板外觀改了，選單也跟著更新
    if menu:IsVisible() then
        LayoutPageMenu()
    end
end

local elapsed = REFRESH_MS
body:SetHandler("OnUpdate", function(self, dt)
    Items.TickSources(dt)

    -- 懸停（本體或標題欄）才顯示按鈕；離開後稍等一下再收起
    if IsMouseOver() then
        leftFor = 0
        if not hovered then
            SetHovered(true)
        end
    elseif hovered then
        leftFor = leftFor + dt
        if leftFor >= HOVER_LINGER_MS then
            SetHovered(false)
        end
    end

    elapsed = elapsed + dt
    if elapsed < REFRESH_MS then
        return
    end
    elapsed = 0
    Popout.Refresh()
end)

-- 載入設定後呼叫
function Popout.Init()
    AnchorHeader()
    Popout.ApplyLayout()
    SetHovered(false)
    Popout.Refresh()
    body:Show(true)
    header:Show(true)
end
