//+------------------------------------------------------------------+
//|                                           DataScanner_Pro.mq4    |
//|                                  Multi-Symbol Market Data Scanner|
//|                                            Version 1.4           |
//+------------------------------------------------------------------+
#property copyright "QuantTrader Data Scanner"
#property link      ""
#property version   "1.43"
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
input string   RustServerUrl    = "http://www.mondayquest.top"; // 服务器地址
input string   ApiPath          = "/api/v1/market/batch";      // API 路径
input int      CollectInterval  = 5;                           // 采集间隔 (秒)
input bool     UseMarketWatch   =  false;                        // true=采集市场报价窗口所有品种, false=只采集下方自定义列表
input string   CustomSymbols    = "XAUUSD,EURUSD,GBPUSD,USDJPY,BTCUSD,NAS100,US30,ETHUSD,AUDUSD,USOIL"; // 自定义品种 (10个热门品种)
input int      BatchSize        = 10;                          // 每次批量上报打包多少个品种 (建议 10-20)
input ENUM_CONNECTION_MODE ConnectionMode = MODE_ONLINE;       // 连接模式

//+------------------------------------------------------------------+
//|                            全局变量                              |
//+------------------------------------------------------------------+
static datetime g_lastSuccessLog = 0;
static datetime g_lastError = 0;

//+------------------------------------------------------------------+
//|                          初始化函数                              |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 检查是否允许 WebRequest
   if(!TerminalInfoInteger(TERMINAL_DLLS_ALLOWED)) {
      Print("Warning: Please check 'Allow WebRequest' in Tools -> Options -> Expert Advisors");
   }

   // 设置定时器，按秒采集
   int interval = CollectInterval;
   if(interval < 1) interval = 1;
   EventSetTimer(interval);
   
   string modeInfo = UseMarketWatch ? "Market Watch Symbols" : "Custom List";
   Print("High-Frequency Data Scanner Started. Mode: ", modeInfo, ". Interval: ", CollectInterval, "s.");
   
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   Print("Data Scanner Stopped.");
  }

void OnTimer()
  {
   if(ConnectionMode == MODE_OFFLINE) {
      Print("DEBUG: Offline Mode - No Action");
      return;
   }
   
   // DEBUG: Heartbeat (强制打印以确认 Timer 存活)
   // 为了防止刷屏太快，每 5 次 Timer 执行打印一次
   static int tick_counter = 0;
   tick_counter++;
   if(tick_counter % 1 == 0) { // 现在改为每次都打印，排查到底进没进来
       Print("DEBUG: OnTimer Executing... Symbols to scan: ", UseMarketWatch ? "MarketWatch" : "Custom");
   }

   if(IsTradeContextBusy()) {
       Print("DEBUG: Trade Context Busy");
       return; 
   }

   string symbols_to_scan[];
   int total_symbols = 0;

   // 1. 确定要扫描哪些品种
   if(UseMarketWatch) {
      total_symbols = SymbolsTotal(true); 
      ArrayResize(symbols_to_scan, total_symbols);
      for(int i=0; i<total_symbols; i++) {
         symbols_to_scan[i] = SymbolName(i, true);
      }
   } else {
      string split[];
      ushort sep = StringGetCharacter(",", 0);
      StringSplit(CustomSymbols, sep, split);
      total_symbols = ArraySize(split);
      ArrayResize(symbols_to_scan, total_symbols);
      for(int i=0; i<total_symbols; i++) {
         symbols_to_scan[i] = split[i];
         StringReplace(symbols_to_scan[i], " ", "");
      }
   }

   // 2. 分批采集并发送 (Batch Process)
   // DEBUG: 打印品种数量，确认解析成功
   if(tick_counter % 1 == 0) {
       Print("DEBUG: Total symbols to scan: ", total_symbols);
       if(total_symbols > 0) Print("DEBUG: First symbol: '", symbols_to_scan[0], "'");
   }

   string json_array = "";
   int count_in_batch = 0;

   for(int i=0; i<total_symbols; i++) {
      string sym = symbols_to_scan[i];
      
      // 获取数据 (MarketInfo)
      double bid = MarketInfo(sym, MODE_BID);
      double ask = MarketInfo(sym, MODE_ASK);
      
      if(bid <= 0 || ask <= 0) {
          // DEBUG: 既然是在调试，告诉用户哪个品种获取失败了
          if(tick_counter % 10 == 0 && i < 5) { // 限制打印数量
              Print("WARNING: Failed to get price for '", sym, "'. Check symbol name/suffix? (Bid=", bid, ")");
          }
          // 这里的 continue 会导致跳过底部的发送逻辑，如果这是最后一个品种，就会丢包！
          // 所以我们需要在 continue 前检查是否是最后一个，如果是，且 buffer 里有数据，得先发了
          if(i == total_symbols - 1 && json_array != "") {
               string final_json = "[" + json_array + "]";
               Print("DEBUG: Last symbol invalid, sending accumulated batch...");
               SendData(final_json);
          }
          continue;
      }

      // 获取 OHLC (当前M1 K线)
      double open = iOpen(sym, PERIOD_M1, 0);
      double high = iHigh(sym, PERIOD_M1, 0);
      double low  = iLow(sym, PERIOD_M1, 0);
      double close= iClose(sym, PERIOD_M1, 0);
      long   time = (long)TimeCurrent();

      // 构建单个品种的 JSON 对象 (保持后端兼容的字段名)
      string item = StringFormat("{\"symbol\":\"%s\",\"timestamp\":%I64d,\"open\":%.5f,\"high\":%.5f,\"low\":%.5f,\"close\":%.5f,\"bid\":%.5f,\"ask\":%.5f}",
                                 sym, time, open, high, low, close, bid, ask);
      
      if(count_in_batch > 0) json_array += ",";
      json_array += item;
      count_in_batch++;

      // 达到 BatchSize 或 最后一个品种时，发送数据
      if(count_in_batch >= BatchSize || i == total_symbols - 1) {
         if(json_array != "") {
             string final_json = "[" + json_array + "]";
             SendData(final_json);
         }
         json_array = "";
         count_in_batch = 0;
      }
   }
  }

void OnTick()
  {
   // 逻辑完全由 OnTimer 驱动
  }

//+------------------------------------------------------------------+
//|                          网络通信层                              |
//+------------------------------------------------------------------+

int SendData(string json_body) {
   if(ConnectionMode == MODE_OFFLINE) return 200;
   
   // DEBUG: 确认 SendData 被调用
   Print("DEBUG: SendData called. Payload size: ", StringLen(json_body));

   char data[], result[];
   string headers = "Content-Type: application/json\r\n";
   StringToCharArray(json_body, data, 0, WHOLE_ARRAY, CP_UTF8);
   
   // WebRequest - 设置 2 秒超时
   int res = WebRequest("POST", RustServerUrl + ApiPath, headers, 2000, data, result, headers);
   
   if(res >= 200 && res <= 299) {
      string response_body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      // DEBUG: 成功日志
      Print("Data Scanner: Sent ", StringLen(json_body), " bytes | Status: ", res, " | Response: ", response_body);
      g_lastSuccessLog = TimeCurrent();
   }
   else if(res == -1) {
      // DEBUG: 强制打印错误，无视频率限制
      int err = GetLastError();
      Print("ERROR: WebRequest failed (-1). Error Code: ", err);
      if(err == 4060) Print("  -> Hint: Enable 'Allow WebRequest' in Tools > Options > Expert Advisors");
      g_lastError = TimeCurrent();
   }
   else {
      // DEBUG: 强制打印 HTTP 错误
      Print("ERROR: Server returned HTTP ", res, " Path: ", ApiPath);
      g_lastError = TimeCurrent();
   }
   return res;
}
