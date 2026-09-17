# 本機開發與測試

## 目錄

- 原始碼：`C:/dev/ArcheRageAddonInstaller/addons/infotracker2`。
- 遊戲路徑：`C:/Users/kevin/OneDrive/文件/ArcheRage/Addon/infotracker2`，以 Junction 指向原始碼。
- 直接修改原始碼，遊戲重新載入即讀取同一份檔案，不需複製。首次使用先確認連結仍有效。
- 開發連結啟用時，不執行 `scripts/sync-addons.ps1`，也不透過安裝器更新、重裝或移除該插件，以免覆寫原始碼或破壞連結。

## 實機測試

1. 完成修改後，請使用者操作：Esc → 附加組件管理器 → infotracker2 最右側圓形箭頭。齒輪是設定。
2. 使用 computer-use 讀取畫面；依該 skill 初始化及選取視窗，只擷取畫面，不啟用視窗、不送出滑鼠或鍵盤輸入。需要切頁、展開或捲動時直接請使用者協助。
3. 從本機聊天框確認載入訊息，查看新項目、展開名稱及狀態。查詢需求讀取 [quest-id.md](quest-id.md)。
4. 移除本次探針與 `toc.g` 載入行、還原暫時開關，再請使用者重新載入正式版本。

`ITV2.Chat` 使用 `X2Chat:DispatchChatMessage(CMF_SYSTEM, ...)`，只顯示本機訊息。此輸出未出現在當次 `Chat.log` 或 `ArcheRage.log`，應直接讀取遊戲聊天框畫面。
