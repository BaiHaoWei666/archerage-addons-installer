-- 共用 UI 元件：文字、按钮、金额（金银铜）显示、下拉选单
-- 外观沿用 Folio105；游戏皮肤定义见 Addon/ui/setting/button_style.g
ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)

local UI = {}
CT.UI = UI

local ICON_DIR = CT.ADDON_PATH .. "icons/"
UI.ICON_MAIN = ICON_DIR .. "main.dds"
UI.ICON_MAIN_HOVER = ICON_DIR .. "main_hover.dds"
UI.ICON_MAIN_PUSHED = ICON_DIR .. "main_pushed.dds"
local ICON_GOLD = ICON_DIR .. "gold.dds"
local ICON_SILVER = ICON_DIR .. "silver.dds"
local ICON_COPPER = ICON_DIR .. "copper.dds"
local ICON_UP = ICON_DIR .. "up.dds"
local ICON_DOWN = ICON_DIR .. "down.dds"
local ICON_SCROLL = ICON_DIR .. "scroll.dds"

function UI.FontColor(key)
    return UIParent:GetFontColor(key)
end

local function SetButtonTextColor(button, color)
    button:SetTextColor(color[1], color[2], color[3], color[4])
end

-- ============================================
-- 文字、按钮
-- ============================================
-- 不指定大小的文字（宽度跟着文字，Folio105 的写法）
function UI.CreateText(parent, id, fontSize, align)
    local label = parent:CreateChildWidget("label", id, 0, true)
    label:EnablePick(false)
    label.style:SetOutline(true)
    label.style:SetAlign(align or ALIGN_LEFT)
    label.style:SetFontSize(fontSize)
    return label
end

-- 棕色标题文字
function UI.CreateCaption(parent, id, fontSize, text, align)
    local label = parent:CreateChildWidget("label", id, 0, false)
    label:SetText(text)
    label.style:SetFontSize(fontSize)
    label.style:SetAlign(align or ALIGN_LEFT)
    label.style:SetColorByKey("brown")
    return label
end

function UI.CreateTextButton(parent, id, text, width, height)
    local button = parent:CreateChildWidget("button", id, 0, true)
    button:SetStyle("text_default")
    button:SetText(text)
    button:SetExtent(width, height)
    button:Show(true)
    return button
end

-- 重新整理按钮（贴图 ui/button/common/reset.dds）
function UI.CreateResetButton(parent, id, size)
    local button = parent:CreateChildWidget("button", id, 0, true)
    button:SetExtent(size, size)
    local skins = {
        { key = "reset_df", setter = "SetNormalBackground" },
        { key = "reset_ov", setter = "SetHighlightBackground" },
        { key = "reset_on", setter = "SetPushedBackground" },
        { key = "reset_dis", setter = "SetDisabledBackground" },
    }
    for _, skin in ipairs(skins) do
        local drawable = button:CreateDrawable("ui/button/common/reset.dds", skin.key, "background")
        drawable:AddAnchor("TOPLEFT", button, 0, 0)
        drawable:AddAnchor("BOTTOMRIGHT", button, 0, 0)
        button[skin.setter](button, drawable)
    end
    button:Show(true)
    return button
end

function UI.CreateIcon(parent, path, width, height)
    local icon = parent:CreateIconDrawable("artwork")
    icon:SetExtent(width, height)
    icon:ClearAllTextures()
    if path ~= nil then
        icon:AddTexture(path)
    end
    return icon
end

function UI.SetIconTexture(icon, path)
    icon:ClearAllTextures()
    if path ~= nil then
        icon:AddTexture(path)
    end
end

-- 水平分隔线
function UI.CreateLine(parent, width, thickness)
    local line = parent:CreateColorDrawable(0.55, 0.55, 0.90, 1, "artwork")
    line:SetExtent(width, thickness)
    return line
end

-- ============================================
-- 金额（金 / 银 / 铜 各一组文字 + 图示，为 0 的单位不显示）
-- ============================================
local CURRENCY_UNITS = {
    { key = "gold", icon = ICON_GOLD },
    { key = "silver", icon = ICON_SILVER },
    { key = "copper", icon = ICON_COPPER },
}
local CURRENCY_ICON_SIZE = 16
local CURRENCY_ICON_GAP = 5
local CURRENCY_UNIT_GAP = 25

function UI.CreateCurrency(parent, id, fontSize)
    local currency = {}
    for _, unit in ipairs(CURRENCY_UNITS) do
        local label = UI.CreateText(parent, id .. "_" .. unit.key, fontSize, ALIGN_RIGHT)
        local icon = UI.CreateIcon(parent, unit.icon, CURRENCY_ICON_SIZE, CURRENCY_ICON_SIZE)
        currency[unit.key] = { label = label, icon = icon }
    end
    UI.HideCurrency(currency)
    return currency
end

function UI.SetCurrencyColor(currency, r, g, b)
    for _, unit in ipairs(CURRENCY_UNITS) do
        currency[unit.key].label.style:SetColor(r, g, b, 1)
    end
end

function UI.HideCurrency(currency)
    for _, unit in ipairs(CURRENCY_UNITS) do
        currency[unit.key].label:Show(false)
        currency[unit.key].icon:SetVisible(false)
    end
end

-- 以 (x, y) 为起点显示金额（取绝对值）；rightAlign 时 x 是右缘
function UI.ShowCurrency(parent, currency, x, y, copper, rightAlign)
    UI.HideCurrency(currency)
    copper = math.abs(math.floor(tonumber(copper) or 0))
    local values = {
        gold = math.floor(copper / 10000),
        silver = math.floor(copper / 100) % 100,
        copper = copper % 100,
    }

    local shown = {}
    for _, unit in ipairs(CURRENCY_UNITS) do
        if values[unit.key] > 0 then
            local part = currency[unit.key]
            part.label:SetText(tostring(values[unit.key]))
            shown[#shown + 1] = { part = part, width = part.label:GetWidth() }
        end
    end
    if #shown == 0 then
        return
    end

    local total = 0
    for index, item in ipairs(shown) do
        total = total + item.width + CURRENCY_ICON_SIZE + CURRENCY_ICON_GAP
        if index < #shown then
            total = total + CURRENCY_UNIT_GAP
        end
    end

    local currentX = rightAlign and (x - total) or x
    for _, item in ipairs(shown) do
        item.part.label:RemoveAllAnchors()
        item.part.label:AddAnchor("TOPLEFT", parent, currentX, y)
        item.part.label:Show(true)
        item.part.icon:RemoveAllAnchors()
        item.part.icon:AddAnchor("LEFT", item.part.label, CURRENCY_ICON_GAP, 0)
        item.part.icon:SetVisible(true)
        currentX = currentX + item.width + CURRENCY_ICON_SIZE + CURRENCY_ICON_GAP + CURRENCY_UNIT_GAP
    end
end

-- ============================================
-- 下拉选单
-- combo:SetOptions({ { text, value }, ... })、combo:Select(value)、combo.onSelect = function(value)
-- ============================================
local COMBO_MAX_VISIBLE = 5
local COMBO_OPTION_HEIGHT = 30
local COMBO_SCROLL_WIDTH = 20
local COMBO_SCROLL_GAP = 2

function UI.CreateComboBox(parent, id, width, height)
    local combo = { options = {}, selected = nil, offset = 0, open = false, onSelect = nil }

    local trigger = parent:CreateChildWidget("button", id, 0, true)
    trigger:SetText("")
    trigger:SetExtent(width, height)
    trigger:Show(true)
    local triggerBg = trigger:CreateColorDrawable(0, 0, 0, 0.5, "background")
    triggerBg:AddAnchor("TOPLEFT", trigger, 0, 0)
    triggerBg:AddAnchor("BOTTOMRIGHT", trigger, 0, 0)
    combo.trigger = trigger

    local list = UIParent:CreateWidget("window", id .. "List", trigger, "")
    list:AddAnchor("TOPLEFT", trigger, "BOTTOMLEFT", 0, 0)
    list:Show(false)
    local listBg = list:CreateColorDrawable(0, 0, 0, 0.5, "background")
    listBg:AddAnchor("TOPLEFT", list, 0, 0)
    listBg:AddAnchor("BOTTOMRIGHT", list, 0, 0)

    local scrollColumn = UIParent:CreateWidget("window", id .. "Scroll", list, "")
    scrollColumn:AddAnchor("TOPLEFT", list, "TOPRIGHT", COMBO_SCROLL_GAP, 0)
    scrollColumn:Show(false)
    local scrollBg = scrollColumn:CreateColorDrawable(0, 0, 0, 0.4, "background")
    scrollBg:AddAnchor("TOPLEFT", scrollColumn, 0, 0)
    scrollBg:AddAnchor("BOTTOMRIGHT", scrollColumn, 0, 0)

    local function CreateIconButton(buttonId, path)
        local button = scrollColumn:CreateChildWidget("button", buttonId, 0, true)
        button:SetText("")
        button:SetExtent(COMBO_SCROLL_WIDTH, COMBO_SCROLL_WIDTH)
        local icon = UI.CreateIcon(button, path, COMBO_SCROLL_WIDTH, COMBO_SCROLL_WIDTH)
        icon:AddAnchor("CENTER", button, 0, 0)
        icon:SetVisible(true)
        return button
    end
    local upButton = CreateIconButton(id .. "Up", ICON_UP)
    upButton:AddAnchor("TOPRIGHT", scrollColumn, 0, 0)
    local downButton = CreateIconButton(id .. "Down", ICON_DOWN)
    downButton:AddAnchor("BOTTOMRIGHT", scrollColumn, 0, 0)
    local thumb = CreateIconButton(id .. "Thumb", ICON_SCROLL)
    thumb:EnablePick(false)

    local optionButtons = {}

    local function IsScrollable()
        return #combo.options > COMBO_MAX_VISIBLE
    end

    local function ListWidth()
        return IsScrollable() and (width - COMBO_SCROLL_WIDTH - COMBO_SCROLL_GAP) or width
    end

    local function OptionColor(option)
        return UI.FontColor(option ~= nil and option.value == combo.selected and "green" or "btn_df")
    end

    local Layout

    local function EnsureOptionButton(index)
        local button = optionButtons[index]
        if button ~= nil then
            return button
        end
        button = list:CreateChildWidget("button", id .. "Option" .. index, 0, true)
        button.bg = button:CreateColorDrawable(0, 0, 0, 0.5, "background")
        button.bg:AddAnchor("TOPLEFT", button, 0, 0)
        button.bg:AddAnchor("BOTTOMRIGHT", button, 0, 0)
        button:SetHandler("OnEnter", function(self)
            self.bg:SetColor(0.3, 0.3, 0.3, 0.7)
            SetButtonTextColor(self, UI.FontColor("btn_ov"))
        end)
        button:SetHandler("OnLeave", function(self)
            self.bg:SetColor(0, 0, 0, 0.5)
            SetButtonTextColor(self, OptionColor(combo.options[self.optionIndex]))
        end)
        button:SetHandler("OnClick", function(self)
            local option = combo.options[self.optionIndex]
            combo.open = false
            if option ~= nil then
                combo:Select(option.value)
                if combo.onSelect ~= nil then
                    combo.onSelect(option.value)
                end
            end
            Layout()
        end)
        optionButtons[index] = button
        return button
    end

    Layout = function()
        local total = #combo.options
        local visible = math.min(total, COMBO_MAX_VISIBLE)
        local listWidth = ListWidth()
        local open = combo.open and total > 0

        list:SetExtent(listWidth, math.max(visible, 1) * COMBO_OPTION_HEIGHT)
        list:Show(open)
        scrollColumn:SetExtent(COMBO_SCROLL_WIDTH, math.max(visible, 1) * COMBO_OPTION_HEIGHT)
        scrollColumn:Show(open and IsScrollable())

        for index = 1, total do
            EnsureOptionButton(index)
        end
        for index, button in ipairs(optionButtons) do
            local option = combo.options[index]
            local row = index - combo.offset
            if open and option ~= nil and row >= 1 and row <= COMBO_MAX_VISIBLE then
                button.optionIndex = index
                button:SetText(option.text)
                button:SetExtent(listWidth, COMBO_OPTION_HEIGHT)
                button:RemoveAllAnchors()
                button:AddAnchor("TOPLEFT", list, 0, (row - 1) * COMBO_OPTION_HEIGHT)
                button.bg:SetColor(0, 0, 0, 0.5)
                SetButtonTextColor(button, OptionColor(option))
                button:Show(true)
            else
                button:Show(false)
            end
        end

        -- 卷动位置指示：上下按钮之间依比例摆放
        if IsScrollable() then
            local maxOffset = total - COMBO_MAX_VISIBLE
            local track = visible * COMBO_OPTION_HEIGHT - COMBO_SCROLL_WIDTH * 3
            thumb:RemoveAllAnchors()
            thumb:AddAnchor("TOPLEFT", scrollColumn, 0,
                COMBO_SCROLL_WIDTH + math.floor(track * combo.offset / maxOffset))
            thumb:Show(true)
        end
    end

    local function Scroll(delta)
        local maxOffset = math.max(0, #combo.options - COMBO_MAX_VISIBLE)
        local offset = math.max(0, math.min(maxOffset, combo.offset + delta))
        if offset ~= combo.offset then
            combo.offset = offset
            Layout()
        end
    end

    upButton:SetHandler("OnClick", function()
        Scroll(-1)
    end)
    downButton:SetHandler("OnClick", function()
        Scroll(1)
    end)
    list:SetHandler("OnWheelUp", function()
        Scroll(-1)
    end)
    list:SetHandler("OnWheelDown", function()
        Scroll(1)
    end)

    trigger:SetHandler("OnClick", function()
        combo.open = not combo.open
        combo.offset = 0
        Layout()
    end)

    local function TextOf(value)
        for _, option in ipairs(combo.options) do
            if option.value == value then
                return option.text
            end
        end
        return nil
    end

    function combo:SetOptions(options)
        self.options = options or {}
        self.offset = 0
        self.open = false
        if TextOf(self.selected) == nil then
            self:Select(nil)
        end
        Layout()
    end

    -- 只改显示，不触发 onSelect
    function combo:Select(value)
        local text = TextOf(value)
        self.selected = text ~= nil and value or nil
        trigger:SetText(text or "")
    end

    function combo:Enable(enabled)
        trigger:Enable(enabled)
        if not enabled and self.open then
            self.open = false
            Layout()
        end
    end

    function combo:Close()
        if self.open then
            self.open = false
            Layout()
        end
    end

    return combo
end
