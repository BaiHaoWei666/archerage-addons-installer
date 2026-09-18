-- 債券拆組保留 ID、舊勾選狀態與排序，拆組後可以獨立設定。
local saved
ADDON={LoadData=function() return saved end}
ITV2={Text=function(key) return key end}
dofile('addons/infotracker2/quest_data.lua')
dofile('addons/infotracker2/items.lua')
dofile('addons/infotracker2/settings.lua')
local S=ITV2.Settings
assert(table.concat(ITV2.Items.byKey.BSB.ids,',')=='9044,9046,9047,9049')
assert(table.concat(ITV2.Items.byKey.BSB60.ids,',')=='9142,9147,9152')
for _,on in ipairs({true,false}) do
 saved={known={'BSB','NUI'},tracked=on and {'BSB'} or {},order={vocation={'NUI','BSB'}}}
 S.Load()
 assert(S.IsTracked('BSB')==on and S.IsTracked('BSB60')==on,'舊勾選狀態未沿用')
 assert(S.orderByCat.vocation[2]=='BSB' and S.orderByCat.vocation[3]=='BSB60','拆組順序不相鄰')
end
saved={known={'BSB','BSB60'},tracked={'BSB60'},order={vocation={'BSB60','NUI','BSB'}}}
S.Load()
assert(not S.IsTracked('BSB') and S.IsTracked('BSB60'),'拆組後獨立勾選被覆蓋')
assert(table.concat(S.orderByCat.vocation,','):sub(1,13)=='BSB60,NUI,BSB','自訂順序被覆蓋')
saved={tracked={'BSB'}};S.Load()
assert(S.IsTracked('BSB60'),'舊版存檔未遷移')
saved={};S.Load()
assert(S.IsTracked('BSB') and S.IsTracked('BSB60'),'新使用者未預設追蹤兩組')
print('PASS: 債券 20／60 任務池、舊設定遷移、獨立追蹤與排序')
