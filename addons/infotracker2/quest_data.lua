-- 追蹤項目資料
-- 每個分類的 kind 決定由 sources/ 裡的哪個來源（ITV2.SOURCES[kind]）負責顯示：
--   quest   任務組（ids = 所有陣營/輪換版本的任務 ID，max = 每天實際可完成數，省略時 = #ids）
--   info    角色資訊
--   income  今日淨收入（field = 累計的欄位：gold | vocation | honor | exp）
--   dungeon 副本（index = X2BattleField:GetInstanceListByKind(4) 裡的位置）
--   assignment 每日挑戰（活動中心；slot = 第幾格）
-- 分類的 fixed = true：全部列出，不能勾選或排序（懸浮窗依格子位置顯示）
-- 所有項目的 key 必須全局唯一（存檔用），同時也是 locale.lua 的文字 key
ITV2.CATEGORIES = {
    {
        key = "daily",
        label = "CAT_DAILY",
        kind = "quest",
        items = {
            { key = "GR", max = 8, ids = { 5138, 5139, 5140, 5150, 5151, 5152, 5153, 5154, 5155, 5156, 5142, 5157, 5143, 5144, 7648, 7649, 11192, 10739 },
              -- 展開時的名稱替換（完全相同才算）；同一個 label 的會合併成一行
              merge = {
                  { label = "QUEST_SUPPLY_SHORTAGE", titles = { "石材不足", "木材不足", "布料不足", "皮革不足", "铁锭不足" } },
                  { label = "QUEST_NIGHTMARE_STAGE3", titles = { "不祥且惊悚的噩梦之痕：消灭军团第3阶段" } },
              } },
            { key = "CR", ids = { 2941, 2942, 2943, 8998, 10729, 10730, 10734, 10735, 9000223 } },
            { key = "WH", max = 6, ids = { 8602, 8603, 8604, 8609, 8610, 8611, 8612, 8613, 8614, 8615, 8616, 8617, 8637, 8638, 8639, 8640, 8605, 8606, 8607, 8608, 9000220 } },
            { key = "AEGIS", max = 7, ids = { 8618, 8619, 8620, 8621, 8623, 8624, 8625, 8626, 8627, 8628, 8629, 8630, 8631, 8632, 8633, 8634, 8641, 8642, 8643, 8644, 8645, 9000221 } },
            { key = "JMG", ids = { 5969, 5970, 5971 } },
            { key = "VOIDATTK", ids = { 11154, 11155, 11156, 11157, 11158 } },
            { key = "WONDERLAND", ids = { 9000333 } },
            { key = "HALCY", ids = { 9000225, 9320 } },
            { key = "GARDENBOSS", ids = { 10056 } },
            { key = "YNYSWORD", ids = { 9965 } },
            { key = "CINDERSWORD", ids = { 9960 } },
            { key = "IPNYSH_DAILY", ids = { 10558, 10559 } },
            { key = "TREE_MAMMOTH", ids = { 9317, 9318 } },
        },
    },
    {
        key = "vocation",
        label = "CAT_VOCATION",
        kind = "quest",
        items = {
            { key = "BSB", ids = { 9044, 9046, 9047, 9049 } },
            { key = "BSB60", ids = { 9142, 9147, 9152 } },
            { key = "NUI", ids = { 9000003, 9000004, 9000005 } },
            { key = "RESIDENT", ids = { 8345, 8347, 8348, 8349, 8350, 8559, 8560, 8561, 8562, 8589, 8590, 8591, 8592, 8593, 8588 } },
            { key = "FISHPACK", ids = { 9000226, 9000531 } },
        },
    },
    {
        key = "weekly",
        label = "CAT_WEEKLY",
        kind = "quest",
        items = {
            { key = "HIRAMONE", ids = { 9017, 9131 } },
            { key = "WHM", ids = { 9077, 11196 } },
            { key = "EHM", ids = { 10334, 10335 } },
            { key = "IPY", ids = { 11200 } },
        },
    },
    {
        key = "others",
        label = "CAT_OTHERS",
        kind = "quest",
        items = {
            { key = "WABOSS", ids = { 9000198 } },
            { key = "LUSCA", ids = { 5765 } },
            { key = "ABYSSAL", max = 2, ids = { 6791, 6973, 6974, 6975 } },
            { key = "AKASCH", ids = { 10564, 10565, 10569, 10571, 10708 } },
            { key = "PRAIRIE", max = 2, ids = { 11066, 11096, 11132, 11116, 11098, 11131, 11133 } },
        },
    },
    {
        key = "challenge",
        label = "CAT_CHALLENGE",
        kind = "assignment",
        fixed = true,   -- 全部列出，不能勾選或排序
        -- 活動中心的每日挑戰（X2Achievement 的 TADT_TODAY）；slot = 第幾格
        items = {
            { key = "AS_1", slot = 1 },
            { key = "AS_2", slot = 2 },
            { key = "AS_3", slot = 3 },
            { key = "AS_4", slot = 4 },
            { key = "AS_5", slot = 5 },
            { key = "AS_6", slot = 6 },
            { key = "AS_7", slot = 7 },
        },
    },
    {
        key = "info",
        label = "CAT_INFO",
        kind = "info",
        items = {
            { key = "INFO_BLESSING" },
            { key = "INFO_COSTUME" },
            { key = "INFO_UNDERWEAR" },
            { key = "INFO_DARU" },
            { key = "INFO_DAILY" },
            { key = "INFO_GUILD" },
        },
    },
    {
        key = "income",
        label = "CAT_INCOME",
        kind = "income",
        items = {
            { key = "INC_EXP", field = "exp" },
            { key = "INC_GOLD", field = "gold" },
            { key = "INC_VOCATION", field = "vocation" },
            { key = "INC_HONOR", field = "honor" },
        },
    },
    {
        key = "dungeon",
        label = "CAT_DUNGEON",
        kind = "dungeon",
        -- 副本分組：其他副本 7 個（跳過 6），再來英雄副本 7 個
        items = {
            { key = "DG_1", index = 1 },
            { key = "DG_2", index = 2 },
            { key = "DG_3", index = 3 },
            { key = "DG_4", index = 4 },
            { key = "DG_5", index = 5 },
            { key = "DG_7", index = 7 },
            { key = "DG_8", index = 8 },
            { key = "DG_12", index = 12 },
            { key = "DG_14", index = 14 },
            { key = "DG_10", index = 10 },
            { key = "DG_11", index = 11 },
            { key = "DG_9", index = 9 },
            { key = "DG_13", index = 13 },
            { key = "DG_15", index = 15 },
        },
    },
}
