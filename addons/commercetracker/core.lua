-- Commerce Tracker（经商追踪）共用基础
-- 所有档案共用全域表 CT，各模组挂在底下（载入顺序见 toc.g）：
--   CT.Text                     文字（locale.lua）
--   CT.CONTINENTS / CT.ZONES    区域资料（data/zones.lua）
--   CT.SPECIALTY_CRAFTS         特产配方编号 → 英文名称（data/specialties.lua）
--   CT.BASE_PRICES              基础售价（data/prices.lua）
--   CT.Trade                    路线比率、包的售价 / 材料 / 利润计算（trade.lua）
--   CT.Auction                  材料拍卖查价（auction.lua）
--   CT.Settings                 存档：开关按钮位置、收藏路线（settings.lua）
--   CT.UI                       共用 UI 元件（windows/widgets.lua）
--   CT.MainWindow / CT.Favorites / CT.ToggleButton   视窗（windows/）
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)

CT = {}

CT.ADDON_PATH = "Addon/commercetracker/"

function CT.Chat(message)
    X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(message))
end

function CT.GetUiScale()
    if UIParent ~= nil and UIParent.GetUIScale ~= nil then
        return UIParent:GetUIScale() or 1
    end
    return 1
end

function CT.IsInWorld()
    local name = X2Unit:UnitName("player")
    return name ~= nil and name ~= ""
end
