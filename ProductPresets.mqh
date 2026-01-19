//+------------------------------------------------------------------+
//|                                            ProductPresets.mqh    |
//|                                  Copyright 2026, Antigravity AI  |
//|                        产品配置预设模块 - 多品种参数适配体系           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property strict

//====================================================================
//                       产品类型枚举
//====================================================================
enum ENUM_PRODUCT_TYPE {
   PRODUCT_GOLD,        // 黄金 (XAUUSD)
   PRODUCT_SILVER,      // 白银 (XAGUSD)
   PRODUCT_EURUSD,      // 欧美
   PRODUCT_GBPUSD,      // 镑美
   PRODUCT_USDJPY,      // 美日
   PRODUCT_AUDUSD,      // 澳美
   PRODUCT_CRYPTO_BTC,  // 比特币
   PRODUCT_CRYPTO_ETH,  // 以太坊
   PRODUCT_INDEX_US30,  // 道琼斯
   PRODUCT_INDEX_NAS,   // 纳斯达克
   PRODUCT_CUSTOM       // 自定义
};

//====================================================================
//                       资金层级枚举 (Capital Tier)
//====================================================================
enum ENUM_CAPITAL_TIER {
   TIER_LABORATORY,     // Lv.1 实验室 ($100-$2,000) - 高风险测试
   TIER_SOLDIER,        // Lv.2 特种兵 ($2,000-$10,000) - 单兵作战
   TIER_COMMANDER,      // Lv.3 指挥官 ($10,000-$50,000) - 组合对冲
   TIER_WHALE           // Lv.4 鲸鱼 ($100,000+) - 机构级保守
};

//====================================================================
//                       层级配置结构体 (Tier Config)
//====================================================================
struct TierConfig {
   ENUM_CAPITAL_TIER tier;        // 层级类型
   string         tierName;       // 层级名称
   double         capitalMin;     // 资金下限
   double         capitalMax;     // 资金上限
   
   // 核心参数调整
   double         initialLots;    // 起始手数
   double         lotMultiplier;  // 相对于基准的手数倍率
   double         distMultiplier; // 网格间距倍率
   int            martinMode;     // 推荐马丁模式 (0=指数,1=斐波,2=线性)
   int            maxLayers;      // 最大层数限制
   double         maxSingleLot;   // 单笔封顶
   
   // 风控参数调整
   double         equityStopPct;  // 熔断比例
   double         dailyLossPct;   // 单日止损
   double         riskLevel;      // 风险等级 (1-10)
   
   // 策略建议
   bool           portfolioMode;  // 是否支持多品种组合
   bool           useCentAccount; // 建议使用美分账户
   string         description;    // 层级描述
};

//====================================================================
//                       产品配置结构体
//====================================================================
struct ProductConfig {
   string         symbol;           // 产品代码
   ENUM_PRODUCT_TYPE type;          // 产品类型
   
   // ATR 动态网格参数
   double         atrMultiplier;    // ATR 倍率
   int            atrPeriod;        // ATR 周期
   ENUM_TIMEFRAMES atrTimeframe;    // ATR 时间框架
   
   // 马丁加仓参数  
   int            martinMode;       // 0=指数, 1=斐波那契, 2=线性
   double         martinMulti;      // 指数模式倍率
   int            decayStep;        // 衰减起始层
   double         decayMulti;       // 衰减后倍率
   double         maxSingleLot;     // 单笔封顶手数
   int            maxLayers;        // 最大层数
   
   // 止盈止损
   int            targetPips;       // 目标点数
   double         dailyLossPct;     // 单日止损比例
   double         equityStopPct;    // 熔断比例
   double         singleSideMaxLoss;// 单边最大浮亏(货币)
   int            maxAdversePoints; // 单边最大浮亏点数
   
   // 网格基础间距
   int            gridMinDist;      // 首层间距
   int            gridDistLayer2;   // 后续层间距
   bool           gridExpansion;    // 动态间距扩张
   
   // 交易时段 (GMT 小时)
   int            sessionStartHour; // 允许交易开始
   int            sessionEndHour;   // 允许交易结束
   bool           allowWeekend;     // 周末交易
   
   // 首尾对冲
   int            destockMinLayer;  // 对冲触发层数
   double         destockProfit;    // 对冲盈利门槛
   
   // 保本锁盈
   int            beProfitPips;     // 保本触发点数
   int            beLockPips;       // 锁定点数
};

//====================================================================
//                       预设配置 - 黄金 (XAUUSD)
//====================================================================
ProductConfig GetGoldConfig() {
   ProductConfig cfg;
   cfg.symbol = "XAUUSD";
   cfg.type = PRODUCT_GOLD;
   
   // ATR 参数 - 黄金高波动，使用 0.5 倍率
   cfg.atrMultiplier = 0.5;
   cfg.atrPeriod = 14;
   cfg.atrTimeframe = PERIOD_H1;
   
   // 马丁参数 - 斐波那契模式，平滑加仓
   cfg.martinMode = 1;  // 斐波那契
   cfg.martinMulti = 1.5;
   cfg.decayStep = 6;
   cfg.decayMulti = 1.1;
   cfg.maxSingleLot = 0.50;
   cfg.maxLayers = 12;
   
   // 止盈止损
   cfg.targetPips = 150;
   cfg.dailyLossPct = 5.0;
   cfg.equityStopPct = 25.0;
   cfg.singleSideMaxLoss = 500.0;
   cfg.maxAdversePoints = 2000;
   
   // 网格间距
   cfg.gridMinDist = 100;
   cfg.gridDistLayer2 = 300;
   cfg.gridExpansion = true;
   
   // 交易时段 (避开亚盘低流动性)
   cfg.sessionStartHour = 8;   // GMT 08:00
   cfg.sessionEndHour = 22;    // GMT 22:00
   cfg.allowWeekend = false;
   
   // 首尾对冲
   cfg.destockMinLayer = 6;
   cfg.destockProfit = 1.0;
   
   // 保本锁盈
   cfg.beProfitPips = 80;
   cfg.beLockPips = 10;
   
   return cfg;
}

//====================================================================
//                       预设配置 - 白银 (XAGUSD)
//====================================================================
ProductConfig GetSilverConfig() {
   ProductConfig cfg;
   cfg.symbol = "XAGUSD";
   cfg.type = PRODUCT_SILVER;
   
   // ATR 参数 - 白银波动巨大，使用 0.8 倍率
   cfg.atrMultiplier = 0.8;
   cfg.atrPeriod = 14;
   cfg.atrTimeframe = PERIOD_H1;
   
   // 马丁参数 - 衰减指数模式，保守
   cfg.martinMode = 0;  // 指数
   cfg.martinMulti = 1.3;
   cfg.decayStep = 4;
   cfg.decayMulti = 1.1;
   cfg.maxSingleLot = 0.30;
   cfg.maxLayers = 8;
   
   // 止盈止损 - 更宽目标
   cfg.targetPips = 250;
   cfg.dailyLossPct = 6.0;
   cfg.equityStopPct = 25.0;
   cfg.singleSideMaxLoss = 400.0;
   cfg.maxAdversePoints = 3000;
   
   // 网格间距 - 宽间距
   cfg.gridMinDist = 200;
   cfg.gridDistLayer2 = 500;
   cfg.gridExpansion = true;
   
   // 交易时段
   cfg.sessionStartHour = 8;
   cfg.sessionEndHour = 20;
   cfg.allowWeekend = false;
   
   // 首尾对冲
   cfg.destockMinLayer = 5;
   cfg.destockProfit = 2.0;
   
   // 保本锁盈
   cfg.beProfitPips = 120;
   cfg.beLockPips = 20;
   
   return cfg;
}

//====================================================================
//                       预设配置 - 欧美 (EURUSD)
//====================================================================
ProductConfig GetEURUSDConfig() {
   ProductConfig cfg;
   cfg.symbol = "EURUSD";
   cfg.type = PRODUCT_EURUSD;
   
   // ATR 参数 - 欧美低波动，使用 0.3 倍率
   cfg.atrMultiplier = 0.3;
   cfg.atrPeriod = 14;
   cfg.atrTimeframe = PERIOD_H1;
   
   // 马丁参数 - 线性递增，稳健
   cfg.martinMode = 2;  // 线性
   cfg.martinMulti = 1.5;
   cfg.decayStep = 10;
   cfg.decayMulti = 1.0;
   cfg.maxSingleLot = 1.00;
   cfg.maxLayers = 18;
   
   // 止盈止损 - 较窄目标
   cfg.targetPips = 80;
   cfg.dailyLossPct = 3.0;
   cfg.equityStopPct = 20.0;
   cfg.singleSideMaxLoss = 300.0;
   cfg.maxAdversePoints = 800;
   
   // 网格间距 - 密集网格
   cfg.gridMinDist = 30;
   cfg.gridDistLayer2 = 80;
   cfg.gridExpansion = false;  // 波动小不需扩张
   
   // 交易时段 (欧美重叠)
   cfg.sessionStartHour = 7;
   cfg.sessionEndHour = 16;
   cfg.allowWeekend = false;
   
   // 首尾对冲
   cfg.destockMinLayer = 8;
   cfg.destockProfit = 0.5;
   
   // 保本锁盈
   cfg.beProfitPips = 50;
   cfg.beLockPips = 5;
   
   return cfg;
}

//====================================================================
//                       预设配置 - 镑美 (GBPUSD)
//====================================================================
ProductConfig GetGBPUSDConfig() {
   ProductConfig cfg;
   cfg.symbol = "GBPUSD";
   cfg.type = PRODUCT_GBPUSD;
   
   // ATR 参数 - 镑美中高波动
   cfg.atrMultiplier = 0.6;
   cfg.atrPeriod = 20;
   cfg.atrTimeframe = PERIOD_H1;
   
   // 马丁参数 - 斐波那契
   cfg.martinMode = 1;
   cfg.martinMulti = 1.5;
   cfg.decayStep = 5;
   cfg.decayMulti = 1.15;
   cfg.maxSingleLot = 0.30;
   cfg.maxLayers = 10;
   
   // 止盈止损
   cfg.targetPips = 120;
   cfg.dailyLossPct = 4.0;
   cfg.equityStopPct = 22.0;
   cfg.singleSideMaxLoss = 400.0;
   cfg.maxAdversePoints = 1200;
   
   // 网格间距
   cfg.gridMinDist = 60;
   cfg.gridDistLayer2 = 150;
   cfg.gridExpansion = true;
   
   // 交易时段
   cfg.sessionStartHour = 8;
   cfg.sessionEndHour = 17;
   cfg.allowWeekend = false;
   
   // 首尾对冲
   cfg.destockMinLayer = 5;
   cfg.destockProfit = 1.5;
   
   // 保本锁盈
   cfg.beProfitPips = 70;
   cfg.beLockPips = 10;
   
   return cfg;
}

//====================================================================
//                       预设配置 - 美日 (USDJPY)
//====================================================================
ProductConfig GetUSDJPYConfig() {
   ProductConfig cfg;
   cfg.symbol = "USDJPY";
   cfg.type = PRODUCT_USDJPY;
   
   // ATR 参数
   cfg.atrMultiplier = 0.4;
   cfg.atrPeriod = 14;
   cfg.atrTimeframe = PERIOD_H1;
   
   // 马丁参数 - 线性，因日本央行干预风险
   cfg.martinMode = 2;
   cfg.martinMulti = 1.5;
   cfg.decayStep = 8;
   cfg.decayMulti = 1.0;
   cfg.maxSingleLot = 0.50;
   cfg.maxLayers = 15;
   
   // 止盈止损
   cfg.targetPips = 100;
   cfg.dailyLossPct = 4.0;
   cfg.equityStopPct = 22.0;
   cfg.singleSideMaxLoss = 400.0;
   cfg.maxAdversePoints = 1000;
   
   // 网格间距
   cfg.gridMinDist = 40;
   cfg.gridDistLayer2 = 100;
   cfg.gridExpansion = false;
   
   // 交易时段 (避开日本央行干预时段)
   cfg.sessionStartHour = 6;
   cfg.sessionEndHour = 15;
   cfg.allowWeekend = false;
   
   // 首尾对冲
   cfg.destockMinLayer = 7;
   cfg.destockProfit = 0.8;
   
   // 保本锁盈
   cfg.beProfitPips = 60;
   cfg.beLockPips = 8;
   
   return cfg;
}

//====================================================================
//                       预设配置 - 比特币 (BTCUSD)
//====================================================================
ProductConfig GetBTCConfig() {
   ProductConfig cfg;
   cfg.symbol = "BTCUSD";
   cfg.type = PRODUCT_CRYPTO_BTC;
   
   // ATR 参数 - 极高波动
   cfg.atrMultiplier = 0.8;
   cfg.atrPeriod = 24;
   cfg.atrTimeframe = PERIOD_H1;
   
   // 马丁参数 - 不加仓纯网格
   cfg.martinMode = 2;  // 线性但封顶极低
   cfg.martinMulti = 1.0;
   cfg.decayStep = 3;
   cfg.decayMulti = 1.0;
   cfg.maxSingleLot = 0.10;
   cfg.maxLayers = 5;
   
   // 止盈止损 - 宽幅
   cfg.targetPips = 300;
   cfg.dailyLossPct = 8.0;
   cfg.equityStopPct = 30.0;
   cfg.singleSideMaxLoss = 600.0;
   cfg.maxAdversePoints = 5000;
   
   // 网格间距 - 超宽
   cfg.gridMinDist = 500;
   cfg.gridDistLayer2 = 1000;
   cfg.gridExpansion = true;
   
   // 交易时段 - 24小时
   cfg.sessionStartHour = 0;
   cfg.sessionEndHour = 24;
   cfg.allowWeekend = true;  // 加密货币周末交易
   
   // 首尾对冲
   cfg.destockMinLayer = 3;
   cfg.destockProfit = 5.0;
   
   // 保本锁盈
   cfg.beProfitPips = 200;
   cfg.beLockPips = 50;
   
   return cfg;
}

//====================================================================
//                       通用配置获取函数
//====================================================================
ProductConfig GetProductConfig(ENUM_PRODUCT_TYPE productType) {
   switch(productType) {
      case PRODUCT_GOLD:      return GetGoldConfig();
      case PRODUCT_SILVER:    return GetSilverConfig();
      case PRODUCT_EURUSD:    return GetEURUSDConfig();
      case PRODUCT_GBPUSD:    return GetGBPUSDConfig();
      case PRODUCT_USDJPY:    return GetUSDJPYConfig();
      case PRODUCT_CRYPTO_BTC: return GetBTCConfig();
      default:                return GetGoldConfig();  // 默认黄金配置
   }
}

//====================================================================
//                       自动产品识别
//====================================================================
ENUM_PRODUCT_TYPE DetectProductType(string symbol) {
   string sym = symbol;
   StringToUpper(sym);
   
   // 贵金属
   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
      return PRODUCT_GOLD;
   if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
      return PRODUCT_SILVER;
   
   // 主流货币对
   if(StringFind(sym, "EURUSD") >= 0)
      return PRODUCT_EURUSD;
   if(StringFind(sym, "GBPUSD") >= 0)
      return PRODUCT_GBPUSD;
   if(StringFind(sym, "USDJPY") >= 0)
      return PRODUCT_USDJPY;
      
   // 加密货币
   if(StringFind(sym, "BTC") >= 0)
      return PRODUCT_CRYPTO_BTC;
   if(StringFind(sym, "ETH") >= 0)
      return PRODUCT_CRYPTO_ETH;
      
   // 股指
   if(StringFind(sym, "US30") >= 0 || StringFind(sym, "DJI") >= 0)
      return PRODUCT_INDEX_US30;
   if(StringFind(sym, "NAS") >= 0 || StringFind(sym, "NDX") >= 0)
      return PRODUCT_INDEX_NAS;
   
   // 默认返回黄金 (作为中等波动参考)
   return PRODUCT_GOLD;
}

//====================================================================
//                       日志输出配置详情
//====================================================================
void PrintProductConfig(ProductConfig &cfg) {
   Print("=== 产品配置详情 ===");
   Print("代码: ", cfg.symbol, " | 类型: ", EnumToString(cfg.type));
   Print("ATR: 倍率=", cfg.atrMultiplier, " 周期=", cfg.atrPeriod);
   Print("马丁: 模式=", cfg.martinMode, " 最大层数=", cfg.maxLayers, " 封顶=", cfg.maxSingleLot);
   Print("风控: 目标=", cfg.targetPips, "点 单日止损=", cfg.dailyLossPct, "% 熔断=", cfg.equityStopPct, "%");
   Print("交易时段: ", cfg.sessionStartHour, ":00 - ", cfg.sessionEndHour, ":00 GMT");
   Print("========================");
}

//====================================================================
//                       交易时段检查
//====================================================================
bool IsWithinTradingSession(ProductConfig &cfg) {
   // 如果开始等于结束，表示24小时交易
   if(cfg.sessionStartHour == cfg.sessionEndHour || 
      (cfg.sessionStartHour == 0 && cfg.sessionEndHour == 24))
      return true;
   
   // 修正：使用 TimeCurrent() 替代 TimeGMT()
   // 因为大多数 MT4 服务器时间是 GMT+2 或 GMT+3
   datetime serverTime = TimeCurrent();
   int currentHour = TimeHour(serverTime);
   
   // 处理跨午夜的时段
   if(cfg.sessionStartHour < cfg.sessionEndHour) {
      // 正常时段 (如 8-22)
      return (currentHour >= cfg.sessionStartHour && currentHour < cfg.sessionEndHour);
   } else {
      // 跨午夜时段 (如 22-6)
      return (currentHour >= cfg.sessionStartHour || currentHour < cfg.sessionEndHour);
   }
}

//====================================================================
//                       周末检查
//====================================================================
bool IsWeekend() {
   // 修正：使用 TimeCurrent() 替代 TimeGMT()
   datetime serverTime = TimeCurrent();
   int dayOfWeek = TimeDayOfWeek(serverTime);
   return (dayOfWeek == 0 || dayOfWeek == 6);  // 周日=0, 周六=6
}

//====================================================================
//                       综合交易许可检查
//====================================================================
bool IsTradingAllowedByProduct(ProductConfig &cfg) {
   // 周末检查
   if(IsWeekend() && !cfg.allowWeekend) {
      return false;
   }
   
   // 时段检查
   if(!IsWithinTradingSession(cfg)) {
      return false;
   }
   
   return true;
}

//====================================================================
//              资金层级预设 - Lv.1 实验室 (Laboratory)
//====================================================================
TierConfig GetLaboratoryTier() {
   TierConfig tier;
   tier.tier = TIER_LABORATORY;
   tier.tierName = "实验室";
   tier.capitalMin = 100;
   tier.capitalMax = 2000;
   
   // 核心参数 - 激进，追求高 ROE
   tier.initialLots = 0.01;      // 标准户最小手数
   tier.lotMultiplier = 1.0;     // 基准倍率
   tier.distMultiplier = 0.6;    // 窄间距，快速成交
   tier.martinMode = 0;          // 指数模式 (激进)
   tier.maxLayers = 8;           // 受限于资金，最多 6-8 层
   tier.maxSingleLot = 0.10;     // 封顶低
   
   // 风控 - 高风险，断臂求生
   tier.equityStopPct = 30.0;    // 宽松熔断（小资金翻倍才有意义）
   tier.dailyLossPct = 10.0;     // 高日亏容忍
   tier.riskLevel = 9;           // 风险等级 9/10
   
   // 策略建议
   tier.portfolioMode = false;   // 单品种
   tier.useCentAccount = true;   // 强烈建议美分账户
   tier.description = "验证阶段，资金有限，追求高 ROE，爆仓当交学费";
   
   return tier;
}

//====================================================================
//              资金层级预设 - Lv.2 特种兵 (Soldier)
//====================================================================
TierConfig GetSoldierTier() {
   TierConfig tier;
   tier.tier = TIER_SOLDIER;
   tier.tierName = "特种兵";
   tier.capitalMin = 2000;
   tier.capitalMax = 10000;
   
   // 核心参数 - 均衡，单兵作战
   tier.initialLots = 0.01;      // 锁死 0.01
   tier.lotMultiplier = 1.0;     // 基准倍率
   tier.distMultiplier = 1.0;    // 标准间距
   tier.martinMode = 1;          // 斐波那契 (均衡)
   tier.maxLayers = 12;          // 可跑完整斐波那契数列
   tier.maxSingleLot = 0.30;     // 中等封顶
   
   // 风控 - 均衡，硬止损保命
   tier.equityStopPct = 20.0;    // 标准熔断
   tier.dailyLossPct = 5.0;      // 标准日亏
   tier.riskLevel = 6;           // 风险等级 6/10
   
   // 策略建议
   tier.portfolioMode = false;   // 1-2 品种
   tier.useCentAccount = false;  // 标准账户
   tier.description = "主战场，专注单品种效率，依赖硬止损断臂求生";
   
   return tier;
}

//====================================================================
//              资金层级预设 - Lv.3 指挥官 (Commander)
//====================================================================
TierConfig GetCommanderTier() {
   TierConfig tier;
   tier.tier = TIER_COMMANDER;
   tier.tierName = "指挥官";
   tier.capitalMin = 10000;
   tier.capitalMax = 50000;
   
   // 核心参数 - 稳健，组合对冲
   tier.initialLots = 0.05;      // 可分批进场
   tier.lotMultiplier = 2.0;     // 手数倍率
   tier.distMultiplier = 1.5;    // 宽间距，容错高
   tier.martinMode = 1;          // 斐波那契 (稳健)
   tier.maxLayers = 15;          // 更深层次
   tier.maxSingleLot = 0.80;     // 较高封顶
   
   // 风控 - 稳健，回撤控制
   tier.equityStopPct = 15.0;    // 严格熔断
   tier.dailyLossPct = 3.0;      // 低日亏容忍
   tier.riskLevel = 4;           // 风险等级 4/10
   
   // 策略建议
   tier.portfolioMode = true;    // 多品种组合
   tier.useCentAccount = false;  // 标准账户
   tier.description = "组合对冲，多品种分散，月化 5-10%，回撤控制优先";
   
   return tier;
}

//====================================================================
//              资金层级预设 - Lv.4 鲸鱼 (Whale)
//====================================================================
TierConfig GetWhaleTier() {
   TierConfig tier;
   tier.tier = TIER_WHALE;
   tier.tierName = "鲸鱼";
   tier.capitalMin = 100000;
   tier.capitalMax = 10000000;  // 无限
   
   // 核心参数 - 极度保守，避免滑点
   tier.initialLots = 0.10;      // 中等起步
   tier.lotMultiplier = 3.0;     // 手数倍率
   tier.distMultiplier = 2.0;    // 超宽间距
   tier.martinMode = 2;          // 线性或不加仓
   tier.maxLayers = 8;           // 限制层数避免大单滑点
   tier.maxSingleLot = 2.00;     // 高封顶但严格控制
   
   // 风控 - 极度保守，资产保值
   tier.equityStopPct = 10.0;    // 极严熔断
   tier.dailyLossPct = 2.0;      // 极低日亏
   tier.riskLevel = 2;           // 风险等级 2/10
   
   // 策略建议
   tier.portfolioMode = true;    // 必须组合
   tier.useCentAccount = false;  // ECN/VIP 账户
   tier.description = "机构级，年化 20-30% 复利目标，弃用高倍马丁";
   
   return tier;
}

//====================================================================
//                       层级获取函数
//====================================================================
TierConfig GetTierConfig(ENUM_CAPITAL_TIER capitalTier) {
   switch(capitalTier) {
      case TIER_LABORATORY: return GetLaboratoryTier();
      case TIER_SOLDIER:    return GetSoldierTier();
      case TIER_COMMANDER:  return GetCommanderTier();
      case TIER_WHALE:      return GetWhaleTier();
      default:              return GetSoldierTier();  // 默认特种兵
   }
}

//====================================================================
//                       自动检测资金层级
//====================================================================
ENUM_CAPITAL_TIER DetectCapitalTier(double balance) {
   if(balance < 2000)        return TIER_LABORATORY;
   else if(balance < 10000)  return TIER_SOLDIER;
   else if(balance < 50000)  return TIER_COMMANDER;
   else                      return TIER_WHALE;
}

//====================================================================
//                       应用层级配置到产品配置
//====================================================================
void ApplyTierToProduct(ProductConfig &productCfg, TierConfig &tierCfg) {
   // 调整手数
   productCfg.maxSingleLot *= tierCfg.lotMultiplier;
   if(productCfg.maxSingleLot > tierCfg.maxSingleLot)
      productCfg.maxSingleLot = tierCfg.maxSingleLot;
   
   // 调整网格间距
   productCfg.gridMinDist = (int)(productCfg.gridMinDist * tierCfg.distMultiplier);
   productCfg.gridDistLayer2 = (int)(productCfg.gridDistLayer2 * tierCfg.distMultiplier);
   
   // 🛡️ 保护机制修正：加密货币不允许层级覆盖马丁模式
   // 因为 BTC/ETH 波动巨大，必须强制保持线性模式，防止爆仓
   if(productCfg.type == PRODUCT_CRYPTO_BTC || productCfg.type == PRODUCT_CRYPTO_ETH) {
      // 不覆盖 martinMode，保持原产品的设定
      Print("🛡️ 加密货币保护：保持原有马丁模式，不应用层级覆盖");
   } else {
      // 其他品种允许层级改变加仓模式
      productCfg.martinMode = tierCfg.martinMode;
   }
   
   // 限制最大层数
   if(productCfg.maxLayers > tierCfg.maxLayers)
      productCfg.maxLayers = tierCfg.maxLayers;
   
   // 调整风控参数
   productCfg.equityStopPct = tierCfg.equityStopPct;
   productCfg.dailyLossPct = tierCfg.dailyLossPct;
}

//====================================================================
//                       日志输出层级详情
//====================================================================
void PrintTierConfig(TierConfig &tier) {
   Print("=== 资金层级配置 ===");
   Print("层级: Lv.", (int)tier.tier + 1, " ", tier.tierName);
   Print("资金范围: $", tier.capitalMin, " - $", tier.capitalMax);
   Print("起始手数: ", tier.initialLots, " | 封顶: ", tier.maxSingleLot);
   Print("马丁模式: ", (tier.martinMode==0?"指数":(tier.martinMode==1?"斐波那契":"线性")));
   Print("最大层数: ", tier.maxLayers, " | 间距倍率: ", tier.distMultiplier);
   Print("风控: 熔断=", tier.equityStopPct, "% 日亏=", tier.dailyLossPct, "%");
   Print("风险等级: ", tier.riskLevel, "/10");
   Print("组合模式: ", (tier.portfolioMode?"是":"否"), " | 美分账户: ", (tier.useCentAccount?"建议":"否"));
   Print("描述: ", tier.description);
   Print("========================");
}
