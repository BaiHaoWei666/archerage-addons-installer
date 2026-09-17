# Commerce Tracker（經商追蹤）

Folio105 的重寫版：選路線，查看每個特產包的比率、售價，以及製作材料的成本和利潤。介面沿用 Folio105。

## 與 Folio105 的差異

- **材料用 API 讀取**：包的物品編號 → `X2Craft:GetCraftTypeByItemType` → `X2Craft:GetCraftMaterialInfo`，材料名稱和數量跟隨遊戲資料與語系，不需要翻譯表。
- 材料行顯示為 `材料名 x數量`。
- 售價一律按最高新鮮度計算（沒有切換按鈕）。
- 查價時只取名稱相符的拍賣結果；非賣品（`data/zones.lua` 的 `CT.AUCTION_EXCLUDED_ITEMS`）不查，成本算 0。
- 設定用 `ADDON:SaveData` 存檔（依角色），不寫文字檔。
- 只支援中文與英文介面。
- 不要和 Folio105 同時啟用（兩者會同時送出路線查詢；本插件會忽略不是自己送出的結果）。

## 使用

以下以繁體中文說明操作；遊戲內實際顯示的中文文字使用簡體中文。

- 畫面上的小圖示：點一下開關主視窗，拖曳可移動。
- 下方依序選擇 大陸 → 起始區域 → 交貨區域，就會查詢路線比率（5 秒冷卻，冷卻中選單與重新整理停用）。
- 「查價」：依序查詢目前所有特產材料的拍賣單價（每 1.2 秒一筆），再按一次停止。
- 「收藏」：右側收藏欄，「+ 加入目前路線」收藏，點路線套用，× 刪除。

## 售價

`售價 = 基礎售價 × 比率 × (1 + 經商熟練度 × 0.05 / 10000) × 新鮮度倍率`

- 基礎售價：`data/prices.lua`（沿用 Folio105 的實測資料），以英文包名對應。
  - 特產包：配方編號 → `data/specialties.lua` 的英文名稱。
  - 其他包（發酵品、商會包）：配方資料裡沒有編號，沿用 Folio105 的名稱判斷（中文用關鍵字 + 起始區域組出英文名稱）。
- 新鮮度倍率：`data/zones.lua`（豪華 1.30、高級 1.15、商業 1.05、保存 1.03；送到希德瑪一律 1.30）。

## 檔案

| 檔案 | 內容 |
|---|---|
| `core.lua` | 命名空間 `CT`、共用函式 |
| `locale.lua` | 中英文文字 `CT.Text(key)` |
| `data/zones.lua` | 大陸、區域（英文名稱、包等級）、新鮮度倍率、非賣品 |
| `data/specialties.lua` | 特產配方編號 → 英文名稱 |
| `data/prices.lua` | 基礎售價 |
| `trade.lua` | 路線比率查詢、包的辨識與售價 |
| `auction.lua` | 材料拍賣查價佇列 |
| `settings.lua` | 存檔：開關按鈕位置、收藏路線 |
| `windows/widgets.lua` | 共用元件：金額顯示、下拉選單、重新整理按鈕 |
| `windows/main_window.lua` | 主視窗 |
| `windows/favorites.lua` | 收藏側欄 |
| `windows/toggle_button.lua` | 開關按鈕 |
| `main.lua` | 進入點（含重新載入時的初始化） |
| `common/` | 通用視窗函式（`CreateEmptyWindow`、`SettingWindowSkin`） |
| `icons/` | 圖示（取自 Folio105） |

存檔 key：`commercetracker_settings`。元件名稱皆以 `ct` 開頭。
