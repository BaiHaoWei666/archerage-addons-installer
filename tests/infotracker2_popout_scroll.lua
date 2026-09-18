-- 模擬遊戲元件，執行真實捲動區域及懸浮窗的點擊、排版流程。
local widgets = {}
local function Widget(name)
    local w = { handlers = {}, visible = true }
    w.style = setmetatable({}, { __index = function() return function() end end })
    setmetatable(w, { __index = function(_, key)
        if string.sub(key, 1, 4) == "itv2" then return nil end
        if key == "CreateChildWidget" then return function(_, _, id) return Widget(id) end end
        if key == "CreateColorDrawable" or key == "CreateDrawable" then return function() return Widget() end end
        if key == "SetHandler" then return function(self, event, fn) self.handlers[event] = fn end end
        if key == "Show" then return function(self, value) self.visible = value end end
        if key == "IsVisible" then return function(self) return self.visible end end
        if key == "IsMouseOver" then return function() return false end end
        if key == "SetValue" then return function(self, value) self.value = value end end
        return function() end
    end })
    if name then widgets[name] = w end
    return w
end
ADDON = { ImportObject = function() end, ImportAPI = function() end }
OBJECT_TYPE = {}
API_TYPE = { INPUT = { id = 1 } }
ALIGN_CENTER = 0
CreateEmptyWindow = Widget
ITV2 = { Text = function(key) return key end, STATUS_PREFIX = {} }
dofile('addons/infotracker2/windows/widgets.lua')
local UI = ITV2.UI
UI.OnLeftClick = function(w, fn) w.click = fn end
UI.EnableWindowDrag = function() end
UI.CreateEllipsisText = function(_, id) return Widget(id) end
UI.CreateTextButton = UI.CreateEllipsisText
UI.SetStatusText = function() end
UI.SetSubRowAction = function() end
UI.SetButtonSize = function() end
local area
local createArea = UI.CreateScrollArea
UI.CreateScrollArea = function(...)
    area = createArea(...)
    return area
end
local count = 2
local queries = 0
ITV2.CATEGORIES = {{ key = 'daily', label = 'daily' }}
ITV2.Settings = {
    panel = { fontTitle = 12, fontItem = 12, fontSub = 12, width = 220, height = 114, bgAlpha = 50 },
    popoutPage = 1, pageOrder = {1}, orderByCat = { daily = {'a','b','c','d','e','f'} },
    IsTracked = function() return true end, IsPageEnabled = function() return true end,
    NextEnabledPage = function() return 1 end, Save = function() end,
}
ITV2.Items = {
    NewContext = function() return {} end, CanExpand = function() return true end,
    View = function(key) queries = queries + 1; return {text = key, status = 'neutral'} end,
    Children = function()
        local children = {}
        for i = 1, count do children[i] = {text = tostring(i), status = 'neutral'} end
        return children
    end,
}
dofile('addons/infotracker2/windows/popout.lua')
ITV2.Popout.Init()
-- 視窗高 100，點擊第五列（80..100）後，兩個子項必須進入視窗。
widgets.itv2PopRow5:click(false)
assert(widgets.itv2PopSubRow1.visible and widgets.itv2PopSubRow2.visible,
    '展開底部項目後，子項仍被擠到可視範圍外')
assert(widgets.itv2PopRow5.visible, '捲動後父項目應保持可見')
assert(widgets.itv2PopListSlider.value == area.offset, '捲軸與內容位置不同步')
local offset = area.offset
ITV2.Popout.Refresh()
assert(area.offset == offset, '定期刷新不應改變捲動位置')
widgets.itv2PopRow5:click(false)
-- 頂部有足夠空間時不應自動捲動。
area:ScrollToTop()
ITV2.Popout.Refresh()
widgets.itv2PopRow1:click(false)
assert(area.offset == 0, '已可見的子項不應觸發捲動')
widgets.itv2PopRow1:click(false)
-- 子項多於一頁時，保留父項目並從第一個子項開始顯示。
count = 10
widgets.itv2PopRow5:click(false)
assert(area.offset == 80, '超過一頁的展開內容應從父項目開始顯示')
assert(widgets.itv2PopRow5.visible and widgets.itv2PopSubRow1.visible)
print('PASS: 底部展開、父項可見、捲軸同步、刷新穩定及超過一頁的子項')

-- 真實捲軸事件不應再次取得任務資料。
local before = queries
widgets.itv2PopListSlider.handlers.OnSliderChanged(nil, 0)
assert(queries == before, '捲動重新查詢了任務資料')
print('PASS: 捲動零資料查詢')
