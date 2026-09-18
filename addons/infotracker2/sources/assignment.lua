-- 每日挑戰（活動中心；X2Achievement 的 TADT_TODAY）
-- 實測回傳：
--   GetTodayAssignmentStatus()          -> 已完成數, 總數        （畫面「任務完成 1/7」）
--   GetTodayAssignmentResetCount(type)  -> 已更換次數, 上限      （畫面「更換任務次數 0/3」）
--   GetTodayAssignmentInfo(type, i)     -> { status, questType, title, desc, ... }
--     status：1 未開啟、2 進行中、3 已完成
--     title 是這一格的分類名稱，畫面上的名稱要用 questType 查任務名
-- 任務日誌的目標（GetQuestJournalObjectiveText）只有 status、done（已完成數）、summary，沒有目標數
-- 特產挑戰可以展開製作材料，見 sources/specialty.lua
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)

local T = ITV2.Text
local Util = ITV2.SourceUtil
local Specialty = ITV2.Specialty

local ASSIGNMENT_STATUS = {
    [1] = "notStarted",
    [2] = "inProgress",
    [3] = "complete",
}

local function GetInfo(item, ctx)
    ctx.assignmentInfo = ctx.assignmentInfo or {}
    local cached = ctx.assignmentInfo[item.slot]
    if cached ~= nil then return cached or nil end
    local info = X2Achievement:GetTodayAssignmentInfo(TADT_TODAY, item.slot)
    ctx.assignmentInfo[item.slot] = type(info) == "table" and info or false
    return ctx.assignmentInfo[item.slot] or nil
end

local function GetSpecialtyCraft(item, ctx)
    ctx.assignmentCraft = ctx.assignmentCraft or {}
    local cached = ctx.assignmentCraft[item.slot]
    if cached ~= nil then return cached or nil end
    local info = GetInfo(item, ctx)
    if info == nil or info.questType == nil then
        ctx.assignmentCraft[item.slot] = false
        return nil
    end
    local craft = Specialty.GetCraft(info.questType, ctx)
    ctx.assignmentCraft[item.slot] = craft or false
    return craft
end

ITV2.SOURCES.assignment = {
    expandable = true,

    -- 只有特產挑戰能展開
    CanExpand = function(item, ctx)
        return GetSpecialtyCraft(item, ctx) ~= nil
    end,

    -- 特產挑戰：製作材料「材料名 x數量」，雙擊到拍賣場查詢（非賣品除外）
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
        local info = GetInfo(item, ctx)
        local fallback = string.format(T("CHALLENGE_SLOT"), item.slot)
        if info == nil then
            return { text = fallback, status = "neutral" }
        end
        local text = (info.questType and Util.GetQuestTitle(info.questType)) or info.title or fallback
        -- 懸浮窗空間小：特產挑戰移除開頭分類前綴
        local shortText = nil
        if string.find(text, "^%[特产%-") ~= nil or GetSpecialtyCraft(item, ctx) ~= nil then
            shortText = string.gsub(text, "^%[[^%]]*%]%s*", "")
        end
        return {
            text = text,
            shortText = shortText,
            status = ASSIGNMENT_STATUS[info.status] or "neutral",
        }
    end,

}
