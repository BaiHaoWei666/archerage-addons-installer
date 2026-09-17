-- 区域资料（区域编号 = X2Store 的 zoneGroup）
-- 显示名称优先用 X2Store:GetProductionZoneGroups() 的游戏语系名称，读不到才用这里的英文名称

-- 大陆：下拉选单顺序、可选的起始区域与交货区域
CT.CONTINENTS = {
    {
        key = "Nuia",
        label = "CONTINENT_NUIA",
        from = { 1, 2, 3, 5, 6, 8, 10, 18, 19, 20, 21, 22, 26, 27, 93 },
        to = { 5, 8, 20 },
    },
    {
        key = "Haranya",
        label = "CONTINENT_HARANYA",
        from = { 4, 7, 9, 11, 12, 13, 14, 15, 16, 17, 23, 24, 25, 99 },
        to = { 4, 12, 17 },
    },
    {
        key = "Auroria",
        label = "CONTINENT_AURORIA",
        from = { 54, 56, 57, 102, 103 },
        to = { 33 },
    },
}

-- 每个区域：
--   name  英文显示名称（备用）
--   base  英文包名开头（「<base> <tier> Specialty」）
--   tier  包的等级：Luxury / Fine / Commercial / Preserved / Coastal
CT.ZONES = {
    [1] = { name = "Gweonid Forest", base = "Gweonid", tier = "Commercial" },
    [2] = { name = "Marianople", base = "Marianople", tier = "Fine" },
    [3] = { name = "Dewstone Plains", base = "Dewstone", tier = "Fine" },
    [4] = { name = "Solis Headlands", base = "Solis", tier = "Luxury" },
    [5] = { name = "Solzreed Peninsula", base = "Solzreed", tier = "Luxury" },
    [6] = { name = "Lilyut Hills", base = "Lilyut", tier = "Fine" },
    [7] = { name = "Arcum Iris", base = "Arcum Iris", tier = "Commercial" },
    [8] = { name = "Two Crowns", base = "Two Crowns", tier = "Luxury" },
    [9] = { name = "Mahadevi", base = "Mahadevi", tier = "Fine" },
    [10] = { name = "Airain Rock", base = "Airain", tier = "Commercial" },
    [11] = { name = "Falcorth Plains", base = "Falcorth", tier = "Fine" },
    [12] = { name = "Villanelle", base = "Villanelle", tier = "Luxury" },
    [13] = { name = "Sunbite Wilds", base = "Sunbite", tier = "Commercial" },
    [14] = { name = "Windscour Savanna", base = "Windscour", tier = "Preserved" },
    [15] = { name = "Perinoor Ruins", base = "Perinoor", tier = "Preserved" },
    [16] = { name = "Rookborne Basin", base = "Rookborne", tier = "Preserved" },
    [17] = { name = "Ynystere", base = "Ynystere", tier = "Commercial" },
    [18] = { name = "White Arden", base = "White Arden", tier = "Commercial" },
    [19] = { name = "Karkasse Ridgelands", base = "Karkasse", tier = "Commercial" },
    [20] = { name = "Cinderstone Moor", base = "Cinderstone", tier = "Luxury" },
    [21] = { name = "Aubre Cradle", base = "Aubre", tier = "Commercial" },
    [22] = { name = "Halcyona", base = "Halcyona", tier = "Preserved" },
    [23] = { name = "Hasla", base = "Hasla", tier = "Preserved" },
    [24] = { name = "Tigerspine Mountains", base = "Tigerspine", tier = "Fine" },
    [25] = { name = "Silent Forest", base = "Silent Forest", tier = "Commercial" },
    [26] = { name = "Hellswamp", base = "Hellswamp", tier = "Preserved" },
    [27] = { name = "Sanddeep", base = "Sanddeep", tier = "Preserved" },
    [33] = { name = "Heedmar" },
    [54] = { name = "Exeloch", base = "Exeloch", tier = "Coastal" },
    [56] = { name = "Sungold Fields", base = "Sungold", tier = "Coastal" },
    [57] = { name = "Golden Ruins", base = "Golden Ruins", tier = "Coastal" },
    [93] = { name = "Ahnimar", base = "Ahnimar", tier = "Preserved" },
    [99] = { name = "Rokhala Mountains", base = "Rokhala", tier = "Preserved" },
    [102] = { name = "Aegis Island", base = "Aegis", tier = "Coastal" },
    [103] = { name = "Whalesong Harbor", base = "Whalesong", tier = "Coastal" },
}

-- 最高新鲜度的售价倍率（依包名里的等级；名称没有等级的包不加成）
CT.FRESHNESS_BY_TIER = {
    Luxury = 1.30,
    Fine = 1.15,
    Commercial = 1.05,
    Preserved = 1.03,
}
-- 送到这些交货区域时，所有包都用这个倍率
CT.FRESHNESS_BY_DESTINATION = {
    [33] = 1.30,
}

-- 不能上拍卖的材料（物品编号）：成本算 0，查价时跳过
CT.AUCTION_EXCLUDED_ITEMS = {
    [23633] = true, -- 德翡纳之星 Gilda Star
}
