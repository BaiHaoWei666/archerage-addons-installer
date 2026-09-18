-- 真實來源模組的 API 次數、延遲工作及即時存檔回歸。
ADDON = { ImportAPI = function() end }
API_TYPE = setmetatable({}, {__index = function() return {id=1} end})
UIParent = {}
dofile('addons/infotracker2/core.lua')
ITV2.Text = function(key) return key end
ITV2.Chat = function() end
ITV2.SOURCES = {}
local questCalls, journalCalls = 0, 0
local complete = false
X2Quest = {
    IsCompleted = function() questCalls = questCalls + 1; return complete end,
    GetActiveQuestListCount = function() journalCalls = journalCalls + 1; return 1 end,
    GetActiveQuestType = function() return 1 end,
    GetQuestContextMainTitle = function(_, id) return tostring(id) end,
}
dofile('addons/infotracker2/sources/common.lua')
dofile('addons/infotracker2/sources/quest.lua')
local quest = ITV2.SOURCES.quest
local item = {key='test', ids={1,2}}
local ctx = {}
quest.View(item, ctx)
quest.Children(item, ctx)
assert(questCalls == 2 and journalCalls == 1, '主項與細項未共用狀態快取')
complete = true
assert(quest.View(item, {}).status == 'complete' and questCalls == 4, '下次刷新仍使用舊狀態')
print('PASS: 主項＋細項的狀態 API 從 4 次降為 2 次，下一次刷新仍取得新狀態')

local infoCalls, craftCalls = 0, 0
local hasInfo = true
TADT_TODAY = 1
X2Achievement = {GetTodayAssignmentInfo = function()
    infoCalls = infoCalls + 1
    if hasInfo then return {questType=1,status=2} end
end}
ITV2.Specialty = {
    GetCraft=function() craftCalls=craftCalls+1; return 10 end,
    GetMaterials=function() return {} end,
}
dofile('addons/infotracker2/sources/assignment.lua')
local assignment=ITV2.SOURCES.assignment
item={slot=1};ctx={}
assignment.View(item,ctx);assignment.CanExpand(item,ctx);assignment.Children(item,ctx)
assert(infoCalls==1 and craftCalls==1,'同格挑戰資訊與配方未共用')
hasInfo=false;ctx={}
assignment.View(item,ctx);assignment.CanExpand(item,ctx);assignment.Children(item,ctx)
assert(infoCalls==2,'查無資訊未快取')
hasInfo=true
assert(assignment.CanExpand(item,{}),'資料恢復後沒有重試')
print('PASS: 每格挑戰只查詢一次，包含空結果與稍後恢復')

local auctionCalls, auctionName = 0, nil
API_TYPE.CRAFT={id=1};API_TYPE.AUCTION={id=2}
ADDON.ShowContent=function() end
X2Auction={SearchAuctionArticle=function(_, a,b,c,d,e,f,name) auctionCalls=auctionCalls+1;auctionName=name end}
dofile('addons/infotracker2/sources/specialty.lua')
ITV2.Specialty.SearchAuction('a')
ITV2.AdvanceTime(200)
assert(auctionCalls==0)
ITV2.Specialty.SearchAuction('b')
ITV2.AdvanceTime(299)
assert(auctionCalls==0)
ITV2.AdvanceTime(1)
assert(auctionCalls==1 and auctionName=='b')
ITV2.AdvanceTime(10000)
assert(auctionCalls==1,'查詢完成後重複執行')

local squadCalls=0
X2BattleField={
 GetInstanceListByKind=function() return {{type=1}} end,
 GetInstanceName=function() return 'test' end,
 GetDetailInstanceInfo=function() return {enterCount=0,maxEnterCount=3,singleApplyAvailable=true} end,
}
X2Squad={CreateSquad=function() squadCalls=squadCalls+1;return true end}
dofile('addons/infotracker2/sources/dungeon.lua')
local dungeon=ITV2.SOURCES.dungeon
item={index=1}
dungeon.Activate(item);ITV2.AdvanceTime(4999);dungeon.Activate(item)
assert(squadCalls==1,'冷卻提早結束')
ITV2.AdvanceTime(1);dungeon.Activate(item)
assert(squadCalls==2,'冷卻結束後仍無法建隊')
assert(dungeon.Tick==nil and assignment.Tick==nil,'仍保留閒置來源輪詢')
print('PASS: 拍賣延遲 300ms、最後一次查詢、建隊冷卻 5000ms')

local events, saves, clears = {}, 0, 0
local day=1
local snapshot
UIEVENT_TYPE=setmetatable({}, {__index=function(_,key) return key end})
UIParent.SetEventHandler=function(_,key,fn) events[key]=fn end
UIParent.GetServerTimeTable=function() return {year=2026,month=9,day=day} end
X2Unit={UnitName=function() return 'test' end}
ADDON.LoadData=function() return nil end
ADDON.ClearData=function() clears=clears+1 end
ADDON.SaveData=function(_,key,value) saves=saves+1;snapshot={gold=value.gold,exp=value.exp,date=value.date} end
dofile('addons/infotracker2/sources/income.lua')
events.PLAYER_MONEY(0)
assert(saves==0,'零收入不應寫入')
events.PLAYER_MONEY(10)
assert(saves==1 and snapshot.gold==10,'初始化與首筆收入應合併保存')
day=2
events.PLAYER_MONEY(5)
assert(saves==2 and snapshot.gold==5 and snapshot.date=='2026-9-2','跨日與當筆收入應只存一次')
events.EXP_CHANGED(nil,20)
assert(saves==3 and snapshot.exp==20,'收入必須即時保存')
assert(clears==saves)
print('PASS: 零收入 0 次存檔，跨日收入 1 次存檔，保留即時保存')
