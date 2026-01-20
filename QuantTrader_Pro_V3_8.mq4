//+------------------------------------------------------------------+
//|                                      QuantTrader_Pro_V3_8.mq4    |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://www.mql5.com"
#property version   "3.80"
#property strict
#property description "全自动多策略量化交易系统 V3.8 [低压加仓优化版]"

//--- 枚举定义
enum ENUM_MARTIN_MODE {
   MODE_EXPONENTIAL, // 指数增加 (0.01, 0.02, 0.04...)
   MODE_FIBONACCI,   // 斐波那契 (0.01, 0.01, 0.02, 0.03, 0.05...)
   MODE_LINEAR       // 线性递增 (0.01, 0.02, 0.03, 0.04...)
};

//====================================================================
//                       参数输入模块 (Parameters)
//====================================================================
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
      int dist = (bCnt == 1) ? GridMinDist : GridDistLayer2;
      // [V3.8] 动态扩张：每深一层加 20% 间距
      if(InpGridExpansion && bCnt >= 4) dist = (int)(dist * (1 + (bCnt-4)*0.2));
      
      if(Bid <= GetLastPrice(OP_BUY) - dist * _Point) {
         if(InpSingleSideMaxLoss == 0 || bProf >= -InpSingleSideMaxLoss)
            SafeOrderSend(OP_BUY, CalculateNextLot(OP_BUY), "Add_V3.8");
      }
   }

   int sCnt = CountOrders(OP_SELL);
   if(g_AllowShort && (sCnt > 0)) {
      int dist = (sCnt == 1) ? GridMinDist : GridDistLayer2;
      if(InpGridExpansion && sCnt >= 4) dist = (int)(dist * (1 + (sCnt-4)*0.2));
      
      if(Ask >= GetLastPrice(OP_SELL) + dist * _Point) {
         if(InpSingleSideMaxLoss == 0 || sProf >= -InpSingleSideMaxLoss)
            SafeOrderSend(OP_SELL, CalculateNextLot(OP_SELL), "Add_V3.8");
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
//                       UI 系统 (V3.8 展示增强)
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
   int x=UI_X_Offset, y=UI_Y_Offset, w=300;
   CreateRect("Bg", x, y, w, 400, C'30,30,30', UI_ThemeColor);
   CreateLabel("L_BuyState", "可以多", x+20, y+15, clrLime, 10, "微软雅黑");
   CreateLabel("L_SellState", "可以空", x+w-70, y+15, clrLime, 10, "微软雅黑");
   
   y+=45; CreateRect("Line1", x+10, y, w-20, 1, clrSilver);
   CreateLabel("T_Profit", "【V3.8 低压版统计】", x+w/2-55, y-10, clrGold, 9, "微软雅黑");
   
   y+=25; CreateLabel("T_Mode", "加仓模式:", x+20, y, clrWhite, 9);
   string modeS = (InpMartinMode==MODE_FIBONACCI?"斐波那契":(InpMartinMode==MODE_LINEAR?"线性递增":"指数衰减"));
   CreateLabel("V_Mode", modeS, x+120, y, clrCyan, 9);

   y+=25; CreateLabel("T_Today", "今日获利:", x+20, y, clrWhite, 9);
   CreateLabel("V_TodayM", "0.00 USD", x+120, y, clrLime, 9);
   CreateLabel("V_TodayP", "0.00%", x+w-70, y, clrLime, 9);
   
   y+=25; CreateLabel("V_Target", "多头目标: 0.00 | 空头目标: 0.00", x+20, y, clrSilver, 8);

   y+=30; CreateRect("Line2", x+10, y, w-20, 1, clrSilver);
   y+=15; CreateLabel("T_Bal", "账户余额:", x+20, y, clrWhite, 9);
   CreateLabel("V_Bal", "0.00 USD", x+120, y, clrWhite, 9);
   
   y+=25; CreateLabel("T_Used", "已用预付款:", x+20, y, clrWhite, 9); // 找回已用预付款
   CreateLabel("V_Used", "0.00 USD", x+120, y, clrSilver, 9);

   y+=25; CreateLabel("T_Margin", "预付款比例:", x+20, y, clrWhite, 9);
   CreateLabel("V_Margin", "0.00%", x+w/2, y, clrCyan, 10, "Arial Bold");
   
   y+=40; CreateButton("Btn_Buy", "多头开关", x+15, y, 85, 25, UI_ThemeColor);
   CreateButton("Btn_Sell", "空头开关", x+w/2-42, y, 85, 25, UI_ThemeColor);
   CreateButton("Btn_CloseAll", "全平清仓", x+w-95, y, 80, 25, clrRed);
   y+=35; CreateButton("Btn_Pause", "系统全线启停", x+15, y, w-30, 25, clrGray);
}

void UpdateDashboard() {
   double bal = AccountBalance();
   datetime todayS = iTime(_Symbol, PERIOD_D1, 0);
   double pToday = GetHistoryProfit(todayS, TimeCurrent()+3600);
   
   SetLabelText("V_TodayM", StringFormat("%.2f USD", pToday));
   SetLabelText("V_TodayP", StringFormat("%.2f%%", (bal>0?pToday/bal*100:0)));
   SetLabelText("V_Bal", StringFormat("%.2f USD", bal));
   SetLabelText("V_Used", StringFormat("%.2f USD", AccountMargin())); // 实时更新已用预付款
   if(AccountMargin()>0) SetLabelText("V_Margin", StringFormat("%.2f%%", AccountEquity()/AccountMargin()*100));
   
   double bLots=GetTotalLots(OP_BUY), sLots=GetTotalLots(OP_SELL);
   SetLabelText("V_Target", StringFormat("多头目标: %.2f | 空头目标: %.2f", bLots*InpTargetPips*g_PipValue, sLots*InpTargetPips*g_PipValue));

   SetLabelText("L_BuyState", g_AllowLong?"可以多":"禁多"); SetObjectColor("L_BuyState", g_AllowLong?clrLime:clrRed);
   SetLabelText("L_SellState", g_AllowShort?"可以空":"禁空"); SetObjectColor("L_SellState", g_AllowShort?clrLime:clrRed);
   SetLabelText("Btn_Pause", g_IsTradingAllowed?"系统正在运行 [点击暂停]":"系统已经停机 [点击恢复]");
   SetBtnColor("Btn_Pause", g_IsTradingAllowed?clrGray:clrRed);
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
void CreateLabel(string n,string t,int x,int y,color c,int s=9,string f="Arial") { string name=g_ObjPrefix+n; if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0); ObjectSetString(0,name,OBJPROP_TEXT,t); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_COLOR,c); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,s); ObjectSetString(0,name,OBJPROP_FONT,f);}
void CreateButton(string n,string t,int x,int y,int w,int h,color bg) { string name=g_ObjPrefix+n; if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_BUTTON,0,0,0); ObjectSetString(0,name,OBJPROP_TEXT,t); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8); }
void SetLabelText(string n,string t) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetString(0,g_ObjPrefix+n,OBJPROP_TEXT,t); }
void SetObjectColor(string n,color c) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetInteger(0,g_ObjPrefix+n,OBJPROP_COLOR,c); }
void SetBtnColor(string n,color c) { if(ObjectFind(0,g_ObjPrefix+n)>=0) ObjectSetInteger(0,g_ObjPrefix+n,OBJPROP_BGCOLOR,c); }
