-- 任务组（每日 / 生活 / 周常 / 其他）
-- 完成数沿用 infotracker：池子里已完成的 ID 数，最多算到上限；不分阵营都能计入
ADDON:ImportAPI(API_TYPE.QUEST.id)

local T = ITV2.Text
local Util = ITV2.SourceUtil

local function IsCompleted(questId)
    return X2Quest:IsCompleted(questId) == true
end

local function IsActive(questId, ctx)
    return Util.GetJournalIndexMap(ctx)[questId] ~= nil
end

-- 名称不同但要当成同一行的任务（quest_data.lua 里项目的 merge 设定，名称必须完全相同）
-- 例：迷雾的「石材不足」「木材不足」…每天只会轮到其中一个，合并成「物资不足」
local mergeMapCache = {}

local function GetMergeTitle(item, title)
    local map = mergeMapCache[item.key]
    if map == nil then
        map = {}
        for _, rule in ipairs(item.merge or {}) do
            for _, ruleTitle in ipairs(rule.titles) do
                map[ruleTitle] = rule.label
            end
        end
        mergeMapCache[item.key] = map
    end
    local label = title and map[title]
    if label ~= nil then
        return T(label)
    end
    return title
end

-- 按任务名称合并（不同阵营同名任务只算一行），保持第一次出现的顺序
local function GetMergedQuests(item, ctx)
    local entries = {}
    local byName = {}
    for _, questId in ipairs(item.ids) do
        local title = GetMergeTitle(item, Util.GetQuestTitle(questId))
        local entry = title and byName[title] or nil
        if entry == nil then
            entry = {
                title = title or string.format(T("QUEST_FALLBACK"), questId),
                ids = {},
                status = "notStarted",
            }
            entries[#entries + 1] = entry
            if title then
                byName[title] = entry
            end
        end
        entry.ids[#entry.ids + 1] = questId
        if IsCompleted(questId) then
            entry.status = "complete"
        elseif IsActive(questId, ctx) and entry.status ~= "complete" then
            entry.status = "inProgress"
        end
    end
    return entries
end

ITV2.SOURCES.quest = {
    expandable = true,

    View = function(item, ctx)
        local max = item.max or #item.ids
        local done = 0
        local anyActive = false
        for _, questId in ipairs(item.ids) do
            if IsCompleted(questId) then
                done = done + 1
            elseif IsActive(questId, ctx) then
                anyActive = true
            end
        end
        done = math.min(done, max)
        local status = Util.ProgressStatus(done, max)
        if status == "notStarted" and anyActive then
            status = "inProgress"
        end
        return {
            text = string.format("%s (%d/%d)", T(item.key), done, max),
            status = status,
        }
    end,

    Children = function(item, ctx)
        local out = {}
        for _, entry in ipairs(GetMergedQuests(item, ctx)) do
            out[#out + 1] = { text = entry.title, status = entry.status }
        end
        return out
    end,

    -- 核对用：把「名称 → ID」输出到聊天框（* 已完成，~ 进行中）
    Dump = function(item, ctx)
        ITV2.Chat(string.format(T("DUMP_HEADER"), T(item.key), item.max or #item.ids))
        for _, entry in ipairs(GetMergedQuests(item, ctx)) do
            local idTexts = {}
            for _, questId in ipairs(entry.ids) do
                local mark = IsCompleted(questId) and "*" or (IsActive(questId, ctx) and "~" or "")
                idTexts[#idTexts + 1] = tostring(questId) .. mark
            end
            ITV2.Chat(string.format(T("DUMP_LINE"),
                ITV2.STATUS_PREFIX[entry.status], entry.title, table.concat(idTexts, ", ")))
        end
    end,
}
