-- InfoTracker v2 共用基础
-- 所有档案共用全域表 ITV2，各模组挂在底下（载入顺序见 toc.g）：
--   ITV2.Text               文字（locale.lua）
--   ITV2.CATEGORIES         分类与项目清单（quest_data.lua）
--   ITV2.SPECIALTY_CRAFTS   特产配方、拍卖排除清单（specialty_data.lua）
--   ITV2.SOURCES            各类项目的资料来源（sources/）
--   ITV2.Items              项目索引，安全呼叫来源（items.lua）
--   ITV2.Settings           设定与存档（settings.lua）
--   ITV2.UI                 共用 UI 元件（windows/widgets.lua）
--   ITV2.Editor / ITV2.SquadConfirm / ITV2.Popout   视窗（windows/）
ADDON:ImportAPI(API_TYPE.CHAT.id)

ITV2 = {}

-- 项目状态：notStarted | inProgress | complete | neutral
-- 细项前面的状态符号（悬浮窗主项只用颜色表示）
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

-- 资料或设定改变后，两个视窗一起刷新（Editor / Popout 由 windows/ 载入时挂上）
function ITV2.RefreshAll()
    ITV2.Editor.Refresh()
    ITV2.Popout.Refresh()
end
