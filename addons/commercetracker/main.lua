-- 进入点：进入世界后读取设定、区域名称，显示开关按钮
-- 插件重新载入时不会再收到 ENTERED_WORLD，所以载入时若已在世界中就直接初始化

-- 冷却、查价佇列、载入动画的计时（dt 单位毫秒）
local updater = CreateEmptyWindow("ctUpdater", "UIParent")
updater:SetHandler("OnUpdate", function(self, dt)
    CT.Trade.Tick(dt)
    CT.Auction.Tick(dt)
    CT.MainWindow.Tick(dt)
end)

local initialized = false

local function Init()
    if initialized then
        return
    end
    initialized = true
    CT.Settings.Load()
    CT.Trade.LoadZoneNames()
    CT.Trade.UpdateCommerceSkill()
    CT.ToggleButton.Init()
    updater:Show(true)
    CT.Chat(CT.Text("LOADED"))
end

UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, Init)

if CT.IsInWorld() then
    Init()
end
