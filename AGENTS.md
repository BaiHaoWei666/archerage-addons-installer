# 專案語言規則

- 僅遊戲內實際顯示的中文使用簡體；管理器介面、設定、錯誤、文件、註解及版本說明使用繁體。
- 接觸到不符規則的文字時一併修正。專有名稱、識別字、路徑及必要原文保留原樣。
- 同時供遊戲內外顯示的文字分開維護。

# 維護範圍

- 本 repo 僅維護安裝器與來源清單。收錄 URL 的唯一來源是 repositories.json。
- addons/ 是忽略追蹤的獨立 Git repo；插件功能、測試、版本、README 與開發規範在各自 repo 維護。
- 線上資料從公開 Release 附件取得；插件規格見 [docs/addon-format.md](docs/addon-format.md)。
- 修改收錄清單使用 registry workflow，不為此調高安裝器版本。

# 提交與發布

- 一般提交：type: 繁體中文摘要，或 type(scope): 繁體中文摘要。
- 前綴使用小寫：feat、fix、doc、chore、refactor、test、perf、style、build、ci、revert。
- 不同目的分開提交；安裝器版本提交固定為 chore(installer): bump version to <版本號>。
- 完成程式與測試後才調高版本，同步 manifest.json 的 installer.version 與 installer/wails.json 的 info.productVersion；建置版本從 manifest 注入。
- 交付前執行 scripts/test.ps1 與 scripts/build-release.ps1，核對產物版本並更新 RELEASE_NOTES.md。
- 只有使用者明確要求發布安裝器時，才建立並推送單一 v<版本號> tag。提交與推送 main 不等於授權發布。
- 推送明列 main 或單一 tag，不使用 --tags。插件 repo 與本 repo 各自提交及推送。
