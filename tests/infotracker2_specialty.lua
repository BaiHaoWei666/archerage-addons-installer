-- 從專案根目錄執行：lua tests/infotracker2_specialty.lua
-- 使用真實來源模組，模擬已完成任務重新載入後不在日誌內的情境。
local function Setup(active, productName, questTitle)
    ADDON = { ImportAPI = function() end }
    API_TYPE = { QUEST = {id=1}, CRAFT = {id=2}, AUCTION = {id=3}, ACHIEVEMENT = {id=4} }
    TADT_TODAY = 1
    local title = questTitle or '[特产-东部] 棋盘石林的保存特产'
    X2Quest = {
        GetActiveQuestListCount = function() error('名稱比對不應讀取任務日誌') end,
        GetActiveQuestType = function() error('名稱比對不應讀取任務日誌') end,
        GetQuestContextMainTitle = function() return title end,
        GetQuestJournalObjectiveText = function() error('名稱比對不應讀取目標物品 ID') end,
    }
    X2Craft = {
        GetCraftProductInfo = function() return {{itemType=456, item_name=productName or '[棋盘]保存特产'}} end,
        GetCraftMaterialInfo = function() return {{item_info={name='石材',itemType=789},amount=3}} end,
    }
    X2Achievement = { GetTodayAssignmentInfo = function() return {questType=123,status=active and 2 or 3} end }
    ITV2 = { SOURCES={}, SPECIALTY_CRAFTS={10}, AUCTION_EXCLUDED_ITEMS={}, Text=function(key) return key end }
    dofile('addons/infotracker2/sources/common.lua')
    dofile('addons/infotracker2/sources/specialty.lua')
    dofile('addons/infotracker2/sources/assignment.lua')
    return ITV2.SOURCES.assignment
end
local item={slot=1}
local source=Setup(false)
local view=source.View(item,{})
assert((view.shortText or view.text)=='棋盘石林的保存特产', '已完成任務重新載入後仍顯示分類前綴')
assert(source.CanExpand(item,{}), '已完成任務重新載入後不能展開')
assert(source.Children(item,{})[1].text=='石材 x3', '材料清單不正確')
assert(view.status=='complete', '完成狀態改變')
print('PASS: 已完成特產重新載入後可移除前綴並展開材料')

for _, pair in ipairs({{'摩哈特比的新鲜特制特产', '[摩哈特比]新鲜特制特产'}, {'棋盘石林的保存特产', '[棋盘]保存特产'}}) do
    local name = pair[1]
    source = Setup(false, pair[2], '[特产-东部] ' .. name)
    assert(source.View(item, {}).shortText == name)
    assert(source.CanExpand(item, {}))
    assert(#source.Children(item, {}) == 1)
end

-- 進行中與已完成皆採名稱比對，不讀取日誌或目標物品 ID。
for _, active in ipairs({true, false}) do
    source = Setup(active)
    assert(source.CanExpand(item, {}))
    assert(source.View(item, {}).status == (active and 'inProgress' or 'complete'))
    source = Setup(active, '其他产品', '[特产-东部] 不同任务名称')
    assert(not source.CanExpand(item, {}))
end

-- 配方暫時不可用仍移除前綴，稍後資料可用時恢復展開。
source = Setup(false)
local products = X2Craft.GetCraftProductInfo
X2Craft.GetCraftProductInfo = function() return nil end
assert(source.View(item, {}).shortText == '棋盘石林的保存特产')
assert(not source.CanExpand(item, {}))
X2Craft.GetCraftProductInfo = products
assert(source.CanExpand(item, {}), '暫時讀不到配方後未重新查詢')

-- 同名配方有歧義時不猜測；非特產的分類前綴保持原樣。
source = Setup(false)
ITV2.SPECIALTY_CRAFTS = {10, 11}
assert(not source.CanExpand(item, {}), '同名配方不應任選一個')
source = Setup(false, '其他产品', '[活动] 普通任务')
view = source.View(item, {})
assert((view.shortText or view.text) == '[活动] 普通任务')
assert(not source.CanExpand(item, {}))

-- 相同語系的英文產品名稱仍可完全比對，不依賴中文前綴。
source = Setup(false, 'Preserved Specialty', '[Specialty-East] Preserved Specialty')
assert(source.View(item, {}).shortText == 'Preserved Specialty')
assert(source.CanExpand(item, {}))
print('PASS: 兩個截圖案例、所有狀態統一名稱比對、延遲資料、同名歧義、非特產與英文名稱')

-- 未在程式中登錄過的任務與地區，也使用相同的資料比對規則。
source = Setup(false, '[测试地区]新鲜传统特产', '[特产-东部] 测试地区高原的新鲜传统特产')
X2Achievement.GetTodayAssignmentInfo = function() return {questType=987654,status=3} end
assert(source.CanExpand(item, {}))
source = Setup(false, '[别的地区]保存特产')
assert(not source.CanExpand(item, {}), '不可配對其他地區')
source = Setup(false, '[棋盘]保存肥料特产')
assert(not source.CanExpand(item, {}), '不可配對其他特產種類')
print('PASS: 新任務無需登錄 ID，且不同地區或種類不會誤配')

-- 兩個不同地區名稱都符合簡稱規則時，也不能任選一個配方。
source = Setup(false)
ITV2.SPECIALTY_CRAFTS = {10, 11}
X2Craft.GetCraftProductInfo = function(self, craft)
    return {{itemType=craft, item_name=craft == 10 and '[棋盘]保存特产' or '[棋盘石林]保存特产'}}
end
assert(not source.CanExpand(item, {}), '地區簡稱有多個候選時應停止配對')
print('PASS: 多個地區簡稱候選不會誤配')


-- 配方與材料資料重用，但每次仍可按名稱查找。
source = Setup(false)
local productCalls, materialCalls = 0, 0
local readProducts, readMaterials = X2Craft.GetCraftProductInfo, X2Craft.GetCraftMaterialInfo
X2Craft.GetCraftProductInfo = function(...)
    productCalls = productCalls + 1
    return readProducts(...)
end
X2Craft.GetCraftMaterialInfo = function(...)
    materialCalls = materialCalls + 1
    return readMaterials(...)
end
for i = 1, 5 do
    assert(source.CanExpand(item, {}))
    assert(#source.Children(item, {}) == 1)
end
assert(productCalls == 1 and materialCalls == 1, '配方或材料 API 被重複查詢')
print('PASS: 配方名稱索引及材料快取避免重複 API 查詢')
