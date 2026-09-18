-- 資料來源共用
-- 每個來源 ITV2.SOURCES[kind]（kind 見 quest_data.lua）提供：
--   View(item, ctx)         -> { text, shortText, status }
--                              shortText：懸浮窗用的短文字（可省略）
--                              status：notStarted | inProgress | complete | neutral
--   expandable              -> 是否能展開
--   CanExpand(item, ctx)    -> 個別項目能否展開（省略 = 全部都能展開）
--   Children(item, ctx)     -> { { text, status, action }, ... }（action：雙擊細項時執行，可省略）
--   Activate(item, options) -> 懸浮窗雙擊並確認後執行（副本；options.inviteParty）
--   GetName(item)           -> 詢問窗顯示的名稱（有 Activate 的來源才需要）
-- ctx：每次重新整理新建的空表，來源可以在裡面快取本次重新整理會重複用到的資料
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

-- 任務名稱（遊戲語系）；讀不到回傳 nil
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

-- 任務日誌：{ [questId] = 日誌索引 }，同一次重新整理只掃一次
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
