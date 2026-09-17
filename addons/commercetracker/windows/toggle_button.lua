-- 画面上的开关按钮（沿用 Folio105 的图示）：点一下开关主视窗，拖动可移动（位置会存档）
local T = CT.Text
local UI = CT.UI
local S = CT.Settings

local ToggleButton = {}
CT.ToggleButton = ToggleButton

local SIZE = 22

local button = UIParent:CreateWidget("button", "ctToggleButton", "UIParent")
button:SetExtent(SIZE, SIZE)
button:SetText("")
button:EnableDrag(true)
button:Show(false)

local function CreateOverlay(path, visible)
    local icon = UI.CreateIcon(button, path, SIZE, SIZE)
    icon:AddAnchor("CENTER", button, 0, 0)
    icon:SetVisible(visible)
    return icon
end
CreateOverlay(UI.ICON_MAIN, true)
local hoverOverlay = CreateOverlay(UI.ICON_MAIN_HOVER, false)
local pushedOverlay = CreateOverlay(UI.ICON_MAIN_PUSHED, false)

local tooltip = button:CreateChildWidget("label", "ctToggleTooltip", 0, true)
tooltip:SetHeight(30)
tooltip:SetAutoResize(true)
local tooltipBg = tooltip:CreateNinePartDrawable("ui/common/hud.dds", "background")
tooltipBg:SetCoords(733, 169, 14, 15)
tooltipBg:SetInset(7, 7, 6, 7)
tooltipBg:AddAnchor("TOPLEFT", tooltip, -10, 0)
tooltipBg:AddAnchor("BOTTOMRIGHT", tooltip, 10, 0)
tooltip:SetText(T("TITLE"))
tooltip.style:SetAlign(ALIGN_CENTER)
tooltip.style:SetColorByKey("brown")
tooltip.style:SetFontSize(12)
tooltip:AddAnchor("TOPLEFT", button, -70, -30)
tooltip:Show(false)

button:SetHandler("OnEnter", function()
    hoverOverlay:SetVisible(true)
    tooltip:Show(true)
end)
button:SetHandler("OnLeave", function()
    hoverOverlay:SetVisible(false)
    pushedOverlay:SetVisible(false)
    tooltip:Show(false)
end)
button:SetHandler("OnMouseDown", function()
    pushedOverlay:SetVisible(true)
end)
button:SetHandler("OnMouseUp", function()
    pushedOverlay:SetVisible(false)
end)
button:SetHandler("OnClick", function()
    CT.MainWindow.Toggle()
end)

button:SetHandler("OnDragStart", function(self)
    self:StartMoving()
end)
button:SetHandler("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:CorrectOffsetByScreen()
    S.SetTogglePosition(x, y)
end)

-- 载入设定后呼叫
function ToggleButton.Init()
    button:RemoveAllAnchors()
    if S.toggleX ~= nil and S.toggleY ~= nil then
        local scale = CT.GetUiScale()
        button:AddAnchor("TOPLEFT", "UIParent", S.toggleX / scale, S.toggleY / scale)
    else
        button:AddAnchor("CENTER", "UIParent", 0, 0)
    end
    button:Show(true)
end
