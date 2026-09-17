-- 暫時開發探針：複製至實機 infotracker2，並在 toc.g 的 main.lua 後載入。
-- 使用當前遊戲語系的名稱片段；空表會列出全部已接任務。
local filters = { "浮空岛", "转移现象", "麦默图斯", "哈拉林特" }

local function Matches(title)
    if #filters == 0 then return true end
    for _, filter in ipairs(filters) do
        if string.find(title, filter, 1, true) then return true end
    end
    return false
end

local function DumpJournal()
    local count = X2Quest:GetActiveQuestListCount() or 0
    local found = 0
    local seen = {}
    for index = 1, count do
        local id = X2Quest:GetActiveQuestType(index)
        local title = id and X2Quest:GetQuestContextMainTitle(id)
        if title and Matches(title) and not seen[id] then
            seen[id] = true
            found = found + 1
            ITV2.Chat(string.format("[Quest ID] %s = %s", title, tostring(id)))
        end
    end
    ITV2.Chat(string.format("[Quest ID] 匹配 %d / 已接 %d", found, count))
end

local window = ITV2.UI.CreateDialog("itv2QuestProbe", 220, 48, -230)
local button = ITV2.UI.CreateTextButton(window, "itv2QuestProbeDump", "查询任务ID", 190, 28)
button:AddAnchor("CENTER", window, 0, 0)
ITV2.UI.OnLeftClick(button, DumpJournal)
window:Show(true)
