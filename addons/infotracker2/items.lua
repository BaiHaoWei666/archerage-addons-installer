-- 追蹤項目索引，以及對來源的安全呼叫（來源讀不到資料或出錯時，不讓視窗停止重新整理）
-- 來源介面見 sources/common.lua
local T = ITV2.Text

local Items = {}
ITV2.Items = Items

Items.byKey = {}      -- { [itemKey] = item }
Items.catByKey = {}   -- { [itemKey] = category }
for _, cat in ipairs(ITV2.CATEGORIES) do
    for _, item in ipairs(cat.items) do
        Items.byKey[item.key] = item
        Items.catByKey[item.key] = cat
    end
end

local function SourceOf(key)
    return ITV2.SOURCES[Items.catByKey[key].kind]
end

-- 每次重新整理新建一個，給來源快取本次重新整理的資料
function Items.NewContext()
    return {}
end

function Items.View(key, ctx)
    local ok, view = pcall(SourceOf(key).View, Items.byKey[key], ctx)
    if ok and type(view) == "table" then
        return view
    end
    return { text = T(key) .. " ?", status = "neutral" }
end

-- 來源能展開，且（有 CanExpand 時）這一項也能展開
function Items.CanExpand(key, ctx)
    local source = SourceOf(key)
    if not source.expandable then
        return false
    end
    if source.CanExpand == nil then
        return true
    end
    local ok, result = pcall(source.CanExpand, Items.byKey[key], ctx)
    return ok and result == true
end

function Items.Children(key, ctx)
    local source = SourceOf(key)
    if not source.expandable then
        return {}
    end
    local ok, children = pcall(source.Children, Items.byKey[key], ctx)
    if ok and type(children) == "table" then
        return children
    end
    return {}
end

function Items.CanActivate(key)
    return SourceOf(key).Activate ~= nil
end

function Items.Activate(key, options)
    SourceOf(key).Activate(Items.byKey[key], options)
end

-- 詢問窗顯示的名稱
function Items.GetName(key)
    local source = SourceOf(key)
    if source.GetName ~= nil then
        local ok, name = pcall(source.GetName, Items.byKey[key])
        if ok and name ~= nil then
            return name
        end
    end
    return T(key)
end

-- 核對用：依序輸出項目的「名稱 → ID」（只有任務來源有 Dump）
function Items.Dump(keys)
    local ctx = Items.NewContext()
    for _, key in ipairs(keys) do
        local source = SourceOf(key)
        if source.Dump ~= nil then
            source.Dump(Items.byKey[key], ctx)
        end
    end
end
