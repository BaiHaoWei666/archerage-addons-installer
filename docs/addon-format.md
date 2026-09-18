# 插件發布格式 v1

每個插件是一個公開 GitHub repo。主專案的 `repositories.json` 是 URL 字串陣列；同一 repo 只收錄一次。不需要向插件作者提供管理器 repo 的權限。

## 目錄與 metadata

插件原始碼可直接放在 repo 根目錄，方便將整個開發目錄連結到遊戲。repo 根目錄維護 `manifest.json`，範例：

```json
{
  "schemaVersion": 1,
  "name": "example-addon",
  "displayName": "範例插件",
  "version": "1.0.0",
  "category": "工具",
  "description": "插件用途",
  "author": "作者",
  "changelog": [
    {"version": "1.0.0", "date": "2026-09-19", "notes": ["首次發布"]}
  ],
  "files": ["*.lua", "toc.g", "common/", "README.md"]
}
```

`name` 是安裝資料夾名稱及附件前綴，須在所有收錄插件間唯一；使用英數、底線或連字號，且不得為 Backup。版本使用三段數字，不含 v。Git tag 必須為 `v<version>`。

`files` 是建置端白名單，安裝器不執行它，也不執行來源 repo 的任何建置腳本。發布者負責排除 .git、測試、開發設定與 CI 檔案。

## Release 附件

最新正式 Release 必須包含：

| 附件 | 內容 |
|---|---|
| `manifest.json` | 上述 metadata，加上 ZIP 的十六進位 `sha256`；可省略 files |
| `<name>.zip` | 根層只有 `<name>/`，內含插件執行檔與純版本號 version.txt |
| `<name>.md` | 使用說明；建議由 README.md 複製 |
| `<name>.png` | 可選圖示；缺少時顯示文字圖示 |

ZIP 建立後才計算 SHA-256，再產生 Release manifest。原始碼 manifest 是版本來源；Release manifest 是附帶封裝雜湊的生成產物。SHA-256 用來核對下載與發布資料的一致性，不代表作者身分簽章。

管理器透過 [GitHub Release API](https://docs.github.com/en/rest/releases/releases) 選擇最新正式版本，並從該次回應的 `browser_download_url` 下載附件；不讀 main 或其他 Git 檔案。預發布與草稿不會作為插件更新。

## 作者 workflow

建議每個 repo 設置：

1. push main 與 pull request：執行語法檢查、回歸測試和封裝驗證。
2. push 單一 v tag：檢查 tag 與 manifest 相符，先通過相同測試。
3. 建立正式 Release，將 ZIP、生成 manifest、README 與圖示一併上傳。
4. 已發布版本不重用；下一次更新調高版本、補上 changelog 並發布新 tag。

CI 的發布工作可以使用 GitHub 提供的 workflow 憑證；管理器使用者不需要憑證。尚未完成的插件可以維持公開 repo 與 CI，準備好後才發布正式版並提出收錄。

## 本機驗證

封裝後核對 ZIP 的 version.txt、執行檔內容與原始碼一致。開發目錄的 version.txt 必須同步；若遊戲目錄是 Junction，先確認目標正確，再從遊戲路徑讀回版本。管理器拒絕修改這類開發連結。

主專案測試不需要 clone 任何插件；每個插件 repo 自行承擔自己的程式測試。新增來源時須測試附件格式、版本、名稱衝突與實際安裝結果。
