# QuantTrader Pro V4.1 需求规格说明书

## 1. 项目概述
QuantTrader Pro 是一款面向 XAUUSD 及主流外汇品种的 MT4 全自动量化交易系统。V4.1 引入**多产品适配体系**，支持 6 种产品预设配置自动加载，配合三重风险防火墙与 ATR 动态波动率适配，使 EA 能够智能适应不同产品的波动特性。

目标：在保持顺势收割效率的同时，降低单边压力，提供可控的风险边界、智能产品适配与更细致的人工干预能力。

## 2. 版本功能要点

### 2.0 V4.1 多产品适配体系 (Product Adaptive) `NEW`
- **产品预设配置**：内置 6 种产品优化参数（黄金/白银/欧美/镑美/美日/比特币）
- **自动产品识别**：根据交易品种代码自动识别产品类型并加载对应配置
- **交易时段过滤**：根据产品特性自动控制交易时段，避开低流动性时段
- **周末控制**：支持加密货币 24/7 交易，传统品种自动周末休市
- **UI 面板增强**：显示当前产品类型与交易时段状态

### 2.0.1 资金层级体系 (Capital Tier System) `NEW`
基于资金规模的 4 级"地质层级"配置，每一层级对应完全不同的策略逻辑和参数：

| 层级 | 资金范围 | 代号 | 风险等级 | 核心特征 |
|:---:|:---|:---|:---:|:---|
| Lv.1 | $100 - $2,000 | 实验室 Laboratory | 9/10 | 高杠杆测试，建议美分账户，追求高 ROE |
| Lv.2 | $2,000 - $10,000 | 特种兵 Soldier | 6/10 | 单兵作战主战场，斐波那契均衡策略 |
| Lv.3 | $10,000 - $50,000 | 指挥官 Commander | 4/10 | 组合对冲，多品种分散，月化 5-10% |
| Lv.4 | $100,000+ | 鲸鱼 Whale | 2/10 | 机构级保守，线性加仓，年化 20-30% |

**自动检测**：EA 根据 `AccountBalance()` 自动识别当前层级并应用对应参数。

### 2.1 V4 三重风险防火墙
- **账户级硬止损 (Circuit Breaker)**：当净值回撤达到 `InpEquityStopPct`，强制全平并关机。
- **单日风控 (Daily Loss Limit)**：当日已实现亏损 + 当前浮亏 >= 余额 × `InpDailyLossPct`，强制全平并当日停机。
- **技术性断裂 (Technical Breakdown)**：单边层数达到 `InpMaxLayerPerSide` 或浮亏点数 >= `InpMaxAdversePoints`，强制平掉该方向并关闭该方向开关。

### 2.2 V3.9 ATR 动态波动率适配 (Volatility Adaptive)
- **动态网格**：废除固定点数间距，使用 ATR 动态计算补仓距离。
- **两种模式**：
  - **直接模式**：`GridDist = InpATRMultiplier * ATR(Period)`
  - **缩放模式**：`GridDist = BaseDist * (CurrentATR / InpBaseATRPoints)`
- **层级保持**：后续层仍沿用 `GridDistLayer2 / GridMinDist` 的间距比例。

### 2.3 V3.8 低压加仓优化
- **多模式加仓**：指数、斐波那契、线性三种模式可选。
- **衰减机制**：达到指定层数后使用衰减倍率，避免手数指数爆炸。
- **单笔封顶**：单笔最大手数限制。
- **动态扩距**：第 4 层起每加一层，补仓间距 +20%。
- **单边独立止盈**：按多/空总手数与目标点数换算的金额进行分开止盈。

### 2.4 V3.7 面板交互增强
- 交易状态与数据可视化面板。
- 按钮式多空开关、全平、暂停/恢复。

### 2.5 V3.6 机构级功能
- **双向启动**：可自动补齐多/空首单。
- **保本/锁盈**：达到指定盈利点数后自动推移止损。

### 2.6 V3.5 首尾对冲减仓
- 当同侧订单层数达到阈值，若最早单 + 最新单合计盈利达标，则同时平仓减压。

## 3. 交易逻辑说明

### 3.1 OnTick 主流程
1. 执行 V4 三重风控检查（可能强平并停机）。
2. 若系统暂停或触发风险锁定，仅刷新面板并返回。
3. 若启用首尾对冲，执行减仓检测。
4. 执行保本/锁盈检查。
5. 若启用双向模式，确保多/空首单存在。
6. 执行马丁网格逻辑（独立止盈 + 加仓）。
7. 刷新面板数据。

### 3.2 账户级硬止损 (Circuit Breaker)
- 当净值回撤达到 `InpEquityStopPct`（如 25%）时，强制全平并关机。
- 触发后保持停机，需人工重新启动策略。

### 3.3 单日风控 (Daily Loss Limit)
- 计算公式：`当日已实现盈亏 + 当前浮动盈亏`（净值日内变化）。
- 当净值下降达到 `余额 × InpDailyLossPct` 时，强制全平并当日停机，次日自动解除。

### 3.4 技术性断裂 (Technical Breakdown)
- 单边层数达到 `InpMaxLayerPerSide` 或单边浮亏点数 >= `InpMaxAdversePoints` 时，强制平掉该方向所有持仓。
- 触发后关闭该方向开关，需手动重新开启。

### 3.5 独立止盈
- 多头目标金额 = 多头总手数 × `InpTargetPips` × 单位点值。
- 空头目标金额 = 空头总手数 × `InpTargetPips` × 单位点值。
- 任一方向浮盈达到目标则只平该方向持仓。

### 3.6 加仓触发与间距
- 基础间距采用 ATR 动态计算，并保留首层/后续层的间距比例：
  - 直接模式：`GridDist = InpATRMultiplier * ATR(Period)`
  - 缩放模式：`GridDist = BaseDist * (CurrentATR / InpBaseATRPoints)`
- 后续层按 `GridDistLayer2 / GridMinDist` 比例放大。
- ATR 计算周期由 `InpATRTF` 与 `InpATRPeriod` 决定。
- 启用动态扩距后，层数 >= 4 时每层间距扩大 20%。

### 3.7 低压手数算法
- **指数模式**：手数 = 上一单手数 × 倍率；达到衰减层后改用 `InpDecayMulti`。
- **斐波那契模式**：手数 = 最近两单手数之和（首单回退至初始手数）。
- **线性模式**：手数 = 上一单手数 + 初始手数。
- 手数最终受 `InpMaxSingleLot` 封顶。

### 3.8 单边浮亏限制
- `InpSingleSideMaxLoss` > 0 时，若该方向浮盈 < -最大值，则禁止继续加仓。
- 设为 0 则不限制。

### 3.9 保本/锁盈
- 多单盈利达到 `InpBEProfitPips` 后，止损上移到开仓价 + `InpBELockPips`。
- 空单盈利达到 `InpBEProfitPips` 后，止损下移到开仓价 - `InpBELockPips`。

### 3.10 首尾对冲减仓
- 达到 `InpDestockMinLayer` 层数后，若最早单 + 最新单合计盈亏 >= `InpDestockProfit`，则同时平仓。

## 4. 参数定义

| 分组 | 参数名 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| **V4.1 产品配置** | `InpUsePreset` | true | 是否使用产品预设配置。 |
| | `InpProductType` | `PRODUCT_GOLD` | 产品类型选择（黄金/白银/欧美/镑美/美日/比特币）。 |
| | `InpEnableSession` | true | 是否启用交易时段过滤。 |
| **V4.1 资金层级** | `InpAutoTier` | true | 自动检测资金层级（根据余额）。 |
| | `InpCapitalTier` | `TIER_SOLDIER` | 手动选择层级（实验室/特种兵/指挥官/鲸鱼）。 |
| **V4 风控防火墙** | `InpEquityStopPct` | 25.0 | 账户级硬止损回撤比例 (%)。 |
| | `InpDailyLossPct` | 5.0 | 单日亏损限制比例 (%)。 |
| | `InpMaxLayerPerSide` | 12 | 单边最大层数。 |
| | `InpMaxAdversePoints` | 2000 | 单边最大浮亏点数。 |
| **V3.9 ATR 动态适配** | `InpUseATRGrid` | true | 是否启用 ATR 动态网格。 |
| | `InpATRMode` | `ATR_DIRECT` | 动态模式：直接/缩放。 |
| | `InpATRTF` | `PERIOD_H1` | ATR 计算周期。 |
| | `InpATRPeriod` | 14 | ATR 周期。 |
| | `InpATRMultiplier` | 0.5 | 直接模式倍率。 |
| | `InpBaseATRPoints` | 1000 | 缩放模式基准 ATR 点数。 |
| **V3.8 低压加仓设置** | `InpMartinMode` | `MODE_FIBONACCI` | 加仓模式：指数/斐波那契/线性。 |
| | `InpMaxSingleLot` | 0.50 | 单笔最大手数。 |
| | `InpDecayStep` | 6 | 从第几层开始衰减倍率（指数模式）。 |
| | `InpDecayMulti` | 1.1 | 衰减后的倍率（指数模式）。 |
| | `InpGridExpansion` | true | 是否开启动态间距扩张。 |
| **V3.7 UI 面板设置** | `UI_X_Offset` | 50 | 面板 X 轴偏移。 |
| | `UI_Y_Offset` | 50 | 面板 Y 轴偏移。 |
| | `UI_ThemeColor` | `C'0,128,128'` | 面板主题色。 |
| **V3.6 机构级设置** | `InpEnableDualMode` | true | 是否启用双向启动。 |
| | `InpBEProfitPips` | 80 | 触发保本的盈利点数。 |
| | `InpBELockPips` | 10 | 保本后锁定点数。 |
| **V3.5 首尾对冲设置** | `InpEnableDualHedge` | true | 是否启用首尾对冲减仓。 |
| | `InpDestockMinLayer` | 6 | 触发减仓的最少层数。 |
| | `InpDestockProfit` | 1.0 | 首尾合计盈利门槛（货币）。 |
| **风控与核心参数** | `InpUseDynamicTP` | true | 预留开关，当前逻辑未使用。 |
| | `InpTargetPips` | 150 | 单边目标点数（用于独立止盈）。 |
| | `InpSingleSideMaxLoss` | 500.0 | 单边最大浮亏限制（货币）。 |
| | `InpMagicNum` | 999008 | 魔术号。 |
| | `InpInitialLots` | 0.01 | 初始手数。 |
| | `MartinMulti` | 1.5 | 指数模式默认倍率。 |
| | `GridMinDist` | 100 | 首次补仓基准间距（点），用于 ATR 缩放与层级比例。 |
| | `GridDistLayer2` | 300 | 后续补仓基准间距（点），用于层级比例。 |

### 4.1 产品预设参数对比

| 产品 | ATR倍率 | 马丁模式 | 最大层数 | 封顶手数 | 目标点数 | 交易时段 (GMT) |
|:---|:---:|:---:|:---:|:---:|:---:|:---|
| **XAUUSD** 黄金 | 0.5 | 斐波那契 | 12 | 0.50 | 150 | 08:00-22:00 |
| **XAGUSD** 白银 | 0.8 | 指数衰减 | 8 | 0.30 | 250 | 08:00-20:00 |
| **EURUSD** 欧美 | 0.3 | 线性 | 18 | 1.00 | 80 | 07:00-16:00 |
| **GBPUSD** 镑美 | 0.6 | 斐波那契 | 10 | 0.30 | 120 | 08:00-17:00 |
| **USDJPY** 美日 | 0.4 | 线性 | 15 | 0.50 | 100 | 06:00-15:00 |
| **BTCUSD** 比特币 | 0.8 | 线性 | 5 | 0.10 | 300 | 24H + 周末 |

## 5. UI 交互设计 (Dashboard)
面板风格：深色战术仪表盘风格，左侧主题色竖条 + 顶部标题栏，数值采用等宽字体强调精度。

布局分区：
1. **产品配置** `V4.1 新增`：当前产品类型 + 交易时段状态（显示"时段: HH:MM-HH:MM"或"休市中"）
2. **策略状态**：多/空状态芯片 + 当前加仓模式。
3. **收益表现**：今日获利金额/百分比（正负变色）+ 双向目标金额。
4. **账户数据**：余额、已用保证金、保证金率。
5. **手动控制**：
   - [多头开关] / [空头开关]
   - [全平清仓]
   - [系统运行中/暂停]（按钮颜色随状态切换）

## 6. 逻辑流程图 (Mermaid)

```mermaid
graph TD
    Start[OnTick] --> Risk{三重风控}
    Risk -- 触发熔断/单日止损 --> Stop[全平并停机]
    Risk -- 触发断裂 --> SideClose[单边强平并关停方向]
    Risk -- 通过 --> Pause{系统暂停?}
    Pause -- Yes --> UIOnly[刷新面板]
    Pause -- No --> Hedge{首尾对冲减仓}
    Hedge --> BE{保本/锁盈检查}
    BE --> Dual{双向启动?}
    Dual --> Martingale{马丁逻辑}
    Martingale --> TP{单边独立止盈}
    TP --> Add{加仓判定}
    Add --> UI[刷新面板]
    Stop --> UI
    SideClose --> UI
```
