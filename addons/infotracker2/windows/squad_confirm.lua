-- 建立戰隊詢問窗（懸浮窗副本行雙擊時出現）
local T = ITV2.Text
local Items = ITV2.Items
local S = ITV2.Settings
local UI = ITV2.UI

local SquadConfirm = {}
ITV2.SquadConfirm = SquadConfirm

local WIDTH = 300
local HEIGHT = 140
local PADDING = 16
local BUTTON_WIDTH = 90
local BUTTON_HEIGHT = 26

local pendingKey = nil
local syncInvite = false

local window = UI.CreateDialog("itv2SquadConfirm", WIDTH, HEIGHT, -60)

local title = UI.CreateCaption(window, "itv2SquadConfirmTitle", WIDTH - PADDING * 2, 22, 15, T("SQUAD_CONFIRM_TITLE"))
title:AddAnchor("TOPLEFT", window, PADDING, 10)

local message = UI.CreateEllipsisText(window, "itv2SquadConfirmMessage", 13)
message:SetExtent(WIDTH - PADDING * 2, 22)
message:AddAnchor("TOPLEFT", window, PADDING, 40)
message:EnablePick(false)
message.style:SetColor(1, 1, 1, 1)

-- 「邀請隊伍成員」勾選框；點文字也能切換
local function ToggleInvite()
    S.squadInvite = not S.squadInvite
    syncInvite = true
    S.Save()
end

local inviteCheck = UI.CreateCheckBox(window, "itv2SquadInviteCheck", ToggleInvite)
inviteCheck:AddAnchor("TOPLEFT", window, PADDING, 72)

local inviteLabel = UI.CreateLabel(window, "itv2SquadInviteLabel", 200, 20, 13)
inviteLabel:AddAnchor("LEFT", inviteCheck, "RIGHT", 6, 0)
inviteLabel.style:SetColor(1, 1, 1, 1)
inviteLabel:SetText(T("SQUAD_INVITE_OPTION"))
inviteLabel:EnablePick(true)
UI.OnLeftClick(inviteLabel, ToggleInvite)

local okButton = UI.CreateTextButton(window, "itv2SquadConfirmOk", T("CONFIRM"), BUTTON_WIDTH, BUTTON_HEIGHT)
okButton:AddAnchor("BOTTOMRIGHT", window, -PADDING - BUTTON_WIDTH - 6, -12)

local cancelButton = UI.CreateTextButton(window, "itv2SquadConfirmCancel", T("CANCEL"), BUTTON_WIDTH, BUTTON_HEIGHT)
cancelButton:AddAnchor("BOTTOMRIGHT", window, -PADDING, -12)

local function Close()
    pendingKey = nil
    window:Show(false)
end

function SquadConfirm.Show(key)
    pendingKey = key
    message:SetText(string.format(T("SQUAD_CONFIRM_MESSAGE"), Items.GetName(key)))
    inviteCheck:SetChecked(S.squadInvite)
    syncInvite = false
    window:Show(true)
    window:Raise()
end

UI.OnLeftClick(okButton, function()
    local key = pendingKey
    Close()
    if key ~= nil then
        Items.Activate(key, { inviteParty = S.squadInvite })
        ITV2.Popout.Refresh()
    end
end)

UI.OnLeftClick(cancelButton, Close)

-- 勾選框點選後會自行切換，下一幀只同步一次。
window:SetHandler("OnUpdate", function()
    if not syncInvite then return end
    syncInvite = false
    inviteCheck:SetChecked(S.squadInvite)
end)
