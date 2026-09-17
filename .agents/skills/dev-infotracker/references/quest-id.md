# 查詢任務 ID

## 從已接任務查詢

以截圖名稱作篩選條件，ID 以目前伺服器及角色的 API 輸出為準。

1. 確認任務已接取。X2Quest:GetActiveQuestListCount() 取得數量；依 1..count 呼叫 GetActiveQuestType(index) 得 ID，再呼叫 GetQuestContextMainTitle(id) 得名稱。正式 sources/common.lua 已使用這組 API。
2. 將 [../assets/quest-probe.lua](../assets/quest-probe.lua) 複製至實機插件根目錄，在實機 toc.g 的 main.lua 後加入 quest-probe.lua。修改 filters 為遊戲語系名稱片段，空表列出全部已接任務；採純文字比對。
3. 依 [live-test.md](live-test.md) 請使用者重新載入並點擊中央偏上的查詢任務 ID 按鈕，之後，會輸出 [Quest ID] 名稱 = ID 及匹配數量。僅點擊時輸出，避免自動洗版。
4. 核對每個目標名稱及 ID。無匹配時先核對語系、篩選文字與接取狀態，不能直接判定任務不存在。片段匹配可能包含無關任務，僅保留使用者指定名稱。
5. 更新 quest_data.lua 的任務組及 locale.lua 的中英文名稱。獨立任務各算一個；只有確認陣營或輪替替代任務才設定較小的 max。
6. 展開檢查名稱與狀態。既有 windows/editor.lua 的 SHOW_DUMP_BUTTON 改 true 後可輸出本頁 ID 池，但無法發現尚未配置的新 ID。
7. 清理探針並重新載入正式版本，將查證對應與測試限制記錄於下方。

## 2026-09-17 查詢紀錄

四個目標都在角色日誌中。當次先在實機 main.lua 加入上述 API 與名稱片段篩選，重新載入時列印結果；可重用版本改為 assets/quest-probe.lua 的按鈕。

名稱片段另命中「前往浮空島」10651 與「在浮空島感受到的氣息」10671，均非指定任務，排除。

正式對應如下（遊戲名稱採原文）：

| 每日任務組 | 遊戲任務名稱 | ID |
|---|---|---|
| 伊福尼爾 | 调查浮空岛 | 10558 |
| 伊福尼爾 | 调查转移现象 | 10559 |
| 樹＋象 | 黑森林统治者哈拉林特 | 9318 |
| 樹＋象 | 雪原统治者麦默图斯 | 9317 |

每組兩個獨立任務，分母均為 2。來源：2026-09-17 ArcheRage NA，使用者角色的已接任務 API 輸出，經遊戲聊天框完整畫面核對。
