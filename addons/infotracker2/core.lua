-- InfoTracker v2 共用基礎
-- 所有檔案共用全域表 ITV2，各模組掛在底下（載入順序見 toc.g）：
--   ITV2.Text               文字（locale.lua）
--   ITV2.CATEGORIES         分類與項目清單（quest_data.lua）
--   ITV2.SPECIALTY_CRAFTS   特產配方、拍賣排除清單（specialty_data.lua）
--   ITV2.SOURCES            各類項目的資料來源（sources/）
--   ITV2.Items              項目索引，安全呼叫來源（items.lua）
--   ITV2.Settings           設定與存檔（settings.lua）
--   ITV2.UI                 共用 UI 元件（windows/widgets.lua）
--   ITV2.Editor / ITV2.SquadConfirm / ITV2.Popout   視窗（windows/）
ADDON:ImportAPI(API_TYPE.CHAT.id)

ITV2 = {}

-- 項目狀態：notStarted | inProgress | complete | neutral
-- 任務 ID 查詢輸出使用的狀態符號；介面清單以顏色表示狀態。
ITV2.STATUS_PREFIX = {
    notStarted = "[ ] ",
    inProgress = "[~] ",
    complete = "[x] ",
}

function ITV2.Chat(message)
    X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(message))
end

function ITV2.GetUiScale()
    if UIParent ~= nil and UIParent.GetUIScale ~= nil then
        return UIParent:GetUIScale()
    end
    return 1
end

-- 資料或設定改變後，兩個視窗一起刷新（Editor / Popout 由 windows/ 載入時掛上）
function ITV2.RefreshAll()
    ITV2.Editor.Refresh()
    ITV2.Popout.Refresh()
end

-- 使用遊戲 OnUpdate 的毫秒差值，不依賴未確認的外部時間 API。
local clockMs = 0
local jobs = {}
function ITV2.NowMs()
    return clockMs
end
function ITV2.Schedule(key, delay, callback)
    jobs[key] = { due = clockMs + delay, callback = callback }
end
function ITV2.AdvanceTime(dt)
    clockMs = clockMs + math.max(0, tonumber(dt) or 0)
    if next(jobs) == nil then return end
    local ready = nil
    for key, job in pairs(jobs) do
        if job.due <= clockMs then
            jobs[key] = nil
            ready = ready or {}
            ready[#ready + 1] = job.callback
        end
    end
    if ready then
        for _, callback in ipairs(ready) do callback() end
    end
end
