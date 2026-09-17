-- 中英文文字：CT.Text(key)，找不到时回传 key 本身
ADDON:ImportAPI(API_TYPE.LOCALE.id)

local isCN = (X2Locale:GetLocale() or "en_us") == "zh_cn"

local texts = {}
if isCN then
    texts.TITLE = "经商追踪"
    texts.LOADED = "[经商追踪] 已载入"
    texts.REQUEST_FAILED = "[经商追踪] 路线比率查询没有送出"
    texts.RESULT_MISSING = "[经商追踪] 没有收到路线比率资料"

    -- 主视窗
    texts.CONTINENT_LABEL = "大陆:"
    texts.FROM_LABEL = "起始区域:"
    texts.TO_LABEL = "交货区域:"
    texts.CONTINENT_NUIA = "诺伊大陆"
    texts.CONTINENT_HARANYA = "哈里拉大陆"
    texts.CONTINENT_AURORIA = "原大陆"
    texts.ZONE_FALLBACK = "区域 %d"
    texts.QUERY_PRICES = "查价"
    texts.STOP_QUERY = "停止查价"
    texts.LOADING_PRICES = "正在加载价格"
    texts.COMMERCE_INFO = "经商熟练度: %d      加成: +%.2f%%"
    texts.MATERIAL_LINE = "%s x%d"

    -- 收藏
    texts.FAVORITES = "收藏"
    texts.FAVORITES_TITLE = "收藏路线"
    texts.FAVORITE_ADD = "+ 加入目前路线"
    texts.FAVORITE_EMPTY = "还没有收藏。选好路线后按「+ 加入目前路线」。"
    texts.FAVORITE_ROUTE = "%s  >  %s"
    texts.FAVORITE_NEED_ROUTE = "[经商追踪] 请先选择起始区域与交货区域"
    texts.FAVORITE_DUPLICATE = "[经商追踪] 这条路线已经收藏过了"
else
    texts.TITLE = "Commerce Tracker"
    texts.LOADED = "[Commerce Tracker] Loaded"
    texts.REQUEST_FAILED = "[Commerce Tracker] Route ratio request was not sent"
    texts.RESULT_MISSING = "[Commerce Tracker] Route ratio data is missing"

    -- Main window
    texts.CONTINENT_LABEL = "Continent:"
    texts.FROM_LABEL = "From Zone:"
    texts.TO_LABEL = "To Zone:"
    texts.CONTINENT_NUIA = "Nuia"
    texts.CONTINENT_HARANYA = "Haranya"
    texts.CONTINENT_AURORIA = "Auroria"
    texts.ZONE_FALLBACK = "Zone %d"
    texts.QUERY_PRICES = "Get Prices"
    texts.STOP_QUERY = "Stop"
    texts.LOADING_PRICES = "Prices Are Loading"
    texts.COMMERCE_INFO = "Commerce: %d      Bonus: +%.2f%%"
    texts.MATERIAL_LINE = "%s x%d"

    -- Favorites
    texts.FAVORITES = "Favorites"
    texts.FAVORITES_TITLE = "Favorites"
    texts.FAVORITE_ADD = "+ Add Current Route"
    texts.FAVORITE_EMPTY = "No favorites yet. Pick a route, then '+ Add Current Route'."
    texts.FAVORITE_ROUTE = "%s  >  %s"
    texts.FAVORITE_NEED_ROUTE = "[Commerce Tracker] Pick a From and To zone first"
    texts.FAVORITE_DUPLICATE = "[Commerce Tracker] That route is already a favorite"
end

function CT.Text(key)
    return texts[key] or key
end
