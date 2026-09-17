-- 角色資訊（判定沿用 infotracker/documents/functions.lua）
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.EQUIPMENT.id)
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)

local T = ITV2.Text

local BLESSING_BUFFS = {}
for _, buffId in ipairs({ 30760, 30764, 30765, 30766, 30767, 30768, 30770, 30771, 30772, 30773,
    9002337, 9002338, 9002339, 9002340, 9002341, 9002342, 902341 }) do
    BLESSING_BUFFS[buffId] = true
end

local function HasBlessing()
    local count = X2Unit:UnitBuffCount("player") or 0
    for index = 1, count do
        local buff = X2Unit:UnitBuff("player", index)
        if buff ~= nil and BLESSING_BUFFS[buff["buff_id"]] then
            return true
        end
    end
    return false
end

-- 裝備的剩餘時間全為 0 才算過期；沒穿或沒有期限都當作正常
local function IsSlotValid(slot)
    local info = X2Equipment:GetEquippedItemTooltipInfo(slot, false)
    local t = info and info.evolvingInfo and info.evolvingInfo.remainTime
    if t == nil then
        return true
    end
    local expired = t.year == 0 and t.month == 0 and t.day == 0
        and t.hour == 0 and t.minute == 0 and t.second == 0
    return not expired
end

-- 今日任務（每日 / 公會）：有任務但一個都沒解鎖也沒完成 = 未解鎖
-- status：1 未開啟、2 進行中、3 已完成（見 sources/assignment.lua）
local function IsAssignmentUnlocked(kind)
    local total, started = 0, 0
    for index = 1, 7 do
        local info = X2Achievement:GetTodayAssignmentInfo(kind, index)
        if info ~= nil then
            if info.status == 1 then
                total = total + 1
            elseif info.status == 2 or info.status == 3 then
                total = total + 1
                started = started + 1
            end
        end
    end
    return total == 0 or started > 0
end

-- 每項：ok / bad = 正常 / 異常時顯示的文字 key，check = 判定函數
local INFO_CHECKS = {
    INFO_BLESSING = { ok = "STATE_HAS", bad = "STATE_MISSING", check = HasBlessing },
    INFO_COSTUME = { ok = "STATE_VALID", bad = "STATE_EXPIRED", check = function() return IsSlotValid(ES_COSPLAY) end },
    INFO_UNDERWEAR = { ok = "STATE_VALID", bad = "STATE_EXPIRED", check = function() return IsSlotValid(ES_UNDERPANTS) end },
    INFO_DARU = { ok = "STATE_VALID", bad = "STATE_EXPIRED", check = function() return IsSlotValid(ES_RACE_COSPLAY) end },
    INFO_DAILY = { ok = "STATE_UNLOCKED", bad = "STATE_LOCKED", check = function() return IsAssignmentUnlocked(TADT_TODAY) end },
    INFO_GUILD = { ok = "STATE_UNLOCKED", bad = "STATE_LOCKED", check = function() return IsAssignmentUnlocked(TADT_EXPEDITION) end },
}

ITV2.SOURCES.info = {
    View = function(item)
        local def = INFO_CHECKS[item.key]
        local good = def.check()
        return {
            text = string.format("%s: %s", T(item.key), T(good and def.ok or def.bad)),
            status = good and "complete" or "notStarted",
        }
    end,
}
