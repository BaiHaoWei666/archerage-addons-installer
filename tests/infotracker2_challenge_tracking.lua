-- 使用真實 UI 模組與元件呼叫計數，驗證閒置、捲動及單次同步。
local widgets, calls = {}, {}
local function Count(key) calls[key]=(calls[key] or 0)+1 end
local function Widget(name)
    local w={handlers={},visible=true}
    w.style=setmetatable({}, {__index=function(_,method)
        return function(self,value)
            Count('style.'..method)
            if method=='SetShadow' then self.shadow=value end
            if method=='SetFontSize' then self.fontSize=value end
        end
    end})
    setmetatable(w,{__index=function(_,key)
        if string.sub(key,1,4)=='itv2' then return nil end
        if key=='CreateChildWidget' then return function(_,_,id) return Widget(id) end end
        if key=='CreateDrawable' or key=='CreateColorDrawable' then return function() return Widget() end end
        if key=='SetHandler' then return function(self,event,fn) self.handlers[event]=fn end end
        if key=='Show' then return function(self,value) self.visible=value;Count(key) end end
        if key=='IsVisible' then return function(self) return self.visible end end
        if key=='IsMouseOver' then return function(self) Count(key);return self.over==true end end
        if key=='SetText' then return function(self,text) self.text=text;Count(key) end end
        if key=='SetChecked' then return function(self,value) self.checked=value;Count(key) end end
        return function() Count(key) end
    end})
    if name then widgets[name]=w end
    return w
end
local function Click(id)
    local w=widgets[id];w.handlers.OnClick(w,'LeftButton',false)
end
local function Frame(id,dt)
    local w=widgets[id];w.handlers.OnUpdate(w,dt)
end
ADDON={ImportAPI=function() end,ImportObject=function() end}
API_TYPE=setmetatable({}, {__index=function() return {id=1} end})
OBJECT_TYPE={};ALIGN_CENTER=0;ALIGN_LEFT=1
CreateEmptyWindow=Widget
UIParent={GetFontColor=function() return {1,1,1,1} end}
local saved
ADDON.LoadData=function() return saved end
ADDON.ClearData=function() end
ADDON.SaveData=function(_,_,value) saved=value end
dofile('addons/infotracker2/core.lua')
ITV2.Text=function(key) if key=='TRACKED_SUMMARY' then return '%d/%d' end;return key end
dofile('addons/infotracker2/quest_data.lua')
ITV2.SOURCES={}
local challenge
for index,cat in ipairs(ITV2.CATEGORIES) do
    ITV2.SOURCES[cat.kind]={View=function(item) return {text=item.key,status='neutral'} end}
    if cat.key=='challenge' then challenge=index end
end
dofile('addons/infotracker2/items.lua')
dofile('addons/infotracker2/settings.lua')
local S=ITV2.Settings
S.Load()
S.popoutPage=challenge
dofile('addons/infotracker2/windows/widgets.lua')
dofile('addons/infotracker2/windows/editor.lua')
dofile('addons/infotracker2/windows/popout.lua')
ITV2.Popout.Init()
ITV2.Editor.Toggle(challenge)
assert(widgets.itv2EditorSummary.visible and widgets.itv2TrackAllButton.visible,'每日挑戰缺少共用追蹤控制')
assert(widgets.itv2EditorSummary.text=='7/7','每日挑戰未預設全部追蹤')
assert(widgets.itv2Track1.visible and widgets.itv2Down1.visible,'每日挑戰缺少勾選或排序')
Click('itv2Track1')
Frame('itv2EditorWindow',16)
assert(not S.IsTracked('AS_1'),'取消每日挑戰追蹤無效')
assert(widgets.itv2PopRow1.itemKey=='AS_2','懸浮窗仍顯示未追蹤挑戰')
assert(widgets.itv2EditorSummary.text=='6/7','取消追蹤未更新計數')
Click('itv2Down1')
assert(S.orderByCat.challenge[1]=='AS_2','挑戰排序未套用')
S.Load()
assert(not S.IsTracked('AS_1') and S.orderByCat.challenge[1]=='AS_2','重新載入未保留挑戰勾選及排序')
Click('itv2TrackAllButton')
assert(S.IsTracked('AS_1'),'本頁全部追蹤未包含每日挑戰')
assert(widgets.itv2EditorSummary.text=='7/7','全部追蹤未更新計數')
for index,cat in ipairs(ITV2.CATEGORIES) do
    Click('itv2Tab'..index)
    assert(widgets.itv2EditorSummary.visible and widgets.itv2TrackAllButton.visible,'分類未使用共用追蹤控制：'..cat.key)
end
print('PASS: 每日挑戰勾選、懸浮窗過濾、排序、存檔還原、全部追蹤與所有分類共用控制')
