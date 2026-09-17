-- 存档（key：commercetracker_settings，依角色）
--   toggleX / toggleY   开关按钮位置（CorrectOffsetByScreen 座标）
--   favorites           收藏路线 { { continent, from, to }, ... }
local T = CT.Text

local SAVE_KEY = "commercetracker_settings"

local S = {}
CT.Settings = S

S.toggleX = nil
S.toggleY = nil
S.favorites = {}

function S.Save()
    ADDON:ClearData(SAVE_KEY)
    ADDON:SaveData(SAVE_KEY, {
        toggleX = S.toggleX,
        toggleY = S.toggleY,
        favorites = S.favorites,
    })
end

function S.Load()
    local saved = ADDON:LoadData(SAVE_KEY)
    if type(saved) ~= "table" then
        return
    end
    S.toggleX = tonumber(saved.toggleX)
    S.toggleY = tonumber(saved.toggleY)
    S.favorites = {}
    for _, fav in ipairs(type(saved.favorites) == "table" and saved.favorites or {}) do
        local from, to = tonumber(fav.from), tonumber(fav.to)
        if CT.Trade.ContinentOf(fav.continent) ~= nil and from ~= nil and to ~= nil then
            S.favorites[#S.favorites + 1] = { continent = fav.continent, from = from, to = to }
        end
    end
end

function S.SetTogglePosition(x, y)
    S.toggleX, S.toggleY = x, y
    S.Save()
end

-- 回传是否有加入（不完整或重复时在聊天框提示）
function S.AddFavorite(route)
    if route.continent == nil or route.from == nil or route.to == nil then
        CT.Chat(T("FAVORITE_NEED_ROUTE"))
        return false
    end
    for _, fav in ipairs(S.favorites) do
        if fav.continent == route.continent and fav.from == route.from and fav.to == route.to then
            CT.Chat(T("FAVORITE_DUPLICATE"))
            return false
        end
    end
    S.favorites[#S.favorites + 1] = { continent = route.continent, from = route.from, to = route.to }
    S.Save()
    return true
end

function S.RemoveFavorite(index)
    if S.favorites[index] == nil then
        return
    end
    table.remove(S.favorites, index)
    S.Save()
end
