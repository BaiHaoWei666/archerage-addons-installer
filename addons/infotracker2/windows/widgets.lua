-- 共用 UI 元件
-- 遊戲皮膚定義：ui/setting/button_style.g、ui/common/default.g（改外觀前先查）
ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.SLIDER)
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)
ADDON:ImportObject(OBJECT_TYPE.TEXTBOX)
ADDON:ImportObject(OBJECT_TYPE.CHECK_BUTTON)
ADDON:ImportAPI(API_TYPE.INPUT.id)

local T = ITV2.Text

local UI = {}
ITV2.UI = UI

UI.STATUS_COLORS = {
    notStarted = { 0.85, 0.15, 0.12, 1 },
    inProgress = { 0.85, 0.40, 0.05, 1 },
    complete = { 0.20, 0.75, 0.20, 1 },
    neutral = { 0.90, 0.90, 0.90, 1 },
}

function UI.StatusColor(status)
    return UI.STATUS_COLORS[status] or UI.STATUS_COLORS.neutral
end

-- 小圖標按鈕（遊戲內建樣式，固定尺寸，見 ui/setting/button_style.g）
UI.ICON_PLUS = { style = "plus", width = 20, height = 20 }
UI.ICON_MINUS = { style = "minus", width = 20, height = 20 }
UI.ICON_UP = { style = "grid_folder_up_arrow", width = 20, height = 13 }
UI.ICON_DOWN = { style = "grid_folder_down_arrow", width = 20, height = 13 }
UI.ICON_GAP = 6

-- 勾選框（貼圖見 ui/button/check_button.g）
UI.CHECK_WIDTH = 18
UI.CHECK_HEIGHT = 17
local CHECK_TEXTURE = "ui/button/check_button.dds"

-- 捲軸（外觀沿用 manager / autostore）
UI.SCROLL_BAR_WIDTH = 20
UI.SCROLL_BAR_GAP = 4
local SCROLL_TEXTURE = "ui/button/scroll_button.dds"
local SCROLL_STEP = 40

-- ============================================
-- 文字、按鈕
-- ============================================
function UI.SetTextColor(widget, color)
    if widget == nil or color == nil then
        return
    end
    if widget.style ~= nil and widget.style.SetColor ~= nil then
        widget.style:SetColor(color[1], color[2], color[3], color[4])
    end
    if widget.SetTextColor ~= nil then
        widget:SetTextColor(color[1], color[2], color[3], color[4])
    end
    if widget.SetHighlightTextColor ~= nil then
        widget:SetHighlightTextColor(color[1], color[2], color[3], color[4])
    end
    if widget.SetPushedTextColor ~= nil then
        widget:SetPushedTextColor(color[1], color[2], color[3], color[4])
    end
end

-- fn(self, doubleClick)；右鍵不動作
function UI.OnLeftClick(widget, fn)
    widget:SetHandler("OnClick", function(self, arg, doubleClick)
        if arg == "RightButton" then
            return
        end
        fn(self, doubleClick == true)
    end)
end

function UI.CreateLabel(parent, id, width, height, fontSize)
    local label = parent:CreateChildWidget("label", id, 0, true)
    label:SetExtent(width, height)
    label.style:SetAlign(ALIGN_LEFT)
    label.style:SetFontSize(fontSize)
    return label
end

-- 不能點的棕色說明文字（標題、區段名稱等）
function UI.CreateCaption(parent, id, width, height, fontSize, text)
    local label = UI.CreateLabel(parent, id, width, height, fontSize)
    label:EnablePick(false)
    label.style:SetColorByKey("brown")
    if text ~= nil then
        label:SetText(text)
    end
    return label
end

-- 單行文字，超出寬度顯示「...」（寫法同 manager 的插件名稱）
function UI.CreateEllipsisText(parent, id, fontSize)
    local box = parent:CreateChildWidget("textbox", id, 0, true)
    box:SetAutoWordwrap(false)
    box.style:SetAlign(ALIGN_LEFT)
    box.style:SetFontSize(fontSize)
    box.style:SetEllipsis(true)
    return box
end

-- textbox 在 SetText 時就定下顏色，之後才改 style 顏色不會重畫。
-- 所以先設顏色再設文字；顏色有變時先清空文字，確保文字沒變也會用新顏色重畫。
function UI.SetStatusText(box, text, status)
    local color = UI.StatusColor(status)
    if box.itv2Color == color and box.itv2Text == text then return end
    if box.itv2Color ~= color then
        box.itv2Color = color
        UI.SetTextColor(box, color)
        box:SetText("")
    end
    box:SetText(text)
    box.itv2Text = text
end

-- text_default 按鈕在 SetText 時會自動改寬度，所以每次改字後都要重設大小
function UI.SetButtonText(button, text)
    button:SetText(text)
    button:SetExtent(button.itv2Width, button.itv2Height)
end

function UI.SetButtonSize(button, width, height)
    button.itv2Width = width
    button.itv2Height = height
    button:SetExtent(width, height)
end

function UI.CreateTextButton(parent, id, text, width, height)
    local button = parent:CreateChildWidget("button", id, 0, true)
    button:SetStyle("text_default")
    button:SetAutoResize(false)
    button.itv2Width = width
    button.itv2Height = height
    UI.SetButtonText(button, text)
    return button
end

function UI.CreateIconButton(parent, id, icon, fn)
    local button = parent:CreateChildWidget("button", id, 0, true)
    button:SetStyle(icon.style)
    button:SetExtent(icon.width, icon.height)
    button.itv2Icon = icon
    UI.OnLeftClick(button, fn)
    return button
end

-- 原生 checkbutton（外觀同附加組件管理器）
-- 勾選框會在點擊處理之後自己再切換一次，所以 fn(self) 只改資料，畫面狀態由刷新時的 SetChecked 決定
function UI.CreateCheckBox(parent, id, fn)
    local box = parent:CreateChildWidget("checkbutton", id, 0, true)
    box:SetExtent(UI.CHECK_WIDTH, UI.CHECK_HEIGHT)
    local skins = {
        { key = "btn_df", setter = "SetNormalBackground" },
        { key = "btn_ov", setter = "SetHighlightBackground" },
        { key = "btn_on", setter = "SetPushedBackground" },
        { key = "btn_dis", setter = "SetDisabledBackground" },
        { key = "btn_chk_df", setter = "SetCheckedBackground" },
        { key = "btn_chk_dis", setter = "SetDisabledCheckedBackground" },
    }
    for _, skin in ipairs(skins) do
        local drawable = box:CreateDrawable(CHECK_TEXTURE, skin.key, "background")
        drawable:AddAnchor("TOPLEFT", box, 0, 0)
        drawable:AddAnchor("BOTTOMRIGHT", box, 0, 0)
        box[skin.setter](box, drawable)
    end
    UI.OnLeftClick(box, fn)
    return box
end

-- 細項有 action 時才能點，雙擊才執行，避免誤觸（例：特產材料 → 拍賣場查詢）
function UI.SetSubRowAction(label, action)
    if (label.itv2Action ~= nil) ~= (action ~= nil) then
        label:EnablePick(action ~= nil)
    end
    label.itv2Action = action
end

function UI.RunSubRowAction(self, doubleClick)
    if doubleClick and self.itv2Action ~= nil then
        pcall(self.itv2Action)
    end
end

-- ============================================
-- 視窗
-- ============================================
-- 拖動 handle 時移動 target；canDrag 回傳 false 時不動。
-- 拖動的元件必須自己 StartMoving，叫別的視窗移動不會生效。
function UI.EnableWindowDrag(handle, target, canDrag, onStop)
    handle:EnableDrag(true)
    handle:SetHandler("OnDragStart", function()
        if canDrag ~= nil and not canDrag() then
            return
        end
        target:StartMoving()
        target.itv2Moving = true
        return true
    end)
    handle:SetHandler("OnDragStop", function()
        if not target.itv2Moving then
            return
        end
        target.itv2Moving = false
        target:StopMovingOrSizing()
        if onStop ~= nil then
            onStop(target)
        end
    end)
end

-- 置中、可拖動、Esc 關閉、有底圖的對話視窗（預設隱藏）
function UI.CreateDialog(id, width, height, offsetY)
    local window = CreateEmptyWindow(id, "UIParent")
    window:SetCloseOnEscape(true)
    window:SetExtent(width, height)
    window:AddAnchor("CENTER", "UIParent", 0, offsetY or 0)
    window:Show(false)
    window:Clickable(true)
    window:SetUILayer("system")
    UI.EnableWindowDrag(window, window)

    local bg = window:CreateDrawable("ui/common/default.dds", "main_bg", "background")
    bg:AddAnchor("TOPLEFT", window, -5, -5)
    bg:AddAnchor("BOTTOMRIGHT", window, 5, 5)
    return window
end

-- 讀不到 Shift 狀態時不要讓標題欄變成完全拖不動：先放行，並提示一次
local shiftWarned = false
function UI.IsShiftDown()
    local ok, down = pcall(function()
        return X2Input:IsShiftKeyDown()
    end)
    if ok then
        return down == true
    end
    if not shiftWarned then
        shiftWarned = true
        ITV2.Chat(T("SHIFT_UNAVAILABLE"))
    end
    return true
end

function UI.EffectiveToAnchorOffset(value)
    if F_LAYOUT ~= nil and F_LAYOUT.CalcDontApplyUIScale ~= nil then
        return F_LAYOUT.CalcDontApplyUIScale(value)
    end
    return value / ITV2.GetUiScale()
end

-- ============================================
-- 捲動區域
-- 清單項目放在 area.content 裡，用 area:Place() 擺放（y 為清單內座標）。
-- 自己記錄捲動位置並在排版時扣掉，完全超出可視範圍的元件直接隱藏，
-- 所以每次重新排版都不會和捲動位置衝突。
-- 排版流程：BeginLayout → Place → SetContentHeight；位置改變時用 Reposition，無須重查資料。
-- ============================================
function UI.CreateScrollArea(parent, id, onScroll)
    local area = { offset = 0, viewHeight = 0, onScroll = onScroll, placements = {}, visibleWidgets = {} }

    local content = parent:CreateChildWidget("emptywidget", id .. "Content", 0, true)
    content:EnableScroll(true)
    area.content = content

    local bar = parent:CreateChildWidget("emptywidget", id .. "Bar", 0, true)
    area.bar = bar

    local upButton = bar:CreateChildWidget("button", id .. "Up", 0, true)
    upButton:SetStyle("slider_scroll_button_up")
    upButton:SetExtent(UI.SCROLL_BAR_WIDTH, 12)
    upButton:AddAnchor("TOPRIGHT", bar, 0, 0)

    local downButton = bar:CreateChildWidget("button", id .. "Down", 0, true)
    downButton:SetStyle("slider_scroll_button_down")
    downButton:SetExtent(UI.SCROLL_BAR_WIDTH, 12)
    downButton:AddAnchor("BOTTOMRIGHT", bar, 0, 0)

    local slider = bar:CreateChildWidget("slider", id .. "Slider", 0, true)
    slider:AddAnchor("TOPLEFT", upButton, "BOTTOMLEFT", 0, 0)
    slider:AddAnchor("BOTTOMRIGHT", downButton, "TOPRIGHT", 0, 0)

    local sliderBg = slider:CreateDrawable(SCROLL_TEXTURE, "scroll_frame_bg", "background")
    sliderBg:AddAnchor("TOPLEFT", slider, 3, -9)
    sliderBg:AddAnchor("BOTTOMRIGHT", slider, -3, 9)

    local thumb = slider:CreateChildWidget("button", id .. "Thumb", 0, true)
    thumb:SetWidth(UI.SCROLL_BAR_WIDTH)
    local thumbSkins = {
        { key = "thumb_df", setter = "SetNormalBackground" },
        { key = "thumb_ov", setter = "SetHighlightBackground" },
        { key = "thumb_on", setter = "SetPushedBackground" },
        { key = "thumb_dis", setter = "SetDisabledBackground" },
    }
    for _, skin in ipairs(thumbSkins) do
        local drawable = thumb:CreateDrawable(SCROLL_TEXTURE, skin.key, "background")
        drawable:AddAnchor("TOPLEFT", thumb, 0, 0)
        drawable:AddAnchor("BOTTOMRIGHT", thumb, 0, 0)
        thumb[skin.setter](thumb, drawable)
    end

    slider:SetThumbButtonWidget(thumb)
    slider:SetPageStep(SCROLL_STEP)
    slider:SetValueStep(SCROLL_STEP)
    slider:SetFixedThumb(true)
    slider:SetMinMaxValues(0, 0)

    local function ScrollUp()
        slider:Up(SCROLL_STEP)
    end
    local function ScrollDown()
        slider:Down(SCROLL_STEP)
    end

    UI.OnLeftClick(upButton, ScrollUp)
    UI.OnLeftClick(downButton, ScrollDown)

    slider:SetHandler("OnSliderChanged", function(_, value)
        value = math.floor(tonumber(value) or 0)
        if value == area.offset then
            return
        end
        area.offset = value
        if not area.updating and area.onScroll ~= nil then
            area.onScroll()
        end
    end)

    -- 滑鼠滾輪：清單區與會接走滑鼠的元件都要綁
    function area:BindWheel(widget)
        widget:SetHandler("OnWheelUp", ScrollUp)
        widget:SetHandler("OnWheelDown", ScrollDown)
    end
    area:BindWheel(content)

    -- 可視範圍（相對 parent）；捲軸貼在清單右邊，間距 barGap（預設 SCROLL_BAR_GAP）
    function area:SetView(x, y, width, height, barGap)
        self.viewHeight = height
        content:RemoveAllAnchors()
        content:AddAnchor("TOPLEFT", parent, x, y)
        content:SetExtent(width, height)
        bar:RemoveAllAnchors()
        bar:AddAnchor("TOPLEFT", parent, x + width + (barGap or UI.SCROLL_BAR_GAP), y)
        bar:SetExtent(UI.SCROLL_BAR_WIDTH, height)
    end

    function area:Show(visible)
        content:Show(visible)
        bar:Show(visible)
    end

    -- 排版記錄只在資料或結構更新時重建，捲動直接重用。
    function area:BeginLayout()
        self.placements = {}
        self.visibleWidgets = {}
    end

    local function PlacePosition(self, widget, x, y, height)
        local top = y - self.offset
        local visible = top >= 0 and top + height <= self.viewHeight
        if visible then
            local old = widget.itv2Placement
            if old == nil or old.x ~= x or old.y ~= top then
                widget:RemoveAllAnchors()
                widget:AddAnchor("TOPLEFT", content, x, top)
                widget.itv2Placement = { x = x, y = top }
            end
            self.visibleWidgets[#self.visibleWidgets + 1] = widget
        end
        -- 首次必須設定自身狀態，不能把父視窗隱藏誤認為元件已隱藏。
        if widget.itv2PlacedVisible ~= visible or widget:IsVisible() ~= visible then
            widget:Show(visible)
        end
        widget.itv2PlacedVisible = visible
    end

    function area:Place(widget, x, y, height)
        self.placements[#self.placements + 1] = { widget = widget, x = x, y = y, height = height }
        PlacePosition(self, widget, x, y, height)
    end

    function area:Reposition()
        self.visibleWidgets = {}
        for _, p in ipairs(self.placements) do
            PlacePosition(self, p.widget, p.x, p.y, p.height)
        end
    end

    -- 圖標按鈕右緣對齊 right、在行內垂直置中；回傳下一個圖標可用的右緣（由右往左排）
    function area:PlaceIcon(button, right, rowY, rowHeight)
        local icon = button.itv2Icon
        local x = right - icon.width
        self:Place(button, x, rowY + math.floor((rowHeight - icon.height) / 2), icon.height)
        return x - UI.ICON_GAP
    end

    -- 排版完後告知清單總高度；捲動位置被夾住時回傳 true，呼叫端使用 Reposition
    function area:SetContentHeight(height)
        local max = math.max(0, height - self.viewHeight)
        if self.maxOffset == max then return false end
        local scrollable = max > 0
        local clamped = false
        self.scrollable = scrollable
        self.maxOffset = max
        self.updating = true
        slider:SetMinMaxValues(0, max)
        if self.offset > max then
            self.offset = max
            slider:SetValue(max, false)
            clamped = true
        end
        self.updating = false
        upButton:Enable(scrollable)
        downButton:Enable(scrollable)
        thumb:Show(scrollable)
        sliderBg:SetTextureColor(scrollable and "default" or "disable")
        return clamped
    end

    -- 更新內容高度後呼叫：以最小捲動量顯示區段；超過一頁時對齊區段頂端。
    -- 回傳位置是否改變，呼叫端需據此重新排版。
    function area:RevealRange(top, bottom)
        local target = self.offset
        if top < target or bottom - top > self.viewHeight then
            target = top
        elseif bottom > target + self.viewHeight then
            target = bottom - self.viewHeight
        end
        target = math.max(0, math.min(target, self.maxOffset or 0))
        if target == self.offset then return false end
        self.updating = true
        self.offset = target
        slider:SetValue(target, false)
        self.updating = false
        return true
    end

    function area:ScrollToTop()
        if self.offset ~= 0 then
            self.updating = true
            self.offset = 0
            slider:SetValue(0, false)
            self.updating = false
        end
    end

    return area
end
