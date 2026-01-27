//+------------------------------------------------------------------+
//|                                           DataScanner_Pro.mq4    |
//|                                  Multi-Symbol Market Data Scanner|
//|                                            Version 1.3           |
//+------------------------------------------------------------------+
#property copyright "QuantTrader Data Scanner"
#property link      ""
#property version   "1.30"
#property strict

//+------------------------------------------------------------------+
//|                            枚举定义                              |
//+------------------------------------------------------------------+
enum ENUM_CONNECTION_MODE
  {
   MODE_ONLINE = 1,    // 连线模式 (开启回传)
   MODE_OFFLINE = 2    // 离线模式 (不回传)
  };

//+------------------------------------------------------------------+
//|                            输入参数                              |
//+------------------------------------------------------------------+
extern string RustServerUrl       = "http://192.168.31.53:3001"; // 服务器地址
extern string SymbolsList         = "XAUUSD,EURUSD,GBPUSD,USDCAD"; // 扫描品种列表 (逗号分隔)
extern int    ScanIntervalMs      = 500;                         // 扫描与上报间隔 (毫秒) - 推荐 200ms 以上
extern ENUM_CONNECTION_MODE ConnectionMode = MODE_ONLINE;        // 连接模式

//+------------------------------------------------------------------+
//|                            全局变量                              |
//+------------------------------------------------------------------+
string g_Symbols[];
int    g_SymbolCount = 0;

//+------------------------------------------------------------------+
//|                          初始化函数                              |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 使用毫秒计时器实现最小间隔汇报
   if(ScanIntervalMs < 100) ScanIntervalMs = 100; // 保护性限制，防止过低导致终端卡死
   EventSetMillisecondTimer(ScanIntervalMs);
   
   // 解析品种列表
   ParseSymbols();
   
   Print("High-Frequency Data Scanner Started. Interval: ", ScanIntervalMs, "ms. Monitoring: ", SymbolsList);
   
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

void OnTimer()
  {
   if(ConnectionMode == MODE_OFFLINE) return;
   if(IsTradeContextBusy()) return;

   // 高频扫描模式：强制批量上报以保证性能
   string batchJson = "[";
   bool hasData = false;

   for(int i = 0; i < g_SymbolCount; i++)
     {
      string item = GetSymbolDataJSON(g_Symbols[i]);
      if(item != "")
        {
         if(hasData) batchJson += ",";
         batchJson += item;
         hasData = true;
        }
     }
   batchJson += "]";

   if(hasData)
     {
      // 批量上报是高频模式下的唯一可行方案
      SendData("/api/v1/market/batch", batchJson);
     }
  }

void OnTick()
  {
   // 逻辑完全由高频 Timer 驱动
  }

//+------------------------------------------------------------------+
//|                          内核扫描逻辑                            |
//+------------------------------------------------------------------+

void ParseSymbols()
  {
   string list = SymbolsList;
   StringReplace(list, " ", ""); 
   
   ushort sep = StringGetCharacter(",", 0);
   g_SymbolCount = StringSplit(list, sep, g_Symbols);
   
   // 验证并预选品种
   for(int i = 0; i < g_SymbolCount; i++)
     {
      if(!SymbolSelect(g_Symbols[i], true))
        {
         Print("Warning: Symbol not found or could not be selected: ", g_Symbols[i]);
        }
     }
  }

string GetSymbolDataJSON(string sym)
  {
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double open  = iOpen(sym, PERIOD_M1, 0);
   double high  = iHigh(sym, PERIOD_M1, 0);
   double low   = iLow(sym, PERIOD_M1, 0);
   double close = iClose(sym, PERIOD_M1, 0);
   
   if(bid == 0 || ask == 0) return "";

   // 返回 JSON 对象片段
   return StringFormat("{\"symbol\":\"%s\",\"timestamp\":%lld,\"open\":%.5f,\"high\":%.5f,\"low\":%.5f,\"close\":%.5f,\"bid\":%.5f,\"ask\":%.5f}",
                               sym, (long)TimeCurrent(), open, high, low, close, bid, ask);
}

//+------------------------------------------------------------------+
//|                          网络通信层                              |
//+------------------------------------------------------------------+

int SendData(string path, string json_body) {
   if(ConnectionMode == MODE_OFFLINE) return 200;
   
   char data[], result[];
   string headers = "Content-Type: application/json\r\n";
   StringToCharArray(json_body, data, 0, WHOLE_ARRAY, CP_UTF8);
   
   // 毫秒级上报必须使用较短的超时时间，防止同步请求阻塞 MT4 主线程
   int res = WebRequest("POST", RustServerUrl + path, headers, 300, data, result, headers);
   
   if(res == -1) {
      static datetime lastError = 0;
      if(TimeCurrent() - lastError > 60) { 
         Print("High-Frequency Network Error. Code: ", GetLastError());
         lastError = TimeCurrent();
      }
   }
   return res;
}
