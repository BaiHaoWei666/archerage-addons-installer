---
name: dev-infotracker
description: 開發 infotracker2 的任務追蹤、查詢遊戲任務 ID，或重新載入實機測試時使用。
---

# infotracker2 開發

- computer-use 僅用於讀取遊戲畫面，不能操作遊戲；點擊、按鍵及重新載入直接請使用者協助，不再嘗試自動輸入。
- 查詢未知任務 ID：讀取 [references/quest-id.md](references/quest-id.md)。
- 修改插件及實機測試：讀取 [references/live-test.md](references/live-test.md)。
- 任務組位於 `addons/infotracker2/quest_data.lua`，顯示名稱位於 `locale.lua`。每日組使用 `daily.items`；未指定 `max` 時分母為 ID 數量。
- 保留既有 key 與使用者設定；交付前清理探針，區分程式驗證與實機驗證結果。
