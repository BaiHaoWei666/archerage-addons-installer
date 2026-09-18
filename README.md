# ArcheRage Addon Installer

Windows x64 的 ArcheRage 插件管理工具。下載單一 exe 即可瀏覽、安裝、更新與移除插件，無須登入或提供 GitHub 權杖。

## 下載與使用

1. 到 [最新正式 Release](https://github.com/BaiHaoWei666/archerage-addons-installer/releases/latest) 下載 `ArcheRageAddonInstaller.exe`。
2. 開啟後確認「設定」中的遊戲 `Addon` 資料夾，預設為 Windows「文件」下的 `ArcheRage/Addon`。
3. 在「瀏覽」選擇插件並安裝；「已安裝」可更新或移除。
4. 回到遊戲重新載入插件，或重新登入。

程式使用 WebView2；缺少時會提示安裝。安裝器尚未簽署，Windows 可能顯示來源確認。

更新既有插件或移除前會備份到 `Addon/Backup/`。更新覆蓋封裝中的檔案，保留使用者另外加入的檔案。Junction／符號連結開發目錄會拒絕更新與移除。

設定位於 `%AppData%/ArcheRageAddonInstaller/settings.json`。舊版設定中的權杖欄位不再讀取，重新儲存設定時會移除。從舊版遷移時，建議直接下載新版 exe；舊版使用的 catalog 已停止維護。

## 更新來源

所有線上安裝資料均來自公開 GitHub Release：

- 收錄清單：本 repo 的 `registry` 預發布附件 `repositories.json`。
- 安裝器：本 repo 最新正式 Release 的 exe，以 tag 判斷版本。
- 插件：收錄 repo 各自最新正式 Release 的 manifest、ZIP、說明及圖示。

安裝器不讀取 Git 分支中的檔案，也不下載 GitHub 自動產生的 Source code ZIP。每次重新整理會固定各來源的 Release；安裝時核對 ZIP 的 SHA-256 及內含版本。個別插件來源失敗時顯示警告，其餘插件仍可使用。匿名 GitHub API 有查詢額度，遇到限制請稍後再試。

主專案只維護管理器與來源清單；插件功能說明、程式、測試與版本由各 repo 自行維護。收錄項目以 [repositories.json](repositories.json) 為準。

## 開發

需求：Git、Go（版本見 `installer/go.mod`）、PowerShell，以及 Wails CLI。

```powershell
go install github.com/wailsapp/wails/v2/cmd/wails@v2.16.0
./scripts/test.ps1
./scripts/build-release.ps1
```

可執行 `ArcheRageAddonInstaller.exe --version` 核對實際版本。

產物：`dist/ArcheRageAddonInstaller.exe`。前端原始檔位於 `installer/frontend/dist/`，直接編入 exe，無 npm 建置步驟。

需要同時開發收錄插件時執行：

```powershell
./scripts/setup-addons.ps1
```

腳本依 URL 的 repo 名稱 clone 到 `addons/<repo名稱>/`，保留已存在目錄；各目錄為獨立 Git repo，主專案忽略整個 `addons/`。若 repo 名稱與 manifest 的安裝名稱不同，遊戲連結應使用 manifest 的 `name`。插件依各自的 AGENTS.md、README 及測試流程維護。

`--source <資料夾或網址>` 可使用舊式彙整 manifest 和同目錄附件做隔離測試；`--addon-dir <資料夾>` 暫時指定安裝位置，不改設定。

## 收錄與發布

新增第三方插件，只需修改 URL 清單；對方不需要主專案寫入權限。格式、附件與工作流程約定見 [插件發布格式](docs/addon-format.md)。

- 修改 `repositories.json` 並推送 main：workflow 更新 `registry` 的清單附件，無須重發 exe。
- 插件作者發布自己的正式 Release：使用者重新整理即可取得該版本，無須修改主專案。
- 發布安裝器：同步根目錄 `manifest.json` 與 `installer/wails.json` 的版本，更新 `RELEASE_NOTES.md`，通過測試與建置後提交。依 AGENTS.md 的發布授權規則，推送單一 `v<版本>` tag 觸發 Release。

`registry` 是專用的可更新預發布，僅供清單使用，不是安裝器版本。重新上傳附件的短暫期間可能讀取失敗，稍後重新整理即可。

## 專案結構

| 路徑 | 用途 |
|---|---|
| `installer/` | Go + Wails 安裝器及前端 |
| `repositories.json` | 公開插件 repo URL 陣列 |
| `manifest.json` | 安裝器版本 |
| `scripts/` | 建置、測試、清單檢查與開發環境初始化 |
| `docs/addon-format.md` | 第三方插件整合規格 |
| `addons/` | 忽略追蹤的本機獨立 repo |
| `.github/workflows/` | CI、安裝器 Release、收錄清單發布 |

## 文字與第三方元件

遊戲內中文使用簡體；管理器、文件、註解及版本說明使用繁體。專有名稱保留原樣。

使用 Wails（MIT）、goldmark（MIT）與 golang.org/x/sys（BSD）；各自授權見上游專案。介面使用 Windows 系統字型。ArcheRage 標誌與遊戲資源的權利歸原權利人。
