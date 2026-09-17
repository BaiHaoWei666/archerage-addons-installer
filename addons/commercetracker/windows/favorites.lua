-- 收藏路线侧栏：贴在主视窗右边，跟着主视窗移动；主视窗打开时一起打开
-- 每行「起始区域 > 交货区域」，点一下套用，右边的 × 删除；超过 MAX_VISIBLE 行时卷动
ADDON:ImportObject(OBJECT_TYPE.SLIDER)

local T = CT.Text
local UI = CT.UI
local S = CT.Settings

local Favorites = {}
CT.Favorites = Favorites

local WIDTH = 380
local ROW_HEIGHT = 34
local MAX_VISIBLE = 8
local LIST_TOP = 90
local SLIDER_WIDTH = 18
local SCROLL_TEXTURE = "ui/button/scroll_button.dds"

local offset = 0

local window = CreateEmptyWindow("ctFavoritesWindow", CT.MainWindow.window)
window:SetExtent(WIDTH, 100 + MAX_VISIBLE * ROW_HEIGHT)
window:AddAnchor("TOPLEFT", CT.MainWindow.window, "TOPRIGHT", 8, 0)
window:SetCloseOnEscape(true)
window:Show(false)
window:SetHandler("OnShow", function()
    SettingWindowSkin(window)
    window:SetStartAnimation(true, true)
end)

local titleBar = window:CreateChildWidget("window", "ctFavTitleBar", 0, true)
titleBar:AddAnchor("TOPLEFT", window, 0, 14)
titleBar:AddAnchor("TOPRIGHT", window, 0, 14)
titleBar:SetHeight(28)
titleBar.titleStyle:SetAlign(ALIGN_CENTER)
titleBar.titleStyle:SetFontSize(18)
titleBar.titleStyle:SetColorByKey("brown")
titleBar:SetTitleText(T("FAVORITES_TITLE"))
titleBar:Show(true)

local closeButton = UI.CreateTextButton(window, "ctFavClose", "X", 30, 22)
closeButton:AddAnchor("TOPRIGHT", window, -10, 8)
closeButton:SetHandler("OnClick", function()
    window:Show(false)
end)

local addButton = UI.CreateTextButton(window, "ctFavAdd", T("FAVORITE_ADD"), 220, 28)
addButton:AddAnchor("TOP", window, 0, 48)

local emptyLabel = window:CreateChildWidget("label", "ctFavEmpty", 0, true)
emptyLabel:AddAnchor("TOP", window, 0, 110)
emptyLabel.style:SetAlign(ALIGN_CENTER)
emptyLabel.style:SetFontSize(13)
emptyLabel.style:SetColor(0.85, 0.85, 0.85, 1)
emptyLabel:SetText(T("FAVORITE_EMPTY"))
emptyLabel:Show(false)

-- ============================================
-- 清单列
-- ============================================
local rows = {}
local rowWidth = WIDTH - 30 - SLIDER_WIDTH - 4
local clickWidth = rowWidth - 30

for index = 1, MAX_VISIBLE do
    local row = window:CreateChildWidget("window", "ctFavRow" .. index, 0, true)
    row:SetExtent(rowWidth, ROW_HEIGHT - 4)
    row:AddAnchor("TOPLEFT", window, 15, LIST_TOP + (index - 1) * ROW_HEIGHT)
    row:Show(false)

    -- 固定宽度的文字（过长会截掉），上面盖一个透明按钮负责点击
    local label = row:CreateChildWidget("label", "ctFavLabel" .. index, 0, true)
    label:SetExtent(clickWidth, ROW_HEIGHT - 4)
    label:AddAnchor("LEFT", row, 4, 0)
    label.style:SetFontSize(13)
    label.style:SetColorByKey("brown")
    label.style:SetAlign(ALIGN_LEFT)
    label:SetAutoResize(false)
    label:Show(true)

    local applyButton = row:CreateChildWidget("button", "ctFavApply" .. index, 0, true)
    applyButton:SetExtent(clickWidth, ROW_HEIGHT - 4)
    applyButton:AddAnchor("LEFT", row, 0, 0)
    applyButton:Show(true)

    local removeButton = row:CreateChildWidget("button", "ctFavRemove" .. index, 0, true)
    removeButton:SetStyle("btn_close_default")
    removeButton:AddAnchor("RIGHT", row, -2, 0)
    removeButton:Show(true)

    rows[index] = { row = row, label = label, apply = applyButton, remove = removeButton }
end

-- ============================================
-- 卷轴
-- ============================================
local sliderFrame = window:CreateChildWidget("emptywidget", "ctFavSliderFrame", 0, true)
sliderFrame:SetExtent(SLIDER_WIDTH, MAX_VISIBLE * ROW_HEIGHT)
sliderFrame:AddAnchor("TOPRIGHT", window, -12, LIST_TOP)

local upButton = sliderFrame:CreateChildWidget("button", "ctFavUp", 0, true)
upButton:SetExtent(SLIDER_WIDTH, 12)
upButton:AddAnchor("TOPRIGHT", sliderFrame, 0, 0)
upButton:SetStyle("slider_scroll_button_up")

local downButton = sliderFrame:CreateChildWidget("button", "ctFavDown", 0, true)
downButton:SetExtent(SLIDER_WIDTH, 12)
downButton:AddAnchor("BOTTOMRIGHT", sliderFrame, 0, 0)
downButton:SetStyle("slider_scroll_button_down")

local slider = sliderFrame:CreateChildWidget("slider", "ctFavSlider", 0, true)
slider:AddAnchor("TOPLEFT", upButton, "BOTTOMLEFT", 0, 0)
slider:AddAnchor("BOTTOMRIGHT", downButton, "TOPRIGHT", 0, 0)
slider:SetOrientation(0)

local sliderBg = slider:CreateDrawable(SCROLL_TEXTURE, "scroll_frame_bg", "background")
sliderBg:SetTextureColor("default")
sliderBg:AddAnchor("TOPLEFT", slider, 3, -9)
sliderBg:AddAnchor("BOTTOMRIGHT", slider, -3, 9)

local thumb = slider:CreateChildWidget("button", "ctFavThumb", 0, true)
thumb:EnableDrag(true)
thumb:SetWidth(SLIDER_WIDTH)
for _, skin in ipairs({
    { key = "thumb_df", setter = "SetNormalBackground" },
    { key = "thumb_ov", setter = "SetHighlightBackground" },
    { key = "thumb_on", setter = "SetPushedBackground" },
}) do
    local drawable = thumb:CreateDrawable(SCROLL_TEXTURE, skin.key, "background")
    drawable:AddAnchor("TOPLEFT", thumb, 0, 0)
    drawable:AddAnchor("BOTTOMRIGHT", thumb, 0, 0)
    thumb[skin.setter](thumb, drawable)
end

slider:SetThumbButtonWidget(thumb)
slider:SetMinMaxValues(0, 0)
slider:SetValueStep(1)
slider:SetValue(0, false)

-- ============================================
-- 刷新
-- ============================================
local function MaxOffset()
    return math.max(0, #S.favorites - MAX_VISIBLE)
end

-- syncSlider：由卷轴本身触发时传 false，避免互相触发
function Favorites.Refresh(syncSlider)
    offset = math.max(0, math.min(MaxOffset(), offset))
    if syncSlider ~= false then
        slider:SetMinMaxValues(0, MaxOffset())
        slider:SetValue(offset, false)
    end
    sliderFrame:Show(MaxOffset() > 0)
    emptyLabel:Show(#S.favorites == 0)

    for index, widgets in ipairs(rows) do
        local favIndex = index + offset
        local fav = S.favorites[favIndex]
        if fav ~= nil then
            widgets.favIndex = favIndex
            widgets.label:SetText(string.format(T("FAVORITE_ROUTE"),
                CT.Trade.ZoneName(fav.from), CT.Trade.ZoneName(fav.to)))
            widgets.label.style:SetColorByKey("brown")
            widgets.row:Show(true)
        else
            widgets.favIndex = nil
            widgets.row:Show(false)
        end
    end
end

local function Scroll(delta)
    local newOffset = math.max(0, math.min(MaxOffset(), offset + delta))
    if newOffset ~= offset then
        offset = newOffset
        Favorites.Refresh()
    end
end

for _, widgets in ipairs(rows) do
    widgets.apply:SetHandler("OnClick", function()
        local fav = widgets.favIndex and S.favorites[widgets.favIndex]
        if fav ~= nil then
            CT.MainWindow.ApplyRoute(fav.continent, fav.from, fav.to)
        end
    end)
    widgets.apply:SetHandler("OnEnter", function()
        widgets.label.style:SetColor(0.45, 1.0, 0.45, 1)
    end)
    widgets.apply:SetHandler("OnLeave", function()
        widgets.label.style:SetColorByKey("brown")
    end)
    widgets.remove:SetHandler("OnClick", function()
        if widgets.favIndex ~= nil then
            S.RemoveFavorite(widgets.favIndex)
            Favorites.Refresh()
        end
    end)
end

addButton:SetHandler("OnClick", function()
    if S.AddFavorite(CT.Trade.route) then
        Favorites.Refresh()
    end
end)

slider:SetHandler("OnSliderChanged", function(_, value)
    offset = math.floor(tonumber(value) or 0)
    Favorites.Refresh(false)
end)
upButton:SetHandler("OnClick", function()
    Scroll(-1)
end)
downButton:SetHandler("OnClick", function()
    Scroll(1)
end)
window:SetHandler("OnWheelUp", function()
    Scroll(-1)
end)
window:SetHandler("OnWheelDown", function()
    Scroll(1)
end)

function Favorites.Show()
    Favorites.Refresh()
    window:Show(true)
end

function Favorites.Toggle()
    if window:IsVisible() then
        window:Show(false)
    else
        Favorites.Show()
    end
end
