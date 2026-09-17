-- 特产资料（每日挑战的特产材料用，见 sources/specialty.lua）

-- 特产配方编号（取自 globals/craftids.lua 中名称含 "Specialty" 的配方）
-- 执行时用 X2Craft:GetCraftProductInfo 读出产品的物品编号，再与挑战目标文字里的物品编号对应
-- 游戏新增特产地区时，把新配方编号补进来
ITV2.SPECIALTY_CRAFTS = {
    11566, -- Aegis Coastal Fertilizer Specialty
    11559, -- Aegis Coastal Gilda Specialty
    11577, -- Aegis Coastal Local Specialty
    9342, -- Ahnimar Preserved Fertilizer Specialty
    9339, -- Ahnimar Preserved Gilda Specialty
    9607, -- Ahnimar Preserved Local Specialty
    9340, -- Ahnimar Preserved Specialty
    9334, -- Airain Commercial Fertilizer Specialty
    9331, -- Airain Commercial Gilda Specialty
    9606, -- Airain Commercial Local Specialty
    9332, -- Airain Commercial Specialty
    7783, -- Arcum Iris Commercial Fertilizer Specialty
    6214, -- Arcum Iris Commercial Gilda Specialty
    9608, -- Arcum Iris Commercial Local Specialty
    6237, -- Arcum Iris Commercial Specialty
    9338, -- Aubre Commercial Fertilizer Specialty
    9335, -- Aubre Commercial Gilda Specialty
    9605, -- Aubre Commercial Local Specialty
    9336, -- Aubre Commercial Specialty
    7779, -- Cinderstone Luxury Fertilizer Specialty
    6210, -- Cinderstone Luxury Gilda Specialty
    9604, -- Cinderstone Luxury Local Specialty
    6233, -- Cinderstone Luxury Specialty
    7773, -- Dewstone Fine Fertilizer Specialty
    6204, -- Dewstone Fine Gilda Specialty
    9595, -- Dewstone Fine Local Specialty
    6227, -- Dewstone Fine Specialty
    11568, -- Exeloch Coastal Fertilizer Specialty
    11563, -- Exeloch Coastal Gilda Specialty
    11579, -- Exeloch Coastal Local Specialty
    7785, -- Falcorth Fine Fertilizer Specialty
    6216, -- Falcorth Fine Gilda Specialty
    9618, -- Falcorth Fine Local Specialty
    6239, -- Falcorth Fine Specialty
    11570, -- Golden Ruins Coastal Fertilizer Specialty
    11565, -- Golden Ruins Coastal Gilda Specialty
    11581, -- Golden Ruins Coastal Local Specialty
    7771, -- Gweonid Commercial Fertilizer Specialty
    6202, -- Gweonid Commercial Gilda Specialty
    9596, -- Gweonid Commercial Local Specialty
    6225, -- Gweonid Commercial Specialty
    7780, -- Halcyona Preserved Fertilizer Specialty
    6211, -- Halcyona Preserved Gilda Specialty
    9601, -- Halcyona Preserved Local Specialty
    6234, -- Halcyona Preserved Specialty
    7793, -- Hasla Preserved Fertilizer Specialty
    6224, -- Hasla Preserved Gilda Specialty
    9615, -- Hasla Preserved Local Specialty
    6247, -- Hasla Preserved Specialty
    7778, -- Hellswamp Preserved Fertilizer Specialty
    6209, -- Hellswamp Preserved Gilda Specialty
    9599, -- Hellswamp Preserved Local Specialty
    6232, -- Hellswamp Preserved Specialty
    9346, -- Karkasse Commercial Fertilizer Specialty
    9343, -- Karkasse Commercial Gilda Specialty
    9597, -- Karkasse Commercial Local Specialty
    9344, -- Karkasse Commercial Specialty
    7776, -- Lilyut Fine Fertilizer Specialty
    6207, -- Lilyut Fine Gilda Specialty
    9594, -- Lilyut Fine Local Specialty
    6230, -- Lilyut Fine Specialty
    7784, -- Mahadevi Fine Fertilizer Specialty
    6215, -- Mahadevi Fine Gilda Specialty
    9610, -- Mahadevi Fine Local Specialty
    6238, -- Mahadevi Fine Specialty
    7772, -- Marianople Fine Fertilizer Specialty
    6203, -- Marianople Fine Gilda Specialty
    9598, -- Marianople Fine Local Specialty
    6226, -- Marianople Fine Specialty
    7790, -- Perinoor Preserved Fertilizer Specialty
    6221, -- Perinoor Preserved Gilda Specialty
    9616, -- Perinoor Preserved Local Specialty
    6244, -- Perinoor Preserved Specialty
    9354, -- Rokhala Preserved Fertilizer Specialty
    9351, -- Rokhala Preserved Gilda Specialty
    9621, -- Rokhala Preserved Local Specialty
    9352, -- Rokhala Preserved Specialty
    7791, -- Rookborne Preserved Fertilizer Specialty
    6222, -- Rookborne Preserved Gilda Specialty
    9619, -- Rookborne Preserved Local Specialty
    6245, -- Rookborne Preserved Specialty
    7781, -- Sanddeep Preserved Fertilizer Specialty
    6212, -- Sanddeep Preserved Gilda Specialty
    9600, -- Sanddeep Preserved Local Specialty
    6235, -- Sanddeep Preserved Specialty
    7787, -- Silent Forest Commercial Fertilizer Specialty
    6218, -- Silent Forest Commercial Gilda Specialty
    9614, -- Silent Forest Commercial Local Specialty
    6241, -- Silent Forest Commercial Specialty
    7782, -- Solis Luxury Fertilizer Specialty
    6213, -- Solis Luxury Gilda Specialty
    9611, -- Solis Luxury Local Specialty
    6236, -- Solis Luxury Specialty
    7774, -- Solzreed Luxury Fertilizer Specialty
    6205, -- Solzreed Luxury Gilda Specialty
    9593, -- Solzreed Luxury Local Specialty
    6228, -- Solzreed Luxury Specialty
    9350, -- Sunbite Commercial Fertilizer Specialty
    9347, -- Sunbite Commercial Gilda Specialty
    9612, -- Sunbite Commercial Local Specialty
    9348, -- Sunbite Commercial Specialty
    11569, -- Sungold Coastal Fertilizer Specialty
    11564, -- Sungold Coastal Gilda Specialty
    11580, -- Sungold Coastal Local Specialty
    7786, -- Tigerspine Fine Fertilizer Specialty
    6217, -- Tigerspine Fine Gilda Specialty
    9609, -- Tigerspine Fine Local Specialty
    6240, -- Tigerspine Fine Specialty
    7777, -- Two Crowns Luxury Fertilizer Specialty
    6208, -- Two Crowns Luxury Gilda Specialty
    9602, -- Two Crowns Luxury Local Specialty
    6231, -- Two Crowns Luxury Specialty
    7788, -- Villanelle Luxury Fertilizer Specialty
    6219, -- Villanelle Luxury Gilda Specialty
    9613, -- Villanelle Luxury Local Specialty
    6242, -- Villanelle Luxury Specialty
    11567, -- Whalesong Coastal Fertilizer Specialty
    11562, -- Whalesong Coastal Gilda Specialty
    11578, -- Whalesong Coastal Local Specialty
    7775, -- White Arden Commercial Fertilizer Specialty
    6206, -- White Arden Commercial Gilda Specialty
    9603, -- White Arden Commercial Local Specialty
    6229, -- White Arden Commercial Specialty
    7789, -- Windscour Preserved Fertilizer Specialty
    6220, -- Windscour Preserved Gilda Specialty
    9620, -- Windscour Preserved Local Specialty
    6243, -- Windscour Preserved Specialty
    7792, -- Ynystere Commercial Fertilizer Specialty
    6223, -- Ynystere Commercial Gilda Specialty
    9617, -- Ynystere Commercial Local Specialty
    6246, -- Ynystere Commercial Specialty
}

-- 不能上拍卖的材料（物品编号）：列出但双击不查询拍卖场
ITV2.AUCTION_EXCLUDED_ITEMS = {
    [23633] = true, -- 德翡纳之星
}
