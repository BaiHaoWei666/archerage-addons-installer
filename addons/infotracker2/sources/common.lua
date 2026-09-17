-- 资料来源共用
-- 每个来源 ITV2.SOURCES[kind]（kind 见 quest_data.lua）提供：
--   View(item, ctx)         -> { text, shortText, status }
--                              shortText：悬浮窗用的短文字（可省略）
--                              status：notStarted | inProgress | complete | neutral
--   expandable              -> 是否能展开
--   CanExpand(item, ctx)    -> 个别项目能否展开（省略 = 全部都能展开）
--   Children(item, ctx)     -> { { text, status, action }, ... }（action：双击细项时执行，可省略）
--   Activate(item, options) -> 悬浮窗双击并确认后执行（副本；options.inviteParty）
--   GetName(item)           -> 询问窗显示的名称（有 Activate 的来源才需要）
--   Tick(dt)                -> 每帧呼叫，dt 单位毫秒
-- ctx：每次刷新新建的空表，来源可以在里面快取本次刷新会重复用到的资料
ADDON:ImportAPI(API_TYPE.QUEST.id)

ITV2.SOURCES = {}

local Util = {}
ITV2.SourceUtil = Util

function Util.ProgressStatus(done, max)
    if max > 0 and done >= max then
        return "complete"
    elseif done > 0 then
        return "inProgress"
    end
    return "notStarted"
end

local titleCache = {}

-- 任务名称（游戏语系）；读不到回传 nil
function Util.GetQuestTitle(questId)
    local title = titleCache[questId]
    if title ~= nil then
        return title
    end
    title = X2Quest:GetQuestContextMainTitle(questId)
    if title == nil or title == "" then
        return nil
    end
    titleCache[questId] = title
    return title
end

-- 任务日志：{ [questId] = 日志索引 }，同一次刷新只扫一次
function Util.GetJournalIndexMap(ctx)
    if ctx.journalIndex ~= nil then
        return ctx.journalIndex
    end
    local map = {}
    local count = X2Quest:GetActiveQuestListCount() or 0
    for index = 1, count do
        local questId = X2Quest:GetActiveQuestType(index)
        if questId ~= nil then
            map[questId] = index
        end
    end
    ctx.journalIndex = map
    return map
end
