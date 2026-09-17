# ArcheRage Addon Installer

給親友用的 ArcheRage 插件安裝與更新工具。單一 exe，不用安裝。

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

```powershell
# 1. 從遊戲的 Addon 資料夾同步插件到 addons/
./scripts/sync-addons.ps1

# 2. 修改 manifest.json：調高有變動的插件 version，並在 changelog 最前面加一筆紀錄
#    （要更新安裝工具本身時，調高 installer.version）

# 3.（可選）本機打包測試，產生 dist/；--addon-dir 可指定測試用的插件資料夾
./scripts/build-release.ps1
./dist/ArcheRageAddonInstaller.exe --source dist --addon-dir D:\test-addon

# 4. 提交並打 tag，GitHub Actions 會自動打包並發佈 Release
git add -A
git commit -m "Release v1.0.1"
git tag v1.0.1
git push origin main --tags
```

tag 名稱只用來命名 Release；程式實際比對的是 `manifest.json` 裡的版本號。

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

使用者貼上權杖後，程式透過 GitHub API 讀取最新 Release 的附件。
沒有權杖時顯示設定指引；只有明確指定 `--source` 的本機／自訂來源測試不需要權杖。

| 附件 | 用途 |
|---|---|
| `manifest.json` | 插件清單與版本 |
| `插件名.zip` | 插件本體（內含發佈時產生的 `version.txt`） |
| `插件名.png` / `插件名.md` | 圖示與說明，安裝前就能顯示 |
| `ArcheRageAddonInstaller.exe` | 安裝工具本身 |

本機版本讀自每個插件資料夾裡的 `version.txt`。

### 第三方元件

- [Wails](https://wails.io/)（MIT）、[goldmark](https://github.com/yuin/goldmark)（MIT）、[golang.org/x/sys](https://pkg.go.dev/golang.org/x/sys)（BSD）
- 介面字型：[Noto Sans TC](https://fonts.google.com/noto/specimen/Noto+Sans+TC)（思源黑體，SIL Open Font License 1.1，
  授權全文見 `installer/frontend/dist/fonts/LICENSE-OFL.txt`），取自 `@fontsource-variable/noto-sans-tc@5.3.0`。
- 側欄與 exe 圖示使用 ArcheRage 遊戲標誌，僅供私人使用。
