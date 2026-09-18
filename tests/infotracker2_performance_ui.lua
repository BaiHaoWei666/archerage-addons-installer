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
dofile('addons/infotracker2/core.lua')
ITV2.Text=function(key) if key=='TRACKED_SUMMARY' then return '%d/%d' end;return key end
ITV2.SOURCES={}
ITV2.CATEGORIES={{key='daily',label='daily',kind='quest'}}
local order={}
for i=1,30 do order[i]=tostring(i) end
local tracked={}
ITV2.Settings={
    panel={fontTitle=12,fontItem=12,fontSub=12,width=220,height=114,bgAlpha=50},
    popoutPage=1,pageOrder={1},orderByCat={daily=order},PANEL_SETTINGS={},squadInvite=false,
    IsTracked=function(key) return tracked[key]~=false end,
    SetTracked=function(key,value) tracked[key]=value;return true end,
    IsPageEnabled=function() return true end,CanDisablePage=function() return false end,
    NextEnabledPage=function() return 1 end,Save=function() end,
}
local queryCount, childCount, status=0,2,'neutral'
ITV2.Items={
    NewContext=function() return {} end,
    View=function(key) queryCount=queryCount+1;return {text=key,status=status} end,
    CanExpand=function() return true end,
    Children=function() local out={};for i=1,childCount do out[i]={text=tostring(i),status='neutral'} end;return out end,
    GetName=function() return 'test' end,
}
dofile('addons/infotracker2/windows/widgets.lua')
dofile('addons/infotracker2/windows/editor.lua')
dofile('addons/infotracker2/windows/squad_confirm.lua')
dofile('addons/infotracker2/windows/popout.lua')
ITV2.Popout.Init()
ITV2.Editor.Toggle(1)
local anchors,texts,queries=calls.RemoveAllAnchors,calls.SetText,queryCount
Frame('itv2EditorWindow',1000)
assert(queryCount==queries+30,'設定窗未刷新資料')
assert(calls.RemoveAllAnchors==anchors and calls.SetText==texts,'無變更的設定窗仍重排或寫入文字')
status='complete'
Frame('itv2EditorWindow',1000)
assert(calls.SetText>texts and calls.RemoveAllAnchors==anchors,'狀態變更未更新或引發重排')
queries=queryCount
widgets.itv2EditorListSlider.handlers.OnSliderChanged(nil,40)
assert(queryCount==queries,'設定窗捲動查詢資料')
Click('itv2ItemLabel1')
childCount=4
anchors=calls.RemoveAllAnchors
Frame('itv2EditorWindow',1000)
assert(widgets.itv2SubLabel4~=nil,'細項增加時未重建版面')
assert(calls.RemoveAllAnchors>anchors,'結構改變應重新排版')
-- 勾選框的引擎後置切換以下一幀同步，不能因文字快取而跳過。
Click('itv2Track1')
widgets.itv2Track1.checked=true
Frame('itv2EditorWindow',16)
assert(widgets.itv2Track1.checked==false,'追蹤勾選狀態未同步')
Click('itv2Tab2')
anchors,texts,queries=calls.RemoveAllAnchors,calls.SetText,queryCount
for i=1,3 do Frame('itv2EditorWindow',1000) end
assert(queryCount==queries and calls.RemoveAllAnchors==anchors and calls.SetText==texts,'靜態設定頁仍定時重排')
print('PASS: 設定窗捲動零查詢、資料更新零重排、靜態頁零刷新及動態細項重排')

local checks=calls.SetChecked
ITV2.SquadConfirm.Show('1')
assert(calls.SetChecked==checks+1)
checks=calls.SetChecked
for i=1,120 do Frame('itv2SquadConfirm',16) end
assert(calls.SetChecked==checks,'確認窗閒置時仍每幀寫入勾選框')
Click('itv2SquadInviteCheck')
widgets.itv2SquadInviteCheck.checked=false
Frame('itv2SquadConfirm',16)
assert(widgets.itv2SquadInviteCheck.checked and calls.SetChecked==checks+1)
for i=1,120 do Frame('itv2SquadConfirm',16) end
assert(calls.SetChecked==checks+1,'確認窗同步超過一次')
print('PASS: 確認窗閒置 120 幀零寫入，點擊後只同步一次')

-- 60 FPS 下每 5 幀檢查一次，隱藏的歷史列不參與命中測試。
widgets.itv2PopoutWindow.over=true
local mouseBefore=calls.IsMouseOver or 0
queries=queryCount
for i=1,60 do Frame('itv2PopoutWindow',1000/60) end
assert(calls.IsMouseOver-mouseBefore==12,'懸停未按 75ms 降頻')
assert(queryCount==queries,'未到 5 秒卻重新查詢懸浮窗')
widgets.itv2PopoutWindow.over=false
widgets.itv2PopRow30.IsMouseOver=function() error('掃描了不可見列') end
for i=1,30 do Frame('itv2PopoutWindow',1000/60) end
assert(not widgets.itv2PopPrev.visible,'離開後未隱藏按鈕')
print('PASS: 60 FPS 懸停檢查從每秒 60 次降為 12 次，只檢查可見列')
-- 正式樣式：設定頁陰影、主子項字級差與追蹤分類的細項縮排。
Click('itv2Tab1')
for _,id in ipairs({'itv2ItemLabel1','itv2SubLabel1'}) do
    assert(widgets[id].style.shadow==true,'設定頁文字缺少陰影：'..id)
end
for _,id in ipairs({'itv2EditorTitle','itv2Tab1','itv2EditorSummary','itv2PanelSizeSection','itv2TrackAllButton'}) do
    assert(widgets[id].style.shadow~=true,'非清單文字不應額外加上陰影：'..id)
end
local parent=widgets.itv2ItemLabel1
local child=widgets.itv2SubLabel1
assert(child.style.fontSize==parent.style.fontSize-1,'子項字級不是主項減一')
assert(child.itv2Placement.x==parent.itv2Placement.x+ITV2.UI.ChildIndent(parent,parent.style.fontSize),'追蹤分類子項未對齊主項第一個字')
assert(ITV2.StylePreview==nil and ITV2.ExpandPreview==nil,'試看功能未清除')
assert(parent.itv2Text:sub(1,#'▼ ')=='▼ ','展開主項缺少前置三角形')
assert(child.itv2Text:sub(1,#'· ')=='· ','子項未使用圓點前綴')
print('PASS: 正式陰影、子項字級小一及追蹤分類細項對齊主項文字')

-- 說明與面板設定共用靜態頁流程，切頁不殘留清單或操作按鈕。
Click('itv2Tab3')
assert(widgets.itv2HelpText1.visible and widgets.itv2HelpText2.visible,'說明內容未顯示')
assert(not widgets.itv2ItemLabel1.visible and not widgets.itv2PanelSizeSection.visible,'說明頁殘留其他頁內容')
assert(not widgets.itv2EditorSummary.visible and not widgets.itv2TrackAllButton.visible,'說明頁殘留追蹤操作')
anchors,texts,queries=calls.RemoveAllAnchors,calls.SetText,queryCount
for i=1,3 do Frame('itv2EditorWindow',1000) end
assert(queryCount==queries and calls.RemoveAllAnchors==anchors and calls.SetText==texts,'說明頁不應定時查詢或重排')
Click('itv2Tab2')
assert(not widgets.itv2HelpText1.visible and widgets.itv2PanelSizeSection.visible,'面板設定頁未清除說明內容')
assert(widgets.itv2PanelDragHint==nil,'移動說明仍留在面板設定頁')
Click('itv2Tab1')
assert(not widgets.itv2HelpText2.visible and widgets.itv2TrackAllButton.visible,'分類頁切換未恢復追蹤操作')
print('PASS: 說明頁切換、內容隔離及閒置零查詢零重排')
