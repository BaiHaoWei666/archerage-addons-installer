-- 副本（建隊邏輯沿用 infotracker/documents/controller.lua 的 CreateTeamForInstance）
ADDON:ImportAPI(API_TYPE.BATTLE_FIELD.id)
ADDON:ImportAPI(API_TYPE.SQUAD.id)

local T = ITV2.Text
local Chat = ITV2.Chat
local Util = ITV2.SourceUtil

local DUNGEON_KIND_ID = 4
local SQUAD_COOLDOWN_MS = 5000
local CANNOT_SOLO = { [24] = true, [43] = true, [52] = true, [53] = true, [66] = true, [80] = true }

local squadCooldownMs = 0

local function GetDungeonList(ctx)
    if ctx ~= nil and ctx.dungeonList ~= nil then
        return ctx.dungeonList
    end
    local list = X2BattleField:GetInstanceListByKind(DUNGEON_KIND_ID) or {}
    if ctx ~= nil then
        ctx.dungeonList = list
    end
    return list
end

local function CreateSquad(instance, inviteParty)
    local name = X2BattleField:GetInstanceName(instance.type) or "?"

    if squadCooldownMs > 0 then
        Chat(string.format(T("COOLDOWN_WAIT"), math.ceil(squadCooldownMs / 1000)))
        return
    end

    local info = X2BattleField:GetDetailInstanceInfo(instance.type)
    if info == nil then
        Chat(string.format(T("CANNOT_GET_INFO"), name))
        return
    end
    if info.enterCount ~= nil and info.maxEnterCount ~= nil and info.enterCount >= info.maxEnterCount then
        Chat(string.format(T("NO_REMAIN_COUNT"), name))
        return
    end

    inviteParty = inviteParty == true
    if inviteParty then
        Chat(T("SQUAD_INVITE_LOG"))
    end

    local minGS = info.gearScore or 0
    local minLV = info.levelMin or 55

    -- 能單人就先快速匹配，失敗再建非公開戰隊
    if info.singleApplyAvailable == true and not CANNOT_SOLO[instance.type] then
        Chat(string.format(T("QUICK_ENTER"), name))
        if X2Squad:CreateSquad(instance.type, SOT_DIRECT_MATCHING, "", inviteParty, minLV, minGS) then
            squadCooldownMs = SQUAD_COOLDOWN_MS
            Chat(string.format(T("CREATE_SUCCESS_QUICK"), name, tostring(instance.type)))
            return
        end
        Chat(string.format(T("CREATE_FAILED_QUICK"), name, tostring(instance.type)))
    else
        Chat(string.format(T("CREATING_TEAM"), name))
    end

    if X2Squad:CreateSquad(instance.type, SOT_PRIVATE, "", inviteParty, minLV, minGS) then
        squadCooldownMs = SQUAD_COOLDOWN_MS
        Chat(string.format(T("CREATE_SUCCESS_PRIVATE"), name))
    else
        Chat(string.format(T("CREATE_FAILED_PRIVATE"), name))
    end
end

ITV2.SOURCES.dungeon = {
    View = function(item, ctx)
        local instance = GetDungeonList(ctx)[item.index]
        if instance == nil then
            return { text = string.format(T("DUNGEON_FALLBACK"), item.index), status = "neutral" }
        end
        local name = X2BattleField:GetInstanceName(instance.type) or "?"
        local info = X2BattleField:GetDetailInstanceInfo(instance.type)
        if info == nil or info.maxEnterCount == nil then
            return { text = name, status = "neutral" }
        end
        local entered = info.enterCount or 0
        return {
            text = string.format("%s [%d/%d]", name, entered, info.maxEnterCount),
            status = Util.ProgressStatus(entered, info.maxEnterCount),
        }
    end,

    -- 詢問窗顯示用的副本名稱
    GetName = function(item)
        local instance = GetDungeonList(nil)[item.index]
        local name = instance and X2BattleField:GetInstanceName(instance.type)
        return name or string.format(T("DUNGEON_FALLBACK"), item.index)
    end,

    -- options.inviteParty：建立戰隊時邀請隊伍成員
    Activate = function(item, options)
        local instance = GetDungeonList(nil)[item.index]
        if instance == nil or instance.type == nil then
            Chat(T("INVALID_INSTANCE"))
            return
        end
        CreateSquad(instance, options ~= nil and options.inviteParty)
    end,

    Tick = function(dt)
        if squadCooldownMs > 0 then
            squadCooldownMs = math.max(0, squadCooldownMs - dt)
        end
    end,
}
