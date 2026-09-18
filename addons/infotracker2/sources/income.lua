-- 今日淨收入（依角色存在插件存檔，每天自動歸零）
ADDON:ImportAPI(API_TYPE.UNIT.id)

local T = ITV2.Text

local income = nil     -- { date, gold, vocation, honor, exp }
local incomeKey = nil

local function TodayString()
    local t = UIParent:GetServerTimeTable()
    return string.format("%d-%d-%d", t.year or 0, t.month or 0, t.day or 0)
end

local function EmptyIncome(date)
    return { date = date, gold = 0, vocation = 0, honor = 0, exp = 0 }
end

local function SaveIncome()
    if incomeKey == nil or income == nil then
        return
    end
    ADDON:ClearData(incomeKey)
    ADDON:SaveData(incomeKey, income)
end

-- 角色名要進入世界後才拿得到，所以第一次用到時才載入
local function EnsureIncome(deferRolloverSave)
    if incomeKey == nil then
        local name = X2Unit:UnitName("player")
        if name == nil or name == "" then
            return false
        end
        incomeKey = "itv2_income_" .. name
        local saved = ADDON:LoadData(incomeKey)
        income = EmptyIncome(nil)
        if type(saved) == "table" then
            income.date = saved.date
            for _, field in ipairs({ "gold", "vocation", "honor", "exp" }) do
                income[field] = tonumber(saved[field]) or 0
            end
        end
    end
    local today = TodayString()
    if income.date ~= today then
        income = EmptyIncome(today)
        if not deferRolloverSave then SaveIncome() end
    end
    return true
end

local function AddIncome(field, amount)
    amount = tonumber(amount)
    if amount == nil or amount == 0 or not EnsureIncome(true) then
        return
    end
    income[field] = income[field] + amount
    SaveIncome()
end

UIParent:SetEventHandler(UIEVENT_TYPE.PLAYER_MONEY, function(amount)
    AddIncome("gold", amount)
end)
UIParent:SetEventHandler(UIEVENT_TYPE.PLAYER_BANK_MONEY, function(amount)
    AddIncome("gold", amount)
end)
UIParent:SetEventHandler(UIEVENT_TYPE.PLAYER_LIVING_POINT, function(amount)
    AddIncome("vocation", amount)
end)
UIParent:SetEventHandler(UIEVENT_TYPE.PLAYER_HONOR_POINT, function(amount)
    AddIncome("honor", amount)
end)
UIParent:SetEventHandler(UIEVENT_TYPE.EXP_CHANGED, function(_, amount)
    AddIncome("exp", amount)
end)

-- 金額單位是銅（10000 = 1 金），顯示方式沿用 infotracker
local function FormatGold(copper)
    if copper > -10000 and copper < 10000 then
        return T("LESS_THAN_1G")
    end
    return string.format("%.2f", copper / 10000) .. T("GOLD_UNIT")
end

ITV2.SOURCES.income = {
    View = function(item)
        if not EnsureIncome() then
            return { text = T(item.key) .. " -", status = "neutral" }
        end
        local value = income[item.field]
        local valueText = item.field == "gold" and FormatGold(value) or tostring(value)
        return { text = T(item.key) .. " " .. valueText, status = "neutral" }
    end,

    Reset = function()
        if not EnsureIncome(true) then
            return
        end
        income = EmptyIncome(TodayString())
        SaveIncome()
        ITV2.Chat(T("INCOME_RESET_DONE"))
    end,
}
