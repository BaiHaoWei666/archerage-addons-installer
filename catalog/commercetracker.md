# Commerce Tracker（经商追踪）

Folio105 的重写版：选路线，查看每个特产包的比率、售价，以及制作材料的成本和利润。界面沿用 Folio105。

## 与 Folio105 的差异
- **材料用 API 读取**：包的物品编号 → `X2Craft:GetCraftTypeByItemType` → `X2Craft:GetCraftMaterialInfo`，材料名称和数量跟随游戏资料与语系，不需要翻译表。
- 材料行显示为 `材料名 x数量`。
- 售价一律按最高新鲜度计算（没有切换按钮）。
- 查价时只取名称相符的拍卖结果；非卖品（`data/zones.lua` 的 `CT.AUCTION_EXCLUDED_ITEMS`）不查，成本算 0。
- 设定用 `ADDON:SaveData` 存档（依角色），不写文字档。
- 只支援中文与英文界面。
- 不要和 Folio105 同时启用（两者会同时送出路线查询；本插件会忽略不是自己送出的结果）。

## 使用
- 画面上的小图示：点一下开关主视窗，拖动可移动。
- 下方依序选择 大陆 → 起始区域 → 交货区域，就会查询路线比率（5 秒冷却，冷却中选单与重新整理停用）。
- 「查价」：依序查询目前所有特产材料的拍卖单价（每 1.2 秒一笔），再按一次停止。
- 「收藏」：右侧收藏栏，「+ 加入目前路线」收藏，点路线套用，× 删除。

## 售价
`售价 = 基础售价 × 比率 × (1 + 经商熟练度 × 0.05 / 10000) × 新鲜度倍率`
- 基础售价：`data/prices.lua`（沿用 Folio105 的实测资料），以英文包名对应。
  - 特产包：配方编号 → `data/specialties.lua` 的英文名称。
  - 其他包（发酵品、商会包）：配方资料里没有编号，沿用 Folio105 的名称判断（中文用关键字 + 起始区域组出英文名称）。
- 新鲜度倍率：`data/zones.lua`（豪华 1.30、高级 1.15、商业 1.05、保存 1.03；送到希德玛一律 1.30）。

## 文件
| 文件 | 内容 |
|---|---|
| `core.lua` | 命名空间 `CT`、共用函数 |
| `locale.lua` | 中英文文字 `CT.Text(key)` |
| `data/zones.lua` | 大陆、区域（英文名称、包等级）、新鲜度倍率、非卖品 |
| `data/specialties.lua` | 特产配方编号 → 英文名称 |
| `data/prices.lua` | 基础售价 |
| `trade.lua` | 路线比率查询、包的辨识与售价 |
| `auction.lua` | 材料拍卖查价佇列 |
| `settings.lua` | 存档：开关按钮位置、收藏路线 |
| `windows/widgets.lua` | 共用元件：金额显示、下拉选单、重新整理按钮 |
| `windows/main_window.lua` | 主视窗 |
| `windows/favorites.lua` | 收藏侧栏 |
| `windows/toggle_button.lua` | 开关按钮 |
| `main.lua` | 进入点（含重新载入时的初始化） |
| `common/` | 通用视窗函数（`CreateEmptyWindow`、`SettingWindowSkin`） |
| `icons/` | 图示（取自 Folio105） |

存档 key：`commercetracker_settings`。元件名称皆以 `ct` 开头。
