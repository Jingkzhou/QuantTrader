//+------------------------------------------------------------------+
//|                                             QuantTrader_Pro.mq4 |
//|                                    基于反编译代码重构的可读版本   |
//|                                         Version 1.0 - 2026.01   |
//+------------------------------------------------------------------+
#property copyright "QuantTrader Pro"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//|                           枚举定义                                |
//+------------------------------------------------------------------+

// 开单模式枚举
enum ENUM_OPEN_MODE
  {
   OPEN_MODE_TIMEFRAME = 1,    // 开单时区模式
   OPEN_MODE_INTERVAL  = 2,    // 开单时间间距(秒)模式
   OPEN_MODE_INSTANT   = 3     // 不延迟模式
  };

//+------------------------------------------------------------------+
//|                         输入参数                                  |
//+------------------------------------------------------------------+

//--- 价格限制参数
extern double BuyFirstOrderPriceLimit   = 0;           // B以上不开(首单)
extern double SellFirstOrderPriceLimit  = 0;           // S以下不开(首单)
extern double BuyAddOrderPriceLimit     = 0;           // B以上不开(补单)
extern double SellAddOrderPriceLimit    = 0;           // S以下不开(补单)
extern int    MaxVolatilityPoints       = 0;           // 波动限制 (原 Zong_32_in_130)
extern string PriceLimitStartTime       = "00:00";     // 限价开始时间
extern string PriceLimitEndTime         = "24:00";     // 限价结束时间

//--- 保护开关
extern bool   EnableReverseProtection   = true;        // 逆势保护开关
extern bool   EnableTrendProtection     = true;        // 顺势保护开关
extern bool   EnableLockTrend           = false;       // 完全对锁时挂上顺势开关
extern bool   StopAfterClose            = false;       // 平仓后停止交易
extern int    RestartDelaySeconds       = 0;           // 整体平仓后多少秒后新局

//--- 距离参数
extern double SecondParamTriggerLoss    = 0;           // 浮亏多少启用第二参数
extern int    FirstOrderDistance        = 30;          // 首单距离
extern int    MinGridDistance           = 60;          // 最小距离
extern int    SecondMinGridDistance     = 60;          // 第二最小距离
extern int    PendingOrderTrailPoints   = 5;           // 挂单追踪点数
extern int    GridStep                  = 100;         // 补单间距
extern int    SecondGridStep            = 100;         // 第二补单间距

//--- 开单控制
extern ENUM_OPEN_MODE    OrderOpenMode       = OPEN_MODE_INSTANT;  // 开单模式
extern ENUM_TIMEFRAMES   OrderTimeframe      = PERIOD_M1;          // 开单时区
extern int               OrderIntervalSeconds = 30;                // 开单时间间距(秒)

//--- 风控参数
extern double MaxFloatingLoss           = 100000;      // 单边浮亏超过多少不继续加仓
extern double MaxLossCloseThreshold     = 50;          // 单边平仓限制

//--- 手数参数
extern double BaseLotSize               = 0.01;        // 起始手数
extern double MaxLotSize                = 10;          // 最大开单手数
extern double LotIncrement              = 0;           // 累加手数
extern double LotMultiplier             = 1.3;         // 倍率
extern int    LotDecimalPlaces          = 2;           // 下单量的小数位

//--- 止盈止损
extern double TotalProfitTarget         = 0.5;         // 整体平仓金额
extern bool   EnableLayeredProfit       = true;        // 单边平仓金额累加开关
extern double SingleSideProfit          = 2;           // 单边平仓金额
extern double StopLossAmount            = 0;           // 止损金额

//--- 交易限制
extern int    MagicNumber               = 9527;        // 魔术号
extern int    MaxTotalOrders            = 50;          // 最大单量
extern int    MaxAllowedSpread          = 200;         // 点差限制
extern int    MinLeverage               = 100;         // 平台杠杆限制

//--- 交易时间
extern string TradingStartTime          = "00:00";     // EA开始时间
extern string TradingEndTime            = "24:00";     // EA结束时间

//--- 显示设置
extern color  BuyAvgPriceColor          = MediumSeaGreen;  // 多单平均价颜色
extern color  SellAvgPriceColor         = Crimson;         // 空单平均价颜色

//--- 订单备注
extern string OrderComment1             = "备注1";     // 订单备注1
extern string OrderComment2             = "备注2";     // 订单备注2

//+------------------------------------------------------------------+
//|                         全局常量                                  |
//+------------------------------------------------------------------+

// UI 对象名称前缀
const string PANEL_PREFIX  = "StatisticsPanel";   // 统计面板前缀
const string BUTTON_PREFIX = "ButtonPanel";       // 按钮面板前缀

// 按钮对象名称
const string BTN_BUY_CLOSE    = "Button1";        // 平多按钮
const string BTN_SELL_CLOSE   = "Button2";        // 平空按钮
const string BTN_ALL_CLOSE    = "Button5";        // 平全部按钮

// 字体设置
const string FONT_NAME        = "Microsoft YaHei";
const int    FONT_SIZE        = 10;

// 颜色设置
const color  COLOR_PROFIT     = Lime;             // 盈利颜色
const color  COLOR_LOSS       = Red;              // 亏损颜色
const color  COLOR_NEUTRAL    = Blue;             // 中性颜色
const color  COLOR_DISABLED   = DimGray;          // 禁用颜色

//+------------------------------------------------------------------+
//|                         全局变量                                  |
//+------------------------------------------------------------------+

//--- UI 状态
bool   g_IsPanelCollapsed     = true;             // 面板是否折叠
bool   g_IsButtonPanelVisible = false;            // 按钮面板是否可见

//--- 交易控制
bool   g_AllowBuy             = true;             // 允许做多
bool   g_AllowSell            = true;             // 允许做空
bool   g_TradingEnabled       = true;             // 交易环境满足
bool   g_BuyTradingEnabled    = true;             // 多单交易允许
bool   g_SellTradingEnabled   = true;             // 空单交易允许

//--- 滑点设置 (原 Zong_50_in_190，初始值0，init中设为30)
int    Slippage               = 0;                // 滑点

//--- 仓位状态
bool   g_SellOverweight       = false;            // 空单严重超仓 (空/多 > 3倍)
bool   g_BuyOverweight        = false;            // 多单严重超仓 (多/空 > 3倍)

//--- 时间控制
//--- 时间控制
datetime g_LastBuyOrderTime   = 0;                // 上次多单开仓时间
datetime g_LastSellOrderTime  = 0;                // 上次空单开仓时间
datetime g_LastCloseAllTime   = 0;                // 上次全部平仓时间
datetime g_GlobalResumeTime   = 0;                // 全局恢复交易时间 (NextTime功能)

//--- 交易时间段
datetime g_TradingStartDT     = 0;                // 交易开始时间戳
datetime g_TradingEndDT       = 0;                // 交易结束时间戳
datetime g_PriceLimitStartDT  = 0;                // 限价开始时间戳
datetime g_PriceLimitEndDT    = 0;                // 限价结束时间戳

//--- 挂单追踪
int    g_BuyPendingTicket     = 0;                // 多单挂单票号
int    g_SellPendingTicket    = 0;                // 空单挂单票号
double g_LastBuyPendingPrice  = 0;                // 多单挂单价格
double g_LastSellPendingPrice = 0;                // 空单挂单价格

//--- EA 信息
string g_EAName               = "QuantTrader Pro";// EA 名称

//+------------------------------------------------------------------+
//|                      订单统计结构体                               |
//+------------------------------------------------------------------+
struct OrderStats
  {
   int    buyCount;           // 多单数量
   int    sellCount;          // 空单数量
   int    buyPendingCount;    // 多单挂单数量
   int    sellPendingCount;   // 空单挂单数量
   double buyLots;            // 多单总手数
   double sellLots;           // 空单总手数
   double buyProfit;          // 多单浮盈
   double sellProfit;         // 空单浮盈
   double avgBuyPrice;        // 多单平均价
   double avgSellPrice;       // 空单平均价
   double highestBuyPrice;    // 多单最高开仓价
   double lowestBuyPrice;     // 多单最低开仓价
   double highestSellPrice;   // 空单最高开仓价
   double lowestSellPrice;    // 空单最低开仓价
   int    lastBuyPendingTicket;   // 最后多单挂单票号
   int    lastSellPendingTicket;  // 最后空单挂单票号
   double lastBuyPendingPrice;    // 最后多单挂单价格
   double lastSellPendingPrice;   // 最后空单挂单价格
  };

//+------------------------------------------------------------------+
//|                         入口函数                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| EA 初始化函数 (原 init 函数)                                      |
//| 原代码初始化逻辑：                                                |
//| - 删除残留图片对象                                                |
//| - 设置滑点 (5位/3位小数点)                                        |
//| - 转换负数参数                                                    |
//| - 格式化时间字符串                                                |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 删除可能残留的图片对象 (原代码)
   ObjectDelete(0, "tubiao");
   ObjectDelete(0, "tubiao1");
   ObjectDelete(0, "tubiao2");
   
   // 设置定时器（每秒刷新一次界面）
   EventSetTimer(1);
   
   // 初始化 EA 名称 (原代码: Zong_78_st_278 = WindowExpertName())
   g_EAName = WindowExpertName();
   
   // 转换周期 (原代码: Zong_47_in_184 = lizong_15(Zong_47_in_184))
   OrderTimeframe = (ENUM_TIMEFRAMES)GetHigherTimeframe();
   
   // 设置滑点 (原代码: if((Digits() == 5 || Digits() == 3)) Zong_50_in_190 = 30)
   if(Digits() == 5 || Digits() == 3)
     {
      Slippage = 30;
     }
   
   // 将参数转换为负数 (原代码逻辑复刻)
   // 原代码: MaxLossCloseAll = -(MaxLossCloseAll); ... Money = -(Money);
   // 为保证 1:1 逻辑一致性，我们将输入的正数转换为负数，并在后续逻辑中统一使用 >或< 负数 的判断
   MaxLossCloseThreshold  = -MathAbs(MaxLossCloseThreshold);
   MaxFloatingLoss        = -MathAbs(MaxFloatingLoss);
   StopLossAmount         = -MathAbs(StopLossAmount);
   SecondParamTriggerLoss = -MathAbs(SecondParamTriggerLoss);
   
   // 格式化时间字符串 (原代码: StringReplace, StringTrim)
   StringReplace(TradingStartTime, " ", "");
   StringReplace(TradingEndTime, " ", "");
   StringTrimLeft(TradingStartTime);
   StringTrimRight(TradingStartTime);
   StringTrimLeft(TradingEndTime);
   StringTrimRight(TradingEndTime);
   
   // 处理 24:00 特殊情况 (原代码)
   if(TradingEndTime == "24:00")
     {
      TradingEndTime = "23:59:59";
     }
   
   // 价格限制时间格式化
   StringReplace(PriceLimitStartTime, " ", "");
   StringReplace(PriceLimitEndTime, " ", "");
   StringTrimLeft(PriceLimitStartTime);
   StringTrimRight(PriceLimitStartTime);
   StringTrimLeft(PriceLimitEndTime);
   StringTrimRight(PriceLimitEndTime);
   
   // 初始化状态变量
   g_TradingEnabled = true;
   g_AllowBuy = true;
   g_AllowSell = true;
   g_IsPanelCollapsed = true;   // 默认展开面板
   g_IsButtonPanelVisible = false;
   
   // 检查交易环境
   OrderStats stats;
   CountOrders(stats);
   if(!CheckTradingEnvironment(stats))
     {
      Print("警告: 交易环境检查未通过，部分功能可能受限");
     }
   
   // 绘制价格限制水平线
   DrawPriceLimitLines();
   
   // 刷新面板
   UpdatePanel();
   
   // 播放启动声音 (原代码: PlaySound("Starting.wav"))
   PlaySound("Starting.wav");
   
   Print("QuantTrader Pro 初始化完成");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| EA 反初始化函数                                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // 删除定时器
   EventKillTimer();
   
   // 删除所有 UI 对象
   DeleteAllPanelObjects();
   
   // 删除价格线
   ObjectDelete(0, "HLINE_LONG");
   ObjectDelete(0, "HLINE_SHORT");
   ObjectDelete(0, "HLINE_LONGII");
   ObjectDelete(0, "HLINE_SHORTII");
   ObjectDelete(0, "SLb");
   ObjectDelete(0, "SLs");
   ObjectDelete(0, "Stop");
   ObjectDelete(0, "Spread");
   
   Print("QuantTrader Pro 已卸载，原因代码: ", reason);
  }

//+------------------------------------------------------------------+
//| 定时器事件                                                        |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // 刷新面板显示
   UpdatePanel();
   
   // 如果按钮面板可见，刷新按钮面板
   if(g_IsButtonPanelVisible)
     {
      DrawButtonPanel();
     }
  }

//+------------------------------------------------------------------+
//| 图表事件处理                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   // 处理对象点击事件
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      HandleButtonClick(sparam);
     }
  }

//+------------------------------------------------------------------+
//| 主交易逻辑 (每个 Tick 执行)                                       |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. 统计订单
   OrderStats stats;
   CountOrders(stats);
   
   // 2. 初始化本轮 Tick 的交易权限 (默认允许)
   bool tickAllowBuy = g_AllowBuy;
   bool tickAllowSell = g_AllowSell;
   
   // 3. 检查 StopAfterClose (Over) 单边停止逻辑
   if(StopAfterClose)
     {
      if(stats.buyCount == 0) tickAllowBuy = false;
      if(stats.sellCount == 0) tickAllowSell = false;
     }

   // 4. 检查交易环境 (原版: 不符合环境时仅禁止开仓，不退出函数)
   if(!CheckTradingEnvironment(stats))
     {
      tickAllowBuy = false;
      tickAllowSell = false;
      ShowStopMessage("不符合设定环境，EA停止运行！");
     }
   else
     {
      // 只有环境符合才清除，或者保持之前的显示? 原版是 else { Clear }
      // 这里为了防止覆盖下面的 Time 提示，需由下文逻辑决定
      ClearStopMessage(); 
     }

   // 5. 检查交易时间
   if(!IsWithinTradingHours())
     {
      tickAllowBuy = false;
      tickAllowSell = false;
      ShowStopMessage("非开仓时间区间，停止开仓！");
     }

   // 6. 检查冷却时间
   if(TimeCurrent() < g_GlobalResumeTime)
     {
      tickAllowBuy = false;
      tickAllowSell = false;
      ShowStopMessage("EA停止运行 " + IntegerToString((int)(g_GlobalResumeTime - TimeCurrent())) + "秒!");
     }

   // --- 逻辑执行区 (不受权限影响的逻辑) ---

   // A. 检查超仓状态
   CheckOverweightStatus(stats);

   // B. 更新UI颜色
   UpdateButtonColors(stats);

   // C. 平仓保护逻辑 (始终运行)
   bool protectionTriggered = false;
   if(CheckTrendProtection(stats)) protectionTriggered = true;
   // 只有上面没触发才继续查下一个 (原版逻辑链)
   if(!protectionTriggered && CheckReverseProtection(stats)) protectionTriggered = true;
   if(!protectionTriggered && CheckProfitTarget(stats)) protectionTriggered = true;
   if(!protectionTriggered && CheckStopLoss(stats)) protectionTriggered = true;
   if(!protectionTriggered && CheckSingleSideProfit(stats)) protectionTriggered = true;

   // D. 开单逻辑 (受权限控制)
   if(!protectionTriggered)
     {
      if(tickAllowBuy && g_BuyTradingEnabled) ProcessBuyLogic(stats); // g_BuyTradingEnabled 是按钮控制
      if(tickAllowSell && g_SellTradingEnabled) ProcessSellLogic(stats);
     }

   // E. 挂单追踪 (原版: 仅在允许交易时才追踪)
   // 原代码: if(Zi_20_do != 0.0 && Zong_29_bo_128) ...
   if(tickAllowBuy && g_BuyTradingEnabled) TrackPendingOrders(stats, 1); // 1=Buy
   if(tickAllowSell && g_SellTradingEnabled) TrackPendingOrders(stats, -1); // -1=Sell

   // F. 刷新面板
   UpdatePanel();
  }

//+------------------------------------------------------------------+
//|                       交易函数                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 统计当前订单 (严格按照原代码 start() 中的统计逻辑)                |
//+------------------------------------------------------------------+
void CountOrders(OrderStats &stats)
  {
   // 初始化结构体 (对应原代码 Zi_3_do = 0.0; ... Zi_23_do = 0.0;)
   ZeroMemory(stats);
   
   double buyWeightedPrice  = 0;  // Zi_23_do
   double sellWeightedPrice = 0;  // Zi_22_do
   
   // 遍历所有订单 (对应原代码 for(Zi_28_in = 0; ...)
   for(int i = 0; i < OrdersTotal(); i++)
     {
      // 原代码: if(!(OrderSelect(Zi_28_in, 0, 0)) || OrderSymbol() != Symbol() || Magic != OrderMagicNumber())
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol())
         continue;
      if(MagicNumber != OrderMagicNumber())
         continue;
      
      int    orderType  = OrderType();                              // Zi_13_in
      double orderLots  = OrderLots();                              // Zi_8_do
      double orderPrice = NormalizeDouble(OrderOpenPrice(), Digits()); // Zi_3_do
      
      // 处理多单STOP挂单 (原代码: if(Zi_13_in == 4))
      if(orderType == 4)  // OP_BUYSTOP
        {
         stats.buyPendingCount++;  // Zi_11_in++
         // 原代码: if((Zi_16_do < Zi_3_do || Zi_16_do == 0.0))
         if(stats.highestBuyPrice < orderPrice || stats.highestBuyPrice == 0.0)
           {
            stats.highestBuyPrice = orderPrice;  // Zi_16_do = Zi_3_do
           }
         stats.lastBuyPendingTicket = OrderTicket();  // Zi_14_in = OrderTicket()
         stats.lastBuyPendingPrice = orderPrice;      // Zi_20_do = Zi_3_do
        }
      
      // 处理空单STOP挂单 (原代码: if(Zi_13_in == 5))
      if(orderType == 5)  // OP_SELLSTOP
        {
         stats.sellPendingCount++;  // Zi_12_in++
         // 原代码: if((Zi_19_do > Zi_3_do || Zi_19_do == 0.0))
         if(stats.lowestSellPrice > orderPrice || stats.lowestSellPrice == 0.0)
           {
            stats.lowestSellPrice = orderPrice;  // Zi_19_do = Zi_3_do
           }
         stats.lastSellPendingTicket = OrderTicket();  // Zi_15_in = OrderTicket()
         stats.lastSellPendingPrice = orderPrice;      // Zi_21_do = Zi_3_do
        }
      
      // 处理多单 (原代码: if(Zi_13_in == 0))
      if(orderType == 0)  // OP_BUY
        {
         stats.buyCount++;  // Zi_9_in++
         stats.buyLots += orderLots;  // Zi_6_do = Zi_6_do + Zi_8_do
         buyWeightedPrice += orderPrice * orderLots;  // Zi_23_do = Zi_3_do * Zi_8_do + Zi_23_do
         
         // 原代码: if((Zi_16_do < Zi_3_do || Zi_16_do == 0.0))
         if(stats.highestBuyPrice < orderPrice || stats.highestBuyPrice == 0.0)
           {
            stats.highestBuyPrice = orderPrice;  // Zi_16_do = Zi_3_do
           }
         // 原代码: if((Zi_17_do > Zi_3_do || Zi_17_do == 0.0))
         if(stats.lowestBuyPrice > orderPrice || stats.lowestBuyPrice == 0.0)
           {
            stats.lowestBuyPrice = orderPrice;  // Zi_17_do = Zi_3_do
           }
         // 原代码: Zi_5_do = OrderProfit() + OrderSwap() + OrderCommission() + Zi_5_do
         stats.buyProfit += OrderProfit() + OrderSwap() + OrderCommission();
        }
      
      // 处理空单 (原代码: if(Zi_13_in != 1) continue; ...)
      if(orderType != 1)  // 不是 OP_SELL 则跳过
         continue;
      
      stats.sellCount++;  // Zi_10_in++
      stats.sellLots += orderLots;  // Zi_7_do = Zi_7_do + Zi_8_do
      sellWeightedPrice += orderPrice * orderLots;  // Zi_22_do = Zi_3_do * Zi_8_do + Zi_22_do
      
      // 原代码: if((Zi_19_do > Zi_3_do || Zi_19_do == 0.0))
      if(stats.lowestSellPrice > orderPrice || stats.lowestSellPrice == 0.0)
        {
         stats.lowestSellPrice = orderPrice;  // Zi_19_do = Zi_3_do
        }
      // 原代码: if((Zi_18_do < Zi_3_do || Zi_18_do == 0.0))
      if(stats.highestSellPrice < orderPrice || stats.highestSellPrice == 0.0)
        {
         stats.highestSellPrice = orderPrice;  // Zi_18_do = Zi_3_do
        }
      // 原代码: Zi_4_do = OrderProfit() + OrderSwap() + OrderCommission() + Zi_4_do
      stats.sellProfit += OrderProfit() + OrderSwap() + OrderCommission();
     }
   
   // 计算平均价 (原代码中在后续使用 Zi_23_do/Zi_6_do 和 Zi_22_do/Zi_7_do)
   if(stats.buyLots > 0)
      stats.avgBuyPrice = buyWeightedPrice / stats.buyLots;
   if(stats.sellLots > 0)
      stats.avgSellPrice = sellWeightedPrice / stats.sellLots;
  }

//+------------------------------------------------------------------+
//| 计算下一单手数 (原代码约 1885 行)                                 |
//| 原代码公式:                                                       |
//| if(Zi_9_in == 0) Zi_27_do = lot;                                  |
//| else Zi_27_do = NormalizeDouble(Zi_9_in * PlusLot + lot *         |
//|                 (MathPow(K_Lot, Zi_9_in)), DigitsLot);            |
//| if(Zi_27_do > Maxlot) Zi_27_do = Maxlot;                          |
//+------------------------------------------------------------------+
double CalculateNextLot(int currentLayer, bool isBuy)
  {
   double nextLot;  // Zi_27_do
   
   // 原代码: if(Zi_9_in == 0) Zi_27_do = lot;
   if(currentLayer == 0)
     {
      nextLot = BaseLotSize;  // lot
     }
   else
     {
      // 原代码: Zi_27_do = NormalizeDouble(Zi_9_in * PlusLot + lot * (MathPow(K_Lot, Zi_9_in)), DigitsLot)
      // Zi_9_in = currentLayer, PlusLot = LotIncrement, lot = BaseLotSize, K_Lot = LotMultiplier
      nextLot = NormalizeDouble(currentLayer * LotIncrement + BaseLotSize * MathPow(LotMultiplier, currentLayer), LotDecimalPlaces);
     }
   
   // 原代码: if(Zi_27_do > Maxlot) Zi_27_do = Maxlot;
   if(nextLot > MaxLotSize)
     {
      nextLot = MaxLotSize;
     }
   
   return nextLot;
  }

//+------------------------------------------------------------------+
//| 规范化手数                                                        |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
  {
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   // 根据小数位四舍五入
   lots = NormalizeDouble(lots, LotDecimalPlaces);
   
   // 按照 lotStep 取整
   lots = MathFloor(lots / lotStep) * lotStep;
   
   // 限制范围
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   
   return NormalizeDouble(lots, LotDecimalPlaces);
  }

//+------------------------------------------------------------------+
//| 开多单                                                            |
//+------------------------------------------------------------------+
int OpenBuyOrder(double lots, string comment = "")
  {
   if(comment == "")
      comment = OrderComment1;
   
   double price = Ask;
   int slippage = 30;
   
   int ticket = OrderSend(Symbol(), OP_BUY, lots, price, slippage, 0, 0, 
                          comment, MagicNumber, 0, Blue);
   
   if(ticket > 0)
     {
      g_LastBuyOrderTime = TimeCurrent();
      Print("开多单成功: Ticket=", ticket, " Lots=", lots, " Price=", price);
     }
   else
     {
      Print("开多单失败: Error=", GetLastError());
     }
   
   return ticket;
  }

//+------------------------------------------------------------------+
//| 开空单                                                            |
//+------------------------------------------------------------------+
int OpenSellOrder(double lots, string comment = "")
  {
   if(comment == "")
      comment = OrderComment1;
   
   double price = Bid;
   int slippage = 30;
   
   int ticket = OrderSend(Symbol(), OP_SELL, lots, price, slippage, 0, 0,
                          comment, MagicNumber, 0, Red);
   
   if(ticket > 0)
     {
      g_LastSellOrderTime = TimeCurrent();
      Print("开空单成功: Ticket=", ticket, " Lots=", lots, " Price=", price);
     }
   else
     {
      Print("开空单失败: Error=", GetLastError());
     }
   
   return ticket;
  }

//+------------------------------------------------------------------+
//| 平掉指定方向的所有订单 (原 lizong_14)                             |
//| direction: 1=多单, -1=空单, 0=全部                                |
//| 返回: 1=成功, 0=失败(重试超过10次)                                |
//+------------------------------------------------------------------+
int CloseAllOrders(int direction)
  {
   int  errorCode       = 0;      // Zi_2_in
   int  retryCount      = 0;      // Zi_3_in
   int  orderType       = 0;      // Zi_4_in
   int  remainingOrders = 0;      // Zi_5_in
   bool closeResult     = false;  // Zi_6_bo
   int  i               = 0;      // Zi_7_in
   
   // 初始化 (与原代码一致)
   orderType = 0;
   remainingOrders = 0;
   closeResult = true;
   
   // 无限循环，直到所有目标订单都平掉或超过重试次数
   for(;;)
     {
      // 遍历所有订单（从后往前）
      for(i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol())
            continue;
         if(OrderMagicNumber() != MagicNumber)
            continue;
         
         orderType = OrderType();
         
         // 平多单 (orderType == 0 即 OP_BUY)
         if(orderType == 0 && (direction == 1 || direction == 0))
           {
            closeResult = OrderClose(OrderTicket(), OrderLots(), 
                                     NormalizeDouble(Bid, Digits()), 
                                     Slippage, Blue);
            if(closeResult)
              {
               Comment("", OrderTicket(), "", OrderProfit(), "     ", 
                       TimeToString(TimeCurrent(), TIME_MINUTES));
              }
           }
         
         // 平空单 (orderType == 1 即 OP_SELL)
         if(orderType == 1 && (direction == -1 || direction == 0))
           {
            closeResult = OrderClose(OrderTicket(), OrderLots(), 
                                     NormalizeDouble(Ask, Digits()), 
                                     Slippage, Red);
            if(closeResult)
              {
               Comment("", OrderTicket(), "", OrderProfit(), "     ", 
                       TimeToString(TimeCurrent(), TIME_MINUTES));
              }
           }
         
         // 删除多单挂单 (orderType == 4 即 OP_BUYSTOP)
         if(orderType == 4 && (direction == 1 || direction == 0))
           {
            closeResult = OrderDelete(OrderTicket(), clrNONE);
           }
         
         // 删除空单挂单 (orderType == 5 即 OP_SELLSTOP)
         if(orderType == 5 && (direction == -1 || direction == 0))
           {
            closeResult = OrderDelete(OrderTicket(), clrNONE);
           }
         
         // 如果平仓成功，继续下一个
         if(closeResult)
            continue;
         
         // 处理错误
         errorCode = GetLastError();
         if(errorCode < 2)
            continue;
         
         if(errorCode == 129)  // ERR_REQUOTE
           {
            Comment("", TimeToString(TimeCurrent(), TIME_MINUTES));
            RefreshRates();
            continue;
           }
         
         if(errorCode == 146)  // ERR_TRADE_CONTEXT_BUSY
           {
            if(!IsTradeContextBusy())
               continue;
            Sleep(2000);
            continue;
           }
         
         Comment("", errorCode, "", OrderTicket(), "     ", 
                 TimeToString(TimeCurrent(), TIME_MINUTES));
        }
      
      // 统计剩余目标订单数
      remainingOrders = 0;
      for(i = 0; i < OrdersTotal(); i++)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol())
            continue;
         if(OrderMagicNumber() != MagicNumber)
            continue;
         
         orderType = OrderType();
         
         // 检查是否还有多单或多单STOP挂单 (原代码: Zi_4_in == 4 || Zi_4_in == 0)
         if((orderType == 4 || orderType == 0) && (direction == 1 || direction == 0))
           {
            remainingOrders++;
           }
         
         // 检查是否还有空单或空单STOP挂单 (原代码逻辑)
         if(orderType != 5 && orderType != 1)
            continue;
         if(direction != -1 && direction != 0)
            continue;
         remainingOrders++;
        }
      
      // 如果没有剩余订单，退出循环
      if(remainingOrders == 0)
         break;
      
      // 重试次数+1
      retryCount++;
      if(retryCount > 10)
        {
         Print(Symbol(), "平仓超过10次", remainingOrders);
         return(0);
        }
      
      Sleep(1000);
      RefreshRates();
      continue;
     }
   
   return(1);
  }

//+------------------------------------------------------------------+
//| 分批平仓 (原 lizong_16)                                           |
//| Mu_0_in: 订单类型 (0=多单, 1=空单, -100=全部)                      |
//| Mu_1_in: MagicNumber (-1=全部)                                    |
//| Mu_2_in: 要平仓的订单数量                                         |
//| Mu_3_in: 平仓模式 (1=平盈利订单, 2=平亏损订单)                     |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 分批平仓/对冲平仓 (原 lizong_16)                                  |
//| orderType: 订单类型 (0=多单, 1=空单, -100=全部)                   |
//| magic: 魔术号                                                     |
//| closeCount: 要平仓的订单数量                                      |
//| closeMode: 平仓模式 (1=平盈利订单, 2=平亏损订单)                  |
//+------------------------------------------------------------------+
bool PartialClose(int orderType, int magic, int closeCount, int closeMode)
  {
   bool anySuccess = false;
   
   for(int c = 0; c < closeCount; c++)
     {
      int targetTicket = -1;
      double targetVal = 0.0;
      
      // 遍历订单，找到目标订单 (模式1: 最大盈利, 模式2: 最大亏损)
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != Symbol()) continue;
         if(magic != -1 && OrderMagicNumber() != magic) continue;
         if(orderType != -100 && OrderType() != orderType) continue;
         
         double profit = OrderProfit();
         
         if(closeMode == 1) // 盈利单模式
           {
            if(profit > 0 && (targetTicket == -1 || profit > targetVal))
              {
               targetVal = profit;
               targetTicket = OrderTicket();
              }
           }
         else if(closeMode == 2) // 亏损单模式
           {
            if(profit < 0 && (targetTicket == -1 || profit < targetVal))
              {
               targetVal = profit;
               targetTicket = OrderTicket();
              }
           }
        }
      
      if(targetTicket == -1) break;
      
      // 选中目标订单
      if(OrderSelect(targetTicket, SELECT_BY_TICKET, MODE_TRADES))
        {
         int currentType = OrderType();
         int oppositeType = (currentType == OP_BUY) ? OP_SELL : OP_BUY;
         int oppositeTicket = -1;
         
         // Removed OrderCloseBy
         for(int k = OrdersTotal() - 1; k >= 0; k--)
           {
            if(!OrderSelect(k, SELECT_BY_POS, MODE_TRADES))
               continue;
            if(OrderSymbol() != Symbol() || OrderMagicNumber() != magic)
               continue;
            
            if(OrderType() == oppositeType)
              {
               oppositeTicket = OrderTicket();
               break; // 找到任意一个反向单
              }
           }
         
         bool res = false;
         
         // 优先尝试 OrderCloseBy

         
         // 如果对冲失败或没有反向单，使用普通平仓
         if(!res)
           {
            // 重新选中目标订单 (OrderCloseBy 失败可能导致选择丢失)
            if(OrderSelect(targetTicket, SELECT_BY_TICKET, MODE_TRADES))
              {
               double price = (OrderType() == OP_BUY) ? Bid : Ask;
               res = OrderClose(targetTicket, OrderLots(), NormalizeDouble(price, Digits()), Slippage, clrNONE);
               if(res)
                  Print("普通平仓成功: Ticket=", targetTicket, " Profit=", OrderProfit());
              }
           }
         
         if(res)
            closeCount--; // 成功平掉一单，计数减一
         else
            break; // 平仓失败，防止死循环
        }
      else
        {
         break;
        }
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//|                       风控函数                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 检查交易环境 (原代码约 950-990 行的判断逻辑)                      |
//| 原代码条件: AccountLeverage() < Leverage ||                       |
//|            IsTradeAllowed() == false ||                           |
//|            IsExpertEnabled() == false ||                          |
//|            IsStopped() ||                                         |
//|            Zi_9_in + Zi_10_in >= Totals ||                        |
//|            MarketInfo(Symbol(), MODE_SPREAD) > MaxSpread ||       |
//|            (Zong_32_in_130 != 0 && 波动过大)                      |
//+------------------------------------------------------------------+
bool CheckTradingEnvironment(const OrderStats &stats)
  {
   // 原代码: if((AccountLeverage() < Leverage || ...))
   
   // 检查杠杆
   if(AccountLeverage() < MinLeverage)
      return false;
   
   // 检查交易是否允许
   if(IsTradeAllowed() == false)
      return false;
   
   // 检查 EA 是否允许
   if(IsExpertEnabled() == false)
      return false;
   
   // 检查是否被停止
   if(IsStopped())
      return false;
   
   // 检查订单总数是否超过限制 (原代码: Zi_9_in + Zi_10_in >= Totals)
   if(stats.buyCount + stats.sellCount >= MaxTotalOrders)
      return false;
   
   // 检查点差 (原代码: MarketInfo(Symbol(), MODE_SPREAD) > MaxSpread)
   if(MarketInfo(Symbol(), MODE_SPREAD) > MaxAllowedSpread)
      return false;
   
   // 波动检查 (原代码: Zong_32_in_130 != 0 && Zi_37_do >= Zong_32_in_130)
   if(MaxVolatilityPoints > 0)
     {
      // 计算近期波动 (原代码使用 Zong_31_in_12C = 1, 即 M1)
      int checkTimeframe = PERIOD_M1;
      double highPoint = iHigh(Symbol(), checkTimeframe, 0);
      double lowPoint = iLow(Symbol(), checkTimeframe, 5);
      
      // 上涨波动
      double upVolatility = (highPoint - lowPoint) / Point();
      // 下跌波动
      double downVolatility = MathAbs((iLow(Symbol(), checkTimeframe, 0) - iHigh(Symbol(), checkTimeframe, 5)) / Point());
      
      if(upVolatility >= MaxVolatilityPoints || downVolatility >= MaxVolatilityPoints)
        {
         return false;
        }
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| 检查是否在交易时间内 (原代码约 980-1010 行)                       |
//| 返回: true=在交易时间内, false=不在                               |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
  {
   datetime currentTime;
   if(IsTesting())
      currentTime = TimeCurrent();
   else
      currentTime = TimeLocal();
   
   // 获取当天的开始和结束时间戳
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   string todayStr = StringConcatenate(dt.year, ".", dt.mon, ".", dt.day, " ");
   datetime startDT = StringToTime(todayStr + TradingStartTime);
   datetime endDT = StringToTime(todayStr + TradingEndTime);
   
   if(startDT < endDT)
     {
      if(currentTime < startDT || currentTime > endDT)
         return false;
     }
   else // 跨天逻辑
     {
      if(currentTime < startDT && currentTime > endDT)
         return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| 显示停止语 (原代码 Stop 标签细节)                                  |
//+------------------------------------------------------------------+
void ShowStopMessage(string message)
  {
   if(ObjectFind(0, "Stop") == -1)
     {
      ObjectCreate(0, "Stop", OBJ_LABEL, 0, 0, 0);
      // 原代码: Zong_74=1 (CORNER_RIGHT_UPPER), Zong_75=10 (X), Zong_76=260 (Y)
      ObjectSetInteger(0, "Stop", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, "Stop", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "Stop", OBJPROP_YDISTANCE, 260);
     }
   ObjectSetString(0, "Stop", OBJPROP_TEXT, message);
   // 原代码: Zong_59 = 0xFFFF (Yellow), Zong_33 = 15 (Size)
   ObjectSetInteger(0, "Stop", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "Stop", OBJPROP_FONTSIZE, 15);
   ObjectSetString(0, "Stop", OBJPROP_FONT, "Arial");
  }

//+------------------------------------------------------------------+
//| 清除停止语                                                        |
//+------------------------------------------------------------------+
void ClearStopMessage()
  {
   ShowStopMessage("");
  }
//+------------------------------------------------------------------+
//| 检查超仓状态 (原代码约 920-940 行)                                |
//| 原代码:                                                           |
//| if(Zi_6_do > 0.0 && Zi_7_do / Zi_6_do > 3.0 && Zi_7_do - Zi_6_do > 0.2) |
//|    Zong_39_bo_151 = true;                                         |
//+------------------------------------------------------------------+
void CheckOverweightStatus(const OrderStats &stats)
  {
   // 空单超仓判断 (原代码: Zi_7_do/Zi_6_do > 3 && 差值 > 0.2手)
   // Zi_6_do = buyLots, Zi_7_do = sellLots
   // Zong_39_bo_151 = g_SellOverweight
   if(stats.buyLots > 0.0 && stats.sellLots / stats.buyLots > 3.0 && 
      stats.sellLots - stats.buyLots > 0.2)
     {
      g_SellOverweight = true;
     }
   else
     {
      g_SellOverweight = false;
     }
   
   // Zong_40_bo_152 = g_BuyOverweight
   if(stats.sellLots > 0.0 && stats.buyLots / stats.sellLots > 3.0 && 
      stats.buyLots - stats.sellLots > 0.2)
     {
      g_BuyOverweight = true;
     }
   else
     {
      g_BuyOverweight = false;
     }
  }

//+------------------------------------------------------------------+
//| 检查整体止盈 (原代码约 1120-1125 行)                              |
//| 原代码: if(Over == 1 && Zi_40_do >= CloseAll)                    |
//|        Zi_40_do = Zi_5_do + Zi_4_do (buyProfit + sellProfit)     |
//+------------------------------------------------------------------+
bool CheckProfitTarget(const OrderStats &stats)
  {
   double totalProfit = stats.buyProfit + stats.sellProfit;  // Zi_40_do
   
   // 原代码: if(Over == 1 && Zi_40_do >= CloseAll)
   // Over = StopAfterClose, CloseAll = TotalProfitTarget
   // 检查整体止盈 (注意：这里我们修正为通用止盈检查，不仅仅是 StopAfterClose)
   if(totalProfit >= TotalProfitTarget && TotalProfitTarget > 0)
     {
      Print("达到整体止盈目标: ", totalProfit, " >= ", TotalProfitTarget);
      bool result = CloseAllOrders(0);
      
      // 平仓成功后设置冷却时间
      if(result && RestartDelaySeconds > 0)
        {
         g_GlobalResumeTime = TimeCurrent() + RestartDelaySeconds;
         Print("触发冷却，暂停交易至: ", TimeToString(g_GlobalResumeTime));
        }
      
      if(StopAfterClose)
        {
         g_TradingEnabled = false;
         g_AllowBuy = false;
         g_AllowSell = false;
         Print("触发 StopAfterClose，EA停止交易");
        }
      
      return true;
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| 检查止损                                                          |
//+------------------------------------------------------------------+
bool CheckStopLoss(const OrderStats &stats)
  {
   if(StopLossAmount <= 0)
      return false;
   
   double totalProfit = stats.buyProfit + stats.sellProfit;
   
   if(totalProfit <= -StopLossAmount)
     {
      Print("触发止损: ", totalProfit, " <= -", StopLossAmount);
      CloseAllOrders(0);
      return true;
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| 检查单边止盈 (原代码中的单边平仓逻辑)                             |
//+------------------------------------------------------------------+
bool CheckSingleSideProfit(const OrderStats &stats)
  {
   if(SingleSideProfit <= 0)
      return false;
   
   double buyTarget, sellTarget;
   
   // 原代码: Profit 开关控制是否累加
   if(EnableLayeredProfit)
     {
      buyTarget = SingleSideProfit * stats.buyCount;    // 按层数累加
      sellTarget = SingleSideProfit * stats.sellCount;
     }
   else
     {
      buyTarget = SingleSideProfit;
      sellTarget = SingleSideProfit;
     }
   
   // 检查多单止盈
   if(stats.buyProfit > buyTarget && stats.buyCount > 0)
     {
      Print("多单达到止盈: ", stats.buyProfit, " > ", buyTarget);
      CloseAllOrders(1);
      return true;
     }
   
   // 检查空单止盈
   if(stats.sellProfit > sellTarget && stats.sellCount > 0)
     {
      Print("空单达到止盈: ", stats.sellProfit, " > ", sellTarget);
      CloseAllOrders(-1);
      return true;
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| 检查顺势保护 (原代码约 1295-1400 行)                              |
//| 原代码: HomeopathyCloseAll == true 时检查 "SS" 备注订单           |
//| 若有 SS 订单，需达到整体止盈才平仓                                |
//+------------------------------------------------------------------+
bool CheckTrendProtection(const OrderStats &stats)
  {
   if(!EnableTrendProtection)
      return false;
   
   // 统计带有 "SS" 备注的订单数量
   int ssOrderCount = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol())
         continue;
      if(OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderComment() != "SS")
         continue;
      
      // 找到 SS 备注的订单
      ssOrderCount++;
     }
   
   // 如果有 SS 订单且达到整体止盈
   if(ssOrderCount > 0)
     {
      double totalProfit = stats.buyProfit + stats.sellProfit;
      if(totalProfit >= TotalProfitTarget && TotalProfitTarget > 0)
        {
         Print("顺势保护触发整体止盈: ", totalProfit, " >= ", TotalProfitTarget);
         CloseAllOrders(0);
         return true;
        }
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| 检查逆势保护 (原代码约 1760-1860 行: CloseBuySell)                |
//| 逻辑: 检查盈利订单，若多单手数远大于空单手数且盈利，则分批平仓    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 检查逆势保护 (原代码约 1760-1860 行: CloseBuySell)                |
//| 逻辑: 计算前N个盈利单与前M个亏损单的盈亏差值 (lizong_17)          |
//| 若差值大于历史最大值，则触发对冲平仓 (lizong_16)                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 检查逆势保护 (1:1 复刻 CloseBuySell 逻辑)                        |
//+------------------------------------------------------------------+
bool CheckReverseProtection(const OrderStats &stats)
  {
   if(!EnableReverseProtection)
      return false;

   // --- 多单侧 ---
   // 计算盈亏差: (前1个盈利单总和) - (前2个亏损单总和)
   // 原版参数：lizong_17(..., Zong_56_in_1CC, ...) - lizong_17(..., Zong_57_in_1D0, ...)
   // 默认 Zong_56=1, Zong_57=2
   double profitDiffBuy = CalculateProfitSum(OP_BUY, MagicNumber, 1, 1) - CalculateProfitSum(OP_BUY, MagicNumber, 2, 2);
   static double maxDiffBuy = 0.0;
   
   // 更新历史最大值
   if(maxDiffBuy < profitDiffBuy) maxDiffBuy = profitDiffBuy;

   // 检查触发条件
   if(maxDiffBuy > 0.0 && profitDiffBuy > 0.0)
     {
      // 寻找多单最大盈利单的手数
      double maxProfitLot = 0;
      double maxProfitVal = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == Symbol() && 
            OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
           {
            if(OrderProfit() > maxProfitVal)
              {
               maxProfitVal = OrderProfit();
               maxProfitLot = OrderLots();
              }
           }
        }

      // 手数失衡判断
      if(stats.buyLots > (maxProfitLot * 3.0 + stats.sellLots) && stats.buyCount > 3)
        {
         // 执行对冲: 平1个盈利，平2个亏损 (对应原版: lizong_16(..., 1) 和 lizong_16(..., 2))
         PartialClose(OP_BUY, MagicNumber, 1, 1); 
         PartialClose(OP_BUY, MagicNumber, 2, 2);
         
         // [关键修正] 平仓后必须重置最大差值记录，否则会连续误触发
         maxDiffBuy = 0.0; 
         
         Print("逆势保护触发（多单侧）: 仓位对冲平仓");
         return true;
        }
     }

   // --- 空单侧 ---
   double profitDiffSell = CalculateProfitSum(OP_SELL, MagicNumber, 1, 1) - CalculateProfitSum(OP_SELL, MagicNumber, 2, 2);
   static double maxDiffSell = 0.0;
   
   if(maxDiffSell < profitDiffSell) maxDiffSell = profitDiffSell;

   if(maxDiffSell > 0.0 && profitDiffSell > 0.0)
     {
      double maxProfitLot = 0;
      double maxProfitVal = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == Symbol() && 
            OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL)
           {
            if(OrderProfit() > maxProfitVal)
              {
               maxProfitVal = OrderProfit();
               maxProfitLot = OrderLots();
              }
           }
        }

      if(stats.sellLots > (maxProfitLot * 3.0 + stats.buyLots) && stats.sellCount > 3)
        {
         PartialClose(OP_SELL, MagicNumber, 1, 1);
         PartialClose(OP_SELL, MagicNumber, 2, 2);
         
         // [关键修正] 重置记录
         maxDiffSell = 0.0;
         
         Print("逆势保护触发（空单侧）: 仓位对冲平仓");
         return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                       交易逻辑函数                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 处理多单开仓/加仓逻辑 (原代码约 1855-2100 行)                     |
//| 核心逻辑:                                                         |
//| - 首单: 挂单价 = Ask + FirstStep * Point                          |
//| - 加仓: 根据 Zi_35_bo (Money条件) 选择 MinDistance 或 TwoMinDistance |
//| - 挂单类型: OP_BUYSTOP (4)                                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 处理多单开仓/加仓逻辑 (原代码约 1855-2100 行)                     |
//| 核心逻辑:                                                         |
//| - 首单: 挂单价 = Ask + FirstStep * Point                          |
//| - 加仓: 根据 Zi_35_bo (Money条件) 选择 MinDistance 或 TwoMinDistance |
//| - 挂单类型: OP_BUYSTOP (4)                                        |
//| - 动态调整: 逆势(Low)默认允许, 顺势(High)仅在超仓/对锁时允许          |
//+------------------------------------------------------------------+
void ProcessBuyLogic(const OrderStats &stats)
  {
   if(!g_AllowBuy || !g_TradingEnabled) return;
   if(stats.buyPendingCount > 0) return;
   if(stats.buyCount + stats.sellCount >= MaxTotalOrders) return;
   if(stats.buyProfit < -MaxFloatingLoss && stats.buyCount > 0) return;

   // 1. 计算挂单价格
   double pendingPrice = 0;
   double totalProfit = stats.buyProfit + stats.sellProfit;
   // Zi_35_bo: 当亏损较小(totalProfit > SecondParamTriggerLoss)时为true
   bool useFirstParam = (SecondParamTriggerLoss == 0 || totalProfit > SecondParamTriggerLoss);

   if(stats.buyCount == 0)
     {
      pendingPrice = NormalizeDouble(Ask + FirstOrderDistance * Point(), Digits());
      // 首单检查价格限制
      if(BuyFirstOrderPriceLimit > 0 && Ask >= BuyFirstOrderPriceLimit) return;
     }
   else
     {
      if(useFirstParam)
         pendingPrice = NormalizeDouble(Ask + MinGridDistance * Point(), Digits());
      else
         pendingPrice = NormalizeDouble(Ask + SecondMinGridDistance * Point(), Digits());

      // 距离调整 (原代码: Zi_26_do < Zi_17_do - Step)
      double limitPrice = 0;
      if(useFirstParam)
         limitPrice = NormalizeDouble(stats.lowestBuyPrice - GridStep * Point(), Digits());
      else if(stats.lowestBuyPrice != 0) 
         limitPrice = NormalizeDouble(stats.lowestBuyPrice - SecondGridStep * Point(), Digits());
      
      // 如果计算出的挂单价 高于 限制价 (即距离不足以构成有效逆势补单)，则重新定位
      if(stats.lowestBuyPrice != 0 && pendingPrice > limitPrice) 
        {
         if(useFirstParam)
            pendingPrice = NormalizeDouble(Ask + GridStep * Point(), Digits());
         else
            pendingPrice = NormalizeDouble(Ask + SecondGridStep * Point(), Digits());
        }
     }

   // 2. 核心开单准入判断 (复刻原版逻辑)
   bool canOpen = false;

   // 首单总是允许
   if(stats.buyCount == 0) canOpen = true;

   // 补单判断
   if(stats.buyCount > 0)
     {
      double step = useFirstParam ? GridStep : SecondGridStep;
      
      // 条件1: 顺势追涨 (超仓保护)
      if(stats.highestBuyPrice != 0 && 
         pendingPrice >= NormalizeDouble(stats.highestBuyPrice + step * Point(), Digits()) &&
         g_SellOverweight)
        {
         if(useFirstParam || SecondParamTriggerLoss != 0) canOpen = true; 
        }

      // 条件2: 逆势补单 (正常网格)
      if(stats.lowestBuyPrice != 0 &&
         pendingPrice <= NormalizeDouble(stats.lowestBuyPrice - step * Point(), Digits()))
        {
         if(useFirstParam || SecondParamTriggerLoss != 0) canOpen = true;
        }
      
      // 条件3: 对锁突破 (Homeopathy)
      if(EnableLockTrend && stats.highestBuyPrice != 0 && 
         pendingPrice >= NormalizeDouble(stats.highestBuyPrice + step * Point(), Digits()) &&
         stats.buyLots == stats.sellLots)
        {
         canOpen = true;
        }
     }

   if(!canOpen) return;

   // 3. 检查开单时间间隔与价格限制
   if(!CheckPriceLimit(true, stats.buyCount)) return;
   if(!CheckOrderInterval(true)) return;

   // 4. 手数计算与资金检查
   double lots = CalculateNextLot(stats.buyCount, true);
   if(lots * 2.0 >= AccountFreeMargin() / MarketInfo(Symbol(), MODE_MARGINREQUIRED)) return;

   // 5. 备注逻辑
   string comment = OrderComment1;
   if(stats.buyCount > 0 && stats.highestBuyPrice != 0 && 
      pendingPrice >= NormalizeDouble(stats.highestBuyPrice + GridStep * Point(), Digits()))
     {
      comment = OrderComment2;
     }

   // 6. 发送订单
   int ticket = OrderSend(Symbol(), OP_BUYSTOP, lots, pendingPrice, Slippage, 0, 0, comment, MagicNumber, 0, Blue);
   if(ticket > 0) 
     {
      g_LastBuyOrderTime = TimeCurrent();
      Print("多单挂单成功: Ticket=", ticket, " Lots=", lots, " Price=", pendingPrice);
     }
  }

//+------------------------------------------------------------------+
//| 处理空单开仓/加仓逻辑 (原代码约 2100-2400 行)                     |
//| 核心逻辑:                                                         |
//| - 首单: 挂单价 = Bid - FirstStep * Point                          |
//| - 加仓: 根据 Zi_35_bo (Money条件) 选择 MinDistance 或 TwoMinDistance |
//| - 挂单类型: OP_SELLSTOP (5)                                       |
//+------------------------------------------------------------------+
void ProcessSellLogic(const OrderStats &stats)
  {
   // 检查是否允许做空
   if(!g_AllowSell || !g_TradingEnabled)
      return;
   
//+------------------------------------------------------------------+
//| 计算前N个盈利/亏损订单的盈亏总和 (原代码 lizong_17)               |
//| orderType: 订单类型筛选, -100=全部                                |
//| magicNumber: 魔术号筛选, -1=全部                                  |
//| profitType: 1=盈利订单, 2=亏损订单                                |
//| topN: 取前N个订单                                                 |
//+------------------------------------------------------------------+
double CalculateProfitSum(int orderType, int magicNumber, int profitType, int topN)
  {
   double profitArray[100]; // 原代码固定大小 100
   int    arrayIndex  = 0;
   double totalProfit = 0.0;
   
   // 初始化数组
   ArrayInitialize(profitArray, 0.0);
   
   // 遍历所有订单，收集盈亏数据
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol())
         continue;
      if(OrderMagicNumber() != magicNumber && magicNumber != -1)
         continue;
      if(OrderType() != orderType && orderType != -100)
         continue;
      
      // 收集盈利订单
      if(profitType == 1 && OrderProfit() >= 0.0)
        {
         if(arrayIndex < 100)
           {
            profitArray[arrayIndex] = OrderProfit();
            arrayIndex++;
           }
        }
      
      // 收集亏损订单（取绝对值）
      // 原代码: if(Mu_2_in != 2 || !(OrderProfit() < 0.0)) continue;
      // Zi_2_do_si100[Zi_3_in] = -(OrderProfit());
      if(profitType == 2 && OrderProfit() < 0.0)
        {
         if(arrayIndex < 100)
           {
            profitArray[arrayIndex] = -OrderProfit(); // 存为正数方便后续排序和求和
            arrayIndex++;
           }
        }
     }
   
   // 降序排序
   ArraySort(profitArray, WHOLE_ARRAY, 0, MODE_DESCEND);
   
   // 计算前N个订单的盈亏总和
   totalProfit = 0.0;
   for(int i = 0; i < topN && i < 100; i++)
     {
      totalProfit += profitArray[i];
     }
   
   return totalProfit;
  }
   
   // 检查是否超过最大订单数 (原代码: Zi_9_in + Zi_10_in >= Totals)
   if(stats.buyCount + stats.sellCount >= MaxTotalOrders)
      return;
   
   // 检查浮亏限制 (原代码: Zi_4_do > MaxLoss)
   if(stats.sellProfit < -MaxFloatingLoss && stats.sellCount > 0)
      return;
   
   // 1. 计算挂单价格
   double pendingPrice = 0;
   double totalProfit = stats.buyProfit + stats.sellProfit;
   // Zi_35_bo: 当亏损较小(totalProfit > SecondParamTriggerLoss)时为true
   bool useFirstParam = (SecondParamTriggerLoss == 0 || totalProfit > SecondParamTriggerLoss);

   if(stats.sellCount == 0)
     {
      pendingPrice = NormalizeDouble(Bid - FirstOrderDistance * Point(), Digits());
      if(SellFirstOrderPriceLimit > 0 && Bid <= SellFirstOrderPriceLimit) return;
     }
   else
     {
      if(useFirstParam)
         pendingPrice = NormalizeDouble(Bid - MinGridDistance * Point(), Digits());
      else
         pendingPrice = NormalizeDouble(Bid - SecondMinGridDistance * Point(), Digits());

      // 距离调整 (原代码: Zi_26_do > Zi_18_do + Step)
      double limitPrice = 0;
      if(useFirstParam)
         limitPrice = NormalizeDouble(stats.highestSellPrice + GridStep * Point(), Digits());
      else if(stats.highestSellPrice != 0)
         limitPrice = NormalizeDouble(stats.highestSellPrice + SecondGridStep * Point(), Digits());
      
      if(stats.highestSellPrice != 0 && pendingPrice < limitPrice)
        {
         if(useFirstParam)
            pendingPrice = NormalizeDouble(Bid - GridStep * Point(), Digits());
         else
            pendingPrice = NormalizeDouble(Bid - SecondGridStep * Point(), Digits());
        }
     }
   // 2. 核心开单准入判断 (复刻原版逻辑)
   bool canOpen = false;

   // 首单总是允许
   if(stats.sellCount == 0) canOpen = true;

   // 补单判断
   if(stats.sellCount > 0)
     {
      double step = useFirstParam ? GridStep : SecondGridStep;
      
      // 条件1: 顺势追空 (超仓保护)
      if(stats.lowestSellPrice != 0 && 
         pendingPrice <= NormalizeDouble(stats.lowestSellPrice - step * Point(), Digits()) &&
         g_BuyOverweight)
        {
         if(useFirstParam || SecondParamTriggerLoss != 0) canOpen = true; 
        }

      // 条件2: 逆势补单 (正常网格)
      if(stats.highestSellPrice != 0 &&
         pendingPrice >= NormalizeDouble(stats.highestSellPrice + step * Point(), Digits()))
        {
         if(useFirstParam || SecondParamTriggerLoss != 0) canOpen = true;
        }
      
      // 条件3: 对锁突破 (Homeopathy)
      if(EnableLockTrend && stats.lowestSellPrice != 0 && 
         pendingPrice <= NormalizeDouble(stats.lowestSellPrice - step * Point(), Digits()) &&
         stats.buyLots == stats.sellLots)
        {
         canOpen = true;
        }
     }

   if(!canOpen) return;

   // 3. 检查开单时间间隔与价格限制
   if(!CheckPriceLimit(false, stats.sellCount)) return;
   if(!CheckOrderInterval(false)) return;

   // 4. 手数计算与资金检查
   double lots = CalculateNextLot(stats.sellCount, false);
   if(lots * 2.0 >= AccountFreeMargin() / MarketInfo(Symbol(), MODE_MARGINREQUIRED)) return;

   // 5. 备注逻辑
   string comment = OrderComment1;
   if(stats.sellCount > 0 && stats.lowestSellPrice != 0 && 
      pendingPrice <= NormalizeDouble(stats.lowestSellPrice - GridStep * Point(), Digits()))
     {
      comment = OrderComment2;
     }

   // 6. 发送订单
   int ticket = OrderSend(Symbol(), OP_SELLSTOP, lots, pendingPrice, Slippage, 0, 0, comment, MagicNumber, 0, Red);
   if(ticket > 0) 
     {
      g_LastSellOrderTime = TimeCURRENT();
      Print("空单挂单成功: Ticket=", ticket, " Lots=", lots, " Price=", pendingPrice);
     }
  }

//+------------------------------------------------------------------+
//| 检查价格限制                                                      |
//+------------------------------------------------------------------+
bool CheckPriceLimit(bool isBuy, int orderCount)
  {
   double currentPrice = isBuy ? Ask : Bid;
   
   if(orderCount == 0)
     {
      // 首单价格限制
      if(isBuy && BuyFirstOrderPriceLimit > 0 && currentPrice >= BuyFirstOrderPriceLimit)
         return false;
      if(!isBuy && SellFirstOrderPriceLimit > 0 && currentPrice <= SellFirstOrderPriceLimit)
         return false;
     }
   else
     {
      // 补单价格限制
      if(isBuy && BuyAddOrderPriceLimit > 0 && currentPrice >= BuyAddOrderPriceLimit)
         return false;
      if(!isBuy && SellAddOrderPriceLimit > 0 && currentPrice <= SellAddOrderPriceLimit)
         return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| 检查开单时间间隔                                                  |
//+------------------------------------------------------------------+
bool CheckOrderInterval(bool isBuy)
  {
   if(OrderOpenMode == OPEN_MODE_INSTANT)
      return true;
   
   datetime lastOrderTime = isBuy ? g_LastBuyOrderTime : g_LastSellOrderTime;
   datetime currentTime = TimeCurrent();
   
   if(OrderOpenMode == OPEN_MODE_INTERVAL)
     {
      if(currentTime - lastOrderTime < OrderIntervalSeconds)
         return false;
     }
   else if(OrderOpenMode == OPEN_MODE_TIMEFRAME)
     {
      // 检查是否在新的时间周期
      datetime currentBarTime = iTime(Symbol(), OrderTimeframe, 0);
      if(lastOrderTime >= currentBarTime)
         return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| 检查首单开仓条件 (原代码约 1870 行)                               |
//| 原代码条件:                                                       |
//| - 价格限制检查 (On_top_of_this_price_not_Buy_first_order 等)      |
//| - 首单距离条件 (FirstStep)                                        |
//+------------------------------------------------------------------+
bool CheckFirstOrderCondition(bool isBuy)
  {
   double currentPrice = isBuy ? Ask : Bid;
   
   // 检查首单价格限制
   if(isBuy)
     {
      // 原代码: On_top_of_this_price_not_Buy_first_order
      if(BuyFirstOrderPriceLimit > 0 && currentPrice >= BuyFirstOrderPriceLimit)
         return false;
     }
   else
     {
      // 原代码: On_under_of_this_price_not_Sell_first_order
      if(SellFirstOrderPriceLimit > 0 && currentPrice <= SellFirstOrderPriceLimit)
         return false;
     }
   
   // 首单距离条件（原代码中计算 Zi_26_do = Bid - FirstStep * Point()）
   // 这里简化：直接返回 true，首单无距离要求
   
   return true;
  }

//+------------------------------------------------------------------+
//| 获取当前网格间距 (原代码约 2050-2070 行)                          |
//| 根据浮亏情况使用不同的间距                                        |
//| 原代码: 使用 Step 或 TwoStep                                      |
//+------------------------------------------------------------------+
int GetCurrentGridDistance(int orderCount)
  {
   // 原代码逻辑:
   // 当 Zi_35_bo = true (Money != 0 && 总盈亏 > Money) 时使用 Step
   // 否则使用 TwoStep
   
   // 此处简化：
   // - 前3单使用首单间距 FirstStep (对应 MinGridDistance)
   // - 之后使用常规间距 Step (对应 GridStep)
   
   if(orderCount < 3)
      return MinGridDistance;  // FirstStep
   else
      return GridStep;         // Step
  }

//+------------------------------------------------------------------+
//| 追踪挂单 (原代码约 2700-2800 行)                                  |
//| 功能: 将挂单追踪到当前价格附近，保持固定距离                      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 追踪挂单 (原代码约 2700-2800 行)                                  |
//| 功能: 将挂单追踪到当前价格附近，保持固定距离                      |
//| 修正: Buy向下追踪, Sell向上追踪, 且需满足开仓限制                 |
//+------------------------------------------------------------------+








//+------------------------------------------------------------------+
//|                       UI 函数                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 刷新统计面板 (原 lizong_20 简化版)                                |
//| 原代码约 3400-4950 行，此处简化实现核心统计显示                   |
//+------------------------------------------------------------------+
void UpdatePanel()
  {
   // 如果面板折叠，不显示详细面板
   if(!g_IsPanelCollapsed)
      return;
   
   // 统计当前订单
   OrderStats stats;
   CountOrders(stats);
   
   string currency = "  " + AccountCurrency();
   int yPos = 110;
   int fontSize = 10;  // Zong_19_in_EC
   string fontName = "Microsoft YaHei";  // Zong_21_st_F8
   int corner = 1;  // 右上角
   
   //--- 创建背景面板
   CreateRectLabel(PANEL_PREFIX + "background", 308, 50, 300, 440, Snow, 8421376);
   CreateRectLabel(PANEL_PREFIX + "showprofit", 298, 90, 280, 85, LightCyan, 8421376);
   CreateRectLabel(PANEL_PREFIX + "showprofittitle", 213, 80, 120, 20, LightCyan, 8421376);
   
   //--- 显示多/空控制状态
   if(g_AllowBuy)
      CreateLabel(PANEL_PREFIX + "1B", 230, 65, "可以多", fontSize, fontName, Green, corner);
   else
      CreateLabel(PANEL_PREFIX + "1B", 230, 65, "禁止多", fontSize, fontName, Red, corner);
   
   if(g_AllowSell)
      CreateLabel(PANEL_PREFIX + "1S", 130, 65, "可以空", fontSize, fontName, Green, corner);
   else
      CreateLabel(PANEL_PREFIX + "1S", 130, 65, "禁止空", fontSize, fontName, Red, corner);
   
   //--- 显示盈亏汇总
   double totalProfit = stats.buyProfit + stats.sellProfit;
   color profitColor = (totalProfit >= 0) ? C'139,69,0' : C'60,60,60';
   CreateLabel(PANEL_PREFIX + "TotalProfit", 150, 115, 
               "盈亏: " + DoubleToString(totalProfit, 2) + currency, 
               fontSize + 2, fontName, profitColor, corner);
   
   //--- 多单统计
   CreateLabel(PANEL_PREFIX + "BuyOrdersN", 255, yPos, "多单:", fontSize, fontName, Green, corner);
   CreateLabel(PANEL_PREFIX + "BuyOrdersC", 180, yPos, IntegerToString(stats.buyCount) + "单", fontSize, fontName, DarkBlue, corner);
   CreateLabel(PANEL_PREFIX + "BuyOrdersL", 120, yPos, DoubleToString(stats.buyLots, 2) + "手", fontSize, fontName, DarkBlue, corner);
   
   color buyProfitColor = (stats.buyProfit >= 0) ? C'139,69,0' : C'60,60,60';
   CreateLabel(PANEL_PREFIX + "BuyOrdersP", 25, yPos, DoubleToString(stats.buyProfit, 2) + currency, fontSize, fontName, buyProfitColor, corner);
   
   yPos += fontSize * 2;
   
   //--- 空单统计
   CreateLabel(PANEL_PREFIX + "SellOrdersN", 255, yPos, "空单:", fontSize, fontName, Green, corner);
   CreateLabel(PANEL_PREFIX + "SellOrdersC", 180, yPos, IntegerToString(stats.sellCount) + "单", fontSize, fontName, DarkBlue, corner);
   CreateLabel(PANEL_PREFIX + "SellOrdersL", 120, yPos, DoubleToString(stats.sellLots, 2) + "手", fontSize, fontName, DarkBlue, corner);
   
   color sellProfitColor = (stats.sellProfit >= 0) ? C'139,69,0' : C'60,60,60';
   CreateLabel(PANEL_PREFIX + "SellOrdersP", 25, yPos, DoubleToString(stats.sellProfit, 2) + currency, fontSize, fontName, sellProfitColor, corner);
   
   yPos += fontSize * 2;
   
   //--- 总计
   CreateLabel(PANEL_PREFIX + "AllOrdersN", 255, yPos, "总共:", fontSize, fontName, Green, corner);
   CreateLabel(PANEL_PREFIX + "AllOrdersL", 120, yPos, DoubleToString(stats.buyLots + stats.sellLots, 2) + "手", fontSize, fontName, DarkBlue, corner);
   CreateLabel(PANEL_PREFIX + "AllOrdersP", 25, yPos, DoubleToString(totalProfit, 2) + currency, fontSize, fontName, profitColor, corner);
   
   yPos += int(fontSize * 2.5);
   
   //--- 分隔线
   CreateRectLabel(PANEL_PREFIX + "Separetor1", 298, yPos, 280, 1, PowderBlue, 15453831);
   
   yPos += int(fontSize * 0.5);
   
   //--- 显示 EA 名称
   CreateLabel(PANEL_PREFIX + "copyrightN", 125, yPos, MQLInfoString(MQL_PROGRAM_NAME), fontSize, fontName, Green, corner);
   
   //--- 显示打开按钮面板的按钮
   CreateButton(PANEL_PREFIX + "OpenBoard", 100, 480, 100, 25, "控制面板", fontSize, fontName);
   
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| 创建文本标签辅助函数                                              |
//+------------------------------------------------------------------+
void CreateLabel(string name, int xDist, int yDist, string text, int fontSize, string fontName, color clr, int corner = 1)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xDist);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDist);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetString(0, name, OBJPROP_FONT, fontName);
     }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| 创建矩形标签辅助函数                                              |
//+------------------------------------------------------------------+
void CreateRectLabel(string name, int xDist, int yDist, int width, int height, color bgColor, color borderColor)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xDist);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDist);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_COLOR, borderColor);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
  }

//+------------------------------------------------------------------+
//| 创建按钮辅助函数                                                  |
//+------------------------------------------------------------------+
void CreateButton(string name, int xDist, int yDist, int width, int height, string text, int fontSize, string fontName)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xDist);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDist);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, name, OBJPROP_FONT, fontName);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrLightGray);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrGray);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
  }

//+------------------------------------------------------------------+
//| 绘制按钮面板 (原 lizong_12 简化版)                                |
//+------------------------------------------------------------------+
void DrawButtonPanel()
  {
   int fontSize = 9;
   string fontName = "Microsoft YaHei";
   int yPos = 200;
   int btnWidth = 80;
   int btnHeight = 22;
   int xPos = 280;
   
   //--- 停止全部交易按钮
   CreateControlButton(BUTTON_PREFIX + "StopAll", xPos, yPos, btnWidth, btnHeight, 
                       "停止全部", fontSize, fontName, 
                       (g_AllowBuy || g_AllowSell) ? clrWhite : clrRed,
                       (g_AllowBuy || g_AllowSell) ? clrDarkGray : clrLightGray);
   yPos += btnHeight + 5;
   
   //--- 停止做多按钮
   CreateControlButton(BUTTON_PREFIX + "StopBuy", xPos, yPos, btnWidth, btnHeight, 
                       g_AllowBuy ? "禁止做多" : "允许做多", fontSize, fontName,
                       g_AllowBuy ? clrWhite : clrGreen,
                       g_AllowBuy ? clrDarkGray : clrLightGray);
   yPos += btnHeight + 5;
   
   //--- 停止做空按钮
   CreateControlButton(BUTTON_PREFIX + "StopSell", xPos, yPos, btnWidth, btnHeight, 
                       g_AllowSell ? "禁止做空" : "允许做空", fontSize, fontName,
                       g_AllowSell ? clrWhite : clrRed,
                       g_AllowSell ? clrDarkGray : clrLightGray);
   yPos += btnHeight + 10;
   
   //--- 平多单按钮
   CreateControlButton(BUTTON_PREFIX + "CloseBuy", xPos, yPos, btnWidth, btnHeight, 
                       "平多单", fontSize, fontName, clrWhite, clrBlue);
   yPos += btnHeight + 5;
   
   //--- 平空单按钮
   CreateControlButton(BUTTON_PREFIX + "CloseSell", xPos, yPos, btnWidth, btnHeight, 
                       "平空单", fontSize, fontName, clrWhite, clrRed);
   yPos += btnHeight + 5;
   
   //--- 平全部按钮
   CreateControlButton(BUTTON_PREFIX + "CloseAll", xPos, yPos, btnWidth, btnHeight, 
                       "平全部", fontSize, fontName, clrWhite, clrDarkRed);
   
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| 创建控制按钮辅助函数                                              |
//+------------------------------------------------------------------+
void CreateControlButton(string name, int xDist, int yDist, int width, int height, 
                         string text, int fontSize, string fontName, color textColor, color bgColor)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xDist);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yDist);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetString(0, name, OBJPROP_FONT, fontName);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
  }

//+------------------------------------------------------------------+
//| 处理按钮点击                                                      |
//+------------------------------------------------------------------+
void HandleButtonClick(string buttonName)
  {
   // 面板折叠/展开切换
   if(buttonName == "tubiao2" || buttonName == "tubiao1")
     {
      g_IsPanelCollapsed = !g_IsPanelCollapsed;
      DeleteAllPanelObjects();
      UpdatePanel();
      if(g_IsButtonPanelVisible)
         DrawButtonPanel();
      return;
     }
   
   // 打开按钮面板
   if(buttonName == PANEL_PREFIX + "OpenBoard")
     {
      g_IsButtonPanelVisible = !g_IsButtonPanelVisible;
      if(!g_IsButtonPanelVisible)
         DeleteButtonPanelObjects();
      else
         DrawButtonPanel();
      ChartRedraw(0);
      return;
     }
   
   // 停止全部交易按钮
   if(buttonName == BUTTON_PREFIX + "StopAll")
     {
      g_AllowBuy = false;
      g_AllowSell = false;
      UpdatePanel();
      if(g_IsButtonPanelVisible)
         DrawButtonPanel();
      return;
     }
   
   // 停止做多按钮
   if(buttonName == BUTTON_PREFIX + "StopBuy")
     {
      g_AllowBuy = !g_AllowBuy;
      UpdatePanel();
      if(g_IsButtonPanelVisible)
         DrawButtonPanel();
      return;
     }
   
   // 停止做空按钮
   if(buttonName == BUTTON_PREFIX + "StopSell")
     {
      g_AllowSell = !g_AllowSell;
      UpdatePanel();
      if(g_IsButtonPanelVisible)
         DrawButtonPanel();
      return;
     }
   
   // 平多单按钮
   if(buttonName == BTN_BUY_CLOSE || buttonName == BUTTON_PREFIX + "CloseBuy")
     {
      CloseAllOrders(1);
      return;
     }
   
   // 平空单按钮
   if(buttonName == BTN_SELL_CLOSE || buttonName == BUTTON_PREFIX + "CloseSell")
     {
      CloseAllOrders(-1);
      return;
     }
   
   // 平全部按钮
   if(buttonName == BTN_ALL_CLOSE || buttonName == BUTTON_PREFIX + "CloseAll")
     {
      CloseAllOrders(0);
      return;
     }
  }

//+------------------------------------------------------------------+
//| 删除所有面板对象                                                  |
//+------------------------------------------------------------------+
void DeleteAllPanelObjects()
  {
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
     {
      string objName = ObjectName(0, i, -1, -1);
      if(StringFind(objName, PANEL_PREFIX, 0) >= 0)
        {
         ObjectDelete(0, objName);
        }
     }
  }

//+------------------------------------------------------------------+
//| 删除按钮面板对象                                                  |
//+------------------------------------------------------------------+
void DeleteButtonPanelObjects()
  {
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
     {
      string objName = ObjectName(0, i, -1, -1);
      if(StringFind(objName, BUTTON_PREFIX, 0) >= 0)
        {
         ObjectDelete(0, objName);
        }
     }
  }

//+------------------------------------------------------------------+
//| 绘制价格限制水平线                                                |
//+------------------------------------------------------------------+
void DrawPriceLimitLines()
  {
   // 多单首单价格上限线
   if(BuyFirstOrderPriceLimit > 0)
     {
      if(ObjectFind(0, "HLINE_LONG") < 0)
         ObjectCreate(0, "HLINE_LONG", OBJ_HLINE, 0, 0, BuyFirstOrderPriceLimit);
      ObjectSetInteger(0, "HLINE_LONG", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "HLINE_LONG", OBJPROP_COLOR, clrMagenta);
     }
   
   // 空单首单价格下限线
   if(SellFirstOrderPriceLimit > 0)
     {
      if(ObjectFind(0, "HLINE_SHORT") < 0)
         ObjectCreate(0, "HLINE_SHORT", OBJ_HLINE, 0, 0, SellFirstOrderPriceLimit);
      ObjectSetInteger(0, "HLINE_SHORT", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "HLINE_SHORT", OBJPROP_COLOR, clrMagenta);
     }
   
   // 多单补单价格上限线
   if(BuyAddOrderPriceLimit > 0)
     {
      if(ObjectFind(0, "HLINE_LONGII") < 0)
         ObjectCreate(0, "HLINE_LONGII", OBJ_HLINE, 0, 0, BuyAddOrderPriceLimit);
      ObjectSetInteger(0, "HLINE_LONGII", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "HLINE_LONGII", OBJPROP_COLOR, clrMagenta);
     }
   
   // 空单补单价格下限线
   if(SellAddOrderPriceLimit > 0)
     {
      if(ObjectFind(0, "HLINE_SHORTII") < 0)
         ObjectCreate(0, "HLINE_SHORTII", OBJ_HLINE, 0, 0, SellAddOrderPriceLimit);
      ObjectSetInteger(0, "HLINE_SHORTII", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "HLINE_SHORTII", OBJPROP_COLOR, clrMagenta);
     }
  }

//+------------------------------------------------------------------+
//| 显示停止消息                                                      |
//+------------------------------------------------------------------+
void ShowStopMessage(string message)
  {
   if(ObjectFind(0, "Stop") < 0)
     {
      ObjectCreate(0, "Stop", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "Stop", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, "Stop", OBJPROP_XDISTANCE, 25);
      ObjectSetInteger(0, "Stop", OBJPROP_YDISTANCE, 30);
     }
   ObjectSetString(0, "Stop", OBJPROP_TEXT, message);
   ObjectSetString(0, "Stop", OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, "Stop", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "Stop", OBJPROP_COLOR, COLOR_DISABLED);
  }

//+------------------------------------------------------------------+
//| 清除停止消息                                                      |
//+------------------------------------------------------------------+
void ClearStopMessage()
  {
   if(ObjectFind(0, "Stop") >= 0)
     {
      ObjectSetString(0, "Stop", OBJPROP_TEXT, "");
     }
  }

//+------------------------------------------------------------------+
//| 更新按钮颜色                                                      |
//+------------------------------------------------------------------+
void UpdateButtonColors(const OrderStats &stats)
  {
   // 多单按钮颜色
   if(stats.buyProfit > 0)
      ObjectSetInteger(0, BTN_BUY_CLOSE, OBJPROP_BGCOLOR, clrLime);
   else
      ObjectSetInteger(0, BTN_BUY_CLOSE, OBJPROP_BGCOLOR, clrDarkGray);
   
   // 空单按钮颜色
   if(stats.sellProfit > 0)
      ObjectSetInteger(0, BTN_SELL_CLOSE, OBJPROP_BGCOLOR, clrLime);
   else
      ObjectSetInteger(0, BTN_SELL_CLOSE, OBJPROP_BGCOLOR, clrDarkGray);
   
   // 全部按钮颜色
   if(stats.buyProfit + stats.sellProfit > 0)
      ObjectSetInteger(0, BTN_ALL_CLOSE, OBJPROP_BGCOLOR, clrLime);
   else
      ObjectSetInteger(0, BTN_ALL_CLOSE, OBJPROP_BGCOLOR, clrDarkGray);
  }

//+------------------------------------------------------------------+
//|                       工具函数                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 获取更高级别时间周期                                              |
//+------------------------------------------------------------------+
int GetHigherTimeframe(int currentTF)
  {
   if(currentTF > PERIOD_MN1)
      return 0;
   if(currentTF > PERIOD_W1)
      return PERIOD_MN1;
   if(currentTF > PERIOD_D1)
      return PERIOD_W1;
   if(currentTF > PERIOD_H4)
      return PERIOD_D1;
   if(currentTF > PERIOD_H1)
      return PERIOD_H4;
   if(currentTF > PERIOD_M30)
      return PERIOD_H1;
   if(currentTF > PERIOD_M15)
      return PERIOD_M30;
   if(currentTF > PERIOD_M5)
      return PERIOD_M15;
   if(currentTF > PERIOD_M1)
      return PERIOD_M5;
   if(currentTF == PERIOD_M1)
      return PERIOD_M1;
   if(currentTF == 0)
      return Period();
   
   return 0;
  }

//+------------------------------------------------------------------+
//| 计算盈亏总和 (用于计算前N个盈利单或M个亏损单的盈亏)               |
//| type: 订单类型 (OP_BUY/OP_SELL)                                   |
//| magic: 魔术号                                                     |
//| count: 计数 (前N个)                                               |
//| mode: 模式 (1=盈利单, 2=亏损单)                                   |
//+------------------------------------------------------------------+
double CalculateProfitSum(int type, int magic, int count, int mode)
  {
   double totalProfit = 0;
   
   // 临时数组存储符合条件的利润
   // 假设最大订单数为100，避免动态数组复杂性
   double profits[100];
   int profitCount = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && 
         OrderSymbol() == Symbol() && 
         OrderMagicNumber() == magic && 
         OrderType() == type)
        {
         double p = OrderProfit(); // 原版逻辑用 OrderProfit
         
         if(mode == 1 && p > 0)
           {
             if(profitCount < 100) profits[profitCount++] = p;
           }
         else if(mode == 2 && p < 0)
           {
             if(profitCount < 100) profits[profitCount++] = p;
           }
        }
     }
   
   // 原版 lizong_17 逻辑：
   // mode=1: 找最大的前count个正数 (降序)
   // mode=2: 找最小的前count个负数 (升序, 绝对值最大)
   
   // 冒泡排序
   for(int i=0; i<profitCount-1; i++)
     {
      for(int j=0; j<profitCount-i-1; j++)
        {
         bool swap = false;
         if(mode == 1) // 降序
           {
            if(profits[j] < profits[j+1]) swap = true;
           }
         else // 升序 (负数越小，绝对值越大)
           {
            if(profits[j] > profits[j+1]) swap = true;
           }
         
         if(swap)
           {
            double temp = profits[j];
            profits[j] = profits[j+1];
            profits[j+1] = temp;
           }
        }
     }
   
   // 累加
   for(int k=0; k<count && k<profitCount; k++)
     {
      totalProfit += profits[k];
     }
     
   return totalProfit;
  }

//+------------------------------------------------------------------+
