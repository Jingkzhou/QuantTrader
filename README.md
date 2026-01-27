# QuantTrader Pro (Version 1.26 Final)

## 项目概述
**QuantTrader Pro** 是一款基于 MT4 平台的自动化网格交易系统。本项目已升级至 **Version 1.0 Final**，核心逻辑基于反编译代码 1:1 精确复刻，专注于高频交易环境下的策略稳定性与风控能力。系统集成了智能双阶段网格、多重风控保护（逆势/顺势/对锁）、UI 可视化面板以及实时数据上报功能。

## 核心功能

### 1. 灵活的开单模式 (Order Open Logic)
系统支持三种开单模式，适应不同的市场节奏：
*   **Timeframe (A模式)**: 依据 K 线收盘价开单 (`OPEN_MODE_TIMEFRAME`)。
*   **Interval (B模式)**: 按照固定的时间间隔（秒）开单 (`OPEN_MODE_INTERVAL`)。
*   **Instant (C模式)**: 满足条件立即开单，无延迟 (`OPEN_MODE_INSTANT`)。

### 2. 双阶段网格策略 (Dual-Stage Grid)
根据账户盈亏状态，自动切换网格参数，实现进攻与防御的平衡：
*   **第一阶段**: 正常状态下，使用标准的 `GridStep` 和 `MinGridDistance`。
*   **第二阶段**: 当浮亏超过 `SecondParamTriggerLoss` 时触发，启用 `SecondGridStep` 和 `SecondMinGridDistance`，通常用于扩大间距以缓解亏损压力。

### 3. 多重风控保护体系 (Risk Protection)
系统内置多层级的保护机制，确保资金安全：

#### 3.1 逆势保护 (Reverse Protection)
*   **原理**: 当检测到“1个盈利单 vs 2个亏损单”且满足特定的手数比例（通常是多空严重失衡）时触发。
*   **动作**: 利用大额盈利单的利润，对冲平仓掉两个亏损单，实现“断臂求生”并释放保证金。

#### 3.2 顺势保护 (Trend Protection)
*   **原理**: 针对标记为 "SS"（顺势）的特定订单。
*   **动作**: 当整体利润达标时，优先平仓此类订单，锁定胜局。

#### 3.3 仓位失衡监控 (Overweight Status)
*   实时监控多空持仓对比，当一方手数显著大于另一方（例如 >3 倍且差值 >0.2 手）时，标记为超仓状态，作为策略调整的信号。

#### 3.4 价格限制 (Price Limits)
*   **首单限制**: `Buy/SellFirstOrderPriceLimit`，价格超过此线不进行首单开仓。
*   **补单限制**: `Buy/SellAddOrderPriceLimit`，价格超过此线不进行补单。

### 4. 交互式 UI 面板
内置高性能 GDI 绘图面板：
*   **StatisticsPanel**: 实时显示账户资金、保证金率、多空持仓详情（单数/手数/均价/保本价/浮盈）。
*   **ButtonPanel**: 提供快捷操作按钮：
    *   **暂停/恢复**: 独立控制多头或空头开仓。
    *   **一键平仓**: 平多、平空、全平。

### 5. 数据集成 (Data Reporting)
内置 HTTP 通信模块，支持与外部系统（如 Rust 后端）交互：
*   **行情上报**: 推送当前 ASK/BID 及 K 线数据。
*   **账户/持仓上报**: 实时推送账户净值与持仓状态。
*   **交易历史**: 平仓后自动上报交易记录。

---

## 详细参数说明

### 1. 价格限制 (Price Limit)
| 参数名                     | 默认值  | 说明                        |
| :------------------------- | :------ | :-------------------------- |
| `BuyFirstOrderPriceLimit`  | 0       | 多单首单价格上限（0为不限） |
| `SellFirstOrderPriceLimit` | 0       | 空单首单价格下限（0为不限） |
| `BuyAddOrderPriceLimit`    | 0       | 多单补单价格上限            |
| `SellAddOrderPriceLimit`   | 0       | 空单补单价格下限            |
| `PriceLimitStartTime`      | "00:00" | 限制生效开始时间            |
| `PriceLimitEndTime`        | "24:00" | 限制生效结束时间            |

### 2. 保护开关 (Protection)
| 参数名                    | 默认值 | 说明                     |
| :------------------------ | :----- | :----------------------- |
| `EnableReverseProtection` | true   | 开启逆势对冲保护         |
| `EnableTrendProtection`   | true   | 开启顺势保护             |
| `EnableLockTrend`         | false  | 启用完全对锁时的顺势开关 |
| `StopAfterClose`          | false  | 整体平仓后停止 EA 运行   |
| `RestartDelaySeconds`     | 0      | 整体平仓后冷却时间（秒） |

### 3. 网格距离 (Grid Distance)
| 参数名                    | 默认值 | 说明                                 |
| :------------------------ | :----- | :----------------------------------- |
| `SecondParamTriggerLoss`  | 0      | 启用第二组参数的浮亏阈值（自动转负） |
| `FirstOrderDistance`      | 30     | 首单开仓距离（点）                   |
| `MinGridDistance`         | 60     | 第一组最小间距                       |
| `SecondMinGridDistance`   | 60     | 第二组最小间距                       |
| `GridStep`                | 100    | 第一组补单步长                       |
| `SecondGridStep`          | 100    | 第二组补单步长                       |
| `PendingOrderTrailPoints` | 5      | 挂单追踪距离                         |

### 4. 开单控制 (Order Control)
| 参数名                 | 默认值      | 说明                               |
| :--------------------- | :---------- | :--------------------------------- |
| `OrderOpenMode`        | 3 (Instant) | 1=Timeframe, 2=Interval, 3=Instant |
| `OrderTimeframe`       | PERIOD_M1   | 开单参考周期                       |
| `OrderIntervalSeconds` | 30          | Mode 2 的开单间隔秒数              |

### 5. 资金管理 (Money Management)
| 参数名          | 默认值 | 说明                               |
| :-------------- | :----- | :--------------------------------- |
| `BaseLotSize`   | 0.01   | 起始手数                           |
| `LotMultiplier` | 1.3    | 加仓倍率                           |
| `LotIncrement`  | 0      | 手数累加值（Lot = Prev*Mul + Inc） |
| `MaxLotSize`    | 10     | 单笔最大手数                       |

### 6. 止盈止损 (TP/SL)
| 参数名                | 默认值 | 说明                       |
| :-------------------- | :----- | :------------------------- |
| `TotalProfitTarget`   | 0.5    | 整体金额止盈               |
| `EnableLayeredProfit` | true   | 是否开启单边金额按层数累加 |
| `SingleSideProfit`    | 2      | 单边金额止盈（基数）       |
| `StopLossAmount`      | 0      | 整体金额止损（0为不设）    |

### 7. 其他设置
| 参数名           | 默认值   | 说明               |
| :--------------- | :------- | :----------------- |
| `MagicNumber`    | 9527     | EA 识别码          |
| `MaxTotalOrders` | 50       | 最大总单量限制     |
| `RustServerUrl`  | ...:3001 | 数据上报服务器地址 |
| `EnableDataLoop` | true     | 开启数据上报循环   |

## 安装与使用
1.  将 `QuantTrader_Pro.mq4` 放入 MT4 的 `Experts` 文件夹。
2.  确保开启 "允许自动交易 (Allow Auto Trading)" 和 "允许 DLL 导入 (Allow DLL imports)"。
3.  若需使用数据上报功能，请在 `工具 -> 选项 -> 智能交易系统` 中勾选 "允许 WebRequest"，并添加 `RustServerUrl` 到白名单。
4.  加载 EA 到任意图表（建议 M1 或 M5 周期）。
5.  在面板上检查网络连接状态与各项参数。

## 版本历史
*   **v1.26**: 修复: 修改持仓上报逻辑为全账户模式，解决多品种运行时持仓显示闪烁的问题
*   **v1.25**: 修复: 增加 StopLevel 检查防止错误 136 (Off quotes)
*   **v1.24**: Fixed: Increased WebRequest timeout to 3000ms
*   **v1.23**: Config: Reverted RustServerUrl for VM setup
*   **v1.22**: Config: Changed default RustServerUrl to localhost
*   **v1.21**: Fixed compilation error: Removed duplicate 'lastReportTime' declaration
*   **v1.20**: 修复 WebRequest 阻塞主线程的致命问题 (深度优化)
*   **v1.0 Final**: 初始重构版本，完整复刻核心逻辑与 UI 系统。