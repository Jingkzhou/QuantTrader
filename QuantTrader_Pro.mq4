//+------------------------------------------------------------------+
//|                                              QuantTrader_Pro.mq4 |
//|                                  基于反编译代码 1:1 逻辑复刻版本 |
//|                                            Version 1.0 Final     |
//+------------------------------------------------------------------+
#property copyright "QuantTrader Pro"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//|                            函数原型                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                            枚举定义                              |
//+------------------------------------------------------------------+
enum ENUM_OPEN_MODE
  {
   OPEN_MODE_TIMEFRAME = 1,    // A: 开单时区模式
   OPEN_MODE_INTERVAL  = 2,    // B: 开单时间间距(秒)模式
   OPEN_MODE_INSTANT   = 3     // C: 不延迟模式
  };

//+------------------------------------------------------------------+
//|                          订单统计结构体                          |
//+------------------------------------------------------------------+
struct OrderStats
  {
   int    buyCount;
   int    sellCount;
   int    buyPendingCount;
   int    sellPendingCount;
   double buyLots;
   double sellLots;
   double buyProfit;
   double sellProfit;
   double highestBuyPrice; // 多单最高开仓价 (原 Zi_16)
   double lowestBuyPrice;  // 多单最低开仓价 (原 Zi_17)
   double highestSellPrice;// 空单最高开仓价 (原 Zi_18)
   double lowestSellPrice; // 空单最低开仓价 (原 Zi_19)
   double avgBuyPrice;     // 多单平均价
   double avgSellPrice;    // 空单平均价
   
   // 挂单追踪专用
   int    lastBuyPendingTicket; // 原 Zi_14
   double lastBuyPendingPrice;  // 原 Zi_20
   int    lastSellPendingTicket;// 原 Zi_15
   double lastSellPendingPrice; // 原 Zi_21
  };

void CountOrders(OrderStats &stats);
void DrawPriceLimitLines();
void CheckOverweightStatus(OrderStats &stats);
bool CheckTradingEnvironment(const OrderStats &stats);
bool IsWithinTradingHours();
bool CheckOrderInterval(bool isBuy);
void UpdatePanel();
void DrawButtonPanel();
void DeleteAllPanelObjects();
void DeleteButtonPanelObjects();
void HandleButtonClick(string name);
void UpdateButtonColors(const OrderStats &stats);
double CalculateProfitSum(int type, int magic, int count, int mode);
int GetHigherTimeframe();
bool CloseAllOrders(int dir);
bool PartialClose(int orderType, int magic, int closeCount, int closeMode);
bool CheckReverseProtection(const OrderStats &stats);
bool CheckTrendProtection(const OrderStats &stats);
bool CheckProfitTarget(const OrderStats &stats);
bool CheckStopLoss(const OrderStats &stats);
bool CheckSingleSideProfit(const OrderStats &stats);
void ProcessBuyLogic(const OrderStats &stats);
void ProcessSellLogic(const OrderStats &stats);
void TrackPendingOrders(const OrderStats &stats, int direction);
void ShowStopMessage(string msg);
void ClearStopMessage();



//+------------------------------------------------------------------+
//|                            输入参数                              |
//+------------------------------------------------------------------+

//--- 价格限制参数
extern double BuyFirstOrderPriceLimit   = 0;            // B以上不开(首单)
extern double SellFirstOrderPriceLimit  = 0;            // S以下不开(首单)
extern double BuyAddOrderPriceLimit     = 0;            // B以上不开(补单)
extern double SellAddOrderPriceLimit    = 0;            // S以下不开(补单)
extern string PriceLimitStartTime       = "00:00";      // 限价开始时间
extern string PriceLimitEndTime         = "24:00";      // 限价结束时间

//--- 保护开关
extern bool   EnableReverseProtection   = true;         // 逆势保护开关 (CloseBuySell)
extern bool   EnableTrendProtection     = true;         // 顺势保护开关 (HomeopathyCloseAll)
extern bool   EnableLockTrend           = false;        // 完全对锁时挂上顺势开关 (Homeopathy)
extern bool   StopAfterClose            = false;        // 平仓后停止交易 (Over)
extern int    RestartDelaySeconds       = 0;            // 整体平仓后多少秒后新局 (NextTime)

//--- 距离参数
extern double SecondParamTriggerLoss    = 0;            // 浮亏多少启用第二参数 (Money, 内部转负数)
extern int    FirstOrderDistance        = 30;           // 首单距离 (FirstStep)
extern int    MinGridDistance           = 60;           // 最小距离 (MinDistance)
extern int    SecondMinGridDistance     = 60;           // 第二最小距离 (TwoMinDistance)
extern int    PendingOrderTrailPoints   = 5;            // 挂单追踪点数 (StepTrallOrders)
extern int    GridStep                  = 100;          // 补单间距 (Step)
extern int    SecondGridStep            = 100;          // 第二补单间距 (TwoStep)

//--- 开单控制
extern ENUM_OPEN_MODE OrderOpenMode     = OPEN_MODE_INSTANT; // 开单模式
extern ENUM_TIMEFRAMES OrderTimeframe   = PERIOD_M1;         // 开单时区
extern int    OrderIntervalSeconds      = 30;                // 开单时间间距(秒)

//--- 风控参数
extern double MaxFloatingLoss           = 100000;       // 单边浮亏超过多少不继续加仓 (MaxLoss)
extern double MaxLossCloseThreshold     = 50;           // 单边平仓限制 (MaxLossCloseAll)
extern int    MaxVolatilityPoints       = 0;            // 波动限制 (原 Zong_32_in_130)

//--- 手数参数
extern double BaseLotSize               = 0.01;         // 起始手数
extern double MaxLotSize                = 10;           // 最大开单手数
extern double LotIncrement              = 0;            // 累加手数
extern double LotMultiplier             = 1.3;          // 倍率
extern int    LotDecimalPlaces          = 2;            // 下单量的小数位

//--- 止盈止损
extern double TotalProfitTarget         = 0.5;          // 整体平仓金额 (CloseAll)
extern bool   EnableLayeredProfit       = true;         // 单边平仓金额累加开关 (Profit)
extern double SingleSideProfit          = 2;            // 单边平仓金额 (StopProfit)
extern double StopLossAmount            = 0;            // 止损金额 (StopLoss)

//--- 交易限制
extern int    MagicNumber               = 9527;         // 魔术号
extern int    MaxTotalOrders            = 50;           // 最大单量 (Totals)
extern int    MaxAllowedSpread          = 200;          // 点差限制
extern int    MinLeverage               = 100;          // 平台杠杆限制

//--- 交易时间
extern string TradingStartTime          = "00:00";      // EA开始时间
extern string TradingEndTime            = "24:00";      // EA结束时间

//--- 显示设置
extern color  BuyAvgPriceColor          = MediumSeaGreen; // 多单平均价颜色
extern color  SellAvgPriceColor         = Crimson;        // 空单平均价颜色
extern string OrderComment1             = "备注1";        // 订单备注1
extern string OrderComment2             = "备注2";        // 订单备注2

//+------------------------------------------------------------------+
//|                            全局常量                              |
//+------------------------------------------------------------------+
const string PANEL_PREFIX  = "StatisticsPanel";
const string BUTTON_PREFIX = "ButtonPanel";
const string BTN_BUY_CLOSE     = "Button1";
const string BTN_SELL_CLOSE    = "Button2";
const string BTN_ALL_CLOSE     = "Button5";
const string FONT_NAME         = "Microsoft YaHei";
const int    FONT_SIZE         = 10;
const color  COLOR_PROFIT      = Lime;
const color  COLOR_LOSS        = Red;
const color  COLOR_NEUTRAL     = Blue;
const color  COLOR_DISABLED    = DimGray;

//+------------------------------------------------------------------+
//|                            全局变量                              |
//+------------------------------------------------------------------+
bool     g_IsPanelCollapsed     = true;
bool     g_IsButtonPanelVisible = false;

// 交易权限标志
bool     g_AllowBuy             = true;
bool     g_AllowSell            = true;
bool     g_BuyTradingEnabled    = true; // 按钮控制
bool     g_SellTradingEnabled   = true; // 按钮控制

int      Slippage               = 0;    // 滑点 (init中初始化)

// 仓位状态
bool     g_SellOverweight       = false; // 多单多，空单少 (原 Zong_39)
bool     g_BuyOverweight        = false; // 空单多，多单少 (原 Zong_40)

// 时间与冷却
datetime g_LastBuyOrderTime     = 0;
datetime g_LastSellOrderTime    = 0;
datetime g_GlobalResumeTime     = 0;    // NextTime 冷却
double   g_TotalDeposits        = 0;    // 总入金 (用于计算回报率)

// 挂单追踪缓存 (原代码 Zi_14/15, Zi_20/21)
// 原代码中这些变量是在 start() 循环中实时更新的，这里我们每次 OnTick 重新计算

string   g_EAName               = "QuantTrader Pro";



//+------------------------------------------------------------------+
//|                          初始化函数                              |
//+------------------------------------------------------------------+
int OnInit()
  {
   ObjectDelete(0, "tubiao"); ObjectDelete(0, "tubiao1"); ObjectDelete(0, "tubiao2");
   EventSetTimer(1);
   g_EAName = WindowExpertName();
   OrderTimeframe = (ENUM_TIMEFRAMES)GetHigherTimeframe();

   // 计算总入金 (1:1 复刻 init 中的逻辑)
   double deposits = 0;
   int historyTotal = OrdersHistoryTotal();
   for(int i = 0; i < historyTotal; i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderType() == OP_BALANCE && OrderProfit() > 0)
         deposits += OrderProfit();
     }
   if(deposits == 0) deposits = 100.0; // 防止除零
   g_TotalDeposits = deposits;

   // 滑点逻辑 1:1 (原代码 init)

   // 滑点逻辑 1:1 (原代码 init)
   if(_Digits == 5 || _Digits == 3) Slippage = 30;

   // 参数转负数 (内部逻辑统一使用 < -Value)
   MaxLossCloseThreshold  = -MathAbs(MaxLossCloseThreshold);
   MaxFloatingLoss        = -MathAbs(MaxFloatingLoss);
   StopLossAmount         = -MathAbs(StopLossAmount);
   SecondParamTriggerLoss = -MathAbs(SecondParamTriggerLoss);

   // 时间字符串处理
   StringReplace(TradingStartTime, " ", ""); StringTrimLeft(TradingStartTime); StringTrimRight(TradingStartTime);
   StringReplace(TradingEndTime, " ", ""); StringTrimLeft(TradingEndTime); StringTrimRight(TradingEndTime);
   if(TradingEndTime == "24:00") TradingEndTime = "23:59:59";

   StringReplace(PriceLimitStartTime, " ", ""); StringTrimLeft(PriceLimitStartTime); StringTrimRight(PriceLimitStartTime);
   StringReplace(PriceLimitEndTime, " ", ""); StringTrimLeft(PriceLimitEndTime); StringTrimRight(PriceLimitEndTime);
   if(PriceLimitEndTime == "24:00") PriceLimitEndTime = "23:59:59";

   // 距离参数校验 (原代码 Zong_48)
   int stopLevel = (int)(MathMax(MarketInfo(Symbol(), MODE_FREEZELEVEL), MarketInfo(Symbol(), MODE_STOPLEVEL)) + 1.0);
   if(GridStep < stopLevel) GridStep = stopLevel;
   if(FirstOrderDistance < stopLevel) FirstOrderDistance = stopLevel;
   if(MinGridDistance < stopLevel) MinGridDistance = stopLevel;

   g_AllowBuy = true;
   g_AllowSell = true;
   g_IsPanelCollapsed = true;

   DrawPriceLimitLines();
   UpdatePanel();
   PlaySound("Starting.wav");
   
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteAllPanelObjects();
   ObjectDelete(0, "HLINE_LONG");
   ObjectDelete(0, "HLINE_SHORT");
   ObjectDelete(0, "HLINE_LONGII");
   ObjectDelete(0, "HLINE_SHORTII");
   ObjectDelete(0, "SLb");
   ObjectDelete(0, "SLs");
   ObjectDelete(0, "Stop");
   ObjectDelete(0, "Spread");
  }

void OnTimer()
  {
   UpdatePanel();
   if(g_IsButtonPanelVisible) DrawButtonPanel();
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK) HandleButtonClick(sparam);
  }

//+------------------------------------------------------------------+
//|                          主交易逻辑                              |
//| 1:1 复刻 Start 函数的流控制逻辑                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. 统计订单
   OrderStats stats;
   CountOrders(stats);

   // 2. 初始化本轮 Tick 的交易权限 (默认跟随全局开关)
   // 原代码使用变量 Zong_29_bo_128 (Buy) 和 Zong_30_bo_129 (Sell)
   bool tickAllowBuy = g_AllowBuy;
   bool tickAllowSell = g_AllowSell;

   // 3. 检查 StopAfterClose (Over) 单边停止逻辑
   if(StopAfterClose)
     {
      if(stats.buyCount == 0) tickAllowBuy = false;
      if(stats.sellCount == 0) tickAllowSell = false;
     }

   // 4. 检查交易环境 
   // 原版逻辑：环境检查失败时不 return，而是将 tickAllow 设为 false，并显示 Stop 消息
   if(!CheckTradingEnvironment(stats))
     {
      tickAllowBuy = false;
      tickAllowSell = false;
      ShowStopMessage("不符合设定环境，EA停止运行！");
     }
   else
     {
      // 只有环境检查通过，才清除消息 (可能被后续 Time 检查覆盖)
      ClearStopMessage(); 
     }

   // 5. 检查交易时间 (原版 Zong_48)
   if(!IsWithinTradingHours())
     {
      tickAllowBuy = false;
      tickAllowSell = false;
      ShowStopMessage("非开仓时间区间，停止开仓！");
     }

   // 6. 检查冷却时间 (NextTime)
   if(TimeCurrent() < g_GlobalResumeTime)
     {
      tickAllowBuy = false;
      tickAllowSell = false;
      ShowStopMessage("EA停止运行 " + IntegerToString((int)(g_GlobalResumeTime - TimeCurrent())) + "秒!");
     }

   // --- 逻辑执行区 (以下逻辑即使 tickAllow=false 也会部分执行，如平仓) ---

   // A. 检查超仓状态
   CheckOverweightStatus(stats);

   // B. 更新UI颜色
   UpdateButtonColors(stats);

   // C. 平仓保护逻辑 (始终运行，不受 Allow 限制)
   // 逻辑链优先级：顺势 -> 逆势 -> 整体止盈 -> 止损 -> 单边止盈
   bool protectionTriggered = false;
   if(CheckTrendProtection(stats)) protectionTriggered = true;
   // 只有上面没触发才继续查下一个 (模拟原版 return(0) 效果)
   if(!protectionTriggered && CheckReverseProtection(stats)) protectionTriggered = true;
   if(!protectionTriggered && CheckProfitTarget(stats)) protectionTriggered = true;
   if(!protectionTriggered && CheckStopLoss(stats)) protectionTriggered = true;
   if(!protectionTriggered && CheckSingleSideProfit(stats)) protectionTriggered = true;

   // D. 开单逻辑 (受 tickAllow 和 按钮 控制)
   if(!protectionTriggered)
     {
      if(tickAllowBuy && g_BuyTradingEnabled) ProcessBuyLogic(stats);
      if(tickAllowSell && g_SellTradingEnabled) ProcessSellLogic(stats);
     }

   // E. 挂单追踪 
   // 原版逻辑: if(Zi_20_do != 0.0 && Zong_29_bo_128) ... 
   // 只有在 tickAllow 为 true 时才执行追踪
   if(tickAllowBuy && g_BuyTradingEnabled) TrackPendingOrders(stats, 1); // 1=Buy
   if(tickAllowSell && g_SellTradingEnabled) TrackPendingOrders(stats, -1); // -1=Sell

   // F. 刷新面板
   UpdatePanel();
  }

//+------------------------------------------------------------------+
//|                          辅助功能函数                            |
//+------------------------------------------------------------------+
void CountOrders(OrderStats &stats)
  {
   ZeroMemory(stats);
   double buyWeightedPrice = 0;
   double sellWeightedPrice = 0;

   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || MagicNumber != OrderMagicNumber()) continue;

      int type = OrderType();
      double lots = OrderLots();
      double price = NormalizeDouble(OrderOpenPrice(), _Digits);

      if(type == OP_BUYSTOP)
        {
         stats.buyPendingCount++;
         if(stats.highestBuyPrice < price || stats.highestBuyPrice == 0.0) stats.highestBuyPrice = price;
         stats.lastBuyPendingTicket = OrderTicket();
         stats.lastBuyPendingPrice = price;
        }
      if(type == OP_SELLSTOP)
        {
         stats.sellPendingCount++;
         if(stats.lowestSellPrice > price || stats.lowestSellPrice == 0.0) stats.lowestSellPrice = price;
         stats.lastSellPendingTicket = OrderTicket();
         stats.lastSellPendingPrice = price;
        }
      if(type == OP_BUY)
        {
         stats.buyCount++;
         stats.buyLots += lots;
         buyWeightedPrice += price * lots;
         if(stats.highestBuyPrice < price || stats.highestBuyPrice == 0.0) stats.highestBuyPrice = price;
         if(stats.lowestBuyPrice > price || stats.lowestBuyPrice == 0.0) stats.lowestBuyPrice = price;
         stats.buyProfit += OrderProfit() + OrderSwap() + OrderCommission();
        }
      if(type == OP_SELL)
        {
         stats.sellCount++;
         stats.sellLots += lots;
         sellWeightedPrice += price * lots;
         if(stats.lowestSellPrice > price || stats.lowestSellPrice == 0.0) stats.lowestSellPrice = price;
         if(stats.highestSellPrice < price || stats.highestSellPrice == 0.0) stats.highestSellPrice = price;
         stats.sellProfit += OrderProfit() + OrderSwap() + OrderCommission();
        }
     }
   
   if(stats.buyLots > 0) stats.avgBuyPrice = NormalizeDouble(buyWeightedPrice / stats.buyLots, _Digits);
   if(stats.sellLots > 0) stats.avgSellPrice = NormalizeDouble(sellWeightedPrice / stats.sellLots, _Digits);
  }

double CalculateNextLot(int currentLayer, bool isBuy)
  {
   double nextLot;
   if(currentLayer == 0) nextLot = BaseLotSize;
   else nextLot = NormalizeDouble(currentLayer * LotIncrement + BaseLotSize * MathPow(LotMultiplier, currentLayer), LotDecimalPlaces);
   if(nextLot > MaxLotSize) nextLot = MaxLotSize;
   return nextLot;
  }

bool CheckTradingEnvironment(const OrderStats &stats)
  {
   if(AccountLeverage() < MinLeverage) return false;
   if(!IsTradeAllowed() || !IsExpertEnabled() || IsStopped()) return false;
   if(stats.buyCount + stats.sellCount >= MaxTotalOrders) return false;
   if(MarketInfo(Symbol(), MODE_SPREAD) > MaxAllowedSpread) return false;

   // 波动检查 (原版: Zong_32_in_130)
   if(MaxVolatilityPoints > 0)
     {
      double h = iHigh(Symbol(), PERIOD_M1, 0);
      double l = iLow(Symbol(), PERIOD_M1, 5);
      if((int)MathRound((h - l) / _Point) >= MaxVolatilityPoints) return false;
      
      l = iLow(Symbol(), PERIOD_M1, 0);
      h = iHigh(Symbol(), PERIOD_M1, 5);
      if((int)MathRound(MathAbs((l - h) / _Point)) >= MaxVolatilityPoints) return false;
     }
   return true;
  }

bool IsWithinTradingHours()
  {
   datetime now;
   if(IsTesting()) now = TimeCurrent(); else now = TimeLocal();
   
   MqlDateTime dt; TimeToStruct(now, dt);
   string day = StringFormat("%04d.%02d.%02d ", dt.year, dt.mon, dt.day);
   datetime start = StringToTime(day + TradingStartTime);
   datetime end = StringToTime(day + TradingEndTime);
   
   if(start < end) return (now >= start && now <= end);
   else return (now >= start || now <= end); // 跨天
  }

//+------------------------------------------------------------------+
//|                      逻辑复刻辅助函数                            |
//+------------------------------------------------------------------+

void DrawPriceLimitLines()
  {
   if(BuyFirstOrderPriceLimit > 0)
     {
      ObjectCreate(0, "HLINE_LONG", OBJ_HLINE, 0, 0, BuyFirstOrderPriceLimit);
      ObjectSetInteger(0, "HLINE_LONG", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "HLINE_LONG", OBJPROP_COLOR, clrMagenta);
     }
   if(SellFirstOrderPriceLimit > 0)
     {
      ObjectCreate(0, "HLINE_SHORT", OBJ_HLINE, 0, 0, SellFirstOrderPriceLimit);
      ObjectSetInteger(0, "HLINE_SHORT", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "HLINE_SHORT", OBJPROP_COLOR, clrMagenta);
     }
   if(BuyAddOrderPriceLimit > 0)
     {
      ObjectCreate(0, "HLINE_LONGII", OBJ_HLINE, 0, 0, BuyAddOrderPriceLimit);
      ObjectSetInteger(0, "HLINE_LONGII", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "HLINE_LONGII", OBJPROP_COLOR, clrMagenta);
     }
   if(SellAddOrderPriceLimit > 0)
     {
      ObjectCreate(0, "HLINE_SHORTII", OBJ_HLINE, 0, 0, SellAddOrderPriceLimit);
      ObjectSetInteger(0, "HLINE_SHORTII", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "HLINE_SHORTII", OBJPROP_COLOR, clrMagenta);
     }
  }

void CheckOverweightStatus(OrderStats &stats)
  {
   if(stats.buyLots > 0.0 && stats.sellLots / stats.buyLots > 3.0 && stats.sellLots - stats.buyLots > 0.2)
      g_SellOverweight = true;
   else
      g_SellOverweight = false;

   if(stats.sellLots > 0.0 && stats.buyLots / stats.sellLots > 3.0 && stats.buyLots - stats.sellLots > 0.2)
      g_BuyOverweight = true;
   else
      g_BuyOverweight = false;
  }

bool CheckOrderInterval(bool isBuy)
  {
   if(OrderOpenMode == OPEN_MODE_INSTANT) return true;
   datetime last = isBuy ? g_LastBuyOrderTime : g_LastSellOrderTime;
   if(OrderOpenMode == OPEN_MODE_INTERVAL) return (TimeCurrent() - last >= OrderIntervalSeconds);
   if(OrderOpenMode == OPEN_MODE_TIMEFRAME) return (last < iTime(NULL, OrderTimeframe, 0));
   return true;
  }

// 1:1 复刻 CloseBuySell 的盈亏差值计算与对冲 (含重置逻辑)
bool CheckReverseProtection(const OrderStats &stats)
  {
   if(!EnableReverseProtection) return false;

   // --- Buy Side ---
   // 计算: (前1个盈利单利润) - (前2个亏损单利润绝对值)
   double profitDiffBuy = CalculateProfitSum(OP_BUY, MagicNumber, 1, 1) - CalculateProfitSum(OP_BUY, MagicNumber, 2, 2);
   static double maxDiffBuy = 0.0;
   
   // 记录历史最大差值
   if(maxDiffBuy < profitDiffBuy) maxDiffBuy = profitDiffBuy;

   // 触发条件: 历史最大差值>0 && 当前差值>0 (意味着盈利足以覆盖亏损)
   if(maxDiffBuy > 0.0 && profitDiffBuy > 0.0)
     {
      double maxProfitLot = 0;
      double maxProfitVal = 0;
      // 找最大盈利单的手数
      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY) {
            if(OrderProfit() > maxProfitVal) { maxProfitVal = OrderProfit(); maxProfitLot = OrderLots(); }
         }
      }
      // 手数失衡判断 (核心逻辑)
      if(stats.buyLots > (maxProfitLot * 3.0 + stats.sellLots) && stats.buyCount > 3)
        {
         // 执行平仓: 1个盈利, 2个亏损
         PartialClose(OP_BUY, MagicNumber, 1, 1);
         PartialClose(OP_BUY, MagicNumber, 2, 2);
         
         maxDiffBuy = 0.0; // 关键：平仓后重置最大差值
         
         Print("逆势保护(多): 对冲平仓");
         return true;
        }
     }

   // --- Sell Side ---
   double profitDiffSell = CalculateProfitSum(OP_SELL, MagicNumber, 1, 1) - CalculateProfitSum(OP_SELL, MagicNumber, 2, 2);
   static double maxDiffSell = 0.0;
   
   if(maxDiffSell < profitDiffSell) maxDiffSell = profitDiffSell;

   if(maxDiffSell > 0.0 && profitDiffSell > 0.0)
     {
      double maxProfitLot = 0;
      double maxProfitVal = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL) {
            if(OrderProfit() > maxProfitVal) { maxProfitVal = OrderProfit(); maxProfitLot = OrderLots(); }
         }
      }
      if(stats.sellLots > (maxProfitLot * 3.0 + stats.buyLots) && stats.sellCount > 3)
        {
         PartialClose(OP_SELL, MagicNumber, 1, 1);
         PartialClose(OP_SELL, MagicNumber, 2, 2);
         
         maxDiffSell = 0.0; // 关键：平仓后重置
         
         Print("逆势保护(空): 对冲平仓");
         return true;
        }
     }
   return false;
  }

void ProcessBuyLogic(const OrderStats &stats)
  {
   if(stats.buyPendingCount > 0) return;
   if(stats.buyCount + stats.sellCount >= MaxTotalOrders) return;
   if(stats.buyProfit < -MathAbs(MaxFloatingLoss) && stats.buyCount > 0) return;

   double pendingPrice = 0;
   double totalProfit = stats.buyProfit + stats.sellProfit;
   // Zi_35_bo: totalProfit > -Money (SecondParamTriggerLoss)
   bool useFirstParam = (SecondParamTriggerLoss == 0 || totalProfit > -MathAbs(SecondParamTriggerLoss));

   if(stats.buyCount == 0)
     {
      pendingPrice = NormalizeDouble(Ask + FirstOrderDistance * Point, Digits);
      if(BuyFirstOrderPriceLimit > 0 && Ask >= BuyFirstOrderPriceLimit) return;
     }
   else
     {
      if(useFirstParam) pendingPrice = NormalizeDouble(Ask + MinGridDistance * Point, Digits);
      else pendingPrice = NormalizeDouble(Ask + SecondMinGridDistance * Point, Digits);

      // 距离修正
      double step = useFirstParam ? GridStep : SecondGridStep;
      double limitPrice = 0;
      // 注意: 逆势时 Ask 在 Lowest 之下. Zi_26 < Zi_17 - Step
      if(useFirstParam) limitPrice = NormalizeDouble(stats.lowestBuyPrice - step * Point, Digits);
      else if(stats.lowestBuyPrice!=0) limitPrice = NormalizeDouble(stats.lowestBuyPrice - step * Point, Digits);

      if(stats.lowestBuyPrice != 0 && pendingPrice > limitPrice)
         pendingPrice = NormalizeDouble(Ask + step * Point, Digits);
     }

   bool canOpen = false;
   if(stats.buyCount == 0) canOpen = true;
   else 
     {
      double step = useFirstParam ? GridStep : SecondGridStep;
      // 1. 顺势 (超仓/对锁)
      if(stats.highestBuyPrice != 0 && pendingPrice >= NormalizeDouble(stats.highestBuyPrice + step * Point, Digits) && g_SellOverweight)
        {
         if(useFirstParam || SecondParamTriggerLoss != 0) canOpen = true;
        }
      // 2. 逆势
      if(stats.lowestBuyPrice != 0 && pendingPrice <= NormalizeDouble(stats.lowestBuyPrice - step * Point, Digits))
        {
         if(useFirstParam || SecondParamTriggerLoss != 0) canOpen = true;
        }
      // 3. 对锁突破
      if(EnableLockTrend && stats.highestBuyPrice != 0 && 
         pendingPrice >= NormalizeDouble(stats.highestBuyPrice + step * Point, Digits) && 
         stats.buyLots == stats.sellLots) canOpen = true;
     }

   if(!canOpen) return;
   if(OrderOpenMode != OPEN_MODE_INSTANT) { if(!CheckOrderInterval(true)) return; }

   double lots = CalculateNextLot(stats.buyCount, true);
   if(lots * 2.0 >= AccountFreeMargin() / MarketInfo(Symbol(), MODE_MARGINREQUIRED)) return;

   string comment = OrderComment1;
   if(stats.buyCount > 0 && stats.highestBuyPrice != 0 && 
      pendingPrice >= NormalizeDouble(stats.highestBuyPrice + GridStep * Point, Digits)) comment = OrderComment2;

   int ticket = OrderSend(Symbol(), OP_BUYSTOP, lots, pendingPrice, Slippage, 0, 0, comment, MagicNumber, 0, Blue);
   if(ticket > 0) g_LastBuyOrderTime = TimeCurrent();
  }

void ProcessSellLogic(const OrderStats &stats)
  {
   if(stats.sellPendingCount > 0) return;
   if(stats.buyCount + stats.sellCount >= MaxTotalOrders) return;
   if(stats.sellProfit < -MathAbs(MaxFloatingLoss) && stats.sellCount > 0) return;

   double pendingPrice = 0;
   double totalProfit = stats.buyProfit + stats.sellProfit;
   bool useFirstParam = (SecondParamTriggerLoss == 0 || totalProfit > -MathAbs(SecondParamTriggerLoss));

   if(stats.sellCount == 0)
     {
      pendingPrice = NormalizeDouble(Bid - FirstOrderDistance * Point, Digits);
      if(SellFirstOrderPriceLimit > 0 && Bid <= SellFirstOrderPriceLimit) return;
     }
   else
     {
      if(useFirstParam) pendingPrice = NormalizeDouble(Bid - MinGridDistance * Point, Digits);
      else pendingPrice = NormalizeDouble(Bid - SecondMinGridDistance * Point, Digits);

      double step = useFirstParam ? GridStep : SecondGridStep;
      double limitPrice = 0;
      if(useFirstParam) limitPrice = NormalizeDouble(stats.highestSellPrice + step * Point, Digits);
      else if(stats.highestSellPrice!=0) limitPrice = NormalizeDouble(stats.highestSellPrice + step * Point, Digits);

      if(stats.highestSellPrice != 0 && pendingPrice < limitPrice)
         pendingPrice = NormalizeDouble(Bid - step * Point, Digits);
     }

   bool canOpen = false;
   if(stats.sellCount == 0) canOpen = true;
   else
     {
      double step = useFirstParam ? GridStep : SecondGridStep;
      // 1. 顺势
      if(stats.lowestSellPrice != 0 && pendingPrice <= NormalizeDouble(stats.lowestSellPrice - step * Point, Digits) && g_BuyOverweight)
        {
         if(useFirstParam || SecondParamTriggerLoss != 0) canOpen = true;
        }
      // 2. 逆势
      if(stats.highestSellPrice != 0 && pendingPrice >= NormalizeDouble(stats.highestSellPrice + step * Point, Digits))
        {
         if(useFirstParam || SecondParamTriggerLoss != 0) canOpen = true;
        }
      // 3. 对锁
      if(EnableLockTrend && stats.lowestSellPrice != 0 && 
         pendingPrice <= NormalizeDouble(stats.lowestSellPrice - step * Point, Digits) && 
         stats.buyLots == stats.sellLots) canOpen = true;
     }

   if(!canOpen) return;
   if(OrderOpenMode != OPEN_MODE_INSTANT) { if(!CheckOrderInterval(false)) return; }

   double lots = CalculateNextLot(stats.sellCount, false);
   if(lots * 2.0 >= AccountFreeMargin() / MarketInfo(Symbol(), MODE_MARGINREQUIRED)) return;

   string comment = OrderComment1;
   if(stats.sellCount > 0 && stats.lowestSellPrice != 0 && 
      pendingPrice <= NormalizeDouble(stats.lowestSellPrice - GridStep * Point, Digits)) comment = OrderComment2;

   int ticket = OrderSend(Symbol(), OP_SELLSTOP, lots, pendingPrice, Slippage, 0, 0, comment, MagicNumber, 0, Red);
   if(ticket > 0) g_LastSellOrderTime = TimeCurrent();
  }

// 1:1 复刻 TrackPendingOrders (包含流控制检查)
void TrackPendingOrders(const OrderStats &stats, int direction)
  {
   if(PendingOrderTrailPoints <= 0) return;
   double trailGap = PendingOrderTrailPoints * Point;
   double totalProfit = stats.buyProfit + stats.sellProfit;
   bool useFirstParam = (SecondParamTriggerLoss == 0 || totalProfit > -MathAbs(SecondParamTriggerLoss));

   // Buy
   if(direction == 1 && stats.lastBuyPendingTicket > 0)
     {
      if(OrderSelect(stats.lastBuyPendingTicket, SELECT_BY_TICKET))
        {
         double orderPrice = OrderOpenPrice();
         double targetPrice = 0;
         
         // 必须重新计算目标价 (逻辑同 ProcessBuyLogic)
         if(stats.buyCount == 0) targetPrice = NormalizeDouble(Ask + FirstOrderDistance * Point, Digits);
         else
           {
            if(useFirstParam) targetPrice = NormalizeDouble(Ask + MinGridDistance * Point, Digits);
            else targetPrice = NormalizeDouble(Ask + SecondMinGridDistance * Point, Digits);
            
            double step = useFirstParam ? GridStep : SecondGridStep;
            double limitPrice = 0;
            if(useFirstParam) limitPrice = NormalizeDouble(stats.lowestBuyPrice - step*Point, Digits);
            else if(stats.lowestBuyPrice!=0) limitPrice = NormalizeDouble(stats.lowestBuyPrice - step*Point, Digits);
            
            if(stats.lowestBuyPrice!=0 && targetPrice > limitPrice) targetPrice = NormalizeDouble(Ask + step*Point, Digits);
           }

         // 原版逻辑: OrderPrice - Gap > Target
         if(orderPrice - trailGap > targetPrice)
           {
            // 复核开仓条件 (简版复刻)
            bool isAllow = false;
            double step = useFirstParam ? GridStep : SecondGridStep;
            
            if(stats.buyCount==0) isAllow=true;
            else if(stats.lowestBuyPrice!=0 && targetPrice <= NormalizeDouble(stats.lowestBuyPrice - step*Point, Digits)) isAllow=true;
            else if(stats.highestBuyPrice!=0 && targetPrice >= NormalizeDouble(stats.highestBuyPrice + step*Point, Digits)) {
               if(g_SellOverweight || (EnableLockTrend && stats.buyLots==stats.sellLots)) isAllow=true;
            }
            
            if(isAllow) 
              {
               if(!OrderModify(OrderTicket(), targetPrice, 0, 0, 0, Blue))
                  Print("OrderModify Error: ", GetLastError());
              }
           }
        }
     }

   // Sell
   if(direction == -1 && stats.lastSellPendingTicket > 0)
     {
      if(OrderSelect(stats.lastSellPendingTicket, SELECT_BY_TICKET))
        {
         double orderPrice = OrderOpenPrice();
         double targetPrice = 0;
         
         if(stats.sellCount == 0) targetPrice = NormalizeDouble(Bid - FirstOrderDistance * Point, Digits);
         else
           {
            if(useFirstParam) targetPrice = NormalizeDouble(Bid - MinGridDistance * Point, Digits);
            else targetPrice = NormalizeDouble(Bid - SecondMinGridDistance * Point, Digits);
            
            double step = useFirstParam ? GridStep : SecondGridStep;
            double limitPrice = 0;
            if(useFirstParam) limitPrice = NormalizeDouble(stats.highestSellPrice + step*Point, Digits);
            else if(stats.highestSellPrice!=0) limitPrice = NormalizeDouble(stats.highestSellPrice + step*Point, Digits);
            
            if(stats.highestSellPrice!=0 && targetPrice < limitPrice) targetPrice = NormalizeDouble(Bid - step*Point, Digits);
           }

         if(orderPrice + trailGap < targetPrice)
           {
            bool isAllow = false;
            double step = useFirstParam ? GridStep : SecondGridStep;
            if(stats.sellCount==0) isAllow=true;
            else if(stats.highestSellPrice!=0 && targetPrice >= NormalizeDouble(stats.highestSellPrice + step*Point, Digits)) isAllow=true;
            else if(stats.lowestSellPrice!=0 && targetPrice <= NormalizeDouble(stats.lowestSellPrice - step*Point, Digits)) {
               if(g_BuyOverweight || (EnableLockTrend && stats.buyLots==stats.sellLots)) isAllow=true;
            }
            
            if(isAllow) 
              {
               if(!OrderModify(OrderTicket(), targetPrice, 0, 0, 0, Red))
                  Print("OrderModify Error: ", GetLastError());
              }
           }
        }
     }
  }

bool CheckProfitTarget(const OrderStats &stats)
  {
   if(StopAfterClose && (stats.buyProfit + stats.sellProfit >= TotalProfitTarget) && TotalProfitTarget > 0)
     {
      Print("整体止盈触发");
      if(CloseAllOrders(0)) 
        {
         if(RestartDelaySeconds > 0) g_GlobalResumeTime = TimeCurrent() + RestartDelaySeconds;
         g_AllowBuy = false; g_AllowSell = false;
         return true;
        }
     }
   return false;
  }

bool CheckStopLoss(const OrderStats &stats)
  {
   if(StopLossAmount > 0 && (stats.buyProfit + stats.sellProfit <= -MathAbs(StopLossAmount)))
     {
      Print("止损触发");
      CloseAllOrders(0);
      if(RestartDelaySeconds > 0) g_GlobalResumeTime = TimeCurrent() + RestartDelaySeconds;
      return true;
     }
   return false;
  }

bool CheckSingleSideProfit(const OrderStats &stats)
  {
   if(SingleSideProfit <= 0) return false;
   double bt = EnableLayeredProfit ? SingleSideProfit * stats.buyCount : SingleSideProfit;
   double st = EnableLayeredProfit ? SingleSideProfit * stats.sellCount : SingleSideProfit;

   if(stats.buyCount > 0 && stats.buyProfit > bt) { CloseAllOrders(1); return true; }
   if(stats.sellCount > 0 && stats.sellProfit > st) { CloseAllOrders(-1); return true; }
   return false;
  }

bool CheckTrendProtection(const OrderStats &stats)
  {
   if(!EnableTrendProtection) return false;
   int ss = 0;
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && OrderComment()=="SS") ss++;
   }
   if(ss > 0 && (stats.buyProfit + stats.sellProfit >= TotalProfitTarget) && TotalProfitTarget > 0) {
      CloseAllOrders(0);
      if(RestartDelaySeconds > 0) g_GlobalResumeTime = TimeCurrent() + RestartDelaySeconds;
      return true;
   }
   return false;
  }

// 1:1 复刻平仓逻辑 (纯 OrderClose 循环，无 CloseBy)
bool PartialClose(int orderType, int magic, int closeCount, int closeMode)
  {
   bool success = false;
   for(int c=0; c<closeCount; c++)
     {
      int ticket = -1;
      double val = 0;
      // 遍历寻找最佳订单
      for(int i=OrdersTotal()-1; i>=0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol()!=Symbol() || (magic!=-1 && OrderMagicNumber()!=magic)) continue;
         if(orderType!=-100 && OrderType()!=orderType) continue;
         
         double p = OrderProfit();
         if(closeMode == 1) { // 盈利单: 找最大值
            if(p > 0 && (ticket == -1 || p > val)) { val = p; ticket = OrderTicket(); }
         } else { // 亏损单: 找最小值 (负数最大绝对值)
            if(p < 0 && (ticket == -1 || p < val)) { val = p; ticket = OrderTicket(); }
         }
        }
        
      if(ticket != -1) {
         if(OrderSelect(ticket, SELECT_BY_TICKET)) {
             double price = (OrderType()==OP_BUY) ? Bid : Ask;
             if(OrderClose(ticket, OrderLots(), price, Slippage, clrNONE)) success = true;
         }
      }
     }
   return success;
  }

bool CloseAllOrders(int dir) // 1=Buy, -1=Sell, 0=All. 返回true如果全平了
  {
   bool res = true;
   for(int i=OrdersTotal()-1; i>=0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
         int type = OrderType();
         bool close = false;
         if(dir==0) close = true;
         else if(dir==1 && (type==OP_BUY || type==OP_BUYSTOP)) close = true;
         else if(dir==-1 && (type==OP_SELL || type==OP_SELLSTOP)) close = true;
         
         if(close) {
            if(type > 1) 
              {
               if(!OrderDelete(OrderTicket()))
                  Print("OrderDelete Error: ", GetLastError());
              }
            else {
               double p = (type==OP_BUY) ? Bid : Ask;
               if(!OrderClose(OrderTicket(), OrderLots(), p, Slippage, clrNONE)) res = false;
            }
         }
      }
   }
   return res;
  }

// 计算盈亏总和函数 (1:1 复刻 lizong_17)
double CalculateProfitSum(int type, int magic, int count, int mode)
  {
   double profits[100]; int cnt = 0;
   ArrayInitialize(profits, 0.0);
   for(int i=OrdersTotal()-1; i>=0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol()==Symbol() && OrderMagicNumber()==magic && OrderType()==type) {
         double p = OrderProfit();
         if(mode==1 && p>0) { if(cnt<100) profits[cnt++]=p; }
         else if(mode==2 && p<0) { if(cnt<100) profits[cnt++]=-p; } // 取绝对值
      }
   }
   ArraySort(profits, WHOLE_ARRAY, 0, MODE_DESCEND);
   double sum = 0;
   for(int k=0; k<count && k<cnt; k++) sum += profits[k];
   return sum;
  }

int GetHigherTimeframe()
  {
   if(Period() > PERIOD_MN1) return 0;
   if(Period() > PERIOD_W1) return PERIOD_MN1;
   if(Period() > PERIOD_D1) return PERIOD_W1;
   if(Period() > PERIOD_H4) return PERIOD_D1;
   if(Period() > PERIOD_H1) return PERIOD_H4;
   if(Period() > PERIOD_M30) return PERIOD_H1;
   if(Period() > PERIOD_M15) return PERIOD_M30;
   if(Period() > PERIOD_M5) return PERIOD_M15;
   if(Period() > PERIOD_M1) return PERIOD_M5;
   return PERIOD_M1;
  }

// UI & Helper Functions
void ShowStopMessage(string msg) {
   if(ObjectFind(0,"Stop")==-1) { ObjectCreate(0,"Stop",OBJ_LABEL,0,0,0); ObjectSetInteger(0,"Stop",OBJPROP_CORNER,1); ObjectSetInteger(0,"Stop",OBJPROP_XDISTANCE,10); ObjectSetInteger(0,"Stop",OBJPROP_YDISTANCE,260); ObjectSetInteger(0,"Stop",OBJPROP_COLOR,clrYellow); ObjectSetInteger(0,"Stop",OBJPROP_FONTSIZE,15); }
   ObjectSetString(0,"Stop",OBJPROP_TEXT,msg);
}
void ClearStopMessage() { ShowStopMessage(""); }

void CreateLabel(string name, int x, int y, string text, int size, string font, color clr, int corner) {
   if(ObjectFind(0,name)<0) { ObjectCreate(0,name,OBJ_LABEL,0,0,0); ObjectSetInteger(0,name,OBJPROP_CORNER,corner); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); }
   ObjectSetString(0,name,OBJPROP_TEXT,text); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size); ObjectSetInteger(0,name,OBJPROP_COLOR,clr); ObjectSetString(0,name,OBJPROP_FONT,font);
}
void CreateRectLabel(string name, int x, int y, int w, int h, color bg, color border) {
   if(ObjectFind(0,name)<0) { ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,name,OBJPROP_CORNER,1); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h); ObjectSetInteger(0,name,OBJPROP_BACK,false); }
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_COLOR,border);
}
void CreateButton(string name, int x, int y, int w, int h, string text, int size, string font) {
   if(ObjectFind(0,name)<0) { ObjectCreate(0,name,OBJ_BUTTON,0,0,0); ObjectSetInteger(0,name,OBJPROP_CORNER,1); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h); ObjectSetInteger(0,name,OBJPROP_HIDDEN,true); }
   ObjectSetString(0,name,OBJPROP_TEXT,text); ObjectSetString(0,name,OBJPROP_FONT,font); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
}
void CreateControlButton(string name, int x, int y, int w, int h, string text, int size, string font, color txtClr, color bgClr) {
   CreateButton(name, x, y, w, h, text, size, font);
   ObjectSetInteger(0,name,OBJPROP_COLOR,txtClr); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgClr);
}
void DeleteAllPanelObjects() { for(int i=ObjectsTotal()-1; i>=0; i--) { string n=ObjectName(0,i); if(StringFind(n,PANEL_PREFIX)>=0) ObjectDelete(0,n); } }
void DeleteButtonPanelObjects() { for(int i=ObjectsTotal()-1; i>=0; i--) { string n=ObjectName(0,i); if(StringFind(n,BUTTON_PREFIX)>=0) ObjectDelete(0,n); } }
void HandleButtonClick(string n) {
   if(n==PANEL_PREFIX+"OpenBoard") { g_IsButtonPanelVisible=!g_IsButtonPanelVisible; if(g_IsButtonPanelVisible) DrawButtonPanel(); else DeleteButtonPanelObjects(); ChartRedraw(); }
   else if(n==BUTTON_PREFIX+"StopAll") { g_AllowBuy=false; g_AllowSell=false; UpdatePanel(); DrawButtonPanel(); }
   else if(n==BUTTON_PREFIX+"StopBuy") { g_AllowBuy=!g_AllowBuy; UpdatePanel(); DrawButtonPanel(); }
   else if(n==BUTTON_PREFIX+"StopSell") { g_AllowSell=!g_AllowSell; UpdatePanel(); DrawButtonPanel(); }
   else if(n==BUTTON_PREFIX+"CloseBuy") CloseAllOrders(1);
   else if(n==BUTTON_PREFIX+"CloseSell") CloseAllOrders(-1);
   else if(n==BUTTON_PREFIX+"CloseAll") CloseAllOrders(0);
}
void UpdateButtonColors(const OrderStats &s) {
   ObjectSetInteger(0, BUTTON_PREFIX+"CloseBuy", OBJPROP_BGCOLOR, s.buyProfit>0 ? clrLime : clrDarkGray);
   ObjectSetInteger(0, BUTTON_PREFIX+"CloseSell", OBJPROP_BGCOLOR, s.sellProfit>0 ? clrLime : clrDarkGray);
   ObjectSetInteger(0, BUTTON_PREFIX+"CloseAll", OBJPROP_BGCOLOR, (s.buyProfit+s.sellProfit)>0 ? clrLime : clrDarkGray);
}
void UpdatePanel() {
   if(!g_IsPanelCollapsed) return;
   OrderStats s; CountOrders(s);
   double totalFloating = s.buyProfit + s.sellProfit;
   double returnRate = (g_TotalDeposits > 0) ? (totalFloating / g_TotalDeposits * 100.0) : 0.0;
   
   // 背景
   CreateRectLabel(PANEL_PREFIX+"bg", 308, 50, 300, 440, Snow, 8421376);
   
   // 1. 状态区
   int y = 65;
   CreateLabel(PANEL_PREFIX+"1B", 230, y, g_AllowBuy?"[多单正常]":"[多单停止]", 10, FONT_NAME, g_AllowBuy?MediumSeaGreen:DimGray, 1);
   CreateLabel(PANEL_PREFIX+"1S", 100, y, g_AllowSell?"[空单正常]":"[空单停止]", 10, FONT_NAME, g_AllowSell?Crimson:DimGray, 1);
   
   // 2. 资金概览区 (新增)
   y += 30;
   CreateLabel(PANEL_PREFIX+"TITLE_ACC", 255, y, "--- 账户资金 ---", 10, FONT_NAME, Black, 1);
   y += 20;
   CreateLabel(PANEL_PREFIX+"L_BAL", 255, y, "余额:", 9, FONT_NAME, DimGray, 1);
   CreateLabel(PANEL_PREFIX+"V_BAL", 180, y, DoubleToString(AccountBalance(), 2), 9, FONT_NAME, Black, 1);
   CreateLabel(PANEL_PREFIX+"L_EQU", 120, y, "净值:", 9, FONT_NAME, DimGray, 1);
   CreateLabel(PANEL_PREFIX+"V_EQU", 40, y, DoubleToString(AccountEquity(), 2), 9, FONT_NAME, Black, 1);
   
   y += 20;
   double marginLevel = (AccountMargin() > 0) ? AccountEquity() / AccountMargin() * 100.0 : 0.0;
   CreateLabel(PANEL_PREFIX+"L_MAR", 255, y, "预付款:", 9, FONT_NAME, DimGray, 1);
   CreateLabel(PANEL_PREFIX+"V_MAR", 180, y, DoubleToString(AccountMargin(), 2), 9, FONT_NAME, Black, 1);
   CreateLabel(PANEL_PREFIX+"L_ML", 120, y, "比例:", 9, FONT_NAME, DimGray, 1);
   CreateLabel(PANEL_PREFIX+"V_ML", 40, y, DoubleToString(marginLevel, 2)+"%", 9, FONT_NAME, marginLevel<100?Red:Black, 1);

   // 3. EA 盈亏区
   y += 30;
   CreateLabel(PANEL_PREFIX+"TITLE_EA", 255, y, "--- EA 统计 ---", 10, FONT_NAME, Black, 1);
   y += 25;
   // EA浮盈
   CreateLabel(PANEL_PREFIX+"TotalStr", 255, y, "EA总浮盈:", 11, FONT_NAME, Black, 1);
   CreateLabel(PANEL_PREFIX+"Total", 150, y, DoubleToString(totalFloating, 2), 12, FONT_NAME, totalFloating>=0?BuyAvgPriceColor:SellAvgPriceColor, 1);
   y += 20;
   CreateLabel(PANEL_PREFIX+"RetStr", 255, y, "浮盈回报:", 9, FONT_NAME, DimGray, 1);
   CreateLabel(PANEL_PREFIX+"Return", 150, y, DoubleToString(returnRate, 2)+"%", 10, FONT_NAME, returnRate>=0?BuyAvgPriceColor:SellAvgPriceColor, 1);
   
   // 4. 订单详情区
   y += 30;
   CreateLabel(PANEL_PREFIX+"TITLE_ORD", 255, y, "--- 订单详情 ---", 10, FONT_NAME, Black, 1);
   
   y += 25;
   CreateLabel(PANEL_PREFIX+"BN", 255, y, "多单持仓:", 9, FONT_NAME, MediumSeaGreen, 1);
   CreateLabel(PANEL_PREFIX+"BC", 180, y, IntegerToString(s.buyCount)+"单", 9, FONT_NAME, Black, 1);
   CreateLabel(PANEL_PREFIX+"BL", 130, y, DoubleToString(s.buyLots, 2)+"手", 9, FONT_NAME, Black, 1);
   CreateLabel(PANEL_PREFIX+"BP", 50, y, DoubleToString(s.buyProfit, 2), 9, FONT_NAME, s.buyProfit>=0?MediumSeaGreen:DimGray, 1);
   
   y += 20;
   CreateLabel(PANEL_PREFIX+"SN", 255, y, "空单持仓:", 9, FONT_NAME, Crimson, 1);
   CreateLabel(PANEL_PREFIX+"SC", 180, y, IntegerToString(s.sellCount)+"单", 9, FONT_NAME, Black, 1);
   CreateLabel(PANEL_PREFIX+"SL", 130, y, DoubleToString(s.sellLots, 2)+"手", 9, FONT_NAME, Black, 1);
   CreateLabel(PANEL_PREFIX+"SP", 50, y, DoubleToString(s.sellProfit, 2), 9, FONT_NAME, s.sellProfit>=0?Crimson:DimGray, 1);

   // 5. 挂单统计 (新增)
   y += 25;
   if(s.buyPendingCount > 0 || s.sellPendingCount > 0) {
      CreateLabel(PANEL_PREFIX+"PN", 255, y, "挂单统计:", 9, FONT_NAME, DimGray, 1);
      CreateLabel(PANEL_PREFIX+"P_DT", 180, y, "B:"+IntegerToString(s.buyPendingCount)+" / S:"+IntegerToString(s.sellPendingCount), 9, FONT_NAME, Black, 1);
   } else {
      ObjectDelete(0, PANEL_PREFIX+"PN");
      ObjectDelete(0, PANEL_PREFIX+"P_DT");
   }

   // 按钮始终在底部
   CreateButton(PANEL_PREFIX+"OpenBoard", 100, 450, 100, 25, "控制面板", 9, FONT_NAME);
   ChartRedraw();
}
void DrawButtonPanel() {
   int x=280, y=200, w=80, h=22;
   CreateControlButton(BUTTON_PREFIX+"StopAll", x, y, w, h, "停止全部", 9, FONT_NAME, (g_AllowBuy||g_AllowSell)?clrWhite:clrRed, (g_AllowBuy||g_AllowSell)?clrDarkGray:clrLightGray); y+=27;
   CreateControlButton(BUTTON_PREFIX+"StopBuy", x, y, w, h, g_AllowBuy?"禁止做多":"允许做多", 9, FONT_NAME, g_AllowBuy?clrWhite:clrGreen, g_AllowBuy?clrDarkGray:clrLightGray); y+=27;
   CreateControlButton(BUTTON_PREFIX+"StopSell", x, y, w, h, g_AllowSell?"禁止做空":"允许做空", 9, FONT_NAME, g_AllowSell?clrWhite:clrRed, g_AllowSell?clrDarkGray:clrLightGray); y+=32;
   CreateControlButton(BUTTON_PREFIX+"CloseBuy", x, y, w, h, "平多单", 9, FONT_NAME, clrWhite, clrBlue); y+=27;
   CreateControlButton(BUTTON_PREFIX+"CloseSell", x, y, w, h, "平空单", 9, FONT_NAME, clrWhite, clrRed); y+=27;
   CreateControlButton(BUTTON_PREFIX+"CloseAll", x, y, w, h, "平全部", 9, FONT_NAME, clrWhite, clrDarkRed);
}
//+------------------------------------------------------------------+