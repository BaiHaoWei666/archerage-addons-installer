-- 追踪项目索引，以及对来源的安全呼叫（来源读不到资料或出错时，不让视窗停止刷新）
-- 来源介面见 sources/common.lua
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

-- 每次刷新新建一个，给来源快取本次刷新的资料
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

-- 来源能展开，且（有 CanExpand 时）这一项也能展开
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

-- 询问窗显示的名称
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

function Items.TickSources(dt)
    for _, source in pairs(ITV2.SOURCES) do
        if source.Tick ~= nil then
            source.Tick(dt)
        end
    end
end

-- 核对用：依序输出项目的「名称 → ID」（只有任务来源有 Dump）
function Items.Dump(keys)
    local ctx = Items.NewContext()
    for _, key in ipairs(keys) do
        local source = SourceOf(key)
        if source.Dump ~= nil then
            source.Dump(Items.byKey[key], ctx)
        end
    end
end
