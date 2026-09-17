-- 每日挑战（活动中心；X2Achievement 的 TADT_TODAY）
-- 实测回传：
--   GetTodayAssignmentStatus()          -> 已完成数, 总数        （画面「任务完成 1/7」）
--   GetTodayAssignmentResetCount(type)  -> 已更换次数, 上限      （画面「更换任务次数 0/3」）
--   GetTodayAssignmentInfo(type, i)     -> { status, questType, title, desc, ... }
--     status：1 未开启、2 进行中、3 已完成
--     title 是这一格的分类名称，画面上的名称要用 questType 查任务名
-- 任务日志的目标（GetQuestJournalObjectiveText）只有 status、done（已完成数）、summary，没有目标数
-- 特产挑战可以展开制作材料，见 sources/specialty.lua
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)

local T = ITV2.Text
local Util = ITV2.SourceUtil
local Specialty = ITV2.Specialty

local ASSIGNMENT_STATUS = {
    [1] = "notStarted",
    [2] = "inProgress",
    [3] = "complete",
}

local function GetInfo(item)
    local info = X2Achievement:GetTodayAssignmentInfo(TADT_TODAY, item.slot)
    if type(info) ~= "table" then
        return nil
    end
    return info
end

local function GetSpecialtyCraft(item, ctx)
    local info = GetInfo(item)
    if info == nil or info.questType == nil then
        return nil
    end
    return Specialty.GetCraft(info.questType, ctx)
end

ITV2.SOURCES.assignment = {
    expandable = true,

    -- 只有特产挑战能展开
    CanExpand = function(item, ctx)
        return GetSpecialtyCraft(item, ctx) ~= nil
    end,

    -- 特产挑战：制作材料「材料名 x数量」，双击到拍卖场查询（非卖品除外）
    Children = function(item, ctx)
        local out = {}
        local craftType = GetSpecialtyCraft(item, ctx)
        if craftType == nil then
            return out
        end
        for _, material in ipairs(Specialty.GetMaterials(craftType)) do
            local action = nil
            if Specialty.CanSearchAuction(material) then
                local name = material.name
                action = function()
                    Specialty.SearchAuction(name)
                end
            end
            out[#out + 1] = {
                text = string.format("%s x%s", material.name, tostring(material.amount or "?")),
                status = "neutral",
                action = action,
            }
        end
        return out
    end,

    View = function(item, ctx)
        local info = GetInfo(item)
        local fallback = string.format(T("CHALLENGE_SLOT"), item.slot)
        if info == nil then
            return { text = fallback, status = "neutral" }
        end
        local text = (info.questType and Util.GetQuestTitle(info.questType)) or info.title or fallback
        -- 悬浮窗空间小：特产挑战去掉开头的分类标志「[特产-东部] 」
        local shortText = nil
        if GetSpecialtyCraft(item, ctx) ~= nil then
            shortText = string.gsub(text, "^%[[^%]]*%]%s*", "")
        end
        return {
            text = text,
            shortText = shortText,
            status = ASSIGNMENT_STATUS[info.status] or "neutral",
        }
    end,

    Tick = function(dt)
        Specialty.Tick(dt)
    end,
}
