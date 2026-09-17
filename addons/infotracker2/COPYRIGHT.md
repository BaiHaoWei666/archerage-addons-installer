# infotracker2 版權、來源與授權說明

## infotracker 原作者與授權

infotracker2 基於 infotracker 的部分程式、資料與功能延伸開發。infotracker 原作者為 **Discord @Nevermore (奈奈呀)**；原作及其可受保護內容的權利仍歸原權利人。本專案維護者與貢獻者只為自己新增或修改的部分署名，不將原作宣稱為自行原創。

依本專案維護者於 2026-09-18 提供的授權確認，作者原話如下（保留原文）：

> as long as its open source and  free to use im fine with that, take credit to the part you changed

本專案據此維持 infotracker2 原始碼公開、免費使用，並區分原作與本專案修改的貢獻。此日期為記錄日期，不代表原始 Discord 訊息日期；本檔記錄維護者提供的授權內容，不代替原始對話紀錄。

這段同意未指定 MIT、GPL 等標準授權，也未完整說明第三人的再授權條件，本檔不替作者擴張授權或替整個專案套用新授權。原作者提到的「open source」保留原意；公開原始碼本身不等同於已採用符合 OSI 定義的開源授權。參見 [OSI 開源定義](https://opensource.org/osd)。

原始碼：[ArcheRageAddonInstaller / infotracker2](https://github.com/BaiHaoWei666/archerage-addons-installer/tree/main/addons/infotracker2)。

## 從 infotracker 沿用及延伸的內容

下表整理 infotracker 的沿用內容與 infotracker2 的延伸功能；路徑分別以各插件目錄為起點。

| 功能／內容 | infotracker 來源 | infotracker2 對應與延伸 |
|---|---|---|
| 通用視窗、按鈕與 API 定義 | `common/apitypes.lua`、`buttoncommon.lua`、`button.lua`、`windowcommon.lua`、`window.lua` | `common/` 同名五個檔案；本次比對位元組完全相同，屬直接沿用。 |
| 每日、生活、週常及其他任務 | `documents/eventDatas.lua`、`documents/controller.lua`、`documents/functions.lua` | `quest_data.lua`、`sources/quest.lua`；延伸任務 ID 池、分類、完成判定與分母上限設定，另加入完成數封頂、同名任務合併顯示及新任務組。原版部分明細另有陣營選擇邏輯，並非全部原樣保留。 |
| 角色狀態 | `documents/functions.lua` | `sources/info.lua`；延伸國王雕像祝福、時裝／內衣／多魯時裝期限、每日與公會任務解鎖判定，整理為統一的狀態來源。 |
| 今日淨收入 | `documents/netIncome.lua` | `sources/income.lua`；延伸金幣、生活點、榮譽、經驗的事件累計與每日歸零，改用插件存檔 API、角色專屬存檔鍵及含年份的日期。 |
| 副本次數與建立戰隊 | `documents/controller.lua` 的 `CreateTeamForInstance`、副本分組設定 | `sources/dungeon.lua`、`quest_data.lua`；延伸副本清單順序、進入次數、先快速配對再建立非公開戰隊、特定副本限制與五秒冷卻，另加入確認視窗及邀請隊伍成員選項。 |

本專案的後續新增或改寫包括：`ITV2` 模組與來源介面、追蹤／排序設定、分頁懸浮窗、捲動與外觀設定、任務明細合併、每日挑戰清單、特產配方與材料展開、拍賣場查詢，以及副本建隊確認流程。這些是修改範圍的說明，不代表其中每一行都由本專案原創；UI 概念參考來源另見下節，個別修改以 Git 紀錄為準。

未整套移植原版的活動時間提醒、社區發展查詢、遠端聊天跳頁與信任名單系統。原版 README 另致謝 Monopolis、Rifleman W.、Xiaocao 及其他插件作者提供參考程式；這些上游貢獻不因本說明而改歸本專案或視為已取得額外授權。

## choretracker：僅參考 UI 操作概念

本專案對 choretracker 僅參考 UI 操作概念，包括勾選追蹤、上下排序、展開明細與懸浮小窗。infotracker2 的 UI 使用遊戲內建 API 與元件樣式實作。

經檢視社群多項插件專案，元件建立、錨點定位、事件處理、拖曳、文字設色及 UI 縮放等皆為常見實作方式。這些共通用法與外觀相似處，不足以認定沿用 choretracker 的特有程式，也無須僅為降低相似度而重構。

choretracker 原始碼署名為 Strawberry，並列出 Discord：exec_noir。本節記錄概念參考來源，不代表已取得該專案程式的授權；遊戲內建資源的權利仍歸各自權利人。
