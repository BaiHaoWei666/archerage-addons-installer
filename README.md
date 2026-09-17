# ArcheRage Addon Installer

給親友用的 ArcheRage 插件安裝與更新工具。單一 exe，不用安裝。

語言規則：僅遊戲內實際顯示的文字使用簡體中文；其餘介面、文件與開發溝通一律使用繁體中文，後續碰到不符合規則的文字時一併修正。完整規則見 [AGENTS.md](AGENTS.md)。第三方授權條款保留原文。

私人倉庫：[BaiHaoWei666/archerage-addons-installer](https://github.com/BaiHaoWei666/archerage-addons-installer)。

Go + Wails 版 Windows x64 exe 實測約 16.5 MiB（17.3 MB），包含 Logo、網頁介面與 Noto Sans TC 字型，不需要 .NET。

目前收錄的插件：

| 插件 | 說明 |
|---|---|
| infotracker2 | 資訊追蹤：任務、每日挑戰、角色資訊、今日淨收入、副本 |
| commercetracker | 經商追蹤：特產包比率、售價、材料成本與利潤 |

## 使用方式

1. 向提供者索取 `ArcheRageAddonInstaller.exe`（repo 是私人的，親友無法直接從 GitHub 下載），放在任何資料夾（建議不要放在 OneDrive 裡）。
2. 雙擊執行。第一次執行時 Windows 可能顯示「Windows 已保護您的電腦」：
   點 **其他資訊** → **仍要執行**。這是因為程式沒有購買數位簽章，只有第一次會出現。
3. 首次開啟會顯示「開始使用：貼上存取權杖」。向提供者取得權杖，貼上後按「儲存並連線」。
   程式會自動找到 `文件\ArcheRage\Addon`；找不到時到「設定」選擇。
4. 「瀏覽」頁可以搜尋、依分類篩選插件，點選後會顯示說明和更新紀錄，按「安裝」或「更新」。
5. 「已安裝」頁可以一次「全部更新」，或解除安裝。
6. 在遊戲裡重新載入插件，或重新登入。

- 安裝、更新或解除安裝前，會先備份到 `Addon\Backup\插件名_日期時間`。
- 更新只會覆蓋插件自帶的檔案，不會刪除你自己加的檔案。
- 安裝工具有新版時，會詢問是否自動更新。
- 出現「存取權杖無效或已過期」時，到「設定 → 存取權杖」貼上提供者給的新權杖。
- 介面使用 Microsoft Edge WebView2（Windows 10/11 通常已內建）；缺少時程式會提示下載。
- 設定存在 `%AppData%\ArcheRageAddonInstaller\settings.json`（權杖以 Windows DPAPI 加密）。

## 維護者

### 開發環境

- [Go](https://go.dev/dl/) 1.26 以上（本機驗證使用 Go 1.27.0）
- Wails CLI：`go install github.com/wailsapp/wails/v2/cmd/wails@v2.16.0`
- git

### 存取權杖

repo 是私人的，安裝工具要用 GitHub 權杖讀取 Release。建立 **fine-grained personal access token**：

- Repository access：**Only select repositories** → 只選這個 repo
- Permissions：**Contents: Read-only**（Metadata: Read-only 會自動加上）
- 設定到期日，到期前換新

權杖只能由使用者在「設定 → 存取權杖」貼上，以 Windows DPAPI 加密存於本機。
程式不內嵌權杖，也不讀取環境變數權杖。未設定時不發送線上下載請求，而是開啟設定指引。
清除權杖後會回到指引頁。到期或失效時，設定頁會顯示錯誤，貼上新權杖即可重試。

GitHub Actions 僅使用 GitHub 自動提供的工作流程憑證上傳 Release，該憑證不會編入 exe。

### 發佈新版本

先完成插件的版本、更新紀錄與 catalog 封裝，獨立提交並推送；安裝器 release 另行處理，規則見 [AGENTS.md](AGENTS.md#發布分流)。

```powershell
# 插件收尾：修改有變動的插件版本與更新紀錄，安裝器版本維持原值。
# 開發資料夾已使用 Junction 時直接修改 addons/，不執行同步腳本。
./scripts/build-release.ps1 -SkipInstaller
./scripts/test.ps1
# 僅暫存本次插件、測試、manifest 與相關 catalog 檔案。
git commit -m "chore(infotracker2): bump version to X.Y.Z"
git push origin main
```

使用者另行要求發布安裝器後，才調高 `installer.version`，執行以下流程：

```powershell
./scripts/build-release.ps1
./scripts/test.ps1
# 僅暫存安裝器版本及相關發布資料，獨立提交。
git commit -m "chore(installer): bump version to X.Y.Z"
git push origin main
# 使用本次安裝器版本建立單一 tag，另一次推送觸發 release workflow。
git tag vX.Y.Z
git push origin refs/tags/vX.Y.Z
```

程式依 latest Release 的 tag 讀取該版本的 catalog/，不會讀到 main 尚未發佈的修改。
發佈前務必提交 catalog/；程式比對其中 manifest.json 的版本號。

### 新增插件

1. 在 `manifest.json` 的 `addons` 加一筆：

   ```json
   {
     "name": "資料夾名稱",
     "displayName": "顯示名稱",
     "version": "1.0.0",
     "category": "分類",
     "author": "作者（可省略）",
     "description": "一句話說明",
     "changelog": [
       { "version": "1.0.0", "date": "2026-09-17", "notes": ["首次發佈"] }
     ]
   }
   ```

2. （可選）圖示放在 `meta/資料夾名稱/icon.png`，建議 144×144。沒有圖示時會顯示文字圖示。
3. 說明頁使用插件資料夾裡的 `README.md`。
4. 執行 `./scripts/sync-addons.ps1`。

### 專案結構

```
addons/                 插件原始檔（由 sync-addons.ps1 同步）
meta/                   插件圖示
catalog/                已打包的插件、清單、圖示與說明（隨版本提交，不上傳 Release）
manifest.json           插件清單、版本號、分類、更新紀錄
scripts/
  sync-addons.ps1       從遊戲資料夾同步插件
  build-release.ps1     打包 dist/
installer/              安裝工具（Go + Wails v2，介面用系統的 WebView2）
  *.go                  後端：下載、安裝、備份、自我更新、權杖
  frontend/dist/        介面（HTML/CSS/JS，編進 exe）
  build/                exe 圖示與 Windows 資源
.github/workflows/      打 tag 時自動發佈
```

### 運作方式

使用者貼上權杖後，程式透過 GitHub API 取得最新 Release 的 tag，再讀取私人倉庫該 tag 的 catalog/。
只有安裝工具自己的 exe 從 Release 下載。Release 頁面只列出 exe 與 GitHub 自動產生的 Source code。
沒有權杖時顯示設定指引；只有明確指定 `--source` 的本機／自訂來源測試不需要權杖。

| 倉庫 catalog/ 檔案 | 用途 |
|---|---|
| `manifest.json` | 插件清單與版本 |
| `插件名.zip` | 插件本體（內含發佈時產生的 `version.txt`） |
| `插件名.png` / `插件名.md` | 圖示與說明，安裝前就能顯示 |

本機版本讀自每個插件資料夾裡的 `version.txt`。

v1.0.1 及更早版本使用舊的 Release 附件格式；移除舊附件後，請手動下載 v1.0.2 或更新的 exe。原有加密 token 設定可沿用。

### 第三方元件

- [Wails](https://wails.io/)（MIT）、[goldmark](https://github.com/yuin/goldmark)（MIT）、[golang.org/x/sys](https://pkg.go.dev/golang.org/x/sys)（BSD）
- 介面字型：[Noto Sans TC](https://fonts.google.com/noto/specimen/Noto+Sans+TC)（思源黑體，SIL Open Font License 1.1，
  授權全文見 `installer/frontend/dist/fonts/LICENSE-OFL.txt`），取自 `@fontsource-variable/noto-sans-tc@5.3.0`。
- 側欄與 exe 圖示使用 ArcheRage 遊戲標誌，僅供私人使用。
