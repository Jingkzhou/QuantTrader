//+------------------------------------------------------------------+
//|                                      QuantTrader_Pro_V4_6.mq4    |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://www.mql5.com"
#property version   "4.60"
#property strict
#property description "全自动多策略量化交易系统 V4.6 [狂暴模式修正 + 动态止盈降级 + 智能双模网格]"

//--- 引入产品预设配置
#include "ProductPresets.mqh"

//--- 枚举定义
enum ENUM_MARTIN_MODE {
   MODE_EXPONENTIAL, // 指数增加 (0.01, 0.02, 0.04...)
   MODE_FIBONACCI,   // 斐波那契 (0.01, 0.01, 0.02, 0.03, 0.05...)
   MODE_LINEAR       // 线性递增 (0.01, 0.02, 0.03, 0.04...)
};
enum ENUM_ATR_GRID_MODE {
   ATR_DIRECT, // 直接模式：倍率 * ATR
   ATR_SCALE   // 缩放模式：BaseDist * (ATR / BaseATR)
};

//====================================================================
//                       参数输入模块 (Parameters)
//====================================================================
input group "=== V4.3 产品配置 ==="
input bool     InpUsePreset     = true;        // 使用产品预设配置
input ENUM_PRODUCT_TYPE InpProductType = PRODUCT_GOLD; // 产品类型选择
input bool     InpEnableSession = true;        // 启用交易时段过滤

input group "=== V4.3 资金层级 ==="
input bool     InpAutoTier      = false;        // 自动检测资金层级
input ENUM_CAPITAL_TIER InpCapitalTier = TIER_SOLDIER; // 手动选择层级

input group "=== V4 风控防火墙 ==="
input double   InpEquityStopPct   = 25.0;        // 账户级硬止损回撤比例
input double   InpDailyLossPct    = 5.0;         // 单日亏损限制比例
input int      InpMaxLayerPerSide = 12;          // 单边最大层数
input int      InpMaxAdversePoints = 2000;       // 单边最大浮亏点数

input group "=== V3.9 ATR 动态波动率适配 ==="
input bool     InpUseATRGrid   = true;           // 是否启用 ATR 动态网格
input ENUM_ATR_GRID_MODE InpATRMode = ATR_DIRECT;// 动态模式
input ENUM_TIMEFRAMES InpATRTF = PERIOD_H1;      // ATR 计算周期
input int      InpATRPeriod    = 14;             // ATR 周期
input double   InpATRMultiplier = 0.5;           // 直接模式倍率
input double   InpBaseATRPoints = 1000;          // 缩放模式基准 ATR 点数

input group "=== V3.8 低压加仓设置 ==="
input ENUM_MARTIN_MODE InpMartinMode = MODE_FIBONACCI; // [核心] 加仓模式
input double   InpMaxSingleLot   = 0.50;           // 单笔订单封顶手数
input int      InpDecayStep      = 6;              // 第几层开始进入倍率衰减
input double   InpDecayMulti     = 1.1;            // 衰减后的倍率
input bool     InpGridExpansion  = true;           // 是否开启动态间距扩张

input group "=== V3.7 UI 面板设置 ==="
input int      UI_X_Offset      = 50;              // 面板水平偏移量
input int      UI_Y_Offset      = 50;              // 面板垂直偏移量
input color    UI_ThemeColor    = C'0,128,128';    // 主题颜色 

input group "=== V3.6 机构级设置 ==="
input bool     InpEnableDualMode = true;           // 是否启用双向持仓模式
input int      InpBEProfitPips   = 80;             // 保本激活所需盈利点数
input int      InpBELockPips     = 10;             // 保本锁定点数偏移        

input group "=== V3.5 首尾对冲设置 ==="
input bool     InpEnableDualHedge = true;          // 是否启用首尾对冲减仓
input int      InpDestockMinLayer = 6;             // 触发对冲的最小层数
input double   InpDestockProfit = 1.0;             // 对冲平仓最低盈利要求        

input group "=== V4.5 动态止盈降级 ==="
input bool     InpUseDynamicTP    = true;          // 是否启用动态止盈降级
input int      InpDynamicStart    = 4;             // 防御模式触发层数
input double   InpDynamicRatio    = 0.5;           // 防御模式止盈折扣
input int      InpSurvivalStart   = 7;             // 逃生模式触发层数
input double   InpSurvivalProfit  = 5.0;           // 逃生模式目标金额($)

input group "=== 风控与核心参数 ==="
input int      InpTargetPips    = 150;             // 目标止盈点数
input double   InpSingleSideMaxLoss = 500.0;       // 单边最大浮亏限额
input int      InpMagicNum      = 999008;          // EA订单魔术号
input double   InpInitialLots   = 0.01;            // 起始开仓手数
input double   MartinMulti      = 1.5;             // 马丁倍率乘数
input int      GridMinDist      = 100;             // 首层网格间距点数
input int      GridDistLayer2   = 300;             // 二层及以后网格间距

//--- 全局变量
bool     g_IsTradingAllowed = true;
bool     g_AllowLong=true, g_AllowShort=true;
bool     g_PanelVisible = true;
string   g_ObjPrefix="QT43_";
string   g_ToggleName="QT43_TogglePanel";
datetime g_LastCloseTime=0;
double   g_PipValue=1.0;
string   g_LastHedgeInfo="";
bool     g_CircuitBreakerTriggered = false;
bool     g_DailyStopTriggered = false;
datetime g_RiskCheckStartTime = 0; // [V4.6] 风控计算起始时间
double   g_RiskCheckBaselinePL = 0; // [V4.6] 损益基准值偏移
ProductConfig g_ProductCfg;  // V4.3 产品配置
TierConfig    g_TierCfg;     // V4.3 资金层级配置
double   g_InitialLots = 0.01; // 动态起始手数
color    g_ColorPanel = C'255,255,255';
color    g_ColorHeader = C'242,244,247';
color    g_ColorLine = C'220,224,230';
color    g_ColorText = C'25,28,32';
color    g_ColorMuted = C'110,120,130';
color    g_ColorInk = C'20,22,24';
color    g_ColorGood = C'82,180,122';
color    g_ColorBad = C'220,85,70';
color    g_ColorButton = C'60,66,72';
color    g_ColorButtonText = C'255,255,255';

//+------------------------------------------------------------------+
//| 初始化                                                           |
//+------------------------------------------------------------------+
int OnInit() {
   g_PipValue = MarketInfo(_Symbol, MODE_TICKVALUE) / (MarketInfo(_Symbol, MODE_TICKSIZE) / _Point);
   
   //--- V4.6 UI 修正：强制图表 K 线在背景，确保面板覆盖 K 线
   ChartSetInteger(0, CHART_FOREGROUND, 0);
   
   //--- V4.3 产品配置初始化
   if(InpUsePreset) {
      // 自动识别产品类型或使用用户选择
      ENUM_PRODUCT_TYPE detectedType = DetectProductType(_Symbol);
      if(detectedType != InpProductType) {
         Print("自动识别产品类型: ", EnumToString(detectedType), " (用户选择: ", EnumToString(InpProductType), ")");
      }
      g_ProductCfg = GetProductConfig(InpProductType);
      PrintProductConfig(g_ProductCfg);
      // 使用面板输入覆盖关键手动参数，避免预设锁死
      g_ProductCfg.gridMinDist = GridMinDist;
      g_ProductCfg.gridDistLayer2 = GridDistLayer2;
      g_ProductCfg.martinMulti = MartinMulti;
      Print("用户手动覆盖：间距=" + IntegerToString(GridMinDist) + "/" + IntegerToString(GridDistLayer2));
   } else {
      // 使用手动输入参数，构建配置
      g_ProductCfg.symbol = _Symbol;
      g_ProductCfg.type = InpProductType;
      g_ProductCfg.atrMultiplier = InpATRMultiplier;
      g_ProductCfg.atrPeriod = InpATRPeriod;
      g_ProductCfg.atrTimeframe = InpATRTF;
      g_ProductCfg.martinMode = InpMartinMode;
      g_ProductCfg.martinMulti = MartinMulti;
      g_ProductCfg.decayStep = InpDecayStep;
      g_ProductCfg.decayMulti = InpDecayMulti;
      g_ProductCfg.maxSingleLot = InpMaxSingleLot;
      g_ProductCfg.maxLayers = InpMaxLayerPerSide;
      g_ProductCfg.targetPips = InpTargetPips;
      g_ProductCfg.dailyLossPct = InpDailyLossPct;
      g_ProductCfg.equityStopPct = InpEquityStopPct;
      g_ProductCfg.singleSideMaxLoss = InpSingleSideMaxLoss;
      g_ProductCfg.maxAdversePoints = InpMaxAdversePoints;
      g_ProductCfg.gridMinDist = GridMinDist;
      g_ProductCfg.gridDistLayer2 = GridDistLayer2;
      g_ProductCfg.gridExpansion = InpGridExpansion;
      g_ProductCfg.sessionStartHour = 0;
      g_ProductCfg.sessionEndHour = 24;
      g_ProductCfg.allowWeekend = true;
      g_ProductCfg.destockMinLayer = InpDestockMinLayer;
      g_ProductCfg.destockProfit = InpDestockProfit;
      g_ProductCfg.beProfitPips = InpBEProfitPips;
      g_ProductCfg.beLockPips = InpBELockPips;
      Print("使用手动参数配置");
   }
   
   //--- V4.3 资金层级配置初始化
   ENUM_CAPITAL_TIER activeTier;
   if(InpAutoTier) {
      // 自动检测资金层级
      double balance = AccountBalance();
      activeTier = DetectCapitalTier(balance);
      Print("自动检测资金层级: $", balance, " -> ", EnumToString(activeTier));
   } else {
      activeTier = InpCapitalTier;
      Print("使用手动选择层级: ", EnumToString(activeTier));
   }
   
   g_TierCfg = GetTierConfig(activeTier);
   PrintTierConfig(g_TierCfg);
   
   // 应用层级配置到产品配置
   ApplyTierToProduct(g_ProductCfg, g_TierCfg);
   g_InitialLots = g_TierCfg.initialLots;
   
   // ========== V4.6 狂暴模式覆盖层 (修正版) ==========
   if(g_TierCfg.tier == TIER_BERSERK) {
      Print("🔥🔥🔥 警告：狂暴模式已启动！强制阉割 ATR 风控！ 🔥🔥🔥");
      
      // 1. 强制覆盖间距 (已由 ApplyTierToProduct 缩放，此处确保逻辑)
      g_ProductCfg.gridExpansion = false; 
      
      // 2. 强制覆盖加仓
      // g_ProductCfg.martinMode = MODE_EXPONENTIAL; // Preset 已设置
      
      // 3. 【核心修正】彻底杀死 ATR
      // 必须把倍率设为 0.0，这样 MathMax(35, 0) 才会强制返回 35
      g_ProductCfg.atrMultiplier = 0.0; 
      
      // 4. 其他修正
      g_ProductCfg.maxLayers = g_TierCfg.maxLayers;
      // InpUseDynamicTP 本身为 input 无法修改，但默认是 true
   }
   // ===============================================
   
   // 输出最终配置
   Print("=== 最终参数配置 ===");
   Print("起始手数: ", g_InitialLots, " | 封顶: ", g_ProductCfg.maxSingleLot);
   Print("马丁模式: ", (g_ProductCfg.martinMode==0?"指数":(g_ProductCfg.martinMode==1?"斐波那契":"线性")));
   Print("最大层数: ", g_ProductCfg.maxLayers);
   Print("网格间距: 首层=", g_ProductCfg.gridMinDist, " 后续=", g_ProductCfg.gridDistLayer2);
   Print("熔断: ", g_ProductCfg.equityStopPct, "% 日亏: ", g_ProductCfg.dailyLossPct, "%");
   if(g_TierCfg.useCentAccount) {
      Print("⚠️ 建议: 当前资金量建议使用美分账户 (Cent Account)");
   }
   Print("========================");
   
   EventSetTimer(1);
   DrawDashboard();
   DrawToggleButton();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) { ObjectsDeleteAll(0, g_ObjPrefix); ObjectDelete(0, g_ToggleName); EventKillTimer(); }

//+------------------------------------------------------------------+
//| 核心引擎                                                         |
//+------------------------------------------------------------------+
void OnTick() {
   if(!GlobalRiskCheck()) { UpdateDashboard(); return; }
   if(!g_IsTradingAllowed) { UpdateDashboard(); return; }
   
   //--- V4.3 交易时段检查
   if(InpEnableSession && !IsTradingAllowedByProduct(g_ProductCfg)) {
      UpdateDashboard();
      return;  // 不在交易时段，跳过交易逻辑
   }

   if(InpEnableDualHedge) { CheckDestocking(OP_BUY); CheckDestocking(OP_SELL); }
   CheckBreakEven();

   if(InpEnableDualMode) ManageDualEntry();
   
   RunMartingaleLogic();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| 定时器事件                                                       |
//+------------------------------------------------------------------+
void OnTimer() {
   if(g_PanelVisible) {
      UpdateDashboard();
   }
}

//====================================================================
//                       V3.8 低压手数算法
//====================================================================

double CalculateNextLot(int side) {
   int cnt = CountOrders(side);
   // 修正：使用 g_InitialLots 而不是 InpInitialLots
   if(cnt == 0) return g_InitialLots;
   
   double lastLot = GetLastLot(side);
   double secondLastLot = GetSecondLastLot(side);
   double nextLot = lastLot;

   // 1. 基础模式计算 - 修正：全部替换为 g_ProductCfg 参数
   if(g_ProductCfg.martinMode == MODE_EXPONENTIAL) {
      double multi = (cnt >= g_ProductCfg.decayStep) ? g_ProductCfg.decayMulti : g_ProductCfg.martinMulti;
      nextLot = lastLot * multi;
   }
   else if(g_ProductCfg.martinMode == MODE_FIBONACCI) {
      if(cnt == 1) nextLot = g_InitialLots;  // 修正
      else nextLot = lastLot + secondLastLot;
   }
   else if(g_ProductCfg.martinMode == MODE_LINEAR) {
      nextLot = lastLot + g_InitialLots;  // 修正
   }

   // 2. 封顶保护 - 修正
   if(nextLot > g_ProductCfg.maxSingleLot) nextLot = g_ProductCfg.maxSingleLot;
   
   return NormalizeDouble(nextLot, 2);
}

// 获取倒数第二单手数 (用于斐波那契)
double GetSecondLastLot(int side) {
   double lastL=0, secondL=0;
   datetime lastT=0, secondT=0;
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber()==InpMagicNum && OrderType()==side) {
         if(OrderOpenTime() > lastT) {
            secondT = lastT; secondL = lastL;
            lastT = OrderOpenTime(); lastL = OrderLots();
         } else if(OrderOpenTime() > secondT) {
            secondT = OrderOpenTime(); secondL = OrderLots();
         }
      }
   }
   return (secondL > 0) ? secondL : g_InitialLots;  // 修正：使用 g_InitialLots
}

//====================================================================
//                       V3.9 ATR 动态网格
//====================================================================

double GetATRPoints() {
   double atr = iATR(_Symbol, InpATRTF, InpATRPeriod, 0);
   if(atr <= 0) return 0;
   return atr / _Point;
}

double GetGridDistance(int orderCount) {
   // 【V4.6 新增】如果是狂暴模式，直接返回固定值，不听 ATR 的废话
   if(g_TierCfg.tier == TIER_BERSERK) {
      return (double)g_ProductCfg.gridMinDist;
   }

   // 1. 获取 V3.8 风格固定间距 (保底收益)
   double fixedDist = (orderCount == 1) ? g_ProductCfg.gridMinDist : g_ProductCfg.gridDistLayer2;
   
   // 2. 获取 ATR 动态间距 (风控安全气囊)
   double atrDist = 0;
   if(InpUseATRGrid) {
      double atrPoints = GetATRPoints();
      if(atrPoints > 0) {
         if(InpATRMode == ATR_DIRECT) {
            atrDist = atrPoints * g_ProductCfg.atrMultiplier;
            if(orderCount > 1 && g_ProductCfg.gridMinDist > 0)
               atrDist *= ((double)g_ProductCfg.gridDistLayer2 / g_ProductCfg.gridMinDist);
         } else {
            double baseAtr = (InpBaseATRPoints > 0 ? InpBaseATRPoints : atrPoints);
            atrDist = fixedDist * (atrPoints / baseAtr);
         }
      }
   }

   // 3. 智能择优：取固定与 ATR 的最大值
   double finalDist = MathMax(fixedDist, atrDist);

   // 4. 动态扩张逻辑 (V3.8 特性保留)
   if(g_ProductCfg.gridExpansion && orderCount >= 4)
      finalDist = finalDist * (1 + (orderCount-4)*0.2);
   if(finalDist < 1) finalDist = 1;
   return finalDist;
}

double GetMaxAdversePoints(int side) {
   double extreme = 0;
   bool has=false;
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber()==InpMagicNum && OrderType()==side) {
         double op = OrderOpenPrice();
         if(!has) { extreme = op; has = true; }
         else {
            if(side==OP_BUY && op > extreme) extreme = op;
            if(side==OP_SELL && op < extreme) extreme = op;
         }
      }
   }
   if(!has) return 0;
   if(side==OP_BUY) {
      double dist = (extreme - Bid) / _Point;
      return (dist > 0 ? dist : 0);
   }
   double dist = (Ask - extreme) / _Point;
   return (dist > 0 ? dist : 0);
}

//====================================================================
//                       重构后的马丁逻辑
//====================================================================

void RunMartingaleLogic() {
   double bProf=GetFloatingPL(OP_BUY), sProf=GetFloatingPL(OP_SELL);
   double bLots=GetTotalLots(OP_BUY), sLots=GetTotalLots(OP_SELL);
   int bCnt = CountOrders(OP_BUY);
   int sCnt = CountOrders(OP_SELL);
   
   // ========== V4.5 动态止盈降级逻辑 ==========
   // 多头止盈检查
   if(bLots > 0) {
      double bTarget = CalculateDynamicTP(bCnt, bLots);
      if(bProf >= bTarget) { ClosePositions(3); return; }
   }
   
   // 空头止盈检查
   if(sLots > 0) {
      double sTarget = CalculateDynamicTP(sCnt, sLots);
      if(sProf >= sTarget) { ClosePositions(4); return; }
   }
   
   // ========== 加仓检查 ==========
   if(g_AllowLong && (bCnt > 0)) {
      double dist = GetGridDistance(bCnt);
      if(Bid <= GetLastPrice(OP_BUY) - dist * _Point) {
         if(g_ProductCfg.singleSideMaxLoss == 0 || bProf >= -g_ProductCfg.singleSideMaxLoss)
            SafeOrderSend(OP_BUY, CalculateNextLot(OP_BUY), "Add_V45");
      }
   }

   if(g_AllowShort && (sCnt > 0)) {
      double dist = GetGridDistance(sCnt);
      if(Ask >= GetLastPrice(OP_SELL) + dist * _Point) {
         if(g_ProductCfg.singleSideMaxLoss == 0 || sProf >= -g_ProductCfg.singleSideMaxLoss)
            SafeOrderSend(OP_SELL, CalculateNextLot(OP_SELL), "Add_V45");
      }
   }
}

//+------------------------------------------------------------------+
//| V4.5 动态止盈计算 - 三阶段降级                                      |
//+------------------------------------------------------------------+
double CalculateDynamicTP(int layerCount, double totalLots) {
   // 基础止盈金额
   double baseTP = totalLots * g_ProductCfg.targetPips * g_PipValue;
   
   // 如果未启用动态止盈，返回基础值
   if(!InpUseDynamicTP) return baseTP;
   
   // 阶段一：贪婪模式 (层数 < InpDynamicStart)
   if(layerCount < InpDynamicStart) {
      return baseTP;
   }
   // 阶段二：防御模式 (InpDynamicStart <= 层数 < InpSurvivalStart)
   else if(layerCount < InpSurvivalStart) {
      return baseTP * InpDynamicRatio;
   }
   // 阶段三：逃生模式 (层数 >= InpSurvivalStart)
   else {
      return InpSurvivalProfit;  // 固定金额止盈
   }
}

//+------------------------------------------------------------------+
//| V4.5 获取止盈模式名称                                               |
//+------------------------------------------------------------------+
string GetTPModeName(int layerCount) {
   if(!InpUseDynamicTP) return "固定";
   if(layerCount < InpDynamicStart) return "贪婪";
   else if(layerCount < InpSurvivalStart) return "防御";
   else return "逃生⚠";
}

//====================================================================
//                       继承功能 (V3.7/3.6/3.5)
//====================================================================

void ManageDualEntry() {
   // 修正：使用 g_InitialLots
   if(CountOrders(OP_BUY)==0 && g_AllowLong) SafeOrderSend(OP_BUY, g_InitialLots, "Dual_Init");
   if(CountOrders(OP_SELL)==0 && g_AllowShort) SafeOrderSend(OP_SELL, g_InitialLots, "Dual_Init");
}

void CheckBreakEven() {
   for(int i=OrdersTotal()-1; i>=0; i--) {
      if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber()==InpMagicNum && OrderSymbol()==_Symbol) {
         double op=OrderOpenPrice(), sl=OrderStopLoss();
         if(OrderType()==OP_BUY && (Bid-op)/_Point >= InpBEProfitPips && sl<op) 
            OrderModify(OrderTicket(),op,op+InpBELockPips*_Point,OrderTakeProfit(),0,clrGold);
         if(OrderType()==OP_SELL && (op-Ask)/_Point >= InpBEProfitPips && (sl>op||sl==0)) 
            OrderModify(OrderTicket(),op,op-InpBELockPips*_Point,OrderTakeProfit(),0,clrGold);
      }
   }
}

void CheckDestocking(int side) {
   if(CountOrders(side) < InpDestockMinLayer) return;
   int fT=-1, lT=-1; datetime ear=D'2099.01.01', lat=D'1970.01.01';
   for(int i=OrdersTotal()-1; i>=0; i--) {
      if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber()==InpMagicNum && OrderType()==side) {
         if(OrderOpenTime()<ear){ear=OrderOpenTime();fT=OrderTicket();}
         if(OrderOpenTime()>lat){lat=OrderOpenTime();lT=OrderTicket();}
      }
   }
   if(fT!=-1 && lT!=-1 && fT!=lT) {
      OrderSelect(fT,SELECT_BY_TICKET); double p1=OrderProfit()+OrderSwap()+OrderCommission();
      OrderSelect(lT,SELECT_BY_TICKET); double p2=OrderProfit()+OrderSwap()+OrderCommission();
      if(p1+p2 >= InpDestockProfit) {
         g_LastHedgeInfo = StringFormat("对冲平仓: %d+%d", fT, lT);
         OrderSelect(fT,SELECT_BY_TICKET); OrderClose(fT,OrderLots(),(OrderType()==OP_BUY?Bid:Ask),10,clrOrange);
         OrderSelect(lT,SELECT_BY_TICKET); OrderClose(lT,OrderLots(),(OrderType()==OP_BUY?Bid:Ask),10,clrOrange);
         g_LastCloseTime=TimeCurrent();
      }
   }
}

//====================================================================
//                       UI 系统 (V4 展示增强)
//====================================================================

void OnChartEvent(const int id, const long& l, const double& d, const string& s) {
   if(id==CHARTEVENT_OBJECT_CLICK) {
      if(s==g_ToggleName) {
         g_PanelVisible = !g_PanelVisible;
         if(g_PanelVisible) DrawDashboard();
         else ObjectsDeleteAll(0, g_ObjPrefix);
         UpdateDashboard();
         return;
      }
      if(s==g_ObjPrefix+"Btn_Buy") g_AllowLong=!g_AllowLong;
      else if(s==g_ObjPrefix+"Btn_Sell") g_AllowShort=!g_AllowShort;
      else if(s==g_ObjPrefix+"Btn_CloseAll") CloseAll();
      else if(s==g_ObjPrefix+"Btn_Pause") {
         // [用户请求] 点击按钮后重置风控状态
         if(g_CircuitBreakerTriggered || g_DailyStopTriggered) {
             g_CircuitBreakerTriggered = false;
             g_DailyStopTriggered = false;
             g_IsTradingAllowed = false; // 重置为暂停状态
             
             // [核心修正] 重置风控起始时间，并快照当前的损益作为基准值
             // 这样后续的 GlobalRiskCheck 将从这一刻的净值开始重新计算
             g_RiskCheckStartTime = TimeCurrent(); 
             g_RiskCheckBaselinePL = GetHistoryProfit(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent()+3600) + GetFloatingPL(OP_BUY) + GetFloatingPL(OP_SELL);
             
             Print(StringFormat("🛡️ 风控状态已重置！快照基准盈利: %.2f。系统已复位为暂停模式，请再次点击启动。", g_RiskCheckBaselinePL));
         } else {
             // 正常切换暂停/运行
             g_IsTradingAllowed=!g_IsTradingAllowed;
         }
         UpdateDashboard();
         ChartRedraw(); // 强制重绘
      }
      UpdateDashboard();
   }
}

void DrawDashboard() {
   if(!g_PanelVisible) return;
   int x=UI_X_Offset, y=UI_Y_Offset;
   int w=960, h=720, headerH=40, pad=18;  // V4.3 深度扩容面板
   int innerW = w - 2*pad;
   int colGap = 36;
   int colW = (innerW - colGap) / 2;
   int xL = x + pad;
   int xR = xL + colW + colGap;
   int cy=y+headerH+16;
   string modeS = (g_ProductCfg.martinMode==1?"斐波那契":(g_ProductCfg.martinMode==2?"线性递增":"指数衰减"));
   string productS = EnumToString(g_ProductCfg.type);
   StringReplace(productS, "PRODUCT_", "");
   string tierS = "Lv." + IntegerToString((int)g_TierCfg.tier + 1) + " " + g_TierCfg.tierName;

   CreateRect("Bg", x, y, w, h, g_ColorPanel, UI_ThemeColor);
   CreateRect("Accent", x, y, 4, h, UI_ThemeColor);
   CreateRect("Header", x+4, y, w-4, headerH, g_ColorHeader);
   CreateLabel("T_Title", "QuantTrader Pro", xL+2, y+9, g_ColorText, 10, "微软雅黑");
   CreateLabel("T_Ver", "V4.5", x+w-46, y+9, g_ColorMuted, 9, "Consolas");

   //--- V4.3 产品+层级信息区
   CreateLabel("T_Product", "配置信息", xL, cy, g_ColorMuted, 8, "微软雅黑");
   cy+=28;
   CreateLabel("V_ProductType", productS, xL, cy, UI_ThemeColor, 10, "Consolas");
   CreateLabel("V_TierName", tierS, xR, cy, UI_ThemeColor, 10, "Consolas");
   cy+=28;
   CreateLabel("V_SessionTime", "首层间距: --", xL, cy, g_ColorMuted, 9, "Consolas");
   CreateLabel("V_RiskLevel", "风险: " + IntegerToString((int)g_TierCfg.riskLevel) + "/10", xR, cy, g_ColorMuted, 9, "Consolas");
   
   cy+=35; CreateRect("Line0", xL, cy, innerW, 1, g_ColorLine);
   cy+=16; CreateLabel("T_Status", "策略状态", xL, cy, g_ColorMuted, 8, "微软雅黑");
   cy+=28;
   int chipW = 100;
   int chipGap = 12;
   CreateRect("Chip_Buy", xL, cy, chipW, 24, g_ColorGood);
   CreateLabel("L_BuyState", "多头 ON", xL+12, cy+5, g_ColorInk, 8, "微软雅黑");
   CreateRect("Chip_Sell", xL+chipW+chipGap, cy, chipW, 24, g_ColorGood);
   CreateLabel("L_SellState", "空头 ON", xL+chipW+chipGap+12, cy+5, g_ColorInk, 8, "微软雅黑");
   CreateLabel("T_Mode", "模式:", xR, cy+5, g_ColorMuted, 9, "微软雅黑");
   CreateLabel("V_Mode", modeS, xR+50, cy+5, UI_ThemeColor, 9, "微软雅黑");

   cy+=35; CreateRect("Line1", xL, cy, innerW, 1, g_ColorLine);
   cy+=16; CreateLabel("T_Profit", "收益表现", xL, cy, g_ColorMuted, 8, "微软雅黑");
   cy+=28; CreateLabel("T_Today", "今日获利", xL, cy, g_ColorText, 10, "微软雅黑");
   CreateLabel("V_TodayM", "0.00 USD", xL+110, cy, g_ColorGood, 10, "Consolas");
   CreateLabel("V_TodayP", "0.00%", xR+colW-70, cy, g_ColorGood, 10, "Consolas");
   cy+=30; CreateLabel("V_Target", "多头目标: 0.00 | 空头目标: 0.00", xL, cy, g_ColorMuted, 9, "微软雅黑");

   cy+=35; CreateRect("Line2", xL, cy, innerW, 1, g_ColorLine);
   cy+=16; CreateLabel("T_Account", "账户数据", xL, cy, g_ColorMuted, 8, "微软雅黑");
   cy+=28; CreateLabel("T_Bal", "余额", xL, cy, g_ColorText, 10, "微软雅黑");
   CreateLabel("V_Bal", "0.00 USD", xL+110, cy, g_ColorText, 10, "Consolas");
   CreateLabel("T_Margin", "保证金率", xR, cy, g_ColorText, 10, "微软雅黑");
   CreateLabel("V_Margin", "0.00%", xR+130, cy, UI_ThemeColor, 11, "Consolas");
   cy+=30; CreateLabel("T_Used", "已用保证金", xL, cy, g_ColorMuted, 10, "微软雅黑");
   CreateLabel("V_Used", "0.00 USD", xL+130, cy, g_ColorMuted, 10, "Consolas");

   cy+=35; CreateRect("Line3", xL, cy, innerW, 1, g_ColorLine);
   cy+=16; CreateLabel("T_Control", "手动控制", xL, cy, g_ColorMuted, 8, "微软雅黑");
   cy+=28;
   int btnGap = 12;
   int btnW = (innerW - btnGap*2) / 3;
   CreateButton("Btn_Buy", "多头开关", xL, cy, btnW, 30, UI_ThemeColor);
   CreateButton("Btn_Sell", "空头开关", xL+btnW+btnGap, cy, btnW, 30, UI_ThemeColor);
   CreateButton("Btn_CloseAll", "全平清仓", xL+2*(btnW+btnGap), cy, btnW, 30, g_ColorBad);
   cy+=40; CreateButton("Btn_Pause", "系统已暂停 · 点击恢复", xL, cy, innerW, 36, g_ColorBad);
}

void UpdateDashboard() {
   DrawToggleButton();
   if(!g_PanelVisible) return;
   double bal = AccountBalance();
   datetime todayS = iTime(_Symbol, PERIOD_D1, 0);
   double pToday = GetHistoryProfit(todayS, TimeCurrent()+3600);
   double margin = AccountMargin();
   color todayColor = (pToday >= 0 ? g_ColorGood : g_ColorBad);
   bool riskLock = (g_CircuitBreakerTriggered || g_DailyStopTriggered);
   
   //--- V4.3 实时显示网格间距 (替代时段显示)
   int currentDist = (int)GetGridDistance(1);
   bool isAtrActive = (currentDist > g_ProductCfg.gridMinDist);
   SetLabelText("V_SessionTime", "首层间距: " + IntegerToString(currentDist) + " 微点");
   if(isAtrActive) {
      SetObjectColor("V_SessionTime", clrOrange);
   } else {
      SetObjectColor("V_SessionTime", g_ColorGood);
   }
   
   // --- 1. 获取核心数据 ---
   int bCnt = CountOrders(OP_BUY);
   int sCnt = CountOrders(OP_SELL);
   double floatPL = GetFloatingPL(OP_BUY) + GetFloatingPL(OP_SELL); // 总浮亏
   double nextBuyLot = CalculateNextLot(OP_BUY);
   double nextSellLot = CalculateNextLot(OP_SELL);

   // --- 2. 改造状态栏：显示层数和下一单手数 ---
   // 新逻辑：显示 "多(3层) 0.05"
   string buyInfo = g_AllowLong ? StringFormat("多(%d层) %.2f", bCnt, nextBuyLot) : "多头 OFF";
   SetLabelText("L_BuyState", buyInfo);
   // 颜色逻辑：层数超过6层变橙色预警，超过10层变红色报警
   if(g_AllowLong) {
      if(bCnt >= 10) SetRectBg("Chip_Buy", clrRed);
      else if(bCnt >= 6) SetRectBg("Chip_Buy", clrOrange);
      else SetRectBg("Chip_Buy", g_ColorGood);
      SetObjectColor("L_BuyState", g_ColorInk);
   } else {
      SetRectBg("Chip_Buy", g_ColorBad);
      SetObjectColor("L_BuyState", g_ColorText);
   }

   string sellInfo = g_AllowShort ? StringFormat("空(%d层) %.2f", sCnt, nextSellLot) : "空头 OFF";
   SetLabelText("L_SellState", sellInfo);
   // 同理设置空头颜色
   if(g_AllowShort) {
      if(sCnt >= 10) SetRectBg("Chip_Sell", clrRed);
      else if(sCnt >= 6) SetRectBg("Chip_Sell", clrOrange);
      else SetRectBg("Chip_Sell", g_ColorGood);
      SetObjectColor("L_SellState", g_ColorInk);
   } else {
      SetRectBg("Chip_Sell", g_ColorBad);
      SetObjectColor("L_SellState", g_ColorText);
   }

   // --- 3. 改造收益区：显示浮动盈亏 ---
   // 新逻辑：显示 "盈:5.07 / 浮:-12.5"
   string profitStr = StringFormat("盈:%.2f  浮:%.2f", pToday, floatPL);
   SetLabelText("V_TodayM", profitStr);
   
   // 浮亏颜色逻辑：浮亏严重时显示红色
   if(floatPL < -50.0) SetObjectColor("V_TodayM", clrRed); // 浮亏超过50刀变红
   else SetObjectColor("V_TodayM", todayColor);

   SetLabelText("V_TodayP", StringFormat("%.2f%%", (bal>0?pToday/bal*100:0)));
   SetObjectColor("V_TodayP", todayColor);
   SetLabelText("V_Bal", StringFormat("%.2f USD", bal));
   SetLabelText("V_Used", StringFormat("%.2f USD", margin));
   if(margin>0) SetLabelText("V_Margin", StringFormat("%.2f%%", AccountEquity()/margin*100));
   else SetLabelText("V_Margin", "0.00%");
   
   // --- V4.5 动态止盈目标显示 ---
   double bLots = GetTotalLots(OP_BUY);
   double sLots = GetTotalLots(OP_SELL);
   double bTarget = CalculateDynamicTP(bCnt, bLots);
   double sTarget = CalculateDynamicTP(sCnt, sLots);
   string bMode = GetTPModeName(bCnt);
   string sMode = GetTPModeName(sCnt);
   
   // 格式: "多目标: 15.50 (贪婪) | 空目标: 5.00 (逃生⚠)"
   string targetInfo = StringFormat("多目标: %.2f (%s) | 空目标: %.2f (%s)", bTarget, bMode, sTarget, sMode);
   SetLabelText("V_Target", targetInfo);
   
   // 颜色逻辑：逃生模式变红，防御模式变橙
   if(bCnt >= InpSurvivalStart || sCnt >= InpSurvivalStart) {
      SetObjectColor("V_Target", clrRed);
   } else if(bCnt >= InpDynamicStart || sCnt >= InpDynamicStart) {
      SetObjectColor("V_Target", clrOrange);
   } else {
      SetObjectColor("V_Target", g_ColorMuted);
   }
   if(riskLock) {
      SetLabelText("Btn_Pause", g_CircuitBreakerTriggered?"已触发熔断 · 关机":"当日止损触发 · 已停机");
      SetBtnColor("Btn_Pause", g_ColorBad);
   } else {
      SetLabelText("Btn_Pause", g_IsTradingAllowed?"系统运行中 · 点击暂停":"系统已暂停 · 点击恢复");
      SetBtnColor("Btn_Pause", g_IsTradingAllowed?g_ColorButton:g_ColorBad);
   }
}

// 辅助底层函数
double GetHistoryProfit(datetime start, datetime end) {
   double p = 0;
   for(int i=OrdersHistoryTotal()-1; i>=0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber()==InpMagicNum && OrderSymbol()==_Symbol) {
         if(OrderCloseTime() >= start && OrderCloseTime() <= end) p += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }
   return p;
}
void ClosePositions(int m) {
   for(int i=OrdersTotal()-1;i>=0;i--) if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum) {
      bool ok=(m==5||m==6)||(m==3&&(OrderType()==OP_BUY))||(m==4&&(OrderType()==OP_SELL));
      if(ok) { if(OrderType()<=1) OrderClose(OrderTicket(),OrderLots(),(OrderType()==OP_BUY?Bid:Ask),10,clrGray); else OrderDelete(OrderTicket()); }
   }
   g_LastCloseTime=TimeCurrent();
}
void CloseAll() { ClosePositions(6); }
//+------------------------------------------------------------------+
//| 全局风控检查器 (修正版)                                             |
//+------------------------------------------------------------------+
bool GlobalRiskCheck() {
   // 1. 日期检测与重置 (新的一天，重置起始点)
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   if(g_RiskCheckStartTime < today) { 
      g_RiskCheckStartTime = today; 
      g_RiskCheckBaselinePL = 0;       // 跨天必须重置基准值
      g_DailyStopTriggered = false; 
      g_CircuitBreakerTriggered = false; 
   }

   double bal = AccountBalance();
   double eq = AccountEquity();

   // ---------------------------------------------------------
   // [一级熔断] 净值硬止损 (Circuit Breaker)
   // 逻辑：保命。一旦净值低于 本金*(1-比例)，无条件清仓。
   // ---------------------------------------------------------
   if(!g_CircuitBreakerTriggered && InpEquityStopPct > 0 && bal > 0) {
      if(eq <= bal * (1.0 - InpEquityStopPct/100.0)) {
         Print(StringFormat("【一级熔断】净值触及止损线! 当前: %.2f, 阈值: %.2f", eq, bal * (1.0 - InpEquityStopPct/100.0)));
         CloseAll();
         g_CircuitBreakerTriggered = true;
         g_IsTradingAllowed = false; 
         return false;
      }
   }
   if(g_CircuitBreakerTriggered) return false;

   // ---------------------------------------------------------
   // [二级熔断] 单日净亏损限额 (Daily Drawdown Limit)
   // 逻辑：防上头。计算 (今日已平仓盈亏 + 当前持仓浮动盈亏)。
   // 修正：使用 g_RiskCheckStartTime 作为计算起点，允许手动重置
   // ---------------------------------------------------------
   if(!g_DailyStopTriggered && InpDailyLossPct > 0 && bal > 0) {
      double currentPL = GetHistoryProfit(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent()+3600) + GetFloatingPL(OP_BUY) + GetFloatingPL(OP_SELL); 
      
      // 核心计算：当前累计损益 - 重置时的基准值 = 本次运行周期的真实损益
      double dailyNetPL = currentPL - g_RiskCheckBaselinePL; 
      double lossLimit = bal * (InpDailyLossPct/100.0); 

      if(dailyNetPL < 0 && MathAbs(dailyNetPL) >= lossLimit) {
         Print(StringFormat("【二级熔断】风控触发! 当前净盈亏: %.2f, 基准: %.2f, 限额: %.2f", currentPL, g_RiskCheckBaselinePL, -lossLimit));
         CloseAll(); 
         g_DailyStopTriggered = true;
         return false;
      }
   }
   if(g_DailyStopTriggered) return false;


   // ---------------------------------------------------------
   // [三级熔断] 技术性止损 (Technical Stop)
   // 逻辑：承认方向错误。层数过高或逆势太远，砍掉单边。
   // ---------------------------------------------------------
   // 检查多头
   if(g_AllowLong) {
      int bCnt = CountOrders(OP_BUY);
      if(bCnt > 0) {
         bool hitLayer = (InpMaxLayerPerSide > 0 && bCnt >= InpMaxLayerPerSide);
         bool hitDist  = (InpMaxAdversePoints > 0 && GetMaxAdversePoints(OP_BUY) >= InpMaxAdversePoints);
         
         if(hitLayer || hitDist) {
            Print("【三级熔断】多头风控触发 (层数/点数超限)，强制平多!");
            ClosePositions(3); // 平多
            g_AllowLong = false; // 仅关闭多头开关
            // 不返回 false，允许程序继续处理空头
         }
      }
   }

   // 检查空头
   if(g_AllowShort) {
      int sCnt = CountOrders(OP_SELL);
      if(sCnt > 0) {
         bool hitLayer = (InpMaxLayerPerSide > 0 && sCnt >= InpMaxLayerPerSide);
         bool hitDist  = (InpMaxAdversePoints > 0 && GetMaxAdversePoints(OP_SELL) >= InpMaxAdversePoints);
         
         if(hitLayer || hitDist) {
            Print("【三级熔断】空头风控触发 (层数/点数超限)，强制平空!");
            ClosePositions(4); // 平空
            g_AllowShort = false; // 仅关闭空头开关
         }
      }
   }

   // 只要没触发一二级熔断，就返回 true 继续交易
   return true;
}
void SafeOrderSend(int t,double l,string c){ if(OrderSend(_Symbol,t,l,(t==OP_BUY?Ask:Bid),10,0,0,c,InpMagicNum,0,(t==OP_BUY?clrBlue:clrRed))<0) Print(GetLastError());}
int CountOrders(int t){int c=0;for(int i=0;i<OrdersTotal();i++)if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum&&OrderType()==t)c++;return c;}
double GetTotalLots(int t){double l=0;for(int i=0;i<OrdersTotal();i++)if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum&&OrderType()==t)l+=OrderLots();return l;}
double GetFloatingPL(int t){double p=0;for(int i=0;i<OrdersTotal();i++)if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum&&OrderType()==t)p+=OrderProfit()+OrderCommission()+OrderSwap();return p;}
double GetLastPrice(int t){double p=0;datetime d=0;for(int i=0;i<OrdersTotal();i++)if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum&&OrderType()==t)if(OrderOpenTime()>d){d=OrderOpenTime();p=OrderOpenPrice();}return p;}
double GetLastLot(int t){double l=InpInitialLots;datetime d=0;for(int i=0;i<OrdersTotal();i++)if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum&&OrderType()==t)if(OrderOpenTime()>d){d=OrderOpenTime();l=OrderLots();}return l;}
void CreateRect(string n,int x,int y,int w,int h,color bg,color border=CLR_NONE) { string name=g_ObjPrefix+n; if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);ObjectSetInteger(0,name,OBJPROP_BACK,false); }
void CreateLabel(string n,string t,int x,int y,color c,int s=9,string f="微软雅黑") { string name=g_ObjPrefix+n; if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0); ObjectSetString(0,name,OBJPROP_TEXT,t); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_COLOR,c); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,s); ObjectSetString(0,name,OBJPROP_FONT,f); ObjectSetInteger(0,name,OBJPROP_BACK,false); }
void CreateButton(string n,string t,int x,int y,int w,int h,color bg) { string name=g_ObjPrefix+n; if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_BUTTON,0,0,0); ObjectSetString(0,name,OBJPROP_TEXT,t); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_COLOR,g_ColorButtonText); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8); ObjectSetString(0,name,OBJPROP_FONT,"微软雅黑"); ObjectSetInteger(0,name,OBJPROP_BACK,false); }
void SetLabelText(string n,string t) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetString(0,g_ObjPrefix+n,OBJPROP_TEXT,t); }
void SetObjectColor(string n,color c) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetInteger(0,g_ObjPrefix+n,OBJPROP_COLOR,c); }
void SetBtnColor(string n,color c) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetInteger(0,g_ObjPrefix+n,OBJPROP_BGCOLOR,c); }
void SetRectBg(string n,color c) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetInteger(0,g_ObjPrefix+n,OBJPROP_BGCOLOR,c); }

void DrawToggleButton() {
   int x=UI_X_Offset, y=UI_Y_Offset-34;
   if(y < 5) y = 5;
   int w=90, h=24;
   if(ObjectFind(0,g_ToggleName)<0) ObjectCreate(0,g_ToggleName,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,g_ToggleName,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,g_ToggleName,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,g_ToggleName,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,g_ToggleName,OBJPROP_YSIZE,h);
   ObjectSetString(0,g_ToggleName,OBJPROP_TEXT, g_PanelVisible ? "隐藏面板" : "显示面板");
   ObjectSetInteger(0,g_ToggleName,OBJPROP_BGCOLOR, g_PanelVisible ? UI_ThemeColor : g_ColorButton);
   ObjectSetInteger(0,g_ToggleName,OBJPROP_COLOR, g_ColorButtonText);
   ObjectSetInteger(0,g_ToggleName,OBJPROP_FONTSIZE,8);
   ObjectSetString(0,g_ToggleName,OBJPROP_FONT,"微软雅黑");
}
// [新增] 计算持仓均价 (加权平均)
double GetAveragePrice(int type) {
   double totalLots = 0;
   double weightedPrice = 0;
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber()==InpMagicNum && OrderType()==type) {
         totalLots += OrderLots();
         weightedPrice += OrderLots() * OrderOpenPrice();
      }
   }
   if(totalLots > 0) return weightedPrice / totalLots;
   return 0;
}
