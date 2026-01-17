//+------------------------------------------------------------------+
//|                                      QuantTrader_Pro_V3_9.mq4    |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://www.mql5.com"
#property version   "3.90"
#property strict
#property description "全自动多策略量化交易系统 V3.9 [ATR动态波动率适配]"

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
input group "=== V3.9 ATR 动态波动率适配 ==="
input bool     InpUseATRGrid   = true;           // 是否启用 ATR 动态网格
input ENUM_ATR_GRID_MODE InpATRMode = ATR_DIRECT;// 动态模式
input ENUM_TIMEFRAMES InpATRTF = PERIOD_CURRENT; // ATR 计算周期
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
input int      UI_X_Offset      = 50;
input int      UI_Y_Offset      = 50;
input color    UI_ThemeColor    = C'0,128,128'; 

input group "=== V3.6 机构级设置 ==="
input bool     InpEnableDualMode = true;      
input int      InpBEProfitPips   = 80;        
input int      InpBELockPips     = 10;        

input group "=== V3.5 首尾对冲设置 ==="
input bool     InpEnableDualHedge = true;     
input int      InpDestockMinLayer = 6;        
input double   InpDestockProfit = 1.0;        

input group "=== 风控与核心参数 ==="
input bool     InpUseDynamicTP  = true;
input int      InpTargetPips    = 150;
input double   InpSingleSideMaxLoss = 500.0;  
input int      InpMagicNum      = 999008;
input double   InpInitialLots   = 0.01;
input double   MartinMulti      = 1.5;
input int      GridMinDist      = 100;
input int      GridDistLayer2   = 300;

//--- 全局变量
bool     g_IsTradingAllowed = true;
bool     g_AllowLong=true, g_AllowShort=true;
string   g_ObjPrefix="QT38_";
datetime g_LastCloseTime=0;
double   g_PipValue=1.0;
string   g_LastHedgeInfo="";
color    g_ColorPanel = C'26,29,33';
color    g_ColorHeader = C'20,23,27';
color    g_ColorLine = C'55,60,66';
color    g_ColorText = C'230,232,235';
color    g_ColorMuted = C'150,160,170';
color    g_ColorInk = C'15,17,19';
color    g_ColorGood = C'90,205,135';
color    g_ColorBad = C'230,90,75';
color    g_ColorButton = C'70,75,80';

//+------------------------------------------------------------------+
//| 初始化                                                           |
//+------------------------------------------------------------------+
int OnInit() {
   g_PipValue = MarketInfo(_Symbol, MODE_TICKVALUE) / (MarketInfo(_Symbol, MODE_TICKSIZE) / _Point);
   EventSetTimer(1);
   DrawDashboard();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) { ObjectsDeleteAll(0, g_ObjPrefix); EventKillTimer(); }

//+------------------------------------------------------------------+
//| 核心引擎                                                         |
//+------------------------------------------------------------------+
void OnTick() {
   if(!g_IsTradingAllowed) { UpdateDashboard(); return; }
   if(!GlobalRiskCheck()) return;

   if(InpEnableDualHedge) { CheckDestocking(OP_BUY); CheckDestocking(OP_SELL); }
   CheckBreakEven();

   if(InpEnableDualMode) ManageDualEntry();
   
   RunMartingaleLogic();
   UpdateDashboard();
}

//====================================================================
//                       V3.8 低压手数算法
//====================================================================

double CalculateNextLot(int side) {
   int cnt = CountOrders(side);
   if(cnt == 0) return InpInitialLots;
   
   double lastLot = GetLastLot(side);
   double secondLastLot = GetSecondLastLot(side);
   double nextLot = lastLot;

   // 1. 基础模式计算
   if(InpMartinMode == MODE_EXPONENTIAL) {
      double multi = (cnt >= InpDecayStep) ? InpDecayMulti : MartinMulti;
      nextLot = lastLot * multi;
   }
   else if(InpMartinMode == MODE_FIBONACCI) {
      if(cnt == 1) nextLot = InpInitialLots;
      else nextLot = lastLot + secondLastLot;
   }
   else if(InpMartinMode == MODE_LINEAR) {
      nextLot = lastLot + InpInitialLots;
   }

   // 2. 封顶保护
   if(nextLot > InpMaxSingleLot) nextLot = InpMaxSingleLot;
   
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
   return (secondL > 0) ? secondL : InpInitialLots;
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
   double baseDist = (orderCount == 1) ? GridMinDist : GridDistLayer2;
   if(InpUseATRGrid) {
      double atrPoints = GetATRPoints();
      if(atrPoints > 0) {
         if(InpATRMode == ATR_DIRECT) {
            baseDist = atrPoints * InpATRMultiplier;
            if(orderCount > 1 && GridMinDist > 0)
               baseDist *= ((double)GridDistLayer2 / GridMinDist);
         } else {
            double baseAtr = (InpBaseATRPoints > 0 ? InpBaseATRPoints : atrPoints);
            baseDist = baseDist * (atrPoints / baseAtr);
         }
      }
   }
   if(InpGridExpansion && orderCount >= 4)
      baseDist = baseDist * (1 + (orderCount-4)*0.2);
   if(baseDist < 1) baseDist = 1;
   return baseDist;
}

//====================================================================
//                       重构后的马丁逻辑
//====================================================================

void RunMartingaleLogic() {
   double bProf=GetFloatingPL(OP_BUY), sProf=GetFloatingPL(OP_SELL);
   double bLots=GetTotalLots(OP_BUY), sLots=GetTotalLots(OP_SELL);
   
   // 1. 独立止盈检查
   double bT = (bLots * InpTargetPips * g_PipValue);
   double sT = (sLots * InpTargetPips * g_PipValue);
   if(bLots > 0 && bProf >= bT) { ClosePositions(3); return; }
   if(sLots > 0 && sProf >= sT) { ClosePositions(4); return; }
   
   // 2. 加仓检查
   int bCnt = CountOrders(OP_BUY);
   if(g_AllowLong && (bCnt > 0)) {
      double dist = GetGridDistance(bCnt);
      if(Bid <= GetLastPrice(OP_BUY) - dist * _Point) {
         if(InpSingleSideMaxLoss == 0 || bProf >= -InpSingleSideMaxLoss)
            SafeOrderSend(OP_BUY, CalculateNextLot(OP_BUY), "Add_V3.9");
      }
   }

   int sCnt = CountOrders(OP_SELL);
   if(g_AllowShort && (sCnt > 0)) {
      double dist = GetGridDistance(sCnt);
      if(Ask >= GetLastPrice(OP_SELL) + dist * _Point) {
         if(InpSingleSideMaxLoss == 0 || sProf >= -InpSingleSideMaxLoss)
            SafeOrderSend(OP_SELL, CalculateNextLot(OP_SELL), "Add_V3.9");
      }
   }
}

//====================================================================
//                       继承功能 (V3.7/3.6/3.5)
//====================================================================

void ManageDualEntry() {
   if(CountOrders(OP_BUY)==0 && g_AllowLong) SafeOrderSend(OP_BUY, InpInitialLots, "Dual_Init");
   if(CountOrders(OP_SELL)==0 && g_AllowShort) SafeOrderSend(OP_SELL, InpInitialLots, "Dual_Init");
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
//                       UI 系统 (V3.9 展示增强)
//====================================================================

void OnChartEvent(const int id, const long& l, const double& d, const string& s) {
   if(id==CHARTEVENT_OBJECT_CLICK) {
      if(s==g_ObjPrefix+"Btn_Buy") g_AllowLong=!g_AllowLong;
      else if(s==g_ObjPrefix+"Btn_Sell") g_AllowShort=!g_AllowShort;
      else if(s==g_ObjPrefix+"Btn_CloseAll") CloseAll();
      else if(s==g_ObjPrefix+"Btn_Pause") g_IsTradingAllowed=!g_IsTradingAllowed;
      UpdateDashboard();
   }
}

void DrawDashboard() {
   int x=UI_X_Offset, y=UI_Y_Offset;
   int w=320, h=390, headerH=34, pad=12;
   int cy=y+headerH+10;
   string modeS = (InpMartinMode==MODE_FIBONACCI?"斐波那契":(InpMartinMode==MODE_LINEAR?"线性递增":"指数衰减"));

   CreateRect("Bg", x, y, w, h, g_ColorPanel, UI_ThemeColor);
   CreateRect("Accent", x, y, 4, h, UI_ThemeColor);
   CreateRect("Header", x+4, y, w-4, headerH, g_ColorHeader);
   CreateLabel("T_Title", "QuantTrader Pro", x+pad+2, y+9, g_ColorText, 10, "微软雅黑");
   CreateLabel("T_Ver", "V3.9", x+w-46, y+9, g_ColorMuted, 9, "Consolas");

   CreateLabel("T_Status", "策略状态", x+pad, cy, g_ColorMuted, 8, "微软雅黑");
   cy+=18;
   CreateRect("Chip_Buy", x+pad, cy, 68, 18, g_ColorGood);
   CreateLabel("L_BuyState", "多头 ON", x+pad+8, cy+3, g_ColorInk, 8, "微软雅黑");
   CreateRect("Chip_Sell", x+pad+76, cy, 68, 18, g_ColorGood);
   CreateLabel("L_SellState", "空头 ON", x+pad+84, cy+3, g_ColorInk, 8, "微软雅黑");
   CreateLabel("T_Mode", "模式:", x+w-110, cy+3, g_ColorMuted, 8, "微软雅黑");
   CreateLabel("V_Mode", modeS, x+w-64, cy+3, UI_ThemeColor, 8, "微软雅黑");

   cy+=26; CreateRect("Line1", x+pad, cy, w-2*pad, 1, g_ColorLine);
   cy+=10; CreateLabel("T_Profit", "收益表现", x+pad, cy, g_ColorMuted, 8, "微软雅黑");
   cy+=18; CreateLabel("T_Today", "今日获利", x+pad, cy, g_ColorText, 9, "微软雅黑");
   CreateLabel("V_TodayM", "0.00 USD", x+pad+70, cy, g_ColorGood, 9, "Consolas");
   CreateLabel("V_TodayP", "0.00%", x+w-58, cy, g_ColorGood, 9, "Consolas");
   cy+=20; CreateLabel("V_Target", "多头目标: 0.00 | 空头目标: 0.00", x+pad, cy, g_ColorMuted, 8, "微软雅黑");

   cy+=24; CreateRect("Line2", x+pad, cy, w-2*pad, 1, g_ColorLine);
   cy+=10; CreateLabel("T_Account", "账户数据", x+pad, cy, g_ColorMuted, 8, "微软雅黑");
   cy+=18; CreateLabel("T_Bal", "余额", x+pad, cy, g_ColorText, 9, "微软雅黑");
   CreateLabel("V_Bal", "0.00 USD", x+pad+70, cy, g_ColorText, 9, "Consolas");
   cy+=20; CreateLabel("T_Used", "已用保证金", x+pad, cy, g_ColorMuted, 9, "微软雅黑");
   CreateLabel("V_Used", "0.00 USD", x+pad+70, cy, g_ColorMuted, 9, "Consolas");
   cy+=20; CreateLabel("T_Margin", "保证金率", x+pad, cy, g_ColorText, 9, "微软雅黑");
   CreateLabel("V_Margin", "0.00%", x+pad+70, cy, UI_ThemeColor, 10, "Consolas");

   cy+=24; CreateRect("Line3", x+pad, cy, w-2*pad, 1, g_ColorLine);
   cy+=10; CreateLabel("T_Control", "手动控制", x+pad, cy, g_ColorMuted, 8, "微软雅黑");
   cy+=18; CreateButton("Btn_Buy", "多头开关", x+pad, cy, 90, 24, UI_ThemeColor);
   CreateButton("Btn_Sell", "空头开关", x+pad+98, cy, 90, 24, UI_ThemeColor);
   CreateButton("Btn_CloseAll", "全平清仓", x+pad+196, cy, 90, 24, g_ColorBad);
   cy+=30; CreateButton("Btn_Pause", "系统运行中", x+pad, cy, w-2*pad, 26, g_ColorButton);
}

void UpdateDashboard() {
   double bal = AccountBalance();
   datetime todayS = iTime(_Symbol, PERIOD_D1, 0);
   double pToday = GetHistoryProfit(todayS, TimeCurrent()+3600);
   double margin = AccountMargin();
   color todayColor = (pToday >= 0 ? g_ColorGood : g_ColorBad);
   
   SetLabelText("V_TodayM", StringFormat("%.2f USD", pToday));
   SetLabelText("V_TodayP", StringFormat("%.2f%%", (bal>0?pToday/bal*100:0)));
   SetObjectColor("V_TodayM", todayColor);
   SetObjectColor("V_TodayP", todayColor);
   SetLabelText("V_Bal", StringFormat("%.2f USD", bal));
   SetLabelText("V_Used", StringFormat("%.2f USD", margin)); // 实时更新已用保证金
   if(margin>0) SetLabelText("V_Margin", StringFormat("%.2f%%", AccountEquity()/margin*100));
   else SetLabelText("V_Margin", "0.00%");
   
   double bLots=GetTotalLots(OP_BUY), sLots=GetTotalLots(OP_SELL);
   SetLabelText("V_Target", StringFormat("多头目标: %.2f | 空头目标: %.2f", bLots*InpTargetPips*g_PipValue, sLots*InpTargetPips*g_PipValue));

   SetLabelText("L_BuyState", g_AllowLong?"多头 ON":"多头 OFF");
   SetObjectColor("L_BuyState", g_AllowLong?g_ColorInk:g_ColorText);
   SetRectBg("Chip_Buy", g_AllowLong?g_ColorGood:g_ColorBad);
   SetLabelText("L_SellState", g_AllowShort?"空头 ON":"空头 OFF");
   SetObjectColor("L_SellState", g_AllowShort?g_ColorInk:g_ColorText);
   SetRectBg("Chip_Sell", g_AllowShort?g_ColorGood:g_ColorBad);
   SetLabelText("Btn_Pause", g_IsTradingAllowed?"系统运行中 · 点击暂停":"系统已暂停 · 点击恢复");
   SetBtnColor("Btn_Pause", g_IsTradingAllowed?g_ColorButton:g_ColorBad);
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
bool GlobalRiskCheck() { return true; } // 简化版风控
void SafeOrderSend(int t,double l,string c){ if(OrderSend(_Symbol,t,l,(t==OP_BUY?Ask:Bid),10,0,0,c,InpMagicNum,0,(t==OP_BUY?clrBlue:clrRed))<0) Print(GetLastError());}
int CountOrders(int t){int c=0;for(int i=0;i<OrdersTotal();i++)if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum&&OrderType()==t)c++;return c;}
double GetTotalLots(int t){double l=0;for(int i=0;i<OrdersTotal();i++)if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum&&OrderType()==t)l+=OrderLots();return l;}
double GetFloatingPL(int t){double p=0;for(int i=0;i<OrdersTotal();i++)if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum&&OrderType()==t)p+=OrderProfit()+OrderCommission()+OrderSwap();return p;}
double GetLastPrice(int t){double p=0;datetime d=0;for(int i=0;i<OrdersTotal();i++)if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum&&OrderType()==t)if(OrderOpenTime()>d){d=OrderOpenTime();p=OrderOpenPrice();}return p;}
double GetLastLot(int t){double l=InpInitialLots;datetime d=0;for(int i=0;i<OrdersTotal();i++)if(OrderSelect(i,SELECT_BY_POS)&&OrderMagicNumber()==InpMagicNum&&OrderType()==t)if(OrderOpenTime()>d){d=OrderOpenTime();l=OrderLots();}return l;}
void CreateRect(string n,int x,int y,int w,int h,color bg,color border=CLR_NONE) { string name=g_ObjPrefix+n; if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);ObjectSetInteger(0,name,OBJPROP_BACK,true); }
void CreateLabel(string n,string t,int x,int y,color c,int s=9,string f="微软雅黑") { string name=g_ObjPrefix+n; if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0); ObjectSetString(0,name,OBJPROP_TEXT,t); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_COLOR,c); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,s); ObjectSetString(0,name,OBJPROP_FONT,f);}
void CreateButton(string n,string t,int x,int y,int w,int h,color bg) { string name=g_ObjPrefix+n; if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_BUTTON,0,0,0); ObjectSetString(0,name,OBJPROP_TEXT,t); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_COLOR,g_ColorText); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8); ObjectSetString(0,name,OBJPROP_FONT,"微软雅黑"); }
void SetLabelText(string n,string t) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetString(0,g_ObjPrefix+n,OBJPROP_TEXT,t); }
void SetObjectColor(string n,color c) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetInteger(0,g_ObjPrefix+n,OBJPROP_COLOR,c); }
void SetBtnColor(string n,color c) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetInteger(0,g_ObjPrefix+n,OBJPROP_BGCOLOR,c); }
void SetRectBg(string n,color c) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetInteger(0,g_ObjPrefix+n,OBJPROP_BGCOLOR,c); }
