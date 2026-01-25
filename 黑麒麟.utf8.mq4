//EA交易     =>  ...\MT4\MQL4\Experts

#property  copyright "Copyright  2011,YQL"
#property  link      "https://hisanhe.com"
#property version    "1.01"
#property strict

////////////////////////////////////////////////////////////////////////
bool     Company_control = false;                                                      // 限制平台开关
bool     Account_Control = false;                                                      // 限制账号开关
bool     Time_Control = false;                                                          // 限制时间开关
string   Company = "";                                                                 // 平台名称
string   Bind_Account = "";                                                            // 绑定真实账号
// 多个账号用+分开。举例：="12345+23456+34567";
datetime Use_Expiration_Time = D'2026.01.22 12:00:00';                                 // 使用期限
string   Company_Error_Reminder_Content = "使用平台错误,请联系...";                    // 平台错误提醒
string   Account_Error_Reminder_Content = "没有绑定该账号,请联系...";                  // 账号错误提醒
string   The_Deadline_Has_Reached_The_Reminder_Content = "使用期限已到,请联系...";     // 时间到期提醒
////////////////////////////////////////////////////////////////////////


enum opentime      {A = 1,//开单时区模式
                    B = 2,//开单时间间距(秒)模式
                    C = 3//不延迟模式
                   };


//------------------
extern string 授权码 = ""  ;
extern double On_top_of_this_price_not_Buy_first_order = 0  ;  //B以上不开(首)
extern double On_under_of_this_price_not_Sell_first_order = 0  ;  //S以下不开(首)
extern double On_top_of_this_price_not_Buy_order = 0  ;  //B以上不开(补)
extern double On_under_of_this_price_not_Sell_order = 0  ;  //S以下不开(补)
extern string Limit_StartTime = "00:00"  ; //限价开始时间
extern string Limit_StopTime = "24:00"  ; //限价结束时间
extern bool CloseBuySell = true  ;  //逆势保护开关
extern bool HomeopathyCloseAll = true  ;  //顺势保护开关
extern bool Homeopathy = false ;  //完全对锁时挂上顺势开关
extern bool Over = false ;  //平仓后停止交易
extern int   NextTime = 0  ;  //整体平仓后多少秒后新局
extern double Money = 0  ;  //浮亏多少启用第二参数
extern int   FirstStep = 30  ;  //首单距离
extern int   MinDistance = 60  ;  //最小距离
extern int   TwoMinDistance = 60  ;  //第二最小距离
extern int   StepTrallOrders = 5  ;  //挂单追踪点数
extern int   Step = 100  ;  //补单间距
extern int   TwoStep = 100  ;  //第二补单间距
extern  opentime  OpenMode = 3  ;
extern  ENUM_TIMEFRAMES  TimeZone = 1  ;  //开单时区
extern int   sleep = 30  ;  //开单时间间距(秒)
extern double MaxLoss = 100000  ;  //单边浮亏超过多少不继续加仓
extern double MaxLossCloseAll = 50  ;  //单边平仓限制
extern double lot = 0.01  ;  //起始手数
extern double Maxlot = 10  ;  //最大开单手数
extern double PlusLot = 0  ;  //累加手数
extern double K_Lot = 1.3  ;  //倍率
extern int   DigitsLot = 2  ;  //下单量的小数位
extern double CloseAll = 0.5  ;  //整体平仓金额
extern bool Profit = true  ;  //单边平仓金额累加开关
extern double StopProfit = 2  ;  //单边平仓金额
extern double StopLoss = 0  ;  //止损金额
extern int   Magic = 9527  ;
extern int   Totals = 50  ;  //最大单量
extern int   MaxSpread = 200  ;  //点差限制
extern int   Leverage = 100  ;  //平台杠杆限制
extern string EA_StartTime = "00:00"  ; //EA开始时间
extern string EA_StopTime = "24:00"  ; //EA结束时间
extern color clr1 = MediumSeaGreen  ;  //多单平均价颜色
extern color clr2 = Crimson  ;  //空单平均价颜色
extern string Com_1 = "备注1";   // 订单备注1
extern string Com_2 = "备注2";     // 订单备注2

string    Zong_1_st_0 = "http://auth.hisanhe.com/index.php?page=verify&lang=zh-cn&ea=1&hwid=";
string    Zong_2_st_10;
string    Zong_3_st_20;
string    Zong_4_st_30 = "GoldKylin";
//string    Zong_5_st_40 = "http://www.hisanhe.com/wp-content/uploads/2025/09/18065128547.bmp";
//string    Zong_6_st_50 = "http://www.hisanhe.com/wp-content/uploads/2025/09/18065133709.bmp";
//string    Zong_7_st_60 = "https://www.hisanhe.com/wp-content/uploads/2025/09/18134718464.bmp";
string    Zong_8_st_70 = "Big.bmp";
string    Zong_9_st_80 = "Round1.bmp";
string    Zong_10_st_90 = "Round2.bmp";
datetime  Zong_13_da_C0 = 0;
int       Zong_14_in_C8 = 0;
bool      Zong_15_bo_CC = true;
bool      Zong_16_bo_CD = false;
string    Zong_17_st_D0 = "StatisticsPanel";
string    Zong_18_st_E0 = "ButtonPanel";
int       Zong_19_in_EC = 10;
uint      Zong_20_ui_F0 = Lime;
string    Zong_21_st_F8 = "Microsoft YaHei";
int       Zong_22_in_104 = 1;
double    Zong_23_do_108 = 0.0;
int       Zong_24_in_110 = 0;
bool      Zong_25_bo_114 = true;
bool      Zong_26_bo_115 = true;
int       Zong_27_in_118 = 30;
double    Zong_28_do_120 = 1.0;
bool      Zong_29_bo_128 = true;
bool      Zong_30_bo_129 = true;
int       Zong_31_in_12C = 1;
int       Zong_32_in_130 = 0;
int       Zong_33_in_134 = 10;
uint      Zong_34_ui_138 = Lime;
uint      Zong_35_ui_13C = Blue;
uint      Zong_36_ui_140 = Red;
datetime  Zong_37_da_148 = 0;
bool      Zong_38_bo_150 = true;
bool      Zong_39_bo_151 = false;
bool      Zong_40_bo_152 = false;
string    Zong_41_st_158 = "";
string    Zong_42_st_168 = "0-off  1-Candle  2-Fractals  >2-pips";
int       Zong_43_in_174 = 3;
int       Zong_44_in_178 = 20;
int       Zong_45_in_17C = 25;
int       Zong_46_in_180 = 0;
int       Zong_47_in_184 = 15;
int       Zong_48_in_188 = 0;
int       Zong_49_in_18C = 346856;
int       Zong_50_in_190 = 0;
double    Zong_51_do_198 = 0.0;
double    Zong_52_do_1A0 = 0.0;
int       Zong_53_in_1A8 = 1482134400;
string    Zong_54_st_1B0 = "Exness Ltd.";
string    Zong_55_st_1C0 = "CB Financial Services Limited";
int       Zong_56_in_1CC = 1;
int       Zong_57_in_1D0 = 2;
double    Zong_58_do_1D8 = 10.0;
color     Zong_59_co_1E0 = DimGray;
string    Zong_60_st_1E8 = "Spread";
int       Zong_61_in_1F4 = 0;
bool      Zong_62_bo_1F8 = true;
string    Zong_63_st_200 = "Button1";
string    Zong_64_st_210 = "Button2";
string    Zong_65_st_220 = "Button5";
int       Zong_66_in_22C = 55295;
int       Zong_67_in_230 = 16777215;
int       Zong_68_in_234 = 65280;
int       Zong_69_in_238 = 65280;
int       Zong_70_in_23C = 65535;
int       Zong_71_in_240 = 12632256;
string    Zong_72_st_248 = "Lever";
string    Zong_73_st_258 = "Spreads";
int       Zong_74_in_264 = 3;
int       Zong_75_in_268 = 25;
int       Zong_76_in_26C = 30;
bool      Zong_77_bo_270 = false;
string    Zong_78_st_278 = "Amazing不爆仓调教版";
double    Zong_79_do_288 = 0.0;
double    Zong_80_do_290 = 0.0;
int       Zong_81_in_298 = 0;
int       Zong_82_in_29C = 0;
int       Zong_83_in_2A0 = 0;
string    Zong_84_st_2A8 = "000,000,000";
string    Zong_85_st_2B8 = "000,000,255";
int       Zong_86_in_2C4 = 40;
int       Zong_87_in_2C8 = 0;
int       Zong_88_in_2CC = 0;
int       Zong_89_in_2D0 = 0;
datetime  Zong_90_da_2D8 = 0;
datetime  Zong_91_da_2E0 = 0;
datetime  Zong_92_da_2E8 = 0;
datetime  Zong_93_da_2F0 = 0;
datetime  Zong_94_da_2F8 = 0;
long      Zong_95_lo_300 = 0;
long      Zong_96_lo_308 = 0;
int       Zong_97_in_310 = 0;
string    Zong_98_st_318 = "";
string    Zong_99_st_328 = "";
string    Zong_100_st_338 = "";
string    Zong_101_st_348 = "";
string    Zong_102_st_358 = "";
string    Zong_103_st_368 = "";
string    Zong_104_st_378 = "";
string    Zong_105_st_388 = "";
string    Zong_106_st_398 = "";
string    Zong_107_st_3A8 = "";
string    Zong_108_st_3B8 = "";
string    Zong_109_st_3C8 = "";
string    Zong_110_st_3D8 = "";
string    Zong_111_st_3E8 = "";
string    Zong_112_st_3F8 = "";
string    Zong_113_st_408 = "";
string    Zong_114_st_418 = "";
string    Zong_115_st_428 = "";
string    Zong_116_st_438 = "";
string    Zong_117_st_448 = "";
string    Zong_118_st_458 = "";
string    Zong_119_st_468 = "";
string    Zong_120_st_478 = "";
string    Zong_121_st_488 = "";
string    Zong_122_st_498 = "";
string    Zong_123_st_4A8 = "";
string    Zong_124_st_4B8 = "";
string    Zong_125_st_4C8 = "";
string    Zong_126_st_4D8 = "";
string    Zong_127_st_4E8 = "";
string    Zong_128_st_4F8 = "";
string    Zong_129_st_508 = "";
string    Zong_130_st_518 = "";
string    Zong_131_st_528 = "";
string    Zong_132_st_538 = "";
string    Zong_133_st_548 = "";
string    Zong_134_st_558 = "";
string    Zong_135_st_568 = "";
string    Zong_136_st_578 = "";
string    Zong_137_st_588 = "";
string    Zong_138_st_598 = "";
string    Zong_139_st_5A8 = "";
string    Zong_140_st_5B8 = "";
string    Zong_141_st_5C8 = "";
string    Zong_142_st_5D8 = "";
string    Zong_143_st_5E8 = "";
string    Zong_144_st_5F8 = "";
string    Zong_145_st_608 = "";
string    Zong_146_st_618 = "";
string    Zong_147_st_628 = "";
string    Zong_148_st_638 = "";
string    Zong_149_st_648 = "";
string    Zong_150_st_658 = "";
string    Zong_151_st_668 = "";
string    Zong_152_st_678 = "";
string    Zong_153_st_688 = "";
string    Zong_154_st_698 = "";
string    Zong_155_st_6A8 = "";
string    Zong_156_st_6B8 = "";
string    Zong_157_st_6C8 = "";
string    Zong_158_st_6D8 = "";
string    Zong_159_st_6E8 = "";
string    Zong_160_st_6F8 = "";
string    Zong_161_st_708 = "";
string    Zong_162_st_718 = "";
string    Zong_163_st_728 = "";
int       Zong_164_in_734 = 0;
int       Zong_165_in_738 = 0;

#import   "wininet.dll"
int InternetOpenW(string Mu_0_st, int Mu_1_in, string Mu_2_st, string Mu_3_st, int Mu_4_in);
int InternetOpenUrlW(int Mu_0_in, string Mu_1_st, string Mu_2_st, int Mu_3_in, int Mu_4_in, int Mu_5_in);
int InternetReadFile(int Mu_0_in, uchar & Mu_1_uc_ko[], int Mu_2_in, int & Mu_3_in);
int InternetCloseHandle(int Mu_0_in);
#import

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int init()
  {
   int       Zi_2_in;
   bool      Zi_3_bo;
   int       Zi_4_in;
   // 强制删除残留的图片对象
   ObjectDelete(0, "tubiao");
   ObjectDelete(0, "tubiao1");
   ObjectDelete(0, "tubiao2");
//----- -----
   double     Lin_do_1;
   int        Lin_in_2;
   int        Lin_in_3;
   if(!(IsTesting()) && !(lizong_18()))
     {
      Comment(Zong_103_st_368 + Zong_3_st_20);
      ExpertRemove();
      return(0);
     }
   Comment(Zong_102_st_358 + Zong_3_st_20);
//   lizong_19(Zong_5_st_40, Zong_4_st_30 + Zong_8_st_70, 1117574);
//   lizong_19(Zong_6_st_50, Zong_4_st_30 + Zong_9_st_80, 19256);
//   lizong_19(Zong_7_st_60, Zong_4_st_30 + Zong_10_st_90, 19254);
   Zi_2_in = 0 ;
   Zi_3_bo = false ;
   Zi_4_in = 0 ;
   Zong_78_st_278 = WindowExpertName() ;
   Zi_2_in = 0 ;
   Zi_3_bo = false ;
   Zi_4_in = 0 ;
   Zong_47_in_184 = lizong_15(Zong_47_in_184) ;
   if((Digits() == 5 || Digits() == 3))
     {
      Zong_50_in_190 = 30 ;
     }
   Comment("");
   Zi_2_in += Zong_33_in_134 * 3;
   Zi_3_bo = false ;
   MaxLossCloseAll = -(MaxLossCloseAll);
   MaxLoss = -(MaxLoss);
   StopLoss = -(StopLoss);
   Money = -(Money);
   if(Zong_78_st_278 != WindowExpertName())
     {
      Comment("");
      Zong_29_bo_128 = false ;
      Zong_30_bo_129 = false ;
      ObjectsDeleteAll(-1, -1);
      if(ObjectFind(Zong_60_st_1E8) <  0)
        {
         ObjectCreate(Zong_60_st_1E8, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zong_60_st_1E8, OBJPROP_CORNER, 1.0);
         ObjectSet(Zong_60_st_1E8, OBJPROP_YDISTANCE, 260.0);
         ObjectSet(Zong_60_st_1E8, OBJPROP_XDISTANCE, 10.0);
         ObjectSetText(Zong_60_st_1E8, "Spread: " + DoubleToString((Ask - Bid) / Zong_58_do_1D8, 1) + " pips", 13, "Arial", Zong_59_co_1E0);
        }
      ObjectSetText(Zong_60_st_1E8, "Spread: " + DoubleToString((Ask - Bid) / Zong_58_do_1D8, 1) + " pips", 0, NULL, 0xFFFFFFFF);
      WindowRedraw();
      WindowRedraw();
     }
   PlaySound("Starting.wav");
   StringReplace(EA_StartTime, " ", "");
   StringReplace(EA_StopTime, " ", "");
   StringTrimLeft(EA_StartTime);
   StringTrimLeft(EA_StopTime);
   StringTrimRight(EA_StartTime);
   StringTrimRight(EA_StopTime);
   if(EA_StopTime == "24:00")
     {
      EA_StopTime = "23:59:59" ;
     }
   StringReplace(Limit_StartTime, " ", "");
   StringReplace(Limit_StopTime, " ", "");
   StringTrimLeft(Limit_StartTime);
   StringTrimLeft(Limit_StopTime);
   StringTrimRight(Limit_StartTime);
   StringTrimRight(Limit_StopTime);
   if(Limit_StopTime == "24:00")
     {
      Limit_StopTime = "23:59:59" ;
     }
   EventSetTimer(1);
   Lin_do_1 = 0.0;
   Lin_in_2 = HistoryTotal();
   for(Lin_in_3 = 0 ; Lin_in_3 < Lin_in_2 ; Lin_in_3 = Lin_in_3 + 1)
     {
      if(!(OrderSelect(Lin_in_3, 0, 1)) || OrderType() != 6 || !(OrderProfit() > 0.0))
         continue;
      Lin_do_1 = Lin_do_1 + OrderProfit();
     }
   if(Lin_do_1 == 0.0)
     {
      Lin_do_1 = 100.0;
     }
   Zong_23_do_108 = Lin_do_1 ;
   Print("TotalDeposits=", Zong_23_do_108);
   lizong_20();
   return(0);
  }
//init <<==--------   --------
int start()
  {
   if(UseCheck() == false)
     {
      return 0;
     }
   bool      Zi_2_bo;
   double    Zi_3_do;
   double    Zi_4_do;
   double    Zi_5_do;
   double    Zi_6_do;
   double    Zi_7_do;
   double    Zi_8_do;
   int       Zi_9_in;
   int       Zi_10_in;
   int       Zi_11_in;
   int       Zi_12_in;
   int       Zi_13_in;
   int       Zi_14_in;
   int       Zi_15_in;
   double    Zi_16_do;
   double    Zi_17_do;
   double    Zi_18_do;
   double    Zi_19_do;
   double    Zi_20_do;
   double    Zi_21_do;
   double    Zi_22_do;
   double    Zi_23_do;
   double    Zi_24_do;
   double    Zi_25_do;
   double    Zi_26_do;
   double    Zi_27_do;
   int       Zi_28_in;
   double    Zi_29_do;
   string    Zi_30_st;
   double    Zi_31_do;
   string    Zi_32_st;
   double    Zi_33_do;
   double    Zi_34_do;
   bool      Zi_35_bo;
   double    Zi_36_do;
   double    Zi_37_do;
   double    Zi_38_do;
   double    Zi_39_do;
   double    Zi_40_do;
   datetime  Zi_41_da;
   bool      Zi_42_bo;
   string    Zi_43_st;
   string    Zi_44_st;
   string    Zi_45_st;
   string    Zi_46_st;
   datetime  Zi_47_da;
   bool      Zi_48_bo;
   string    Zi_49_st;
   string    Zi_50_st;
   string    Zi_51_st;
   string    Zi_52_st;
   datetime  Zi_53_da;
   bool      Zi_54_bo;
   string    Zi_55_st;
   string    Zi_56_st;
   string    Zi_57_st;
   string    Zi_58_st;
   int       Zi_59_in;
   double    Zi_60_do;
   int       Zi_61_in;
   double    Zi_62_do;
   int       Zi_63_in;
   string    Zi_64_st;
   string    Zi_65_st;
   int       Zi_66_in;
   double    Zi_67_do;
   int       Zi_68_in;
   double    Zi_69_do;
   string    Zi_70_st;
   string    Zi_71_st;
   int       Zi_72_in;
   double    Zi_73_do;
   int       Zi_74_in;
   double    Zi_75_do;
   int       Zi_76_in;
   string    Zi_77_st;
   string    Zi_78_st;
   int       Zi_79_in;
   double    Zi_80_do;
   int       Zi_81_in;
   double    Zi_82_do;
   string    Zi_83_st;
   int       Zi_84_in;
   int       Zi_85_in;
   string    Zi_86_st;
   int       Zi_87_in;
   int       Zi_88_in;
   string    Zi_89_st;
   int       Zi_90_in;
   int       Zi_91_in;
   string    Zi_92_st;
   int       Zi_93_in;
   int       Zi_94_in;
   string    Zi_95_st;
   string    Zi_96_st;
   int       Zi_97_in;
   double    Zi_98_do;
   int       Zi_99_in;
   double    Zi_100_do;
   int       Zi_101_in;
   string    Zi_102_st;
   string    Zi_103_st;
   int       Zi_104_in;
   double    Zi_105_do;
   int       Zi_106_in;
   double    Zi_107_do;
   string    Zi_108_st;
   string    Zi_109_st;
   int       Zi_110_in;
   double    Zi_111_do;
   int       Zi_112_in;
   double    Zi_113_do;
   int       Zi_114_in;
   string    Zi_115_st;
   string    Zi_116_st;
   int       Zi_117_in;
   double    Zi_118_do;
   int       Zi_119_in;
   double    Zi_120_do;
   string    Zi_121_st;
   string    Zi_122_st;
   int       Zi_123_in;
   double    Zi_124_do;
   int       Zi_125_in;
   double    Zi_126_do;
   int       Zi_127_in;
   string    Zi_128_st;
   string    Zi_129_st;
   int       Zi_130_in;
   double    Zi_131_do;
   int       Zi_132_in;
   double    Zi_133_do;
   string    Zi_134_st;
   string    Zi_135_st;
   int       Zi_136_in;
   double    Zi_137_do;
   int       Zi_138_in;
   double    Zi_139_do;
   int       Zi_140_in;
   string    Zi_141_st;
   string    Zi_142_st;
   int       Zi_143_in;
   double    Zi_144_do;
   int       Zi_145_in;
   double    Zi_146_do;
   int       Zi_147_in;
   int       Zi_148_in;
   int       Zi_149_in;
   double    Zi_150_do;
   double    Zi_151_do;
   int       Zi_152_in;
   int       Zi_153_in;
   int       Zi_154_in;
   int       Zi_155_in;
   double    Zi_156_do;
   double    Zi_157_do;
   int       Zi_158_in;
   datetime  Zi_159_da;
   bool      Zi_160_bo;
   datetime  Zi_161_da;
   bool      Zi_162_bo;
   datetime  Zi_163_da;
   bool      Zi_164_bo;
   datetime  Zi_165_da;
   bool      Zi_166_bo;
   datetime  Zi_167_da;
   bool      Zi_168_bo;
   datetime  Zi_169_da;
   bool      Zi_170_bo;
   int       Zi_171_in;
   int       Zi_172_in;
   datetime  Zi_173_da;
   int       Zi_174_in;
   int       Zi_175_in;
   datetime  Zi_176_da;
   bool      Zi_177_bo;
   datetime  Zi_178_da;
   bool      Zi_179_bo;
   datetime  Zi_180_da;
   bool      Zi_181_bo;
   datetime  Zi_182_da;
   bool      Zi_183_bo;
   datetime  Zi_184_da;
   bool      Zi_185_bo;
   datetime  Zi_186_da;
   bool      Zi_187_bo;
   int       Zi_188_in;
   int       Zi_189_in;
   datetime  Zi_190_da;
   int       Zi_191_in;
   int       Zi_192_in;
   color     Zi_193_co;
   color     Zi_194_co;
   color     Zi_195_co;
//----- -----
   if(!(IsTesting()) && !(lizong_18()))
     {
      Comment(Zong_103_st_368 + Zong_3_st_20);
      ExpertRemove();
      return(0);
     }
   Zi_2_bo = false ;
   Zi_3_do = 0.0 ;
   Zi_4_do = 0.0 ;
   Zi_5_do = 0.0 ;
   Zi_6_do = 0.0 ;
   Zi_7_do = 0.0 ;
   Zi_8_do = 0.0 ;
   Zi_9_in = 0 ;
   Zi_10_in = 0 ;
   Zi_11_in = 0 ;
   Zi_12_in = 0 ;
   Zi_13_in = 0 ;
   Zi_14_in = 0 ;
   Zi_15_in = 0 ;
   Zi_16_do = 0.0 ;
   Zi_17_do = 0.0 ;
   Zi_18_do = 0.0 ;
   Zi_19_do = 0.0 ;
   Zi_20_do = 0.0 ;
   Zi_21_do = 0.0 ;
   Zi_22_do = 0.0 ;
   Zi_23_do = 0.0 ;
   Zi_24_do = 0.0 ;
   Zi_25_do = 0.0 ;
   Zi_26_do = 0.0 ;
   Zi_27_do = 0.0 ;
   Zi_28_in = 0 ;
   Zi_29_do = 0.0 ;
   Zi_31_do = 0.0 ;
   Zi_33_do = 0.0 ;
   Zi_34_do = 0.0 ;
   Zi_35_bo = false ;
   Zi_36_do = 0.0 ;
   Zi_37_do = 0.0 ;
   Zi_38_do = 0.0 ;
   Zi_39_do = 0.0 ;
   Zi_40_do = 0.0 ;
   Zi_41_da = 0 ;
   Zi_42_bo = false ;
   Zi_47_da = 0 ;
   Zi_48_bo = false ;
   Zi_53_da = 0 ;
   Zi_54_bo = false ;
   Zi_59_in = 0 ;
   Zi_60_do = 0.0 ;
   Zi_61_in = 0 ;
   Zi_62_do = 0.0 ;
   Zi_63_in = 0 ;
   Zi_66_in = 0 ;
   Zi_67_do = 0.0 ;
   Zi_68_in = 0 ;
   Zi_69_do = 0.0 ;
   Zi_72_in = 0 ;
   Zi_73_do = 0.0 ;
   Zi_74_in = 0 ;
   Zi_75_do = 0.0 ;
   Zi_76_in = 0 ;
   Zi_79_in = 0 ;
   Zi_80_do = 0.0 ;
   Zi_81_in = 0 ;
   Zi_82_do = 0.0 ;
   Zi_84_in = 0 ;
   Zi_85_in = 0 ;
   Zi_87_in = 0 ;
   Zi_88_in = 0 ;
   Zi_90_in = 0 ;
   Zi_91_in = 0 ;
   Zi_93_in = 0 ;
   Zi_94_in = 0 ;
   Zi_97_in = 0 ;
   Zi_98_do = 0.0 ;
   Zi_99_in = 0 ;
   Zi_100_do = 0.0 ;
   Zi_101_in = 0 ;
   Zi_104_in = 0 ;
   Zi_105_do = 0.0 ;
   Zi_106_in = 0 ;
   Zi_107_do = 0.0 ;
   Zi_110_in = 0 ;
   Zi_111_do = 0.0 ;
   Zi_112_in = 0 ;
   Zi_113_do = 0.0 ;
   Zi_114_in = 0 ;
   Zi_117_in = 0 ;
   Zi_118_do = 0.0 ;
   Zi_119_in = 0 ;
   Zi_120_do = 0.0 ;
   Zi_123_in = 0 ;
   Zi_124_do = 0.0 ;
   Zi_125_in = 0 ;
   Zi_126_do = 0.0 ;
   Zi_127_in = 0 ;
   Zi_130_in = 0 ;
   Zi_131_do = 0.0 ;
   Zi_132_in = 0 ;
   Zi_133_do = 0.0 ;
   Zi_136_in = 0 ;
   Zi_137_do = 0.0 ;
   Zi_138_in = 0 ;
   Zi_139_do = 0.0 ;
   Zi_140_in = 0 ;
   Zi_143_in = 0 ;
   Zi_144_do = 0.0 ;
   Zi_145_in = 0 ;
   Zi_146_do = 0.0 ;
   Zi_147_in = 0 ;
   Zi_148_in = 0 ;
   Zi_149_in = 0 ;
   Zi_150_do = 0.0 ;
   Zi_151_do = 0.0 ;
   Zi_152_in = 0 ;
   Zi_153_in = 0 ;
   Zi_154_in = 0 ;
   Zi_155_in = 0 ;
   Zi_156_do = 0.0 ;
   Zi_157_do = 0.0 ;
   Zi_158_in = 0 ;
   Zi_159_da = 0 ;
   Zi_160_bo = false ;
   Zi_161_da = 0 ;
   Zi_162_bo = false ;
   Zi_163_da = 0 ;
   Zi_164_bo = false ;
   Zi_165_da = 0 ;
   Zi_166_bo = false ;
   Zi_167_da = 0 ;
   Zi_168_bo = false ;
   Zi_169_da = 0 ;
   Zi_170_bo = false ;
   Zi_171_in = 0 ;
   Zi_172_in = 0 ;
   Zi_173_da = 0 ;
   Zi_174_in = 0 ;
   Zi_175_in = 0 ;
   Zi_176_da = 0 ;
   Zi_177_bo = false ;
   Zi_178_da = 0 ;
   Zi_179_bo = false ;
   Zi_180_da = 0 ;
   Zi_181_bo = false ;
   Zi_182_da = 0 ;
   Zi_183_bo = false ;
   Zi_184_da = 0 ;
   Zi_185_bo = false ;
   Zi_186_da = 0 ;
   Zi_187_bo = false ;
   Zi_188_in = 0 ;
   Zi_189_in = 0 ;
   Zi_190_da = 0 ;
   Zi_191_in = 0 ;
   Zi_192_in = 0 ;
   Zi_193_co = 0 ;
   Zi_194_co = 0 ;
   Zi_195_co = 0 ;
   switch(AccountNumber())
     {
      case 5320061 :
         Zi_2_bo = true ;
         break;
      case 200007738 :
         Zi_2_bo = true ;
         break;
      case 10048166 :
         Zi_2_bo = false ;
         break;
      case 7061521 :
         Zi_2_bo = false ;
         break;
      case 12456 :
         Zi_2_bo = false ;
         break;
      default :
         Zi_2_bo = false ;
     }
   if(IsDemo())
     {
      Zi_2_bo = true ;
     }
   if(IsTesting())
     {
      Zi_2_bo = true ;
     }
   Zong_48_in_188 = int(MathMax(MarketInfo(Symbol(), MODE_FREEZELEVEL), MarketInfo(Symbol(), MODE_STOPLEVEL)) + 1.0) ;
   if(Step <  Zong_48_in_188)
     {
      Step = Zong_48_in_188 ;
     }
   if(FirstStep <  Zong_48_in_188)
     {
      FirstStep = Zong_48_in_188 ;
     }
   if(MinDistance <  Zong_48_in_188)
     {
      MinDistance = Zong_48_in_188 ;
     }
   Zi_41_da = 0 ;
   if(IsTesting())
     {
      Zi_41_da = TimeCurrent() ;
     }
   else
     {
      Zi_41_da = TimeLocal() ;
     }
   Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_41_da), ".", TimeMonth(Zi_41_da), ".", TimeDay(Zi_41_da), " ", Limit_StartTime)) ;
   Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_41_da), ".", TimeMonth(Zi_41_da), ".", TimeDay(Zi_41_da), " ", Limit_StopTime)) ;
   if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_41_da < Zong_91_da_2E0 || Zi_41_da >  Zong_94_da_2F8))
     {
      ObjectDelete("HLINE_LONG");
      ObjectDelete("HLINE_SHORT");
      ObjectDelete("HLINE_LONGII");
      ObjectDelete("HLINE_SHORTII");
      Zi_42_bo = false ;
     }
   else
     {
      if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_41_da <  Zong_93_da_2F0 && Zi_41_da >  Zong_94_da_2F8)
        {
         ObjectDelete("HLINE_LONG");
         ObjectDelete("HLINE_SHORT");
         ObjectDelete("HLINE_LONGII");
         ObjectDelete("HLINE_SHORTII");
         Zi_42_bo = false ;
        }
      else
        {
         Zi_42_bo = true ;
        }
     }
   if(Zi_42_bo)
     {
      if(On_top_of_this_price_not_Buy_first_order != 0.0)
        {
         ObjectCreate(0, "HLINE_LONG", OBJ_HLINE, 0, 0, On_top_of_this_price_not_Buy_first_order);
         ObjectSet("HLINE_LONG", OBJPROP_STYLE, 0.0);
         ObjectSet("HLINE_LONG", OBJPROP_COLOR, 10025880.0);
        }
      if(On_under_of_this_price_not_Sell_first_order != 0.0)
        {
         ObjectCreate(0, "HLINE_SHORT", OBJ_HLINE, 0, 0, On_under_of_this_price_not_Sell_first_order);
         ObjectSet("HLINE_SHORT", OBJPROP_STYLE, 0.0);
         ObjectSet("HLINE_SHORT", OBJPROP_COLOR, 16711935.0);
        }
      if(On_top_of_this_price_not_Buy_order != 0.0)
        {
         ObjectCreate(0, "HLINE_LONGII", OBJ_HLINE, 0, 0, On_top_of_this_price_not_Buy_order);
         ObjectSet("HLINE_LONGII", OBJPROP_STYLE, 2.0);
         ObjectSet("HLINE_LONGII", OBJPROP_COLOR, 10025880.0);
        }
      if(On_under_of_this_price_not_Sell_order != 0.0)
        {
         ObjectCreate(0, "HLINE_SHORTII", OBJ_HLINE, 0, 0, On_under_of_this_price_not_Sell_order);
         ObjectSet("HLINE_SHORTII", OBJPROP_STYLE, 2.0);
         ObjectSet("HLINE_SHORTII", OBJPROP_COLOR, 16711935.0);
        }
     }
   Zi_3_do = 0.0 ;
   Zi_4_do = 0.0 ;
   Zi_5_do = 0.0 ;
   Zi_6_do = 0.0 ;
   Zi_7_do = 0.0 ;
   Zi_8_do = 0.0 ;
   Zi_9_in = 0 ;
   Zi_10_in = 0 ;
   Zi_11_in = 0 ;
   Zi_12_in = 0 ;
   Zi_13_in = 0 ;
   Zi_14_in = 0 ;
   Zi_15_in = 0 ;
   Zi_16_do = 0.0 ;
   Zi_17_do = 0.0 ;
   Zi_18_do = 0.0 ;
   Zi_19_do = 0.0 ;
   Zi_20_do = 0.0 ;
   Zi_21_do = 0.0 ;
   Zi_22_do = 0.0 ;
   Zi_23_do = 0.0 ;
   Zi_24_do = 0.0 ;
   Zi_25_do = 0.0 ;
   Zi_26_do = 0.0 ;
   Zi_27_do = 0.0 ;
   Zi_28_in = 0 ;
   Zi_29_do = 0.0 ;
   Zi_31_do = 0.0 ;
   Zi_33_do = 0.0 ;
   Zi_34_do = 0.0 ;
   Zi_35_bo = false ;
   for(Zi_28_in = 0 ; Zi_28_in < OrdersTotal() ; Zi_28_in ++)
     {
      if(!(OrderSelect(Zi_28_in, 0, 0)) || OrderSymbol() != Symbol() || Magic != OrderMagicNumber())
         continue;
      Zi_13_in = OrderType() ;
      Zi_8_do = OrderLots() ;
      Zi_3_do = NormalizeDouble(OrderOpenPrice(), Digits()) ;
      if(Zi_13_in == 4)
        {
         Zi_11_in ++;
         if((Zi_16_do < Zi_3_do || Zi_16_do == 0.0))
           {
            Zi_16_do = Zi_3_do ;
           }
         Zi_14_in = OrderTicket() ;
         Zi_20_do = Zi_3_do ;
        }
      if(Zi_13_in == 5)
        {
         Zi_12_in ++;
         if((Zi_19_do > Zi_3_do || Zi_19_do == 0.0))
           {
            Zi_19_do = Zi_3_do ;
           }
         Zi_15_in = OrderTicket() ;
         Zi_21_do = Zi_3_do ;
        }
      if(Zi_13_in == 0)
        {
         Zi_9_in ++;
         Zi_6_do = Zi_6_do + Zi_8_do ;
         Zi_23_do = Zi_3_do * Zi_8_do + Zi_23_do ;
         if((Zi_16_do < Zi_3_do || Zi_16_do == 0.0))
           {
            Zi_16_do = Zi_3_do ;
           }
         if((Zi_17_do > Zi_3_do || Zi_17_do == 0.0))
           {
            Zi_17_do = Zi_3_do ;
           }
         Zi_5_do = OrderProfit() + OrderSwap() + OrderCommission() + Zi_5_do ;
        }
      if(Zi_13_in != 1)
         continue;
      Zi_10_in ++;
      Zi_7_do = Zi_7_do + Zi_8_do ;
      Zi_22_do = Zi_3_do * Zi_8_do + Zi_22_do ;
      if((Zi_19_do > Zi_3_do || Zi_19_do == 0.0))
        {
         Zi_19_do = Zi_3_do ;
        }
      if((Zi_18_do < Zi_3_do || Zi_18_do == 0.0))
        {
         Zi_18_do = Zi_3_do ;
        }
      Zi_4_do = OrderProfit() + OrderSwap() + OrderCommission() + Zi_4_do ;
     }
   if(Zi_5_do > 0.0)
     {
      ObjectSetInteger(0, Zong_63_st_200, OBJPROP_BGCOLOR, 17919);
     }
   else
     {
      ObjectSetInteger(0, Zong_63_st_200, OBJPROP_BGCOLOR, 6908265);
     }
   if(Zi_4_do > 0.0)
     {
      ObjectSetInteger(0, Zong_64_st_210, OBJPROP_BGCOLOR, 17919);
     }
   else
     {
      ObjectSetInteger(0, Zong_64_st_210, OBJPROP_BGCOLOR, 6908265);
     }
   if(Zi_5_do + Zi_4_do > 0.0)
     {
      ObjectSetInteger(0, Zong_65_st_220, OBJPROP_BGCOLOR, 17919);
     }
   else
     {
      ObjectSetInteger(0, Zong_65_st_220, OBJPROP_BGCOLOR, 6908265);
     }
   if(Zi_6_do > 0.0 && Zi_7_do / Zi_6_do > 3.0 && Zi_7_do - Zi_6_do > 0.2)
     {
      Zong_39_bo_151 = true ;
     }
   else
     {
      Zong_39_bo_151 = false ;
     }
   if(Zi_7_do > 0.0 && Zi_6_do / Zi_7_do > 3.0 && Zi_6_do - Zi_7_do > 0.2)
     {
      Zong_40_bo_152 = true ;
     }
   else
     {
      Zong_40_bo_152 = false ;
     }
   Zi_36_do = 0.0 ;
   Zi_37_do = 0.0 ;
   Zi_38_do = 0.0 ;
   Zi_39_do = 0.0 ;
   Zi_36_do = iHigh(Symbol(), Zong_31_in_12C, 0) - iLow(Symbol(), Zong_31_in_12C, 5) ;
   Zi_38_do = iLow(Symbol(), Zong_31_in_12C, 0) - iHigh(Symbol(), Zong_31_in_12C, 5) ;
   Zi_37_do = int(Zi_36_do / Point()) ;
   Zi_39_do = MathAbs(Zi_38_do / Point());
   if((AccountLeverage() < Leverage || IsTradeAllowed() == false || IsExpertEnabled() == false || IsStopped() || Zi_9_in + Zi_10_in >= Totals || MarketInfo(Symbol(), MODE_SPREAD) > MaxSpread || (Zong_32_in_130 != 0 && Zi_37_do >= Zong_32_in_130) || (Zong_32_in_130 != 0 && Zi_39_do >= Zong_32_in_130)))
     {
      Zong_29_bo_128 = false ;
      Zong_30_bo_129 = false ;
      Zi_43_st = "Arial" ;
      Zi_44_st = "不符合设定环境，EA停止运行！" ;
      if(ObjectFind("Stop") == -1)
        {
         ObjectCreate("Stop", OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet("Stop", OBJPROP_CORNER, Zong_74_in_264);
         ObjectSet("Stop", OBJPROP_XDISTANCE, Zong_75_in_268);
         ObjectSet("Stop", OBJPROP_YDISTANCE, Zong_76_in_26C);
        }
      ObjectSetText("Stop", Zi_44_st, Zong_33_in_134, Zi_43_st, Zong_59_co_1E0);
     }
   else
     {
      Zong_29_bo_128 = true ;
      Zong_30_bo_129 = true ;
      Zi_45_st = "Arial" ;
      Zi_46_st = "" ;
      if(ObjectFind("Stop") == -1)
        {
         ObjectCreate("Stop", OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet("Stop", OBJPROP_CORNER, Zong_74_in_264);
         ObjectSet("Stop", OBJPROP_XDISTANCE, Zong_75_in_268);
         ObjectSet("Stop", OBJPROP_YDISTANCE, Zong_76_in_26C);
        }
      ObjectSetText("Stop", Zi_46_st, Zong_33_in_134, Zi_45_st, Zong_59_co_1E0);
     }
   Zi_47_da = 0 ;
   if(IsTesting())
     {
      Zi_47_da = TimeCurrent() ;
     }
   else
     {
      Zi_47_da = TimeLocal() ;
     }
   Zong_91_da_2E0 = StringToTime(StringConcatenate(TimeYear(Zi_47_da), ".", TimeMonth(Zi_47_da), ".", TimeDay(Zi_47_da), " ", EA_StartTime)) ;
   Zong_92_da_2E8 = StringToTime(StringConcatenate(TimeYear(Zi_47_da), ".", TimeMonth(Zi_47_da), ".", TimeDay(Zi_47_da), " ", EA_StopTime)) ;
   if(Zong_91_da_2E0 <  Zong_92_da_2E8 && (Zi_47_da < Zong_91_da_2E0 || Zi_47_da >  Zong_92_da_2E8))
     {
      Zi_48_bo = false ;
     }
   else
     {
      if(Zong_91_da_2E0 >  Zong_92_da_2E8 && Zi_47_da <  Zong_91_da_2E0 && Zi_47_da >  Zong_92_da_2E8)
        {
         Zi_48_bo = false ;
        }
      else
        {
         Zi_48_bo = true ;
        }
     }
   if(!(Zi_48_bo))
     {
      Zi_49_st = "Arial" ;
      Zi_50_st = "非开仓时间区间，停止开仓！" ;
      if(ObjectFind("Stop") == -1)
        {
         ObjectCreate("Stop", OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet("Stop", OBJPROP_CORNER, Zong_74_in_264);
         ObjectSet("Stop", OBJPROP_XDISTANCE, Zong_75_in_268);
         ObjectSet("Stop", OBJPROP_YDISTANCE, Zong_76_in_26C);
        }
      ObjectSetText("Stop", Zi_50_st, Zong_33_in_134, Zi_49_st, Zong_59_co_1E0);
     }
   if(Zong_78_st_278 != WindowExpertName())
     {
      Zong_29_bo_128 = false ;
      Zong_30_bo_129 = false ;
      Zi_51_st = "Arial" ;
      Zi_52_st = "EA已切换，停止交易! " ;
      if(ObjectFind("Stop") == -1)
        {
         ObjectCreate("Stop", OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet("Stop", OBJPROP_CORNER, Zong_74_in_264);
         ObjectSet("Stop", OBJPROP_XDISTANCE, Zong_75_in_268);
         ObjectSet("Stop", OBJPROP_YDISTANCE, Zong_76_in_26C);
        }
      ObjectSetText("Stop", Zi_52_st, Zong_33_in_134, Zi_51_st, Zong_59_co_1E0);
     }
   if(TimeCurrent() <  Zong_37_da_148)
     {
      Zi_53_da = 0 ;
      if(IsTesting())
        {
         Zi_53_da = TimeCurrent() ;
        }
      else
        {
         Zi_53_da = TimeLocal() ;
        }
      Zong_91_da_2E0 = StringToTime(StringConcatenate(TimeYear(Zi_53_da), ".", TimeMonth(Zi_53_da), ".", TimeDay(Zi_53_da), " ", EA_StartTime)) ;
      Zong_92_da_2E8 = StringToTime(StringConcatenate(TimeYear(Zi_53_da), ".", TimeMonth(Zi_53_da), ".", TimeDay(Zi_53_da), " ", EA_StopTime)) ;
      if(Zong_91_da_2E0 <  Zong_92_da_2E8 && (Zi_53_da < Zong_91_da_2E0 || Zi_53_da >  Zong_92_da_2E8))
        {
         Zi_54_bo = false ;
        }
      else
        {
         if(Zong_91_da_2E0 >  Zong_92_da_2E8 && Zi_53_da <  Zong_91_da_2E0 && Zi_53_da >  Zong_92_da_2E8)
           {
            Zi_54_bo = false ;
           }
         else
           {
            Zi_54_bo = true ;
           }
        }
      if(Zi_54_bo)
        {
         Zong_29_bo_128 = false ;
         Zong_30_bo_129 = false ;
         Zi_55_st = "Arial" ;
         Zi_56_st = "EA停止运行 " + string(NextTime) + "秒! " ;
         if(ObjectFind("Stop") == -1)
           {
            ObjectCreate("Stop", OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet("Stop", OBJPROP_CORNER, Zong_74_in_264);
            ObjectSet("Stop", OBJPROP_XDISTANCE, Zong_75_in_268);
            ObjectSet("Stop", OBJPROP_YDISTANCE, Zong_76_in_26C);
           }
         ObjectSetText("Stop", Zi_56_st, Zong_33_in_134, Zi_55_st, Zong_59_co_1E0);
        }
     }
   if(Over == 1 && Zi_9_in == 0)
     {
      Zong_29_bo_128 = false ;
     }
   if(Over == 1 && Zi_10_in == 0)
     {
      Zong_30_bo_129 = false ;
     }
   ObjectDelete("SLb");
   ObjectDelete("SLs");
   if(Zi_9_in >  0)
     {
      Zi_24_do = NormalizeDouble(Zi_23_do / Zi_6_do, Digits()) ;
      if(ObjectFind("SLb") != -1)
        {
         ObjectMove("SLb", 0, iTime(Symbol(), PERIOD_M1, 5 - 1), Zi_24_do);
         ObjectMove("SLb", 1, iTime(Symbol(), PERIOD_M1, 0), Zi_24_do);
        }
      else
        {
         ObjectCreate("SLb", OBJ_TREND, 0, iTime(Symbol(), PERIOD_M1, 5 - 1), Zi_24_do, iTime(Symbol(), PERIOD_M1, 0), Zi_24_do, 0, 0.0);
         ObjectSet("SLb", OBJPROP_COLOR, clr1);
         ObjectSet("SLb", OBJPROP_STYLE, 0.0);
         ObjectSet("SLb", OBJPROP_WIDTH, 2.0);
         ObjectSet("SLb", OBJPROP_BACK, 0.0);
         ObjectSet("SLb", 1004, 0.0);
        }
     }
   if(Zi_10_in >  0)
     {
      Zi_25_do = NormalizeDouble(Zi_22_do / Zi_7_do, Digits()) ;
      if(ObjectFind("SLs") != -1)
        {
         ObjectMove("SLs", 0, iTime(Symbol(), PERIOD_M1, 5 - 1), Zi_25_do);
         ObjectMove("SLs", 1, iTime(Symbol(), PERIOD_M1, 0), Zi_25_do);
        }
      else
        {
         ObjectCreate("SLs", OBJ_TREND, 0, iTime(Symbol(), PERIOD_M1, 5 - 1), Zi_25_do, iTime(Symbol(), PERIOD_M1, 0), Zi_25_do, 0, 0.0);
         ObjectSet("SLs", OBJPROP_COLOR, clr2);
         ObjectSet("SLs", OBJPROP_STYLE, 0.0);
         ObjectSet("SLs", OBJPROP_WIDTH, 2.0);
         ObjectSet("SLs", OBJPROP_BACK, 0.0);
         ObjectSet("SLs", 1004, 0.0);
        }
     }
   ObjectSetText("Char.op", CharToString(74), Zong_33_in_134 + 2, "Wingdings", Red);
   Zi_40_do = Zi_5_do + Zi_4_do ;
   if(Over == 1 && Zi_40_do >= CloseAll)
     {
      Zong_29_bo_128 = false ;
      Zong_30_bo_129 = false ;
      Zi_57_st = "订单号" ;
      Zi_58_st = "sell" ;
      Zi_59_in = 0 ;
      Zi_60_do = 0.0 ;
      for(Zi_61_in = OrdersTotal() - 1 ; Zi_61_in >= 0 ; Zi_61_in --)
        {
         if(!(OrderSelect(Zi_61_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
            continue;
         if(Zi_58_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_59_in)
           {
            OrderOpenTime();
            OrderOpenPrice();
            Zi_60_do = OrderLots() ;
            Zi_59_in = OrderTicket() ;
           }
         if(Zi_58_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_59_in)
            continue;
         OrderOpenTime();
         OrderOpenPrice();
         Zi_60_do = OrderLots() ;
         Zi_59_in = OrderTicket() ;
        }
      if(Zi_57_st == "订单号")
        {
         Zi_62_do = Zi_59_in ;
        }
      else
        {
         if(Zi_57_st == "手")
           {
            Zi_62_do = Zi_60_do ;
           }
         else
           {
            Zi_62_do = 0.0 ;
           }
        }
      Zi_63_in = (int)Zi_62_do ;
      Zi_64_st = "订单号" ;
      Zi_65_st = "buy" ;
      Zi_66_in = 0 ;
      Zi_67_do = 0.0 ;
      for(Zi_68_in = OrdersTotal() - 1 ; Zi_68_in >= 0 ; Zi_68_in --)
        {
         if(!(OrderSelect(Zi_68_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
            continue;
         if(Zi_65_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_66_in)
           {
            OrderOpenTime();
            OrderOpenPrice();
            Zi_67_do = OrderLots() ;
            Zi_66_in = OrderTicket() ;
           }
         if(Zi_65_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_66_in)
            continue;
         OrderOpenTime();
         OrderOpenPrice();
         Zi_67_do = OrderLots() ;
         Zi_66_in = OrderTicket() ;
        }
      if(Zi_64_st == "订单号")
        {
         Zi_69_do = Zi_66_in ;
        }
      else
        {
         if(Zi_64_st == "手")
           {
            Zi_69_do = Zi_67_do ;
           }
         else
           {
            Zi_69_do = 0.0 ;
           }
        }
      if(OrderCloseBy((int)Zi_69_do, Zi_63_in, 0xFFFFFFFF))
        {
         do
           {
            Zi_70_st = "订单号" ;
            Zi_71_st = "sell" ;
            Zi_72_in = 0 ;
            Zi_73_do = 0.0 ;
            for(Zi_74_in = OrdersTotal() - 1 ; Zi_74_in >= 0 ; Zi_74_in --)
              {
               if(!(OrderSelect(Zi_74_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
                  continue;
               if(Zi_71_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_72_in)
                 {
                  OrderOpenTime();
                  OrderOpenPrice();
                  Zi_73_do = OrderLots() ;
                  Zi_72_in = OrderTicket() ;
                 }
               if(Zi_71_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_72_in)
                  continue;
               OrderOpenTime();
               OrderOpenPrice();
               Zi_73_do = OrderLots() ;
               Zi_72_in = OrderTicket() ;
              }
            if(Zi_70_st == "订单号")
              {
               Zi_75_do = Zi_72_in ;
              }
            else
              {
               if(Zi_70_st == "手")
                 {
                  Zi_75_do = Zi_73_do ;
                 }
               else
                 {
                  Zi_75_do = 0.0 ;
                 }
              }
            Zi_76_in = (int)Zi_75_do ;
            Zi_77_st = "订单号" ;
            Zi_78_st = "buy" ;
            Zi_79_in = 0 ;
            Zi_80_do = 0.0 ;
            for(Zi_81_in = OrdersTotal() - 1 ; Zi_81_in >= 0 ; Zi_81_in --)
              {
               if(!(OrderSelect(Zi_81_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
                  continue;
               if(Zi_78_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_79_in)
                 {
                  OrderOpenTime();
                  OrderOpenPrice();
                  Zi_80_do = OrderLots() ;
                  Zi_79_in = OrderTicket() ;
                 }
               if(Zi_78_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_79_in)
                  continue;
               OrderOpenTime();
               OrderOpenPrice();
               Zi_80_do = OrderLots() ;
               Zi_79_in = OrderTicket() ;
              }
            if(Zi_77_st == "订单号")
              {
               Zi_82_do = Zi_79_in ;
              }
            else
              {
               if(Zi_77_st == "手")
                 {
                  Zi_82_do = Zi_80_do ;
                 }
               else
                 {
                  Zi_82_do = 0.0 ;
                 }
              }
           }
         while(OrderCloseBy((int)Zi_82_do, Zi_76_in, 0xFFFFFFFF));
        }
      lizong_14(0);
      if(ObjectFind(Zong_60_st_1E8) <  0)
        {
         ObjectCreate(Zong_60_st_1E8, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zong_60_st_1E8, OBJPROP_CORNER, 1.0);
         ObjectSet(Zong_60_st_1E8, OBJPROP_YDISTANCE, 260.0);
         ObjectSet(Zong_60_st_1E8, OBJPROP_XDISTANCE, 10.0);
         ObjectSetText(Zong_60_st_1E8, "点差: " + DoubleToString((Ask - Bid) / Zong_58_do_1D8, 1) + " 点", 13, "Arial", Zong_59_co_1E0);
        }
      ObjectSetText(Zong_60_st_1E8, "点差: " + DoubleToString((Ask - Bid) / Zong_58_do_1D8, 1) + " 点", 0, NULL, 0xFFFFFFFF);
      WindowRedraw();
      WindowRedraw();
     }
   if(Over == false)
     {
      if(HomeopathyCloseAll == true)
        {
         Zi_83_st = "buy" ;
         Zi_84_in = 0 ;
         for(Zi_85_in = OrdersTotal() - 1 ; Zi_85_in >= 0 ; Zi_85_in --)
           {
            if(!(OrderSelect(Zi_85_in, 0, 0)) || Symbol() != OrderSymbol() || OrderMagicNumber() != Magic || OrderComment() != "SS")
               continue;
            if(Zi_83_st == "buy" && OrderType() == 0)
              {
               Zi_84_in ++;
              }
            if(Zi_83_st != "sell" || OrderType() != 1)
               continue;
            Zi_84_in ++;
           }
         if(Zi_84_in <  1)
           {
            Zi_86_st = "sell" ;
            Zi_87_in = 0 ;
            for(Zi_88_in = OrdersTotal() - 1 ; Zi_88_in >= 0 ; Zi_88_in --)
              {
               if(!(OrderSelect(Zi_88_in, 0, 0)) || Symbol() != OrderSymbol() || OrderMagicNumber() != Magic || OrderComment() != "SS")
                  continue;
               if(Zi_86_st == "buy" && OrderType() == 0)
                 {
                  Zi_87_in ++;
                 }
               if(Zi_86_st != "sell" || OrderType() != 1)
                  continue;
               Zi_87_in ++;
              }
           }
        }
      if((Zi_87_in < 1 || HomeopathyCloseAll == false) && Zi_5_do > MaxLossCloseAll && Zi_4_do > MaxLossCloseAll)
        {
         ObjectSetText("Char.op", CharToString(251), Zong_33_in_134 + 2, "Wingdings", Silver);
         if(((Profit == true && Zi_5_do > StopProfit * Zi_9_in) || (Profit == false && Zi_5_do > StopProfit)))
           {
            Print("买单盈利 ", Zi_5_do);
            lizong_14(1);
            return(0);
           }
         if(((Profit == true && Zi_4_do > StopProfit * Zi_10_in) || (Profit == false && Zi_4_do > StopProfit)))
           {
            Print("卖单盈利 ", Zi_4_do);
            lizong_14(-1);
            return(0);
           }
        }
      if(HomeopathyCloseAll == true)
        {
         Zi_89_st = "buy" ;
         Zi_90_in = 0 ;
         for(Zi_91_in = OrdersTotal() - 1 ; Zi_91_in >= 0 ; Zi_91_in --)
           {
            if(!(OrderSelect(Zi_91_in, 0, 0)) || Symbol() != OrderSymbol() || OrderMagicNumber() != Magic || OrderComment() != "SS")
               continue;
            if(Zi_89_st == "buy" && OrderType() == 0)
              {
               Zi_90_in ++;
              }
            if(Zi_89_st != "sell" || OrderType() != 1)
               continue;
            Zi_90_in ++;
           }
         Zi_92_st = "sell" ;
         Zi_93_in = 0 ;
         for(Zi_94_in = OrdersTotal() - 1 ; Zi_94_in >= 0 ; Zi_94_in --)
           {
            if(!(OrderSelect(Zi_94_in, 0, 0)) || Symbol() != OrderSymbol() || OrderMagicNumber() != Magic || OrderComment() != "SS")
               continue;
            if(Zi_92_st == "buy" && OrderType() == 0)
              {
               Zi_93_in ++;
              }
            if(Zi_92_st != "sell" || OrderType() != 1)
               continue;
            Zi_93_in ++;
           }
         if((Zi_90_in > 0 || Zi_93_in >  0) && Zi_5_do + Zi_4_do >= CloseAll)
           {
            Zi_95_st = "订单号" ;
            Zi_96_st = "sell" ;
            Zi_97_in = 0 ;
            Zi_98_do = 0.0 ;
            for(Zi_99_in = OrdersTotal() - 1 ; Zi_99_in >= 0 ; Zi_99_in --)
              {
               if(!(OrderSelect(Zi_99_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
                  continue;
               if(Zi_96_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_97_in)
                 {
                  OrderOpenTime();
                  OrderOpenPrice();
                  Zi_98_do = OrderLots() ;
                  Zi_97_in = OrderTicket() ;
                 }
               if(Zi_96_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_97_in)
                  continue;
               OrderOpenTime();
               OrderOpenPrice();
               Zi_98_do = OrderLots() ;
               Zi_97_in = OrderTicket() ;
              }
            if(Zi_95_st == "订单号")
              {
               Zi_100_do = Zi_97_in ;
              }
            else
              {
               if(Zi_95_st == "手")
                 {
                  Zi_100_do = Zi_98_do ;
                 }
               else
                 {
                  Zi_100_do = 0.0 ;
                 }
              }
            Zi_101_in = (int)Zi_100_do ;
            Zi_102_st = "订单号" ;
            Zi_103_st = "buy" ;
            Zi_104_in = 0 ;
            Zi_105_do = 0.0 ;
            for(Zi_106_in = OrdersTotal() - 1 ; Zi_106_in >= 0 ; Zi_106_in --)
              {
               if(!(OrderSelect(Zi_106_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
                  continue;
               if(Zi_103_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_104_in)
                 {
                  OrderOpenTime();
                  OrderOpenPrice();
                  Zi_105_do = OrderLots() ;
                  Zi_104_in = OrderTicket() ;
                 }
               if(Zi_103_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_104_in)
                  continue;
               OrderOpenTime();
               OrderOpenPrice();
               Zi_105_do = OrderLots() ;
               Zi_104_in = OrderTicket() ;
              }
            if(Zi_102_st == "订单号")
              {
               Zi_107_do = Zi_104_in ;
              }
            else
              {
               if(Zi_102_st == "手")
                 {
                  Zi_107_do = Zi_105_do ;
                 }
               else
                 {
                  Zi_107_do = 0.0 ;
                 }
              }
            if(OrderCloseBy((int)Zi_107_do, Zi_101_in, 0xFFFFFFFF))
              {
               do
                 {
                  Zi_108_st = "订单号" ;
                  Zi_109_st = "sell" ;
                  Zi_110_in = 0 ;
                  Zi_111_do = 0.0 ;
                  for(Zi_112_in = OrdersTotal() - 1 ; Zi_112_in >= 0 ; Zi_112_in --)
                    {
                     if(!(OrderSelect(Zi_112_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
                        continue;
                     if(Zi_109_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_110_in)
                       {
                        OrderOpenTime();
                        OrderOpenPrice();
                        Zi_111_do = OrderLots() ;
                        Zi_110_in = OrderTicket() ;
                       }
                     if(Zi_109_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_110_in)
                        continue;
                     OrderOpenTime();
                     OrderOpenPrice();
                     Zi_111_do = OrderLots() ;
                     Zi_110_in = OrderTicket() ;
                    }
                  if(Zi_108_st == "订单号")
                    {
                     Zi_113_do = Zi_110_in ;
                    }
                  else
                    {
                     if(Zi_108_st == "手")
                       {
                        Zi_113_do = Zi_111_do ;
                       }
                     else
                       {
                        Zi_113_do = 0.0 ;
                       }
                    }
                  Zi_114_in = (int)Zi_113_do ;
                  Zi_115_st = "订单号" ;
                  Zi_116_st = "buy" ;
                  Zi_117_in = 0 ;
                  Zi_118_do = 0.0 ;
                  for(Zi_119_in = OrdersTotal() - 1 ; Zi_119_in >= 0 ; Zi_119_in --)
                    {
                     if(!(OrderSelect(Zi_119_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
                        continue;
                     if(Zi_116_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_117_in)
                       {
                        OrderOpenTime();
                        OrderOpenPrice();
                        Zi_118_do = OrderLots() ;
                        Zi_117_in = OrderTicket() ;
                       }
                     if(Zi_116_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_117_in)
                        continue;
                     OrderOpenTime();
                     OrderOpenPrice();
                     Zi_118_do = OrderLots() ;
                     Zi_117_in = OrderTicket() ;
                    }
                  if(Zi_115_st == "订单号")
                    {
                     Zi_120_do = Zi_117_in ;
                    }
                  else
                    {
                     if(Zi_115_st == "手")
                       {
                        Zi_120_do = Zi_118_do ;
                       }
                     else
                       {
                        Zi_120_do = 0.0 ;
                       }
                    }
                 }
               while(OrderCloseBy((int)Zi_120_do, Zi_114_in, 0xFFFFFFFF));
              }
            lizong_14(0);
            if(NextTime >  0)
              {
               Zong_37_da_148 = TimeCurrent() + NextTime;
              }
            return(0);
           }
        }
      if(Zi_5_do + Zi_4_do >= CloseAll && (Zi_5_do <= MaxLossCloseAll || Zi_4_do <= MaxLossCloseAll))
        {
         Zi_121_st = "订单号" ;
         Zi_122_st = "sell" ;
         Zi_123_in = 0 ;
         Zi_124_do = 0.0 ;
         for(Zi_125_in = OrdersTotal() - 1 ; Zi_125_in >= 0 ; Zi_125_in --)
           {
            if(!(OrderSelect(Zi_125_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
               continue;
            if(Zi_122_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_123_in)
              {
               OrderOpenTime();
               OrderOpenPrice();
               Zi_124_do = OrderLots() ;
               Zi_123_in = OrderTicket() ;
              }
            if(Zi_122_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_123_in)
               continue;
            OrderOpenTime();
            OrderOpenPrice();
            Zi_124_do = OrderLots() ;
            Zi_123_in = OrderTicket() ;
           }
         if(Zi_121_st == "订单号")
           {
            Zi_126_do = Zi_123_in ;
           }
         else
           {
            if(Zi_121_st == "手")
              {
               Zi_126_do = Zi_124_do ;
              }
            else
              {
               Zi_126_do = 0.0 ;
              }
           }
         Zi_127_in = (int)Zi_126_do ;
         Zi_128_st = "订单号" ;
         Zi_129_st = "buy" ;
         Zi_130_in = 0 ;
         Zi_131_do = 0.0 ;
         for(Zi_132_in = OrdersTotal() - 1 ; Zi_132_in >= 0 ; Zi_132_in --)
           {
            if(!(OrderSelect(Zi_132_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
               continue;
            if(Zi_129_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_130_in)
              {
               OrderOpenTime();
               OrderOpenPrice();
               Zi_131_do = OrderLots() ;
               Zi_130_in = OrderTicket() ;
              }
            if(Zi_129_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_130_in)
               continue;
            OrderOpenTime();
            OrderOpenPrice();
            Zi_131_do = OrderLots() ;
            Zi_130_in = OrderTicket() ;
           }
         if(Zi_128_st == "订单号")
           {
            Zi_133_do = Zi_130_in ;
           }
         else
           {
            if(Zi_128_st == "手")
              {
               Zi_133_do = Zi_131_do ;
              }
            else
              {
               Zi_133_do = 0.0 ;
              }
           }
         if(OrderCloseBy((int)Zi_133_do, Zi_127_in, 0xFFFFFFFF))
           {
            do
              {
               Zi_134_st = "订单号" ;
               Zi_135_st = "sell" ;
               Zi_136_in = 0 ;
               Zi_137_do = 0.0 ;
               for(Zi_138_in = OrdersTotal() - 1 ; Zi_138_in >= 0 ; Zi_138_in --)
                 {
                  if(!(OrderSelect(Zi_138_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
                     continue;
                  if(Zi_135_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_136_in)
                    {
                     OrderOpenTime();
                     OrderOpenPrice();
                     Zi_137_do = OrderLots() ;
                     Zi_136_in = OrderTicket() ;
                    }
                  if(Zi_135_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_136_in)
                     continue;
                  OrderOpenTime();
                  OrderOpenPrice();
                  Zi_137_do = OrderLots() ;
                  Zi_136_in = OrderTicket() ;
                 }
               if(Zi_134_st == "订单号")
                 {
                  Zi_139_do = Zi_136_in ;
                 }
               else
                 {
                  if(Zi_134_st == "手")
                    {
                     Zi_139_do = Zi_137_do ;
                    }
                  else
                    {
                     Zi_139_do = 0.0 ;
                    }
                 }
               Zi_140_in = (int)Zi_139_do ;
               Zi_141_st = "订单号" ;
               Zi_142_st = "buy" ;
               Zi_143_in = 0 ;
               Zi_144_do = 0.0 ;
               for(Zi_145_in = OrdersTotal() - 1 ; Zi_145_in >= 0 ; Zi_145_in --)
                 {
                  if(!(OrderSelect(Zi_145_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
                     continue;
                  if(Zi_142_st == "buy" && OrderType() == 0 && OrderTicket() >  Zi_143_in)
                    {
                     OrderOpenTime();
                     OrderOpenPrice();
                     Zi_144_do = OrderLots() ;
                     Zi_143_in = OrderTicket() ;
                    }
                  if(Zi_142_st != "sell" || OrderType() != 1 || OrderTicket() <= Zi_143_in)
                     continue;
                  OrderOpenTime();
                  OrderOpenPrice();
                  Zi_144_do = OrderLots() ;
                  Zi_143_in = OrderTicket() ;
                 }
               if(Zi_141_st == "订单号")
                 {
                  Zi_146_do = Zi_143_in ;
                 }
               else
                 {
                  if(Zi_141_st == "手")
                    {
                     Zi_146_do = Zi_144_do ;
                    }
                  else
                    {
                     Zi_146_do = 0.0 ;
                    }
                 }
              }
            while(OrderCloseBy((int)Zi_146_do, Zi_140_in, 0xFFFFFFFF));
           }
         lizong_14(0);
         if(NextTime >  0)
           {
            Zong_37_da_148 = TimeCurrent() + NextTime;
           }
         return(0);
        }
     }
   if(StopLoss != 0.0 && Zi_5_do + Zi_4_do <= StopLoss)
     {
      Print("Buy Loss ", Zi_5_do);
      Print("Sell Loss ", Zi_4_do);
      lizong_14(0);
      if(NextTime >  0)
        {
         Zong_37_da_148 = TimeCurrent() + NextTime;
        }
      return(0);
     }
   if(Zi_5_do <= MaxLoss)
     {
      Comment("Buy");
      ObjectSetText("Char.b", CharToString(225) + CharToString(251), Zong_33_in_134, "Wingdings", Red);
     }
   else
     {
      ObjectSetText("Char.b", CharToString(233), Zong_33_in_134, "Wingdings", Lime);
     }
   if(Zi_4_do <= MaxLoss)
     {
      Comment("Sell");
      ObjectSetText("Char.s", CharToString(226) + CharToString(251), Zong_33_in_134, "Wingdings", Red);
     }
   else
     {
      ObjectSetText("Char.s", CharToString(234), Zong_33_in_134, "Wingdings", Lime);
     }
   if(iOpen(Symbol(), PERIOD_M1, 0) > iOpen(Symbol(), PERIOD_M1, 1))
     {
      Zong_68_in_234 = Zong_66_in_22C ;
     }
   if(iOpen(Symbol(), PERIOD_M1, 0) < iOpen(Symbol(), PERIOD_M1, 1))
     {
      Zong_68_in_234 = Zong_67_in_230 ;
     }
   if(iClose(Symbol(), PERIOD_M1, 0) > iClose(Symbol(), PERIOD_M1, 1))
     {
      Zong_68_in_234 = Zong_70_in_23C ;
     }
   if(iClose(Symbol(), PERIOD_M1, 0) < iClose(Symbol(), PERIOD_M1, 1))
     {
      Zong_68_in_234 = Zong_71_in_240 ;
     }
   Zi_29_do = (Ask - Bid) / Point() ;
   Zi_30_st = Symbol() + ": " + DoubleToString(Zi_29_do, 1) + " 点" ;
   Zi_31_do = AccountLeverage() ;
   Zi_32_st = "杠杆: " + DoubleToString(Zi_31_do, 0) + " 倍" ;
   if(CloseBuySell == 1)
     {
      Zi_33_do = lizong_17(0, Magic, 1, Zong_56_in_1CC) - lizong_17(0, Magic, 2, Zong_57_in_1D0) ;
      if(Zong_51_do_198 < Zi_33_do)
        {
         Zong_51_do_198 = Zi_33_do ;
        }
      if(Zong_51_do_198 > 0.0 && Zi_33_do > 0.0 && Zong_51_do_198 > 0.0)
        {
         Zi_147_in = 1 ;
         Zi_148_in = Magic ;
         Zi_149_in = 0 ;
         Zi_150_do = 0.0 ;
         Zi_151_do = 0.0 ;
         for(Zi_152_in = OrdersTotal() - 1 ; Zi_152_in >= 0 ; Zi_152_in --)
           {
            if(!(OrderSelect(Zi_152_in, 0, 0)) || OrderSymbol() != Symbol())
               continue;
            if((OrderMagicNumber() != Zi_148_in && Zi_148_in != -1))
               continue;
            if((OrderType() != Zi_149_in && Zi_149_in != -100))
               continue;
            if(Zi_147_in == 1 && Zi_151_do < OrderProfit())
              {
               Zi_151_do = OrderProfit() ;
               Zi_150_do = OrderLots() ;
              }
            if(Zi_147_in != 2)
               continue;
            if((!(Zi_151_do > OrderProfit()) && !(Zi_151_do == 0.0)))
               continue;
            Zi_151_do = OrderProfit() ;
            Zi_150_do = OrderLots() ;
           }
         if(Zi_6_do > Zi_150_do * 3.0 + Zi_7_do && Zi_9_in >  3)
           {
            lizong_16(0, Magic, Zong_56_in_1CC, 1);
            lizong_16(0, Magic, Zong_57_in_1D0, 2);
            Zong_51_do_198 = 0.0 ;
            Zong_52_do_1A0 = 0.0 ;
           }
        }
      Zi_33_do = lizong_17(1, Magic, 1, Zong_56_in_1CC) - (lizong_17(1, Magic, 2, Zong_57_in_1D0)) ;
      if(Zong_52_do_1A0 < Zi_33_do)
        {
         Zong_52_do_1A0 = Zi_33_do ;
        }
      if(Zong_52_do_1A0 > 0.0 && Zi_33_do > 0.0 && Zong_52_do_1A0 > 0.0)
        {
         Zi_153_in = 1 ;
         Zi_154_in = Magic ;
         Zi_155_in = 1 ;
         Zi_156_do = 0.0 ;
         Zi_157_do = 0.0 ;
         for(Zi_158_in = OrdersTotal() - 1 ; Zi_158_in >= 0 ; Zi_158_in --)
           {
            if(!(OrderSelect(Zi_158_in, 0, 0)) || OrderSymbol() != Symbol())
               continue;
            if((OrderMagicNumber() != Zi_154_in && Zi_154_in != -1))
               continue;
            if((OrderType() != Zi_155_in && Zi_155_in != -100))
               continue;
            if(Zi_153_in == 1 && Zi_157_do < OrderProfit())
              {
               Zi_157_do = OrderProfit() ;
               Zi_156_do = OrderLots() ;
              }
            if(Zi_153_in != 2)
               continue;
            if((!(Zi_157_do > OrderProfit()) && !(Zi_157_do == 0.0)))
               continue;
            Zi_157_do = OrderProfit() ;
            Zi_156_do = OrderLots() ;
           }
         if(Zi_7_do > Zi_156_do * 3.0 + Zi_6_do && Zi_10_in >  3)
           {
            lizong_16(1, Magic, Zong_56_in_1CC, 1);
            lizong_16(1, Magic, Zong_57_in_1D0, 2);
            Zong_51_do_198 = 0.0 ;
            Zong_52_do_1A0 = 0.0 ;
           }
        }
     }
   if(((Money != 0.0 && Zi_40_do > Money) || Money == 0.0))
     {
      Zi_35_bo = true ;
     }
   if(Money != 0.0 && Zi_40_do <= Money)
     {
      Zi_35_bo = false ;
     }
   if(((OpenMode == 1 && Zong_90_da_2D8 != iTime(NULL, TimeZone, 0)) || OpenMode == 2 || OpenMode == 3))
     {
      if(Zi_11_in == 0 && Zi_5_do > MaxLoss && Zong_29_bo_128)
        {
         if(Zi_9_in == 0)
           {
            Zi_26_do = NormalizeDouble(FirstStep * Point() + Ask, Digits()) ;
           }
         else
           {
            if(Zi_35_bo)
              {
               Zi_26_do = NormalizeDouble(MinDistance * Point() + Ask, Digits()) ;
              }
            if(Zi_35_bo == false && Money != 0.0)
              {
               Zi_26_do = NormalizeDouble(TwoMinDistance * Point() + Ask, Digits()) ;
              }
            if(Zi_26_do < NormalizeDouble(Zi_17_do - Step * Point(), Digits()) && Zi_35_bo)
              {
               Zi_26_do = NormalizeDouble(Step * Point() + Ask, Digits()) ;
              }
            if(Zi_26_do < NormalizeDouble(Zi_17_do - TwoStep * Point(), Digits()) && Zi_35_bo == false && Money != 0.0)
              {
               Zi_26_do = NormalizeDouble(TwoStep * Point() + Ask, Digits()) ;
              }
           }
         if((Zi_9_in == 0 || (Zi_16_do != 0.0 && Zi_26_do >= NormalizeDouble(Step * Point() + Zi_16_do, Digits()) && Zong_39_bo_151 && Zi_35_bo) || (Zi_16_do != 0.0 && Zi_26_do >= NormalizeDouble(TwoStep * Point() + Zi_16_do, Digits()) && Zong_39_bo_151 && Zi_35_bo == false && Money != 0.0) || (Zi_17_do != 0.0 && Zi_26_do <= NormalizeDouble(Zi_17_do - Step * Point(), Digits()) && Zi_35_bo) || (Zi_17_do != 0.0 && Zi_26_do <= NormalizeDouble(Zi_17_do - TwoStep * Point(), Digits()) && Zi_35_bo == false && Money != 0.0) || (Homeopathy && Zi_16_do != 0.0 && Zi_26_do >= NormalizeDouble(Step * Point() + Zi_16_do, Digits()) && Zi_6_do == Zi_7_do)))
           {
            if(Zi_9_in == 0)
              {
               Zi_27_do = lot ;
              }
            else
              {
               Zi_27_do = NormalizeDouble(Zi_9_in * PlusLot + lot * (MathPow(K_Lot, Zi_9_in)), DigitsLot) ;
              }
            if(Zi_27_do > Maxlot)
              {
               Zi_27_do = Maxlot ;
              }
            if(((Zi_27_do * 2.0 < AccountFreeMargin() / MarketInfo(Symbol(), MODE_MARGINREQUIRED) && Zi_9_in > 0) || Zong_38_bo_150))
              {
               Zi_159_da = 0 ;
               if(IsTesting())
                 {
                  Zi_159_da = TimeCurrent() ;
                 }
               else
                 {
                  Zi_159_da = TimeLocal() ;
                 }
               Zong_91_da_2E0 = StringToTime(StringConcatenate(TimeYear(Zi_159_da), ".", TimeMonth(Zi_159_da), ".", TimeDay(Zi_159_da), " ", EA_StartTime)) ;
               Zong_92_da_2E8 = StringToTime(StringConcatenate(TimeYear(Zi_159_da), ".", TimeMonth(Zi_159_da), ".", TimeDay(Zi_159_da), " ", EA_StopTime)) ;
               if(Zong_91_da_2E0 <  Zong_92_da_2E8 && (Zi_159_da < Zong_91_da_2E0 || Zi_159_da >  Zong_92_da_2E8))
                 {
                  Zi_160_bo = false ;
                 }
               else
                 {
                  if(Zong_91_da_2E0 >  Zong_92_da_2E8 && Zi_159_da <  Zong_91_da_2E0 && Zi_159_da >  Zong_92_da_2E8)
                    {
                     Zi_160_bo = false ;
                    }
                  else
                    {
                     Zi_160_bo = true ;
                    }
                 }
               Zi_161_da = 0 ;
               if(Zi_160_bo)
                 {
                  if(IsTesting())
                    {
                     Zi_161_da = TimeCurrent() ;
                    }
                  else
                    {
                     Zi_161_da = TimeLocal() ;
                    }
                  Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_161_da), ".", TimeMonth(Zi_161_da), ".", TimeDay(Zi_161_da), " ", Limit_StartTime)) ;
                  Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_161_da), ".", TimeMonth(Zi_161_da), ".", TimeDay(Zi_161_da), " ", Limit_StopTime)) ;
                  if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_161_da < Zong_91_da_2E0 || Zi_161_da >  Zong_94_da_2F8))
                    {
                     ObjectDelete("HLINE_LONG");
                     ObjectDelete("HLINE_SHORT");
                     ObjectDelete("HLINE_LONGII");
                     ObjectDelete("HLINE_SHORTII");
                     Zi_162_bo = false ;
                    }
                  else
                    {
                     if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_161_da <  Zong_93_da_2F0 && Zi_161_da >  Zong_94_da_2F8)
                       {
                        ObjectDelete("HLINE_LONG");
                        ObjectDelete("HLINE_SHORT");
                        ObjectDelete("HLINE_LONGII");
                        ObjectDelete("HLINE_SHORTII");
                        Zi_162_bo = false ;
                       }
                     else
                       {
                        Zi_162_bo = true ;
                       }
                    }
                  Zi_163_da = 0 ;
                  if(IsTesting())
                    {
                     Zi_163_da = TimeCurrent() ;
                    }
                  else
                    {
                     Zi_163_da = TimeLocal() ;
                    }
                  Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_163_da), ".", TimeMonth(Zi_163_da), ".", TimeDay(Zi_163_da), " ", Limit_StartTime)) ;
                  Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_163_da), ".", TimeMonth(Zi_163_da), ".", TimeDay(Zi_163_da), " ", Limit_StopTime)) ;
                  if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_163_da < Zong_91_da_2E0 || Zi_163_da >  Zong_94_da_2F8))
                    {
                     ObjectDelete("HLINE_LONG");
                     ObjectDelete("HLINE_SHORT");
                     ObjectDelete("HLINE_LONGII");
                     ObjectDelete("HLINE_SHORTII");
                     Zi_164_bo = false ;
                    }
                  else
                    {
                     if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_163_da <  Zong_93_da_2F0 && Zi_163_da >  Zong_94_da_2F8)
                       {
                        ObjectDelete("HLINE_LONG");
                        ObjectDelete("HLINE_SHORT");
                        ObjectDelete("HLINE_LONGII");
                        ObjectDelete("HLINE_SHORTII");
                        Zi_164_bo = false ;
                       }
                     else
                       {
                        Zi_164_bo = true ;
                       }
                    }
                  if(!(Zi_164_bo))
                    {
                     Zi_165_da = 0 ;
                     if(IsTesting())
                       {
                        Zi_165_da = TimeCurrent() ;
                       }
                     else
                       {
                        Zi_165_da = TimeLocal() ;
                       }
                     Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_165_da), ".", TimeMonth(Zi_165_da), ".", TimeDay(Zi_165_da), " ", Limit_StartTime)) ;
                     Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_165_da), ".", TimeMonth(Zi_165_da), ".", TimeDay(Zi_165_da), " ", Limit_StopTime)) ;
                     if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_165_da < Zong_91_da_2E0 || Zi_165_da >  Zong_94_da_2F8))
                       {
                        ObjectDelete("HLINE_LONG");
                        ObjectDelete("HLINE_SHORT");
                        ObjectDelete("HLINE_LONGII");
                        ObjectDelete("HLINE_SHORTII");
                        Zi_166_bo = false ;
                       }
                     else
                       {
                        if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_165_da <  Zong_93_da_2F0 && Zi_165_da >  Zong_94_da_2F8)
                          {
                           ObjectDelete("HLINE_LONG");
                           ObjectDelete("HLINE_SHORT");
                           ObjectDelete("HLINE_LONGII");
                           ObjectDelete("HLINE_SHORTII");
                           Zi_166_bo = false ;
                          }
                        else
                          {
                           Zi_166_bo = true ;
                          }
                       }
                     Zi_167_da = 0 ;
                     if(IsTesting())
                       {
                        Zi_167_da = TimeCurrent() ;
                       }
                     else
                       {
                        Zi_167_da = TimeLocal() ;
                       }
                     Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_167_da), ".", TimeMonth(Zi_167_da), ".", TimeDay(Zi_167_da), " ", Limit_StartTime)) ;
                     Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_167_da), ".", TimeMonth(Zi_167_da), ".", TimeDay(Zi_167_da), " ", Limit_StopTime)) ;
                     if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_167_da < Zong_91_da_2E0 || Zi_167_da >  Zong_94_da_2F8))
                       {
                        ObjectDelete("HLINE_LONG");
                        ObjectDelete("HLINE_SHORT");
                        ObjectDelete("HLINE_LONGII");
                        ObjectDelete("HLINE_SHORTII");
                        Zi_168_bo = false ;
                       }
                     else
                       {
                        if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_167_da <  Zong_93_da_2F0 && Zi_167_da >  Zong_94_da_2F8)
                          {
                           ObjectDelete("HLINE_LONG");
                           ObjectDelete("HLINE_SHORT");
                           ObjectDelete("HLINE_LONGII");
                           ObjectDelete("HLINE_SHORTII");
                           Zi_168_bo = false ;
                          }
                        else
                          {
                           Zi_168_bo = true ;
                          }
                       }
                     Zi_169_da = 0 ;
                     if(IsTesting())
                       {
                        Zi_169_da = TimeCurrent() ;
                       }
                     else
                       {
                        Zi_169_da = TimeLocal() ;
                       }
                     Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_169_da), ".", TimeMonth(Zi_169_da), ".", TimeDay(Zi_169_da), " ", Limit_StartTime)) ;
                     Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_169_da), ".", TimeMonth(Zi_169_da), ".", TimeDay(Zi_169_da), " ", Limit_StopTime)) ;
                     if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_169_da < Zong_91_da_2E0 || Zi_169_da >  Zong_94_da_2F8))
                       {
                        ObjectDelete("HLINE_LONG");
                        ObjectDelete("HLINE_SHORT");
                        ObjectDelete("HLINE_LONGII");
                        ObjectDelete("HLINE_SHORTII");
                        Zi_170_bo = false ;
                       }
                     else
                       {
                        if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_169_da <  Zong_93_da_2F0 && Zi_169_da >  Zong_94_da_2F8)
                          {
                           ObjectDelete("HLINE_LONG");
                           ObjectDelete("HLINE_SHORT");
                           ObjectDelete("HLINE_LONGII");
                           ObjectDelete("HLINE_SHORTII");
                           Zi_170_bo = false ;
                          }
                        else
                          {
                           Zi_170_bo = true ;
                          }
                       }
                    }
                  if((On_top_of_this_price_not_Buy_order == 0.0 || (Zi_168_bo && Zi_9_in >= 1 && Zi_26_do < On_top_of_this_price_not_Buy_order) || Zi_9_in == 0 || !(Zi_170_bo)))
                    {
                     Zi_171_in = 0 ;
                     Zi_172_in = Magic ;
                     Zi_173_da = 0 ;
                     Zi_174_in = 0 ;
                     for(Zi_175_in = OrdersTotal() - 1 ; Zi_175_in >= 0 ; Zi_175_in --)
                       {
                        if(!(OrderSelect(Zi_175_in, 0, 0)) || Symbol() != OrderSymbol() || OrderMagicNumber() != Zi_172_in || OrderTicket() <= Zi_174_in || OrderType() != Zi_171_in)
                           continue;
                        Zi_174_in = OrderTicket() ;
                        Zi_173_da = OrderOpenTime() ;
                       }
                     if(((TimeCurrent() - Zi_173_da >= sleep && OpenMode == 2) || OpenMode == 3 || OpenMode == 1))
                       {
                        if(((Zi_16_do != 0.0 && Zi_26_do >= NormalizeDouble(Step * Point() + Zi_16_do, Digits()) && Zong_39_bo_151 && Zi_35_bo) || (Zi_16_do != 0.0 && Zi_26_do >= NormalizeDouble(TwoStep * Point() + Zi_16_do, Digits()) && Zong_39_bo_151 && Zi_35_bo == false && Money != 0.0) || (Homeopathy && Zi_16_do != 0.0 && Zi_26_do >= NormalizeDouble(Step * Point() + Zi_16_do, Digits()) && Zi_6_do == Zi_7_do)))
                          {
                           Zong_97_in_310 = OrderSend(Symbol(), 4, Zi_27_do, Zi_26_do, Zong_50_in_190, 0.0, 0.0, Com_2, Magic, 0, Blue) ;
                           if(Zong_97_in_310 >  0)
                             {
                              Print(Symbol() + "开单成功，订单编号:" + DoubleToString(Zong_97_in_310, 0));
                             }
                           else
                             {
                              Print(Symbol() + "开单失败" + string(GetLastError()));
                             }
                          }
                        else
                          {
                           Zong_97_in_310 = OrderSend(Symbol(), 4, Zi_27_do, Zi_26_do, Zong_50_in_190, 0.0, 0.0, Com_1, Magic, 0, Blue) ;
                           if(Zong_97_in_310 >  0)
                             {
                              Print(Symbol() + "开单成功，订单编号:" + DoubleToString(Zong_97_in_310, 0));
                             }
                           else
                             {
                              Print(Symbol() + "开单失败" + string(GetLastError()));
                             }
                          }
                       }
                    }
                 }
              }
            else
              {
               Comment("Lot ", DoubleToString(Zi_27_do, 2));
              }
           }
        }
      if(Zi_12_in == 0 && Zi_4_do > MaxLoss && Zong_30_bo_129)
        {
         if(Zi_10_in == 0)
           {
            Zi_26_do = NormalizeDouble(Bid - FirstStep * Point(), Digits()) ;
           }
         else
           {
            if(Zi_35_bo)
              {
               Zi_26_do = NormalizeDouble(Bid - MinDistance * Point(), Digits()) ;
              }
            if(Zi_35_bo == false)
              {
               Zi_26_do = NormalizeDouble(Bid - TwoMinDistance * Point(), Digits()) ;
              }
            if(Zi_26_do < NormalizeDouble(Step * Point() + Zi_18_do, Digits()) && Zi_35_bo)
              {
               Zi_26_do = NormalizeDouble(Bid - Step * Point(), Digits()) ;
              }
            if(Zi_26_do < NormalizeDouble(TwoStep * Point() + Zi_18_do, Digits()) && Zi_35_bo == false && Money != 0.0)
              {
               Zi_26_do = NormalizeDouble(Bid - TwoStep * Point(), Digits()) ;
              }
           }
         if((Zi_10_in == 0 || (Zi_19_do != 0.0 && Zi_26_do <= NormalizeDouble(Zi_19_do - Step * Point(), Digits()) && Zong_40_bo_152 && Zi_35_bo) || (Zi_19_do != 0.0 && Zi_26_do <= NormalizeDouble(Zi_19_do - TwoStep * Point(), Digits()) && Zong_40_bo_152 && Zi_35_bo == false && Money != 0.0) || (Zi_18_do != 0.0 && Zi_26_do >= NormalizeDouble(Step * Point() + Zi_18_do, Digits()) && Zi_35_bo) || (Zi_18_do != 0.0 && Zi_26_do >= NormalizeDouble(TwoStep * Point() + Zi_18_do, Digits()) && Zi_35_bo == false && Money != 0.0) || (Homeopathy && Zi_19_do != 0.0 && Zi_26_do <= NormalizeDouble(Zi_19_do - Step * Point(), Digits()) && Zi_6_do == Zi_7_do)))
           {
            if(Zi_10_in == 0)
              {
               Zi_27_do = lot ;
              }
            else
              {
               Zi_27_do = NormalizeDouble(Zi_10_in * PlusLot + lot * (MathPow(K_Lot, Zi_10_in)), DigitsLot) ;
              }
            if(Zi_27_do > Maxlot)
              {
               Zi_27_do = Maxlot ;
              }
            if(((Zi_27_do * 2.0 < AccountFreeMargin() / MarketInfo(Symbol(), MODE_MARGINREQUIRED) && Zi_10_in > 0) || Zong_38_bo_150))
              {
               Zi_176_da = 0 ;
               if(IsTesting())
                 {
                  Zi_176_da = TimeCurrent() ;
                 }
               else
                 {
                  Zi_176_da = TimeLocal() ;
                 }
               Zong_91_da_2E0 = StringToTime(StringConcatenate(TimeYear(Zi_176_da), ".", TimeMonth(Zi_176_da), ".", TimeDay(Zi_176_da), " ", EA_StartTime)) ;
               Zong_92_da_2E8 = StringToTime(StringConcatenate(TimeYear(Zi_176_da), ".", TimeMonth(Zi_176_da), ".", TimeDay(Zi_176_da), " ", EA_StopTime)) ;
               if(Zong_91_da_2E0 <  Zong_92_da_2E8 && (Zi_176_da < Zong_91_da_2E0 || Zi_176_da >  Zong_92_da_2E8))
                 {
                  Zi_177_bo = false ;
                 }
               else
                 {
                  if(Zong_91_da_2E0 >  Zong_92_da_2E8 && Zi_176_da <  Zong_91_da_2E0 && Zi_176_da >  Zong_92_da_2E8)
                    {
                     Zi_177_bo = false ;
                    }
                  else
                    {
                     Zi_177_bo = true ;
                    }
                 }
               Zi_178_da = 0 ;
               if(Zi_177_bo)
                 {
                  if(IsTesting())
                    {
                     Zi_178_da = TimeCurrent() ;
                    }
                  else
                    {
                     Zi_178_da = TimeLocal() ;
                    }
                  Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_178_da), ".", TimeMonth(Zi_178_da), ".", TimeDay(Zi_178_da), " ", Limit_StartTime)) ;
                  Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_178_da), ".", TimeMonth(Zi_178_da), ".", TimeDay(Zi_178_da), " ", Limit_StopTime)) ;
                  if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_178_da < Zong_91_da_2E0 || Zi_178_da >  Zong_94_da_2F8))
                    {
                     ObjectDelete("HLINE_LONG");
                     ObjectDelete("HLINE_SHORT");
                     ObjectDelete("HLINE_LONGII");
                     ObjectDelete("HLINE_SHORTII");
                     Zi_179_bo = false ;
                    }
                  else
                    {
                     if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_178_da <  Zong_93_da_2F0 && Zi_178_da >  Zong_94_da_2F8)
                       {
                        ObjectDelete("HLINE_LONG");
                        ObjectDelete("HLINE_SHORT");
                        ObjectDelete("HLINE_LONGII");
                        ObjectDelete("HLINE_SHORTII");
                        Zi_179_bo = false ;
                       }
                     else
                       {
                        Zi_179_bo = true ;
                       }
                    }
                  Zi_180_da = 0 ;
                  if(IsTesting())
                    {
                     Zi_180_da = TimeCurrent() ;
                    }
                  else
                    {
                     Zi_180_da = TimeLocal() ;
                    }
                  Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_180_da), ".", TimeMonth(Zi_180_da), ".", TimeDay(Zi_180_da), " ", Limit_StartTime)) ;
                  Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_180_da), ".", TimeMonth(Zi_180_da), ".", TimeDay(Zi_180_da), " ", Limit_StopTime)) ;
                  if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_180_da < Zong_91_da_2E0 || Zi_180_da >  Zong_94_da_2F8))
                    {
                     ObjectDelete("HLINE_LONG");
                     ObjectDelete("HLINE_SHORT");
                     ObjectDelete("HLINE_LONGII");
                     ObjectDelete("HLINE_SHORTII");
                     Zi_181_bo = false ;
                    }
                  else
                    {
                     if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_180_da <  Zong_93_da_2F0 && Zi_180_da >  Zong_94_da_2F8)
                       {
                        ObjectDelete("HLINE_LONG");
                        ObjectDelete("HLINE_SHORT");
                        ObjectDelete("HLINE_LONGII");
                        ObjectDelete("HLINE_SHORTII");
                        Zi_181_bo = false ;
                       }
                     else
                       {
                        Zi_181_bo = true ;
                       }
                    }
                  if(!(Zi_181_bo))
                    {
                     Zi_182_da = 0 ;
                     if(IsTesting())
                       {
                        Zi_182_da = TimeCurrent() ;
                       }
                     else
                       {
                        Zi_182_da = TimeLocal() ;
                       }
                     Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_182_da), ".", TimeMonth(Zi_182_da), ".", TimeDay(Zi_182_da), " ", Limit_StartTime)) ;
                     Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_182_da), ".", TimeMonth(Zi_182_da), ".", TimeDay(Zi_182_da), " ", Limit_StopTime)) ;
                     if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_182_da < Zong_91_da_2E0 || Zi_182_da >  Zong_94_da_2F8))
                       {
                        ObjectDelete("HLINE_LONG");
                        ObjectDelete("HLINE_SHORT");
                        ObjectDelete("HLINE_LONGII");
                        ObjectDelete("HLINE_SHORTII");
                        Zi_183_bo = false ;
                       }
                     else
                       {
                        if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_182_da <  Zong_93_da_2F0 && Zi_182_da >  Zong_94_da_2F8)
                          {
                           ObjectDelete("HLINE_LONG");
                           ObjectDelete("HLINE_SHORT");
                           ObjectDelete("HLINE_LONGII");
                           ObjectDelete("HLINE_SHORTII");
                           Zi_183_bo = false ;
                          }
                        else
                          {
                           Zi_183_bo = true ;
                          }
                       }
                     Zi_184_da = 0 ;
                     if(IsTesting())
                       {
                        Zi_184_da = TimeCurrent() ;
                       }
                     else
                       {
                        Zi_184_da = TimeLocal() ;
                       }
                     Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_184_da), ".", TimeMonth(Zi_184_da), ".", TimeDay(Zi_184_da), " ", Limit_StartTime)) ;
                     Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_184_da), ".", TimeMonth(Zi_184_da), ".", TimeDay(Zi_184_da), " ", Limit_StopTime)) ;
                     if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_184_da < Zong_91_da_2E0 || Zi_184_da >  Zong_94_da_2F8))
                       {
                        ObjectDelete("HLINE_LONG");
                        ObjectDelete("HLINE_SHORT");
                        ObjectDelete("HLINE_LONGII");
                        ObjectDelete("HLINE_SHORTII");
                        Zi_185_bo = false ;
                       }
                     else
                       {
                        if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_184_da <  Zong_93_da_2F0 && Zi_184_da >  Zong_94_da_2F8)
                          {
                           ObjectDelete("HLINE_LONG");
                           ObjectDelete("HLINE_SHORT");
                           ObjectDelete("HLINE_LONGII");
                           ObjectDelete("HLINE_SHORTII");
                           Zi_185_bo = false ;
                          }
                        else
                          {
                           Zi_185_bo = true ;
                          }
                       }
                     Zi_186_da = 0 ;
                     if(IsTesting())
                       {
                        Zi_186_da = TimeCurrent() ;
                       }
                     else
                       {
                        Zi_186_da = TimeLocal() ;
                       }
                     Zong_93_da_2F0 = StringToTime(StringConcatenate(TimeYear(Zi_186_da), ".", TimeMonth(Zi_186_da), ".", TimeDay(Zi_186_da), " ", Limit_StartTime)) ;
                     Zong_94_da_2F8 = StringToTime(StringConcatenate(TimeYear(Zi_186_da), ".", TimeMonth(Zi_186_da), ".", TimeDay(Zi_186_da), " ", Limit_StopTime)) ;
                     if(Zong_93_da_2F0 <  Zong_94_da_2F8 && (Zi_186_da < Zong_91_da_2E0 || Zi_186_da >  Zong_94_da_2F8))
                       {
                        ObjectDelete("HLINE_LONG");
                        ObjectDelete("HLINE_SHORT");
                        ObjectDelete("HLINE_LONGII");
                        ObjectDelete("HLINE_SHORTII");
                        Zi_187_bo = false ;
                       }
                     else
                       {
                        if(Zong_93_da_2F0 >  Zong_94_da_2F8 && Zi_186_da <  Zong_93_da_2F0 && Zi_186_da >  Zong_94_da_2F8)
                          {
                           ObjectDelete("HLINE_LONG");
                           ObjectDelete("HLINE_SHORT");
                           ObjectDelete("HLINE_LONGII");
                           ObjectDelete("HLINE_SHORTII");
                           Zi_187_bo = false ;
                          }
                        else
                          {
                           Zi_187_bo = true ;
                          }
                       }
                    }
                  if((On_under_of_this_price_not_Sell_order == 0.0 || (Zi_185_bo && Zi_10_in >= 1 && Zi_26_do > On_under_of_this_price_not_Sell_order) || Zi_10_in == 0 || !(Zi_187_bo)))
                    {
                     Zi_188_in = 1 ;
                     Zi_189_in = Magic ;
                     Zi_190_da = 0 ;
                     Zi_191_in = 0 ;
                     for(Zi_192_in = OrdersTotal() - 1 ; Zi_192_in >= 0 ; Zi_192_in --)
                       {
                        if(!(OrderSelect(Zi_192_in, 0, 0)) || Symbol() != OrderSymbol() || OrderMagicNumber() != Zi_189_in || OrderTicket() <= Zi_191_in || OrderType() != Zi_188_in)
                           continue;
                        Zi_191_in = OrderTicket() ;
                        Zi_190_da = OrderOpenTime() ;
                       }
                     if(((TimeCurrent() - Zi_190_da >= sleep && OpenMode == 2) || OpenMode == 3 || OpenMode == 1))
                       {
                        if(((Zi_19_do != 0.0 && Zi_26_do <= NormalizeDouble(Zi_19_do - Step * Point(), Digits()) && Zong_40_bo_152 && Zi_35_bo) || (Zi_19_do != 0.0 && Zi_26_do <= NormalizeDouble(Zi_19_do - TwoStep * Point(), Digits()) && Zong_40_bo_152 && Zi_35_bo == false && Money != 0.0) || (Homeopathy && Zi_19_do != 0.0 && Zi_26_do <= NormalizeDouble(Zi_19_do - Step * Point(), Digits()) && Zi_6_do == Zi_7_do)))
                          {
                           Zong_97_in_310 = OrderSend(Symbol(), 5, Zi_27_do, Zi_26_do, Zong_50_in_190, 0.0, 0.0, Com_2, Magic, 0, Red) ;
                           if(Zong_97_in_310 >  0)
                             {
                              Print(Symbol() + "开单成功，订单编号:" + DoubleToString(Zong_97_in_310, 0));
                             }
                           else
                             {
                              Print(Symbol() + "开单失败" + string(GetLastError()));
                             }
                          }
                        else
                          {
                           Zong_97_in_310 = OrderSend(Symbol(), 5, Zi_27_do, Zi_26_do, Zong_50_in_190, 0.0, 0.0, Com_1, Magic, 0, Red) ;
                           if(Zong_97_in_310 >  0)
                             {
                              Print(Symbol() + "开单成功，订单编号:" + DoubleToString(Zong_97_in_310, 0));
                             }
                           else
                             {
                              Print(Symbol() + "开单失败" + string(GetLastError()));
                             }
                          }
                       }
                    }
                 }
              }
            else
              {
               Comment("Lot ", DoubleToString(Zi_27_do, 2));
              }
           }
        }
      Zong_90_da_2D8 = iTime(NULL, TimeZone, 0) ;
     }
   Zi_34_do = Zi_5_do + Zi_4_do ;
   if(Zi_6_do > 0.0)
     {
      if(Zi_5_do > 0.0)
        {
         Zi_193_co = 255 ;
        }
      else
        {
         Zi_193_co = 65280 ;
        }
      ObjectSetText("ProfitB", StringConcatenate("Buy ", Zi_9_in, "单 , ", DoubleToString(Zi_6_do, 2), "手,  盈亏= ", DoubleToString(Zi_5_do, 2)), Zong_33_in_134, "Arial", Zi_193_co);
     }
   else
     {
      ObjectSetText("ProfitB", "", Zong_33_in_134, "Arial", Gray);
     }
   if(Zi_7_do > 0.0)
     {
      if(Zi_4_do > 0.0)
        {
         Zi_194_co = 255 ;
        }
      else
        {
         Zi_194_co = 65280 ;
        }
      ObjectSetText("ProfitS", StringConcatenate("Sell ", Zi_10_in, "单 , ", DoubleToString(Zi_7_do, 2), "手,  盈亏= ", DoubleToString(Zi_4_do, 2)), Zong_33_in_134, "Arial", Zi_194_co);
     }
   else
     {
      ObjectSetText("ProfitS", "", Zong_33_in_134, "Arial", Gray);
     }
   if(Zi_7_do + Zi_6_do > 0.0)
     {
      if(Zi_34_do > 0.0)
        {
         Zi_195_co = 255 ;
        }
      else
        {
         Zi_195_co = 65280 ;
        }
      ObjectSetText("Profit", StringConcatenate("总盈亏= ", DoubleToString(Zi_34_do, 2)), Zong_33_in_134, "Arial", Zi_195_co);
     }
   else
     {
      ObjectSetText("Profit", "", Zong_33_in_134, "Arial", White);
     }
   if(Zi_20_do != 0.0 && Zong_29_bo_128)
     {
      if(Zi_9_in == 0)
        {
         Zi_26_do = NormalizeDouble(FirstStep * Point() + Ask, Digits()) ;
        }
      if(Zi_35_bo && Zi_9_in >  0)
        {
         Zi_26_do = NormalizeDouble(MinDistance * Point() + Ask, Digits()) ;
        }
      if(Zi_35_bo == false && Zi_9_in >  0 && Money != 0.0)
        {
         Zi_26_do = NormalizeDouble(TwoMinDistance * Point() + Ask, Digits()) ;
        }
      if(NormalizeDouble(Zi_20_do - StepTrallOrders * Point(), Digits()) > Zi_26_do && (((Zi_26_do <= NormalizeDouble(Zi_17_do - Step * Point(), Digits()) || Zi_17_do == 0.0 || (Zong_39_bo_151 && Zi_9_in == 0) || Zi_26_do >= NormalizeDouble(Step * Point() + Zi_16_do, Digits()) || Zi_26_do <= NormalizeDouble(Zi_17_do - Step * Point(), Digits())) && Zi_35_bo) || ((Zi_26_do <= NormalizeDouble(Zi_17_do - TwoStep * Point(), Digits()) || Zi_17_do == 0.0 || (Zong_39_bo_151 && Zi_9_in == 0) || Zi_26_do >= NormalizeDouble(TwoStep * Point() + Zi_16_do, Digits()) || Zi_26_do <= NormalizeDouble(Zi_17_do - TwoStep * Point(), Digits())) && Zi_35_bo == false && Money != 0.0)))
        {
         if(!(OrderModify(Zi_14_in, Zi_26_do, 0.0, 0.0, 0, White)))
           {
            Print("Error ", GetLastError(), "   Order Modify Buy   OOP ", Zi_20_do, "->", Zi_26_do);
           }
         else
           {
            Print("Order Buy Modify   OOP ", Zi_3_do, "->", Zi_26_do);
           }
        }
     }
   if(Zi_21_do != 0.0 && Zong_30_bo_129)
     {
      if(Zi_10_in == 0)
        {
         Zi_26_do = NormalizeDouble(Bid - FirstStep * Point(), Digits()) ;
        }
      if(Zi_35_bo && Zi_10_in >  0)
        {
         Zi_26_do = NormalizeDouble(Bid - MinDistance * Point(), Digits()) ;
        }
      if(Zi_35_bo == false && Zi_10_in >  0 && Money != 0.0)
        {
         Zi_26_do = NormalizeDouble(Bid - TwoMinDistance * Point(), Digits()) ;
        }
      if(NormalizeDouble(StepTrallOrders * Point() + Zi_21_do, Digits()) < Zi_26_do && (((Zi_26_do >= NormalizeDouble(Step * Point() + Zi_18_do, Digits()) || Zi_18_do == 0.0 || (Zong_40_bo_152 && Zi_10_in == 0) || Zi_26_do <= NormalizeDouble(Zi_19_do - Step * Point(), Digits()) || Zi_26_do >= NormalizeDouble(Step * Point() + Zi_18_do, Digits())) && Zi_35_bo) || ((Zi_26_do >= NormalizeDouble(TwoStep * Point() + Zi_18_do, Digits()) || Zi_18_do == 0.0 || (Zong_40_bo_152 && Zi_10_in == 0) || Zi_26_do <= NormalizeDouble(Zi_19_do - TwoStep * Point(), Digits()) || Zi_26_do >= NormalizeDouble(TwoStep * Point() + Zi_18_do, Digits())) && Zi_35_bo == false && Money != 0.0)))
        {
         if(!(OrderModify(Zi_15_in, Zi_26_do, 0.0, 0.0, 0, White)))
           {
            Print("Error ", GetLastError(), "   Order Modify Sell   OOP ", Zi_21_do, "->", Zi_26_do);
           }
         else
           {
            Print("Order Sell Modify   OOP ", Zi_3_do, "->", Zi_26_do);
           }
        }
     }
   lizong_20();
   return(0);
  }
//start <<==--------   --------
void OnTimer()
  {
   if(!(IsTesting()) && !(lizong_18()))
     {
      Comment(Zong_103_st_368 + Zong_3_st_20);
      ExpertRemove();
     }
   lizong_20();
   if(Zong_16_bo_CD != true)
      return;
   lizong_12();
  }
//OnTimer <<==--------   --------
void OnChartEvent(const int Mu_0_in, const long & Mu_1_lo, const double & Mu_2_do, const string & Mu_3_st)
  {
   string     Lin_st_1;
   string     Lin_st_2;
   int        Lin_in_3;
   string     Lin_st_4;
   string     Lin_st_5;
   int        Lin_in_6;
   int        Lin_in_7;
   string     Lin_st_8;
   int        Lin_in_9;
   string     Lin_st_10;
   int        Lin_in_11;
   string     Lin_st_12;
   int        Lin_in_13;
   string     Lin_st_14;
   int        Lin_in_15;
   if(Mu_0_in == 1)
     {
      if((Mu_3_st == "tubiao2" || Mu_3_st == "tubiao1"))
        {
         if(Zong_15_bo_CC == true)
           {
            Zong_15_bo_CC = false ;
            ObjectDelete(0, "tubiao1");
           }
         else
           {
            Zong_15_bo_CC = true ;
            ObjectDelete(0, "tubiao2");
           }
         Lin_st_1 = Zong_17_st_D0;
         for(Lin_in_3 = ObjectsTotal(0, -1, -1) - 1 ; Lin_in_3 >= 0 ; Lin_in_3 = Lin_in_3 - 1)
           {
            Lin_st_2 = ObjectName(0, Lin_in_3, -1, -1);
            if(StringFind(Lin_st_2, Lin_st_1, 0) >= 0)
              {
               ObjectDelete(0, Lin_st_2);
              }
           }
         Lin_st_4 = Zong_18_st_E0;
         for(Lin_in_6 = ObjectsTotal(0, -1, -1) - 1 ; Lin_in_6 >= 0 ; Lin_in_6 = Lin_in_6 - 1)
           {
            Lin_st_5 = ObjectName(0, Lin_in_6, -1, -1);
            if(StringFind(Lin_st_5, Lin_st_4, 0) >= 0)
              {
               ObjectDelete(0, Lin_st_5);
              }
           }
         if(!(IsTesting()) && !(lizong_18()))
           {
            Comment(Zong_103_st_368 + Zong_3_st_20);
            ExpertRemove();
           }
         lizong_20();
         if(Zong_16_bo_CD == true)
           {
            lizong_12();
           }
        }
      else
        {
         if(Mu_3_st == Zong_17_st_D0 + "OpenBoard")
           {
            ObjectSetInteger(0, Zong_17_st_D0 + "OpenBoard", OBJPROP_STATE, 0);
            if(Zong_16_bo_CD)
              {
               for(Lin_in_7 = ObjectsTotal(0, -1, -1) - 1 ; Lin_in_7 >= 0 ; Lin_in_7 = Lin_in_7 - 1)
                 {
                  if(StringFind(ObjectName(0, Lin_in_7, -1, -1), Zong_18_st_E0, 0) >= 0)
                    {
                     ObjectDelete(0, ObjectName(0, Lin_in_7, -1, -1));
                    }
                 }
              }
            else
              {
               lizong_12();
              }
            Zong_16_bo_CD = !(Zong_16_bo_CD);
            ChartRedraw(0);
           }
        }
     }
   if(ObjectGetInteger(0, Zong_18_st_E0 + "StopAll", OBJPROP_STATE, 0) == 1)
     {
      Zong_25_bo_114 = false ;
      Zong_26_bo_115 = false ;
      if(!(IsTesting()) && !(lizong_18()))
        {
         Comment(Zong_103_st_368 + Zong_3_st_20);
         ExpertRemove();
        }
      lizong_20();
      if(Zong_16_bo_CD == true)
        {
         lizong_12();
        }
     }
   else
     {
      if(ObjectGetInteger(0, Zong_18_st_E0 + "StopBuy", OBJPROP_STATE, 0) == 1)
        {
         Zong_25_bo_114 = false ;
         if(!(IsTesting()) && !(lizong_18()))
           {
            Comment(Zong_103_st_368 + Zong_3_st_20);
            ExpertRemove();
           }
         lizong_20();
         if(Zong_16_bo_CD == true)
           {
            lizong_12();
           }
        }
      else
        {
         Zong_25_bo_114 = true ;
         if(!(IsTesting()) && !(lizong_18()))
           {
            Comment(Zong_103_st_368 + Zong_3_st_20);
            ExpertRemove();
           }
         lizong_20();
         if(Zong_16_bo_CD == true)
           {
            lizong_12();
           }
        }
      if(ObjectGetInteger(0, Zong_18_st_E0 + "StopSell", OBJPROP_STATE, 0) == 1)
        {
         Zong_26_bo_115 = false ;
         if(!(IsTesting()) && !(lizong_18()))
           {
            Comment(Zong_103_st_368 + Zong_3_st_20);
            ExpertRemove();
           }
         lizong_20();
         if(Zong_16_bo_CD == true)
           {
            lizong_12();
           }
        }
      else
        {
         Zong_26_bo_115 = true ;
         if(!(IsTesting()) && !(lizong_18()))
           {
            Comment(Zong_103_st_368 + Zong_3_st_20);
            ExpertRemove();
           }
         lizong_20();
         if(Zong_16_bo_CD == true)
           {
            lizong_12();
           }
        }
     }
   if(ObjectGetInteger(0, Zong_18_st_E0 + "CloseAll", OBJPROP_STATE, 0) == 1)
     {
      lizong_13(0);
      ObjectSetInteger(0, Zong_18_st_E0 + "CloseAll", OBJPROP_STATE, 0);
     }
   if(ObjectGetInteger(0, Zong_18_st_E0 + "CloseBuy", OBJPROP_STATE, 0) == 1)
     {
      lizong_13(1);
      ObjectSetInteger(0, Zong_18_st_E0 + "CloseBuy", OBJPROP_STATE, 0);
     }
   if(ObjectGetInteger(0, Zong_18_st_E0 + "CloseSell", OBJPROP_STATE, 0) == 1)
     {
      lizong_13(-1);
      ObjectSetInteger(0, Zong_18_st_E0 + "CloseSell", OBJPROP_STATE, 0);
     }
   if(ObjectGetInteger(0, Zong_18_st_E0 + "CloseProfit", OBJPROP_STATE, 0) == 1)
     {
      Lin_st_8 = "盈利";
      for(Lin_in_9 = OrdersTotal() - 1 ; Lin_in_9 >= 0 ; Lin_in_9 = Lin_in_9 - 1)
        {
         if(!(OrderSelect(Lin_in_9, 0, 0)))
            continue;
         if(((string(Magic) == "" || OrderMagicNumber() != Magic) && string(Magic) != ""))
            continue;
         if(Lin_st_8 == "盈利" && OrderProfit() + OrderSwap() >= 0.0)
           {
            if(OrderType() == 0)
              {
               bool res = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits), Zong_27_in_118, Blue);
               continue;
              }
            if(OrderType() != 1)
               continue;
            bool res = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits), Zong_27_in_118, Red);
            continue;
           }
         if(Lin_st_8 != "亏损" || !(OrderProfit() + OrderSwap() < 0.0))
            continue;
         if(OrderType() == 0)
           {
            bool res = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits), Zong_27_in_118, Blue);
            continue;
           }
         if(OrderType() != 1)
            continue;
         bool res = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits), Zong_27_in_118, Red);
        }
      ObjectSetInteger(0, Zong_18_st_E0 + "CloseProfit", OBJPROP_STATE, 0);
     }
   if(ObjectGetInteger(0, Zong_18_st_E0 + "CloseLoss", OBJPROP_STATE, 0) == 1)
     {
      Lin_st_10 = "亏损";
      for(Lin_in_11 = OrdersTotal() - 1 ; Lin_in_11 >= 0 ; Lin_in_11 = Lin_in_11 - 1)
        {
         if(!(OrderSelect(Lin_in_11, 0, 0)))
            continue;
         if(((string(Magic) == "" || OrderMagicNumber() != Magic) && string(Magic) != ""))
            continue;
         if(Lin_st_10 == "盈利" && OrderProfit() + OrderSwap() >= 0.0)
           {
            if(OrderType() == 0)
              {
               bool res = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits), Zong_27_in_118, Blue);
               continue;
              }
            if(OrderType() != 1)
               continue;
            bool res = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits), Zong_27_in_118, Red);
            continue;
           }
         if(Lin_st_10 != "亏损" || !(OrderProfit() + OrderSwap() < 0.0))
            continue;
         if(OrderType() == 0)
           {
            bool res = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits), Zong_27_in_118, Blue);
            continue;
           }
         if(OrderType() != 1)
            continue;
         bool res = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits), Zong_27_in_118, Red);
        }
      ObjectSetInteger(0, Zong_18_st_E0 + "CloseLoss", OBJPROP_STATE, 0);
     }
   if(ObjectGetInteger(0, Zong_18_st_E0 + "CloseSymbol", OBJPROP_STATE, 0) == 1)
     {
      Lin_st_12 = Symbol();
      for(Lin_in_13 = OrdersTotal() - 1 ; Lin_in_13 >= 0 ; Lin_in_13 = Lin_in_13 - 1)
        {
         if(!(OrderSelect(Lin_in_13, 0, 0)))
            continue;
         if((Lin_st_12 != "all" && OrderSymbol() != Lin_st_12))
            continue;
         if(OrderType() == 0)
           {
            bool res = OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), Zong_27_in_118, Blue);
            continue;
           }
         if(OrderType() != 1)
            continue;
         bool res = OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), Zong_27_in_118, Red);
        }
      ObjectSetInteger(0, Zong_18_st_E0 + "CloseSymbol", OBJPROP_STATE, 0);
     }
   if(ObjectGetInteger(0, Zong_18_st_E0 + "CloseAccountAll", OBJPROP_STATE, 0) != 1)
      return;
   Lin_st_14 = "all";
   for(Lin_in_15 = OrdersTotal() - 1 ; Lin_in_15 >= 0 ; Lin_in_15 = Lin_in_15 - 1)
     {
      if(!(OrderSelect(Lin_in_15, 0, 0)))
         continue;
      if((Lin_st_14 != "all" && OrderSymbol() != Lin_st_14))
         continue;
      if(OrderType() == 0)
        {
         bool res = OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), Zong_27_in_118, Blue);
         continue;
        }
      if(OrderType() != 1)
         continue;
      bool res = OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), Zong_27_in_118, Red);
     }
   ObjectSetInteger(0, Zong_18_st_E0 + "CloseAccountAll", OBJPROP_STATE, 0);
  }
//OnChartEvent <<==--------   --------
int deinit()
  {
   ObjectDelete("HLINE_LONGII");
   ObjectDelete("HLINE_SHORTII");
   ObjectDelete("HLINE_LONG");
   ObjectDelete("HLINE_SHORT");
   ObjectsDeleteAll(0, -1);
   return(0);
  }
//deinit <<==--------   --------
void lizong_12()
  {
   int       Zi_1_in;
   int       Zi_2_in;
   int       Zi_3_in;
//----- -----
   uint       Lin_ui_1;
   long       Lin_lo_2;
   Zi_1_in = Zong_24_in_110 ;
   Zi_2_in = 3 ;
   Zi_3_in = 30 ;
   Lin_ui_1 = PowderBlue;
   Lin_lo_2 = 0;
   if(ObjectFind(0, Zong_18_st_E0 + "Panel") <  0)
     {
      ObjectCreate(0, Zong_18_st_E0 + "Panel", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_XDISTANCE, 308);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_YDISTANCE, Zong_24_in_110);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_XSIZE, 300);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_YSIZE, 205);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_BORDER_TYPE, 0);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_CORNER, 1);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_COLOR, 15453831);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_STYLE, 0);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_BACK, 0);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_SELECTABLE, 0);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_SELECTED, 0);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_HIDDEN, 1);
      ObjectSetInteger(0, Zong_18_st_E0 + "Panel", OBJPROP_ZORDER, 0);
     }
   ObjectSetInteger(Lin_lo_2, Zong_18_st_E0 + "Panel", OBJPROP_BGCOLOR, Lin_ui_1);
   Zi_1_in += Zi_2_in;
   lizong_22(Zong_18_st_E0 + "StopAll", "停止交易", "开启交易", 298, Zi_1_in, 280, Zi_3_in, Zong_22_in_104, White, White, Brown, SteelBlue, Zong_21_st_F8, Zong_19_in_EC);
   Zi_1_in = Zi_1_in + Zi_2_in + Zi_3_in;
   lizong_22(Zong_18_st_E0 + "StopBuy", "停止做多", "开启做多", 298, Zi_1_in, 135, Zi_3_in, Zong_22_in_104, White, White, Brown, SteelBlue, Zong_21_st_F8, Zong_19_in_EC);
   lizong_22(Zong_18_st_E0 + "StopSell", "停止做空", "开启做空", 154, Zi_1_in, 135, Zi_3_in, Zong_22_in_104, White, White, Brown, SteelBlue, Zong_21_st_F8, Zong_19_in_EC);
   Zi_1_in = Zi_1_in + Zi_2_in + Zi_3_in;
   lizong_22(Zong_18_st_E0 + "CloseProfit", "获利单平仓", "获利单平仓中", 298, Zi_1_in, 135, Zi_3_in, Zong_22_in_104, White, White, Teal, Teal, Zong_21_st_F8, Zong_19_in_EC);
   lizong_22(Zong_18_st_E0 + "CloseLoss", "亏损单平仓", "亏损单平仓中", 154, Zi_1_in, 135, Zi_3_in, Zong_22_in_104, White, White, Teal, Teal, Zong_21_st_F8, Zong_19_in_EC);
   Zi_1_in = Zi_1_in + Zi_2_in + Zi_3_in;
   lizong_22(Zong_18_st_E0 + "CloseBuy", "多单平仓", "多单平仓中", 298, Zi_1_in, 135, Zi_3_in, Zong_22_in_104, White, White, Teal, Teal, Zong_21_st_F8, Zong_19_in_EC);
   lizong_22(Zong_18_st_E0 + "CloseSell", "空单平仓", "空单平仓中", 154, Zi_1_in, 135, Zi_3_in, Zong_22_in_104, White, White, Teal, Teal, Zong_21_st_F8, Zong_19_in_EC);
   Zi_1_in = Zi_1_in + Zi_2_in + Zi_3_in;
   lizong_22(Zong_18_st_E0 + "CloseSymbol", Symbol() + "全部平仓", Symbol() + "全部平仓中", 298, Zi_1_in, 135, Zi_3_in, Zong_22_in_104, White, White, Teal, Teal, Zong_21_st_F8, Zong_19_in_EC);
   lizong_22(Zong_18_st_E0 + "CloseAll", "EA全部平仓", "EA全部平仓中", 154, Zi_1_in, 135, Zi_3_in, Zong_22_in_104, White, White, Teal, Teal, Zong_21_st_F8, Zong_19_in_EC);
   Zi_1_in = Zi_1_in + Zi_2_in + Zi_3_in;
   lizong_22(Zong_18_st_E0 + "CloseAccountAll", "账号全部平仓", "账号全部平仓中", 298, Zi_1_in, 280, Zi_3_in, Zong_22_in_104, White, White, SeaGreen, DodgerBlue, Zong_21_st_F8, Zong_19_in_EC);
  }
//lizong_12 <<==--------   --------
int lizong_13(int Mu_0_in)
  {
   int       Zi_2_in = 0;
   int       Zi_3_in = 0;
   int       Zi_4_in;
   int       Zi_5_in;
   bool      Zi_6_bo;
   int       Zi_7_in;
   int       Zi_8_in;
//----- -----
   Zi_4_in = 0 ;
   Zi_5_in = 0 ;
   Zi_6_bo = false ;
   for(; ;)
     {
      for(Zi_7_in = OrdersTotal() - 1 ; Zi_7_in >= 0 ; Zi_7_in --)
        {
         if(!(OrderSelect(Zi_7_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
            continue;
         Zi_4_in = OrderType() ;
         if(Zi_4_in == 0 && (Mu_0_in == 1 || Mu_0_in == 0))
           {
            Zi_6_bo = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits()), int(Zong_27_in_118 * Zong_28_do_120), 0xFFFFFFFF) ;
            if(Zi_6_bo)
              {
               Comment("", OrderTicket(), "", OrderProfit(), "     ", TimeToString(TimeCurrent(), 4));
              }
           }
         if(Zi_4_in == 1 && (Mu_0_in == -1 || Mu_0_in == 0))
           {
            Zi_6_bo = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits()), int(Zong_27_in_118 * Zong_28_do_120), 0xFFFFFFFF) ;
            if(Zi_6_bo)
              {
               Comment("", OrderTicket(), "", OrderProfit(), "     ", TimeToString(TimeCurrent(), 4));
              }
           }
         if((Zi_4_in == 4 || Zi_4_in == 5))
           {
            Zi_6_bo = OrderDelete(OrderTicket(), 0xFFFFFFFF) ;
           }
         if(Zi_6_bo)
            continue;
         Zi_2_in = GetLastError() ;
         if(Zi_2_in < 2)
            continue;
         if(Zi_2_in == 129)
           {
            Comment("", TimeToString(TimeCurrent(), 4));
            RefreshRates();
            continue;
           }
         if(Zi_2_in == 146)
           {
            if(!(IsTradeContextBusy()))
               continue;
            Sleep(2000);
            continue;
           }
         Comment("", Zi_2_in, "", OrderTicket(), "     ", TimeToString(TimeCurrent(), 4));
        }
      Zi_5_in = 0 ;
      for(Zi_8_in = 0 ; Zi_8_in < OrdersTotal() ; Zi_8_in ++)
        {
         if(!(OrderSelect(Zi_8_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
            continue;
         Zi_4_in = OrderType() ;
         if((Zi_4_in == 4 || Zi_4_in == 0) && (Mu_0_in == 1 || Mu_0_in == 0))
           {
            Zi_5_in ++;
           }
         if((Zi_4_in != 5 && Zi_4_in != 1))
            continue;
         if((Mu_0_in != -1 && Mu_0_in != 0))
            continue;
         Zi_5_in ++;
        }
      if(Zi_5_in == 0)
         break;
      Zi_3_in ++;
      if(Zi_3_in >  10)
        {
         Print(Symbol(), "平仓超过10次，剩余未平仓单数为：", Zi_5_in);
         return(0);
        }
      Sleep(1000);
      RefreshRates();
      continue;
     }
   return(1);
  }
//lizong_13 <<==--------   --------
int lizong_14(int Mu_0_in)
  {
   int       Zi_2_in = 0;
   int       Zi_3_in = 0;
   int       Zi_4_in = 0;
   int       Zi_5_in = 0;
   bool      Zi_6_bo = false;
   int       Zi_7_in = 0;
//----- -----
   Zi_4_in = 0 ;
   Zi_5_in = 0 ;
   Zi_6_bo = true ;
   for(; ;)
     {
      for(Zi_7_in = OrdersTotal() - 1 ; Zi_7_in >= 0 ; Zi_7_in --)
        {
         if(!(OrderSelect(Zi_7_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
            continue;
         Zi_4_in = OrderType() ;
         if(Zi_4_in == 0 && (Mu_0_in == 1 || Mu_0_in == 0))
           {
            Zi_6_bo = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits()), Zong_50_in_190, Blue) ;
            if(Zi_6_bo)
              {
               Comment("", OrderTicket(), "", OrderProfit(), "     ", TimeToString(TimeCurrent(), 4));
              }
           }
         if(Zi_4_in == 1 && (Mu_0_in == -1 || Mu_0_in == 0))
           {
            Zi_6_bo = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits()), Zong_50_in_190, Red) ;
            if(Zi_6_bo)
              {
               Comment("", OrderTicket(), "", OrderProfit(), "     ", TimeToString(TimeCurrent(), 4));
              }
           }
         if(Zi_4_in == 4 && (Mu_0_in == 1 || Mu_0_in == 0))
           {
            Zi_6_bo = OrderDelete(OrderTicket(), 0xFFFFFFFF) ;
           }
         if(Zi_4_in == 5 && (Mu_0_in == -1 || Mu_0_in == 0))
           {
            Zi_6_bo = OrderDelete(OrderTicket(), 0xFFFFFFFF) ;
           }
         if(Zi_6_bo)
            continue;
         Zi_2_in = GetLastError() ;
         if(Zi_2_in < 2)
            continue;
         if(Zi_2_in == 129)
           {
            Comment("", TimeToString(TimeCurrent(), 4));
            RefreshRates();
            continue;
           }
         if(Zi_2_in == 146)
           {
            if(!(IsTradeContextBusy()))
               continue;
            Sleep(2000);
            continue;
           }
         Comment("", Zi_2_in, "", OrderTicket(), "     ", TimeToString(TimeCurrent(), 4));
        }
      Zi_5_in = 0 ;
      for(Zi_7_in = 0 ; Zi_7_in < OrdersTotal() ; Zi_7_in ++)
        {
         if(!(OrderSelect(Zi_7_in, 0, 0)) || OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
            continue;
         Zi_4_in = OrderType() ;
         if((Zi_4_in == 4 || Zi_4_in == 0) && (Mu_0_in == 1 || Mu_0_in == 0))
           {
            Zi_5_in ++;
           }
         if((Zi_4_in != 5 && Zi_4_in != 1))
            continue;
         if((Mu_0_in != -1 && Mu_0_in != 0))
            continue;
         Zi_5_in ++;
        }
      if(Zi_5_in == 0)
         break;
      Zi_3_in ++;
      if(Zi_3_in >  10)
        {
         Print(Symbol(), "平仓超过10次", Zi_5_in);
         return(0);
        }
      Sleep(1000);
      RefreshRates();
      continue;
     }
   return(1);
  }
//lizong_14 <<==--------   --------
int lizong_15(int Mu_0_in)
  {
   if(Mu_0_in >  43200)
     {
      return(0);
     }
   if(Mu_0_in >  10080)
     {
      return(43200);
     }
   if(Mu_0_in >  1440)
     {
      return(10080);
     }
   if(Mu_0_in >  240)
     {
      return(1440);
     }
   if(Mu_0_in >  60)
     {
      return(240);
     }
   if(Mu_0_in >  30)
     {
      return(60);
     }
   if(Mu_0_in >  15)
     {
      return(30);
     }
   if(Mu_0_in >  5)
     {
      return(15);
     }
   if(Mu_0_in >  1)
     {
      return(5);
     }
   if(Mu_0_in == 1)
     {
      return(1);
     }
   if(Mu_0_in == 0)
     {
      return(Period());
     }
   return(0);
  }
//lizong_15 <<==--------   --------
void lizong_16(int Mu_0_in, int Mu_1_in, int Mu_2_in, int Mu_3_in)
  {
   int       Zi_1_in = 0;
   int       Zi_2_in = 0;
   int       Zi_3_in;
   double    Zi_4_do;
   int       Zi_5_in;
//----- -----
   Zi_3_in = 0 ;
   Zi_4_do = 0.0 ;
   Zi_5_in = 0 ;
   while(Mu_2_in > 0)
     {
      Zi_1_in = Mu_1_in ;
      Zi_2_in = Mu_0_in ;
      Zi_3_in = -1 ;
      Zi_4_do = 0.0 ;
      for(Zi_5_in = OrdersTotal() - 1 ; Zi_5_in >= 0 ; Zi_5_in --)
        {
         if(!(OrderSelect(Zi_5_in, 0, 0)) || OrderSymbol() != Symbol())
            continue;
         if((OrderMagicNumber() != Zi_1_in && Zi_1_in != -1))
            continue;
         if((OrderType() != Zi_2_in && Zi_2_in != -100))
            continue;
         if(Mu_3_in == 1 && Zi_4_do < OrderProfit())
           {
            Zi_4_do = OrderProfit() ;
            Zi_3_in = OrderTicket() ;
           }
         if(Mu_3_in != 2)
            continue;
         if((!(Zi_4_do > OrderProfit()) && !(Zi_4_do == 0.0)))
            continue;
         Zi_4_do = OrderProfit() ;
         Zi_3_in = OrderTicket() ;
        }
      if(OrderSelect(Zi_3_in, 1, 0))
        {
         if(Mu_3_in == 1 && OrderProfit() >= 0.0 && OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 0, 0xFFFFFFFF))
           {
            Mu_2_in --;
           }
         if(Mu_3_in == 1 && OrderProfit() < 0.0)
           {
            Mu_2_in --;
           }
         if(Mu_3_in == 2 && OrderProfit() < 0.0 && OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 0, 0xFFFFFFFF))
           {
            Mu_2_in --;
           }
         if(Mu_3_in != 2 || !(OrderProfit() >= 0.0))
            continue;
         Mu_2_in --;
         continue;
        }
      Mu_2_in --;
     }
  }
//lizong_16 <<==--------   --------
double lizong_17(int Mu_0_in, int Mu_1_in, int Mu_2_in, int Mu_3_in)
  {
   double    Zi_2_do_si100[100];
   int       Zi_3_in = 0;
   int       Zi_4_in = 0;
   double    Zi_5_do = 0.0;
//----- -----
   Zi_4_in = 0 ;
   Zi_5_do = 0.0 ;
   ArrayInitialize(Zi_2_do_si100, 0.0);
   Zi_3_in = 0 ;
   for(Zi_4_in = OrdersTotal() - 1 ; Zi_4_in >= 0 ; Zi_4_in --)
     {
      if(!(OrderSelect(Zi_4_in, 0, 0)) || OrderSymbol() != Symbol())
         continue;
      if((OrderMagicNumber() != Mu_1_in && Mu_1_in != -1))
         continue;
      if((OrderType() != Mu_0_in && Mu_0_in != -100))
         continue;
      if(Mu_2_in == 1 && OrderProfit() >= 0.0)
        {
         Zi_2_do_si100[Zi_3_in] = OrderProfit();
         Zi_3_in ++;
        }
      if(Mu_2_in != 2 || !(OrderProfit() < 0.0))
         continue;
      Zi_2_do_si100[Zi_3_in] =  -(OrderProfit());
      Zi_3_in ++;
     }
   ArraySort(Zi_2_do_si100, 0, 0, 2);
   Zi_5_do = 0.0 ;
   for(Zi_4_in = 0 ; Zi_4_in < Mu_3_in ; Zi_4_in ++)
     {
      Zi_5_do = Zi_5_do + Zi_2_do_si100[Zi_4_in] ;
     }
   return(Zi_5_do);
  }
//lizong_17 <<==--------   --------
bool lizong_18()
  {
   int       Zi_2_in;
   int       Zi_3_in;
   uchar     Zi_4_uc_si1024[1024];
   int       Zi_5_in;
   string    Zi_6_st;
   int       Zi_7_in;
   int       Zi_8_in;
   datetime  Zi_9_da;
   datetime  Zi_10_da;
//----- -----
   if(授权码 == "")
     {
      授权码 = (string)GlobalVariableGet(Zong_4_st_30 + string(AccountNumber()) + "AuthCode") ;
     }
   if(授权码 == "0")
     {
      授权码 = (string)AccountNumber() ;
     }
   GlobalVariableSet(Zong_4_st_30 + string(AccountNumber()) + "AuthCode", (double)授权码);
   Zong_13_da_C0 = iTime(NULL, PERIOD_D1, 0) ;
   Zong_2_st_10 = Zong_1_st_0 + 授权码;
   Zi_2_in = 0; // InternetOpenW("MT4",1,"","",0) ;
   if(Zi_2_in == 0)
     {
      Zong_3_st_20 = "";//Zong_144_st_5F8 ;
      return(true);// return(false);
     }
   Zi_3_in = InternetOpenUrlW(Zi_2_in, Zong_2_st_10, "", 0, -2147483648, 0) ;
   if(Zi_3_in == 0)
     {
      InternetCloseHandle(Zi_2_in);
      Zong_3_st_20 = Zong_144_st_5F8 ;
      return(false);
     }
   Zi_5_in = 0 ;
   Zi_6_st = "" ;
   if(InternetReadFile(Zi_3_in, Zi_4_uc_si1024, 1024, Zi_5_in))
     {
      while(Zi_5_in > 0)
        {
         for(Zi_7_in = 0 ; Zi_7_in < Zi_5_in ; Zi_7_in ++)
           {
            Zi_6_st += CharToString(Zi_4_uc_si1024[Zi_7_in]);
           }
         if(!(InternetReadFile(Zi_3_in, Zi_4_uc_si1024, 1024, Zi_5_in)))
            break;
        }
     }
   InternetCloseHandle(Zi_3_in);
   InternetCloseHandle(Zi_2_in);
   Zi_8_in = StringFind(Zi_6_st, string(AccountNumber()), 0) ;
   if(Zi_8_in <  0)
     {
      Alert(Zong_145_st_608);
      Zong_3_st_20 = Zong_145_st_608 ;
      ExpertRemove();
      return(false);
     }
   Zi_8_in = StringFind(Zi_6_st, "class=\"info-value expire-date valid\">", 0) ;
   if(Zi_8_in >= 0)
     {
      Zi_8_in += 37;
      Zong_3_st_20 = StringSubstr(Zi_6_st, Zi_8_in, 10) ;
      StringReplace(Zong_3_st_20, "-", ".");
      Zi_9_da = StringToTime(Zong_3_st_20) ;
      Zi_10_da = TimeLocal() ;
      Zi_10_da -= Zi_10_da % 86400;
      Zong_14_in_C8 = int((Zi_9_da - Zi_10_da) / 86400) ;
      return(true);
     }
   Zi_8_in = StringFind(Zi_6_st, "class=\"info-value expire-date expired\">", 0) ;
   if(Zi_8_in >= 0)
     {
      Zi_8_in += 39;
      Zong_3_st_20 = StringSubstr(Zi_6_st, Zi_8_in, 10) ;
      Alert(StringFormat(Zong_146_st_618, Zong_3_st_20));
      return(false);
     }
   Zong_3_st_20 = Zong_144_st_5F8 ;
   Alert(Zong_144_st_5F8);
   return(false);
  }
//lizong_18 <<==--------   --------
bool lizong_19(string Mu_0_st, string Mu_1_st, ulong Mu_2_ul)
  {
   int       Zi_2_in;
   ulong     Zi_3_ul;
   int       Zi_4_in;
   int       Zi_5_in;
   uchar     Zi_6_uc_si1024[1024];
   int       Zi_7_in;
//----- -----
   Zi_2_in = FileOpen(Mu_1_st, 7) ;
   Zi_3_ul = FileSize(Zi_2_in) ;
   if(Zi_2_in == -1)
     {
      Print("打开logo文件失败");
      return(false);
     }
   if(Zi_3_ul == Mu_2_ul)
     {
      FileClose(Zi_2_in);
      return(true);
     }
   Zi_4_in = InternetOpenW("MT4", 1, "", "", 0) ;
   if(Zi_4_in == 0)
     {
      return(false);
     }
   Zi_5_in = InternetOpenUrlW(Zi_4_in, Mu_0_st, "", 0, -2147483648, 0) ;
   if(Zi_5_in == 0)
     {
      InternetCloseHandle(Zi_4_in);
      return(false);
     }
   Zi_7_in = 0 ;
   if(InternetReadFile(Zi_5_in, Zi_6_uc_si1024, 1024, Zi_7_in))
     {
      while(Zi_7_in > 0)
        {
         FileWriteArray(Zi_2_in, Zi_6_uc_si1024, 0, Zi_7_in);
         if(!(InternetReadFile(Zi_5_in, Zi_6_uc_si1024, 1024, Zi_7_in)))
            break;
        }
     }
   FileClose(Zi_2_in);
   InternetCloseHandle(Zi_5_in);
   InternetCloseHandle(Zi_4_in);
   return(true);
  }
//lizong_19 <<==--------   --------
void lizong_20()
  {
   string    Zi_1_st;
   int       Zi_2_in;
   string    Zi_3_st;
   int       Zi_4_in;
   double    Zi_5_do;
   double    Zi_6_do;
   double    Zi_7_do;
   double    Zi_8_do;
   double    Zi_9_do;
   string    Zi_10_st;
   string    Zi_11_st;
   string    Zi_12_st;
//----- -----
   uint       Lin_ui_1;
   long       Lin_lo_2;
   uint       Lin_ui_3;
   long       Lin_lo_4;
   uint       Lin_ui_5;
   long       Lin_lo_6;
   int        Lin_in_7;
   string     Lin_st_8;
   uint       Lin_ui_9;
   string     Lin_st_10;
   int        Lin_in_11;
   string     Lin_st_12;
   uint       Lin_ui_13;
   string     Lin_st_14;
   int        Lin_in_15;
   string     Lin_st_16;
   uint       Lin_ui_17;
   string     Lin_st_18;
   int        Lin_in_19;
   string     Lin_st_20;
   uint       Lin_ui_21;
   string     Lin_st_22;
   int        Lin_in_23;
   string     Lin_st_24;
   uint       Lin_ui_25;
   string     Lin_st_26;
   int        Lin_in_27;
   string     Lin_st_28;
   uint       Lin_ui_29;
   string     Lin_st_30;
   string     Lin_st_31;
   int        Lin_in_32;
   int        Lin_in_33;
   double     Lin_do_34;
   double     Lin_do_35;
   long       Lin_lo_36;
   int        Lin_in_37;
   int        Lin_in_38;
   int        Lin_in_39;
   string     Lin_st_40;
   int        Lin_in_41;
   uint       Lin_ui_42;
   string     Lin_st_43;
   int        Lin_in_44;
   string     Lin_st_45;
   int        Lin_in_46;
   uint       Lin_ui_47;
   string     Lin_st_48;
   int        Lin_in_49;
   string     Lin_st_50;
   uint       Lin_ui_51;
   string     Lin_st_52;
   string     Lin_st_53;
   int        Lin_in_54;
   int        Lin_in_55;
   double     Lin_do_56;
   double     Lin_do_57;
   long       Lin_lo_58;
   int        Lin_in_59;
   int        Lin_in_60;
   int        Lin_in_61;
   string     Lin_st_62;
   int        Lin_in_63;
   uint       Lin_ui_64;
   string     Lin_st_65;
   int        Lin_in_66;
   string     Lin_st_67;
   int        Lin_in_68;
   uint       Lin_ui_69;
   string     Lin_st_70;
   int        Lin_in_71;
   string     Lin_st_72;
   uint       Lin_ui_73;
   string     Lin_st_74;
   string     Lin_st_75;
   int        Lin_in_76;
   int        Lin_in_77;
   double     Lin_do_78;
   double     Lin_do_79;
   long       Lin_lo_80;
   int        Lin_in_81;
   int        Lin_in_82;
   int        Lin_in_83;
   string     Lin_st_84;
   int        Lin_in_85;
   uint       Lin_ui_86;
   string     Lin_st_87;
   int        Lin_in_88;
   string     Lin_st_89;
   int        Lin_in_90;
   uint       Lin_ui_91;
   string     Lin_st_92;
   int        Lin_in_93;
   string     Lin_st_94;
   uint       Lin_ui_95;
   string     Lin_st_96;
   int        Lin_in_97;
   string     Lin_st_98;
   uint       Lin_ui_99;
   string     Lin_st_100;
   int        Lin_in_101;
   string     Lin_st_102;
   uint       Lin_ui_103;
   string     Lin_st_104;
   int        Lin_in_105;
   string     Lin_st_106;
   uint       Lin_ui_107;
   string     Lin_st_108;
   int        Lin_in_109;
   string     Lin_st_110;
   uint       Lin_ui_111;
   string     Lin_st_112;
   int        Lin_in_113;
   string     Lin_st_114;
   uint       Lin_ui_115;
   string     Lin_st_116;
   int        Lin_in_117;
   string     Lin_st_118;
   uint       Lin_ui_119;
   string     Lin_st_120;
   string     Lin_st_121;
   int        Lin_in_122;
   double     Lin_do_123;
   int        Lin_in_124;
   string     Lin_st_125;
   int        Lin_in_126;
   double     Lin_do_127;
   int        Lin_in_128;
   string     Lin_st_129;
   int        Lin_in_130;
   double     Lin_do_131;
   int        Lin_in_132;
   string     Lin_st_133;
   int        Lin_in_134;
   double     Lin_do_135;
   int        Lin_in_136;
   uint       Lin_ui_137;
   long       Lin_lo_138;
   int        Lin_in_139;
   string     Lin_st_140;
   uint       Lin_ui_141;
   string     Lin_st_142;
   int        Lin_in_143;
   string     Lin_st_144;
   uint       Lin_ui_145;
   string     Lin_st_146;
   int        Lin_in_147;
   string     Lin_st_148;
   uint       Lin_ui_149;
   string     Lin_st_150;
   uint       Lin_ui_151;
   long       Lin_lo_152;
   int        Lin_in_153;
   string     Lin_st_154;
   uint       Lin_ui_155;
   string     Lin_st_156;
   int        Lin_in_157;
   string     Lin_st_158;
   uint       Lin_ui_159;
   string     Lin_st_160;
   int        Lin_in_161;
   string     Lin_st_162;
   uint       Lin_ui_163;
   string     Lin_st_164;
   uint       Lin_ui_165;
   long       Lin_lo_166;
   int        Lin_in_167;
   string     Lin_st_168;
   uint       Lin_ui_169;
   string     Lin_st_170;
   int        Lin_in_171;
   string     Lin_st_172;
   uint       Lin_ui_173;
   string     Lin_st_174;
   int        Lin_in_175;
   string     Lin_st_176;
   uint       Lin_ui_177;
   string     Lin_st_178;
   uint       Lin_ui_179;
   long       Lin_lo_180;
   uint       Lin_ui_181;
   long       Lin_lo_182;
   uint       Lin_ui_183;
   long       Lin_lo_184;
   int        Lin_in_185;
   string     Lin_st_186;
   uint       Lin_ui_187;
   string     Lin_st_188;
   int        Lin_in_189;
   string     Lin_st_190;
   uint       Lin_ui_191;
   string     Lin_st_192;
   int        Lin_in_193;
   string     Lin_st_194;
   uint       Lin_ui_195;
   string     Lin_st_196;
   uint       Lin_ui_197;
   long       Lin_lo_198;
   int        Lin_in_199;
   string     Lin_st_200;
   uint       Lin_ui_201;
   string     Lin_st_202;
   int        Lin_in_203;
   string     Lin_st_204;
   uint       Lin_ui_205;
   string     Lin_st_206;
   int        Lin_in_207;
   string     Lin_st_208;
   uint       Lin_ui_209;
   string     Lin_st_210;
   uint       Lin_ui_211;
   long       Lin_lo_212;
   int        Lin_in_213;
   string     Lin_st_214;
   uint       Lin_ui_215;
   string     Lin_st_216;
   int        Lin_in_217;
   string     Lin_st_218;
   uint       Lin_ui_219;
   string     Lin_st_220;
   int        Lin_in_221;
   string     Lin_st_222;
   uint       Lin_ui_223;
   string     Lin_st_224;
   uint       Lin_ui_225;
   long       Lin_lo_226;
   int        Lin_in_227;
   string     Lin_st_228;
   uint       Lin_ui_229;
   string     Lin_st_230;
   int        Lin_in_231;
   string     Lin_st_232;
   uint       Lin_ui_233;
   string     Lin_st_234;
   int        Lin_in_235;
   string     Lin_st_236;
   int        Lin_in_237;
   uint       Lin_ui_238;
   string     Lin_st_239;
   int        Lin_in_240;
   string     Lin_st_241;
   uint       Lin_ui_242;
   string     Lin_st_243;
   int        Lin_in_244;
   string     Lin_st_245;
   uint       Lin_ui_246;
   string     Lin_st_247;
   int        Lin_in_248;
   string     Lin_st_249;
   int        Lin_in_250;
   uint       Lin_ui_251;
   string     Lin_st_252;
   int        Lin_in_253;
   string     Lin_st_254;
   uint       Lin_ui_255;
   string     Lin_st_256;
   int        Lin_in_257;
   string     Lin_st_258;
   uint       Lin_ui_259;
   string     Lin_st_260;
   int        Lin_in_261;
   string     Lin_st_262;
   int        Lin_in_263;
   uint       Lin_ui_264;
   string     Lin_st_265;
   uint       Lin_ui_266;
   long       Lin_lo_267;
   int        Lin_in_268;
   string     Lin_st_269;
   uint       Lin_ui_270;
   string     Lin_st_271;
   int        Lin_in_272;
   string     Lin_st_273;
   uint       Lin_ui_274;
   string     Lin_st_275;
   int        Lin_in_276;
   string     Lin_st_277;
   uint       Lin_ui_278;
   string     Lin_st_279;
   Zi_1_st = "  " + AccountCurrency();
   Zi_2_in = 1 ;
   Zi_4_in = 110 ;
   Zi_5_do = 0.0 ;
   if(Zong_15_bo_CC == false)
     {
//      lizong_21(0, "tubiao", 0, 0, 30, 610, 610, "//Files/" + Zong_4_st_30 + Zong_8_st_70, "//Files/" + Zong_4_st_30 + Zong_8_st_70, 0, true);
//      lizong_21(0, "tubiao2", 0, 190, 50, 80, 80, "//Files/" + Zong_4_st_30 + Zong_10_st_90, "//Files/" + Zong_4_st_30 + Zong_10_st_90, 1, false);
     }
   else
     {
//      lizong_21(0, "tubiao", 0, 0, 30, 610, 610, "//Files/" + Zong_4_st_30 + Zong_8_st_70, "//Files/" + Zong_4_st_30 + Zong_8_st_70, 0, true);
      Lin_ui_1 = Snow;
      Lin_lo_2 = 0;
      if(ObjectFind(0, Zong_17_st_D0 + "background") <  0)
        {
         ObjectCreate(0, Zong_17_st_D0 + "background", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_XDISTANCE, 308);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_YDISTANCE, 50);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_XSIZE, 300);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_YSIZE, 440);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_BORDER_TYPE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_CORNER, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_COLOR, 8421376);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_STYLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_WIDTH, 10);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_BACK, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_SELECTABLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_SELECTED, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_HIDDEN, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "background", OBJPROP_ZORDER, 0);
        }
      ObjectSetInteger(Lin_lo_2, Zong_17_st_D0 + "background", OBJPROP_BGCOLOR, Lin_ui_1);
//      lizong_21(0, "tubiao1", 0, 190, 50, 80, 80, "//Files/" + Zong_4_st_30 + Zong_9_st_80, "//Files/" + Zong_4_st_30 + Zong_9_st_80, 1, false);
      Lin_ui_3 = LightCyan;
      Lin_lo_4 = 0;
      if(ObjectFind(0, Zong_17_st_D0 + "showprofit") <  0)
        {
         ObjectCreate(0, Zong_17_st_D0 + "showprofit", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_XDISTANCE, 298);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_YDISTANCE, 90);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_XSIZE, 280);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_YSIZE, 85);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_BORDER_TYPE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_CORNER, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_COLOR, 8421376);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_STYLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_BACK, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_SELECTABLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_SELECTED, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_HIDDEN, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofit", OBJPROP_ZORDER, 0);
        }
      ObjectSetInteger(Lin_lo_4, Zong_17_st_D0 + "showprofit", OBJPROP_BGCOLOR, Lin_ui_3);
      Lin_ui_5 = LightCyan;
      Lin_lo_6 = 0;
      if(ObjectFind(0, Zong_17_st_D0 + "showprofittitle") <  0)
        {
         ObjectCreate(0, Zong_17_st_D0 + "showprofittitle", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_XDISTANCE, 213);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_YDISTANCE, 80);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_XSIZE, 120);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_YSIZE, 20);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_BORDER_TYPE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_CORNER, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_COLOR, 8421376);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_STYLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_BACK, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_SELECTABLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_SELECTED, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_HIDDEN, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "showprofittitle", OBJPROP_ZORDER, 0);
        }
      ObjectSetInteger(Lin_lo_6, Zong_17_st_D0 + "showprofittitle", OBJPROP_BGCOLOR, Lin_ui_5);
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "B" ;
      if(Zong_25_bo_114 == true)
        {
         Lin_in_7 = Zong_19_in_EC;
         Lin_st_8 = Zong_21_st_F8;
         Lin_ui_9 = Green;
         Lin_st_10 = "可以多";
         if(ObjectFind(Zi_3_st) == -1)
           {
            ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 230);
            ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, 65);
            ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_3_st, Lin_st_10, Lin_in_7, Lin_st_8, Lin_ui_9);
        }
      else
        {
         Lin_in_11 = Zong_19_in_EC;
         Lin_st_12 = Zong_21_st_F8;
         Lin_ui_13 = Tomato;
         Lin_st_14 = "禁止多";
         if(ObjectFind(Zi_3_st) == -1)
           {
            ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 230);
            ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, 65);
            ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_3_st, Lin_st_14, Lin_in_11, Lin_st_12, Lin_ui_13);
        }
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "S" ;
      if(Zong_26_bo_115 == true)
        {
         Lin_in_15 = Zong_19_in_EC;
         Lin_st_16 = Zong_21_st_F8;
         Lin_ui_17 = Green;
         Lin_st_18 = "可以空";
         if(ObjectFind(Zi_3_st) == -1)
           {
            ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 40);
            ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, 65);
            ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_3_st, Lin_st_18, Lin_in_15, Lin_st_16, Lin_ui_17);
        }
      else
        {
         Lin_in_19 = Zong_19_in_EC;
         Lin_st_20 = Zong_21_st_F8;
         Lin_ui_21 = Tomato;
         Lin_st_22 = "禁止空";
         if(ObjectFind(Zi_3_st) == -1)
           {
            ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 40);
            ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, 65);
            ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_3_st, Lin_st_22, Lin_in_19, Lin_st_20, Lin_ui_21);
        }
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "N" ;
      Lin_in_23 = Zong_19_in_EC;
      Lin_st_24 = Zong_21_st_F8;
      Lin_ui_25 = 0;
      Lin_st_26 = "获利统计";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 122);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, 80);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_26, Lin_in_23, Lin_st_24, Lin_ui_25);
      Zi_2_in ++;
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "N" ;
      Lin_in_27 = Zong_19_in_EC;
      Lin_st_28 = "Microsoft YaHei";
      Lin_ui_29 = 0;
      Lin_st_30 = "今日获利:";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 230);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, "Microsoft YaHei");
        }
      ObjectSetText(Zi_3_st, Lin_st_30, Lin_in_27, Lin_st_28, Lin_ui_29);
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "V" ;
      Lin_st_31 = (string)Magic;
      Lin_in_32 = 0;
      Lin_in_33 = 0;
      switch(0)
        {
         case 0 :
            Lin_in_32 = TimeDay(TimeCurrent());
            Lin_in_33 = Lin_in_32;
            break;
         case 1 :
            Lin_in_32 = Lin_in_33 - 1;
            Lin_in_33 = Lin_in_32;
            break;
         case 2 :
            Lin_in_32 = 0;
            Lin_in_33 = 999999;
            break;
         default :
            Lin_do_34 = 0.0;
            break;
        }
      Lin_do_35 = 0.0;
      if(Lin_st_31 == "")
        {
         Lin_lo_36 = -1;
        }
      else
        {
         Lin_lo_36 = StringToInteger(Lin_st_31);
        }
      Lin_lo_36 = Lin_lo_36;
      for(Lin_in_37 = HistoryTotal() - 1 ; Lin_in_37 >= 0 ; Lin_in_37 = Lin_in_37 - 1)
        {
         if(!(OrderSelect(Lin_in_37, 0, 1)))
            continue;
         Lin_in_38 = TimeDay(OrderCloseTime());
         if(Lin_in_38 < Lin_in_32 || Lin_in_38 > Lin_in_33)
            continue;
         if((Lin_lo_36 != -1 && OrderMagicNumber() != Lin_lo_36))
            continue;
         Lin_do_35 = OrderProfit() + OrderSwap() + OrderCommission() + Lin_do_35;
        }
      Lin_do_34 = NormalizeDouble(Lin_do_35, 2);
      Zi_5_do = Lin_do_34 ;
      Lin_in_39 = Zong_19_in_EC;
      Lin_st_40 = Zong_21_st_F8;
      Lin_in_41 = Zong_22_in_104;
      Lin_ui_42 = (Zi_5_do >= 0.0) ? 25600 : 3937500 ;
      Lin_st_43 = DoubleToString(Zi_5_do, 2) + Zi_1_st;
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Lin_in_41);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 100);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Lin_st_40);
        }
      ObjectSetText(Zi_3_st, Lin_st_43, Lin_in_39, Lin_st_40, Lin_ui_42);
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "P" ;
      Lin_in_44 = Zong_19_in_EC;
      Lin_st_45 = Zong_21_st_F8;
      Lin_in_46 = Zong_22_in_104;
      Lin_ui_47 = (Zi_5_do >= 0.0) ? 25600 : 3937500 ;
      Lin_st_48 = DoubleToString(Zi_5_do / Zong_23_do_108 * 100.0, 2) + "%";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Lin_in_46);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 25);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Lin_st_45);
        }
      ObjectSetText(Zi_3_st, Lin_st_48, Lin_in_44, Lin_st_45, Lin_ui_47);
      Zi_2_in ++;
      Zi_4_in += Zong_19_in_EC * 2;
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "N" ;
      Lin_in_49 = Zong_19_in_EC;
      Lin_st_50 = Zong_21_st_F8;
      Lin_ui_51 = 0;
      Lin_st_52 = "昨日获利:";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 230);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_52, Lin_in_49, Lin_st_50, Lin_ui_51);
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "V" ;
      Lin_st_53 = (string)Magic;
      Lin_in_54 = 0;
      Lin_in_55 = 0;
      switch(1)
        {
         case 0 :
            Lin_in_54 = TimeDay(TimeCurrent());
            Lin_in_55 = Lin_in_54;
            break;
         case 1 :
            Lin_in_54 = Lin_in_55 - 1;
            Lin_in_55 = Lin_in_54;
            break;
         case 2 :
            Lin_in_54 = 0;
            Lin_in_55 = 999999;
            break;
         default :
            Lin_do_56 = 0.0;
            break;
        }
      Lin_do_57 = 0.0;
      if(Lin_st_53 == "")
        {
         Lin_lo_58 = -1;
        }
      else
        {
         Lin_lo_58 = StringToInteger(Lin_st_53);
        }
      Lin_lo_58 = Lin_lo_58;
      for(Lin_in_59 = HistoryTotal() - 1 ; Lin_in_59 >= 0 ; Lin_in_59 = Lin_in_59 - 1)
        {
         if(!(OrderSelect(Lin_in_59, 0, 1)))
            continue;
         Lin_in_60 = TimeDay(OrderCloseTime());
         if(Lin_in_60 < Lin_in_54 || Lin_in_60 > Lin_in_55)
            continue;
         if((Lin_lo_58 != -1 && OrderMagicNumber() != Lin_lo_58))
            continue;
         Lin_do_57 = OrderProfit() + OrderSwap() + OrderCommission() + Lin_do_57;
        }
      Lin_do_56 = NormalizeDouble(Lin_do_57, 2);
      Zi_5_do = Lin_do_56 ;
      Lin_in_61 = Zong_19_in_EC;
      Lin_st_62 = Zong_21_st_F8;
      Lin_in_63 = Zong_22_in_104;
      Lin_ui_64 = (Zi_5_do >= 0.0) ? 25600 : 3937500 ;
      Lin_st_65 = DoubleToString(Zi_5_do, 2) + Zi_1_st;
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Lin_in_63);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 100);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Lin_st_62);
        }
      ObjectSetText(Zi_3_st, Lin_st_65, Lin_in_61, Lin_st_62, Lin_ui_64);
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "P" ;
      Lin_in_66 = Zong_19_in_EC;
      Lin_st_67 = Zong_21_st_F8;
      Lin_in_68 = Zong_22_in_104;
      Lin_ui_69 = (Zi_5_do >= 0.0) ? 25600 : 3937500 ;
      Lin_st_70 = DoubleToString(Zi_5_do / Zong_23_do_108 * 100.0, 2) + "%";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Lin_in_68);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 25);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Lin_st_67);
        }
      ObjectSetText(Zi_3_st, Lin_st_70, Lin_in_66, Lin_st_67, Lin_ui_69);
      Zi_2_in ++;
      Zi_4_in += Zong_19_in_EC * 2;
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "N" ;
      Lin_in_71 = Zong_19_in_EC;
      Lin_st_72 = Zong_21_st_F8;
      Lin_ui_73 = 0;
      Lin_st_74 = "总计获利:";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 230);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_74, Lin_in_71, Lin_st_72, Lin_ui_73);
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "V" ;
      Lin_st_75 = (string)Magic;
      Lin_in_76 = 0;
      Lin_in_77 = 0;
      switch(2)
        {
         case 0 :
            Lin_in_76 = TimeDay(TimeCurrent());
            Lin_in_77 = Lin_in_76;
            break;
         case 1 :
            Lin_in_76 = Lin_in_77 - 1;
            Lin_in_77 = Lin_in_76;
            break;
         case 2 :
            Lin_in_76 = 0;
            Lin_in_77 = 999999;
            break;
         default :
            Lin_do_78 = 0.0;
            break;
        }
      Lin_do_79 = 0.0;
      if(Lin_st_75 == "")
        {
         Lin_lo_80 = -1;
        }
      else
        {
         Lin_lo_80 = StringToInteger(Lin_st_75);
        }
      Lin_lo_80 = Lin_lo_80;
      for(Lin_in_81 = HistoryTotal() - 1 ; Lin_in_81 >= 0 ; Lin_in_81 = Lin_in_81 - 1)
        {
         if(!(OrderSelect(Lin_in_81, 0, 1)))
            continue;
         Lin_in_82 = TimeDay(OrderCloseTime());
         if(Lin_in_82 < Lin_in_76 || Lin_in_82 > Lin_in_77)
            continue;
         if((Lin_lo_80 != -1 && OrderMagicNumber() != Lin_lo_80))
            continue;
         Lin_do_79 = OrderProfit() + OrderSwap() + OrderCommission() + Lin_do_79;
        }
      Lin_do_78 = NormalizeDouble(Lin_do_79, 2);
      Zi_5_do = Lin_do_78 ;
      Lin_in_83 = Zong_19_in_EC;
      Lin_st_84 = Zong_21_st_F8;
      Lin_in_85 = Zong_22_in_104;
      Lin_ui_86 = (Zi_5_do >= 0.0) ? 25600 : 3937500 ;
      Lin_st_87 = DoubleToString(Zi_5_do, 2) + Zi_1_st;
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Lin_in_85);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 100);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Lin_st_84);
        }
      ObjectSetText(Zi_3_st, Lin_st_87, Lin_in_83, Lin_st_84, Lin_ui_86);
      Zi_3_st = Zong_17_st_D0 + string(Zi_2_in) + "P" ;
      Lin_in_88 = Zong_19_in_EC;
      Lin_st_89 = Zong_21_st_F8;
      Lin_in_90 = Zong_22_in_104;
      Lin_ui_91 = (Zi_5_do >= 0.0) ? 25600 : 3937500 ;
      Lin_st_92 = DoubleToString(Zi_5_do / Zong_23_do_108 * 100.0, 2) + "%";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Lin_in_90);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 25);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Lin_st_89);
        }
      ObjectSetText(Zi_3_st, Lin_st_92, Lin_in_88, Lin_st_89, Lin_ui_91);
      Zi_4_in += Zong_19_in_EC * 3;
      Zi_3_st = Zong_17_st_D0 + "Balance" + "N" ;
      Lin_in_93 = Zong_19_in_EC;
      Lin_st_94 = Zong_21_st_F8;
      Lin_ui_95 = Teal;
      Lin_st_96 = "账户余额:";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 230);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_96, Lin_in_93, Lin_st_94, Lin_ui_95);
      Zi_3_st = Zong_17_st_D0 + "Balance" + "V" ;
      Lin_in_97 = Zong_19_in_EC;
      Lin_st_98 = Zong_21_st_F8;
      Lin_ui_99 = Teal;
      Lin_st_100 = DoubleToString(AccountBalance(), 2) + Zi_1_st;
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 80);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_100, Lin_in_97, Lin_st_98, Lin_ui_99);
      Zi_2_in ++;
      Zi_4_in += Zong_19_in_EC * 2;
      Zi_3_st = Zong_17_st_D0 + "Equity" + "N" ;
      Lin_in_101 = Zong_19_in_EC;
      Lin_st_102 = Zong_21_st_F8;
      Lin_ui_103 = Teal;
      Lin_st_104 = "账户净值:";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 230);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_104, Lin_in_101, Lin_st_102, Lin_ui_103);
      Zi_3_st = Zong_17_st_D0 + "Equity" + "V" ;
      Lin_in_105 = Zong_19_in_EC;
      Lin_st_106 = Zong_21_st_F8;
      Lin_ui_107 = Green;
      Lin_st_108 = DoubleToString(AccountEquity(), 2) + Zi_1_st;
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 80);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_108, Lin_in_105, Lin_st_106, Lin_ui_107);
      Zi_2_in ++;
      Zi_4_in += Zong_19_in_EC * 2;
      Zi_3_st = Zong_17_st_D0 + "MarginLevel" + "N" ;
      Lin_in_109 = Zong_19_in_EC;
      Lin_st_110 = Zong_21_st_F8;
      Lin_ui_111 = Teal;
      Lin_st_112 = "预付款比例:";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 218);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_112, Lin_in_109, Lin_st_110, Lin_ui_111);
      Zi_3_st = Zong_17_st_D0 + "MarginLevel" + "V" ;
      if(AccountMargin() == 0.0)
        {
         Lin_in_113 = Zong_19_in_EC;
         Lin_st_114 = Zong_21_st_F8;
         Lin_ui_115 = DarkBlue;
         Lin_st_116 = "0.00%";
         if(ObjectFind(Zi_3_st) == -1)
           {
            ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 80);
            ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
            ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_3_st, Lin_st_116, Lin_in_113, Lin_st_114, Lin_ui_115);
        }
      else
        {
         Lin_in_117 = Zong_19_in_EC;
         Lin_st_118 = Zong_21_st_F8;
         Lin_ui_119 = DarkBlue;
         Lin_st_120 = DoubleToString(AccountEquity() / AccountMargin() * 100.0, 2) + "%";
         if(ObjectFind(Zi_3_st) == -1)
           {
            ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 80);
            ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
            ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_3_st, Lin_st_120, Lin_in_117, Lin_st_118, Lin_ui_119);
        }
      Lin_st_121 = "Lot";
      Lin_in_122 = 0;
      Lin_do_123 = 0.0;
      for(Lin_in_124 = OrdersTotal() - 1 ; Lin_in_124 >= 0 ; Lin_in_124 = Lin_in_124 - 1)
        {
         bool res = OrderSelect(Lin_in_124, 0, 0);
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic || OrderType() != Lin_in_122)
            continue;
         if(Lin_st_121 == "Profit")
           {
            Lin_do_123 = Lin_do_123 + OrderProfit() - OrderSwap() - OrderCommission();
           }
         if(Lin_st_121 != "Lot")
            continue;
         Lin_do_123 = Lin_do_123 + OrderLots();
        }
      Zi_6_do = Lin_do_123 ;
      Lin_st_125 = "Lot";
      Lin_in_126 = 1;
      Lin_do_127 = 0.0;
      for(Lin_in_128 = OrdersTotal() - 1 ; Lin_in_128 >= 0 ; Lin_in_128 = Lin_in_128 - 1)
        {
         bool res = OrderSelect(Lin_in_128, 0, 0);
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic || OrderType() != Lin_in_126)
            continue;
         if(Lin_st_125 == "Profit")
           {
            Lin_do_127 = Lin_do_127 + OrderProfit() - OrderSwap() - OrderCommission();
           }
         if(Lin_st_125 != "Lot")
            continue;
         Lin_do_127 = Lin_do_127 + OrderLots();
        }
      Zi_7_do = Lin_do_127 ;
      Lin_st_129 = "Profit";
      Lin_in_130 = 0;
      Lin_do_131 = 0.0;
      for(Lin_in_132 = OrdersTotal() - 1 ; Lin_in_132 >= 0 ; Lin_in_132 = Lin_in_132 - 1)
        {
         bool res = OrderSelect(Lin_in_132, 0, 0);
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic || OrderType() != Lin_in_130)
            continue;
         if(Lin_st_129 == "Profit")
           {
            Lin_do_131 = Lin_do_131 + OrderProfit() - OrderSwap() - OrderCommission();
           }
         if(Lin_st_129 != "Lot")
            continue;
         Lin_do_131 = Lin_do_131 + OrderLots();
        }
      Zi_8_do = Lin_do_131 ;
      Lin_st_133 = "Profit";
      Lin_in_134 = 1;
      Lin_do_135 = 0.0;
      for(Lin_in_136 = OrdersTotal() - 1 ; Lin_in_136 >= 0 ; Lin_in_136 = Lin_in_136 - 1)
        {
         bool res = OrderSelect(Lin_in_136, 0, 0);
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic || OrderType() != Lin_in_134)
            continue;
         if(Lin_st_133 == "Profit")
           {
            Lin_do_135 = Lin_do_135 + OrderProfit() - OrderSwap() - OrderCommission();
           }
         if(Lin_st_133 != "Lot")
            continue;
         Lin_do_135 = Lin_do_135 + OrderLots();
        }
      Zi_9_do = Lin_do_135 ;
      Zi_4_in += Zong_19_in_EC * 2;
      Lin_ui_137 = MistyRose;
      Lin_lo_138 = 0;
      if(ObjectFind(0, Zong_17_st_D0 + "showtotalprofit") <  0)
        {
         ObjectCreate(0, Zong_17_st_D0 + "showtotalprofit", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_XDISTANCE, 190);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_XSIZE, 171);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_YSIZE, 60);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BORDER_TYPE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_CORNER, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_COLOR, 8421376);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_STYLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BACK, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_SELECTABLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_SELECTED, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_HIDDEN, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_ZORDER, 0);
        }
      ObjectSetInteger(Lin_lo_138, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BGCOLOR, Lin_ui_137);
      Zi_4_in += Zong_19_in_EC * 2;
      Zi_3_st = Zong_17_st_D0 + "TotalProfit" + "N" ;
      Zi_10_st = Zong_17_st_D0 + "TotalProfit" + "V" ;
      Zi_11_st = Zong_17_st_D0 + "TotalProfit" + "P" ;
      if(Zi_6_do == 0.0 && Zi_7_do == 0.0)
        {
         Lin_in_139 = int(Zong_19_in_EC * 1.5);
         Lin_st_140 = Zong_21_st_F8;
         Lin_ui_141 = Teal;
         Lin_st_142 = "账号空仓：";
         if(ObjectFind(Zi_3_st) == -1)
           {
            ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 188);
            ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
            ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_3_st, Lin_st_142, Lin_in_139, Lin_st_140, Lin_ui_141);
         Lin_in_143 = Zong_19_in_EC;
         Lin_st_144 = Zong_21_st_F8;
         Lin_ui_145 = Teal;
         Lin_st_146 = "0.00$";
         if(ObjectFind(Zi_10_st) == -1)
           {
            ObjectCreate(Zi_10_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_10_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_10_st, OBJPROP_XDISTANCE, 35);
            ObjectSet(Zi_10_st, OBJPROP_YDISTANCE, Zi_4_in - Zong_19_in_EC);
            ObjectSet(Zi_10_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_10_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_10_st, Lin_st_146, Lin_in_143, Lin_st_144, Lin_ui_145);
         Lin_in_147 = Zong_19_in_EC;
         Lin_st_148 = Zong_21_st_F8;
         Lin_ui_149 = Teal;
         Lin_st_150 = "0.00%";
         if(ObjectFind(Zi_11_st) == -1)
           {
            ObjectCreate(Zi_11_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_11_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_11_st, OBJPROP_XDISTANCE, 50);
            ObjectSet(Zi_11_st, OBJPROP_YDISTANCE, Zi_4_in + Zong_19_in_EC * 2);
            ObjectSet(Zi_11_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_11_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_11_st, Lin_st_150, Lin_in_147, Lin_st_148, Lin_ui_149);
         ObjectSetText(Zi_3_st, "账号空仓：", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, Teal);
         ObjectSetText(Zi_10_st, "0.00$", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, Teal);
         Lin_ui_151 = Snow;
         Lin_lo_152 = 0;
         if(ObjectFind(0, Zong_17_st_D0 + "showtotalprofit") <  0)
           {
            ObjectCreate(0, Zong_17_st_D0 + "showtotalprofit", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_XDISTANCE, 190);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_YDISTANCE, Zi_4_in);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_XSIZE, 171);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_YSIZE, 60);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BORDER_TYPE, 0);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_CORNER, 1);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_COLOR, 8421376);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_STYLE, 0);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BACK, 0);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_SELECTABLE, 0);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_SELECTED, 0);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_HIDDEN, 1);
            ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_ZORDER, 0);
           }
         ObjectSetInteger(Lin_lo_152, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BGCOLOR, Lin_ui_151);
        }
      else
        {
         if(AccountProfit() > 0.0)
           {
            Lin_in_153 = int(Zong_19_in_EC * 1.5);
            Lin_st_154 = Zong_21_st_F8;
            Lin_ui_155 = DarkGreen;
            Lin_st_156 = "账号盈利：";
            if(ObjectFind(Zi_3_st) == -1)
              {
               ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
               ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
               ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 188);
               ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
               ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
               ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
              }
            ObjectSetText(Zi_3_st, Lin_st_156, Lin_in_153, Lin_st_154, Lin_ui_155);
            Lin_in_157 = Zong_19_in_EC;
            Lin_st_158 = Zong_21_st_F8;
            Lin_ui_159 = DarkGreen;
            Lin_st_160 = DoubleToString(AccountProfit(), 2) + "$";
            if(ObjectFind(Zi_10_st) == -1)
              {
               ObjectCreate(Zi_10_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
               ObjectSet(Zi_10_st, OBJPROP_CORNER, Zong_22_in_104);
               ObjectSet(Zi_10_st, OBJPROP_XDISTANCE, 30);
               ObjectSet(Zi_10_st, OBJPROP_YDISTANCE, Zi_4_in - Zong_19_in_EC);
               ObjectSet(Zi_10_st, OBJPROP_BACK, 0.0);
               ObjectSetString(0, Zi_10_st, 1001, Zong_21_st_F8);
              }
            ObjectSetText(Zi_10_st, Lin_st_160, Lin_in_157, Lin_st_158, Lin_ui_159);
            Lin_in_161 = Zong_19_in_EC;
            Lin_st_162 = Zong_21_st_F8;
            Lin_ui_163 = DarkGreen;
            Lin_st_164 = DoubleToString(AccountProfit() / Zong_23_do_108 * 100.0, 2) + "%";
            if(ObjectFind(Zi_11_st) == -1)
              {
               ObjectCreate(Zi_11_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
               ObjectSet(Zi_11_st, OBJPROP_CORNER, Zong_22_in_104);
               ObjectSet(Zi_11_st, OBJPROP_XDISTANCE, 50);
               ObjectSet(Zi_11_st, OBJPROP_YDISTANCE, Zi_4_in + Zong_19_in_EC * 2);
               ObjectSet(Zi_11_st, OBJPROP_BACK, 0.0);
               ObjectSetString(0, Zi_11_st, 1001, Zong_21_st_F8);
              }
            ObjectSetText(Zi_11_st, Lin_st_164, Lin_in_161, Lin_st_162, Lin_ui_163);
            ObjectSetText(Zi_3_st, "账号盈利：", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, Brown);
            ObjectSetText(Zi_10_st, DoubleToString(AccountProfit(), 2) + "$", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, Brown);
            Lin_ui_165 = Honeydew;
            Lin_lo_166 = 0;
            if(ObjectFind(0, Zong_17_st_D0 + "showtotalprofit") <  0)
              {
               ObjectCreate(0, Zong_17_st_D0 + "showtotalprofit", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_XDISTANCE, 190);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_YDISTANCE, Zi_4_in);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_XSIZE, 171);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_YSIZE, 60);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BORDER_TYPE, 0);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_CORNER, 1);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_COLOR, 8421376);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_STYLE, 0);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BACK, 0);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_SELECTABLE, 0);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_SELECTED, 0);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_HIDDEN, 1);
               ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_ZORDER, 0);
              }
            ObjectSetInteger(Lin_lo_166, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BGCOLOR, Lin_ui_165);
           }
         else
           {
            if(AccountProfit() < 0.0)
              {
               Lin_in_167 = int(Zong_19_in_EC * 1.5);
               Lin_st_168 = Zong_21_st_F8;
               Lin_ui_169 = Brown;
               Lin_st_170 = "账号亏损：";
               if(ObjectFind(Zi_3_st) == -1)
                 {
                  ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
                  ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
                  ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 188);
                  ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
                  ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
                  ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
                 }
               ObjectSetText(Zi_3_st, Lin_st_170, Lin_in_167, Lin_st_168, Lin_ui_169);
               Lin_in_171 = Zong_19_in_EC;
               Lin_st_172 = Zong_21_st_F8;
               Lin_ui_173 = Brown;
               Lin_st_174 = DoubleToString(AccountProfit(), 2) + "$";
               if(ObjectFind(Zi_10_st) == -1)
                 {
                  ObjectCreate(Zi_10_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
                  ObjectSet(Zi_10_st, OBJPROP_CORNER, Zong_22_in_104);
                  ObjectSet(Zi_10_st, OBJPROP_XDISTANCE, 30);
                  ObjectSet(Zi_10_st, OBJPROP_YDISTANCE, Zi_4_in - Zong_19_in_EC);
                  ObjectSet(Zi_10_st, OBJPROP_BACK, 0.0);
                  ObjectSetString(0, Zi_10_st, 1001, Zong_21_st_F8);
                 }
               ObjectSetText(Zi_10_st, Lin_st_174, Lin_in_171, Lin_st_172, Lin_ui_173);
               Lin_in_175 = Zong_19_in_EC;
               Lin_st_176 = Zong_21_st_F8;
               Lin_ui_177 = Brown;
               Lin_st_178 = DoubleToString(AccountProfit() / Zong_23_do_108 * 100.0, 2) + "%";
               if(ObjectFind(Zi_11_st) == -1)
                 {
                  ObjectCreate(Zi_11_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
                  ObjectSet(Zi_11_st, OBJPROP_CORNER, Zong_22_in_104);
                  ObjectSet(Zi_11_st, OBJPROP_XDISTANCE, 50);
                  ObjectSet(Zi_11_st, OBJPROP_YDISTANCE, Zi_4_in + Zong_19_in_EC * 2);
                  ObjectSet(Zi_11_st, OBJPROP_BACK, 0.0);
                  ObjectSetString(0, Zi_11_st, 1001, Zong_21_st_F8);
                 }
               ObjectSetText(Zi_11_st, Lin_st_178, Lin_in_175, Lin_st_176, Lin_ui_177);
               ObjectSetText(Zi_3_st, "账号亏损：", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, Crimson);
               ObjectSetText(Zi_10_st, DoubleToString(AccountProfit(), 2) + "$", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, Crimson);
               Lin_ui_179 = MistyRose;
               Lin_lo_180 = 0;
               if(ObjectFind(0, Zong_17_st_D0 + "showtotalprofit") <  0)
                 {
                  ObjectCreate(0, Zong_17_st_D0 + "showtotalprofit", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_XDISTANCE, 190);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_YDISTANCE, Zi_4_in);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_XSIZE, 171);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_YSIZE, 60);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BORDER_TYPE, 0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_CORNER, 1);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_COLOR, 8421376);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_STYLE, 0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_WIDTH, 1);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BACK, 0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_SELECTABLE, 0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_SELECTED, 0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_HIDDEN, 1);
                  ObjectSetInteger(0, Zong_17_st_D0 + "showtotalprofit", OBJPROP_ZORDER, 0);
                 }
               ObjectSetInteger(Lin_lo_180, Zong_17_st_D0 + "showtotalprofit", OBJPROP_BGCOLOR, Lin_ui_179);
              }
           }
        }
      Zi_4_in += Zong_19_in_EC * 4;
      Lin_ui_181 = LightCyan;
      Lin_lo_182 = 0;
      if(ObjectFind(0, Zong_17_st_D0 + "EAshowaccountprofit") <  0)
        {
         ObjectCreate(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_XDISTANCE, 298);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_XSIZE, 280);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_YSIZE, 60);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_BORDER_TYPE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_CORNER, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_COLOR, 8421376);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_STYLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_BACK, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_SELECTABLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_SELECTED, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_HIDDEN, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_ZORDER, 0);
        }
      ObjectSetInteger(Lin_lo_182, Zong_17_st_D0 + "EAshowaccountprofit", OBJPROP_BGCOLOR, Lin_ui_181);
      Lin_ui_183 = MistyRose;
      Lin_lo_184 = 0;
      if(ObjectFind(0, Zong_17_st_D0 + "EAshowtotalprofit") <  0)
        {
         ObjectCreate(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_XDISTANCE, 190);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_XSIZE, 171);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_YSIZE, 60);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BORDER_TYPE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_CORNER, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_COLOR, 8421376);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_STYLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BACK, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_SELECTABLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_SELECTED, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_HIDDEN, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_ZORDER, 0);
        }
      ObjectSetInteger(Lin_lo_184, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BGCOLOR, Lin_ui_183);
      Zi_4_in += Zong_19_in_EC * 2;
      Zi_3_st = Zong_17_st_D0 + "EATotalProfit" + "N" ;
      Zi_10_st = Zong_17_st_D0 + "EATotalProfit" + "V" ;
      Zi_11_st = Zong_17_st_D0 + "EATotalProfit" + "P" ;
      if(Zi_6_do == 0.0 && Zi_7_do == 0.0)
        {
         Lin_in_185 = int(Zong_19_in_EC * 1.5);
         Lin_st_186 = Zong_21_st_F8;
         Lin_ui_187 = LightSkyBlue;
         Lin_st_188 = "EA等开仓：";
         if(ObjectFind(Zi_3_st) == -1)
           {
            ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 188);
            ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
            ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_3_st, Lin_st_188, Lin_in_185, Lin_st_186, Lin_ui_187);
         Lin_in_189 = Zong_19_in_EC;
         Lin_st_190 = Zong_21_st_F8;
         Lin_ui_191 = LightSkyBlue;
         Lin_st_192 = "0.00$";
         if(ObjectFind(Zi_10_st) == -1)
           {
            ObjectCreate(Zi_10_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_10_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_10_st, OBJPROP_XDISTANCE, 35);
            ObjectSet(Zi_10_st, OBJPROP_YDISTANCE, Zi_4_in - Zong_19_in_EC);
            ObjectSet(Zi_10_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_10_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_10_st, Lin_st_192, Lin_in_189, Lin_st_190, Lin_ui_191);
         Lin_in_193 = Zong_19_in_EC;
         Lin_st_194 = Zong_21_st_F8;
         Lin_ui_195 = LightSkyBlue;
         Lin_st_196 = "0.00%";
         if(ObjectFind(Zi_11_st) == -1)
           {
            ObjectCreate(Zi_11_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
            ObjectSet(Zi_11_st, OBJPROP_CORNER, Zong_22_in_104);
            ObjectSet(Zi_11_st, OBJPROP_XDISTANCE, 50);
            ObjectSet(Zi_11_st, OBJPROP_YDISTANCE, Zi_4_in + Zong_19_in_EC * 2);
            ObjectSet(Zi_11_st, OBJPROP_BACK, 0.0);
            ObjectSetString(0, Zi_11_st, 1001, Zong_21_st_F8);
           }
         ObjectSetText(Zi_11_st, Lin_st_196, Lin_in_193, Lin_st_194, Lin_ui_195);
         ObjectSetText(Zi_3_st, "EA等开仓：", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, LightSkyBlue);
         ObjectSetText(Zi_10_st, "0.00$", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, LightSkyBlue);
         Lin_ui_197 = Snow;
         Lin_lo_198 = 0;
         if(ObjectFind(0, Zong_17_st_D0 + "EAshowtotalprofit") <  0)
           {
            ObjectCreate(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_XDISTANCE, 190);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_YDISTANCE, Zi_4_in);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_XSIZE, 171);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_YSIZE, 60);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BORDER_TYPE, 0);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_CORNER, 1);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_COLOR, 8421376);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_STYLE, 0);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BACK, 0);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_SELECTABLE, 0);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_SELECTED, 0);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_HIDDEN, 1);
            ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_ZORDER, 0);
           }
         ObjectSetInteger(Lin_lo_198, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BGCOLOR, Lin_ui_197);
        }
      else
        {
         if(AccountProfit() > 0.0)
           {
            Lin_in_199 = int(Zong_19_in_EC * 1.5);
            Lin_st_200 = Zong_21_st_F8;
            Lin_ui_201 = DarkGreen;
            Lin_st_202 = "EA浮盈：";
            if(ObjectFind(Zi_3_st) == -1)
              {
               ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
               ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
               ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 188);
               ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
               ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
               ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
              }
            ObjectSetText(Zi_3_st, Lin_st_202, Lin_in_199, Lin_st_200, Lin_ui_201);
            Lin_in_203 = Zong_19_in_EC;
            Lin_st_204 = Zong_21_st_F8;
            Lin_ui_205 = DarkGreen;
            Lin_st_206 = DoubleToString(Zi_8_do + Zi_9_do, 2) + "$";
            if(ObjectFind(Zi_10_st) == -1)
              {
               ObjectCreate(Zi_10_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
               ObjectSet(Zi_10_st, OBJPROP_CORNER, Zong_22_in_104);
               ObjectSet(Zi_10_st, OBJPROP_XDISTANCE, 30);
               ObjectSet(Zi_10_st, OBJPROP_YDISTANCE, Zi_4_in - Zong_19_in_EC);
               ObjectSet(Zi_10_st, OBJPROP_BACK, 0.0);
               ObjectSetString(0, Zi_10_st, 1001, Zong_21_st_F8);
              }
            ObjectSetText(Zi_10_st, Lin_st_206, Lin_in_203, Lin_st_204, Lin_ui_205);
            Lin_in_207 = Zong_19_in_EC;
            Lin_st_208 = Zong_21_st_F8;
            Lin_ui_209 = DarkGreen;
            Lin_st_210 = DoubleToString((Zi_8_do + Zi_9_do) / Zong_23_do_108 * 100.0, 2) + "%";
            if(ObjectFind(Zi_11_st) == -1)
              {
               ObjectCreate(Zi_11_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
               ObjectSet(Zi_11_st, OBJPROP_CORNER, Zong_22_in_104);
               ObjectSet(Zi_11_st, OBJPROP_XDISTANCE, 50);
               ObjectSet(Zi_11_st, OBJPROP_YDISTANCE, Zi_4_in + Zong_19_in_EC * 2);
               ObjectSet(Zi_11_st, OBJPROP_BACK, 0.0);
               ObjectSetString(0, Zi_11_st, 1001, Zong_21_st_F8);
              }
            ObjectSetText(Zi_11_st, Lin_st_210, Lin_in_207, Lin_st_208, Lin_ui_209);
            ObjectSetText(Zi_3_st, "EA浮盈：", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, Brown);
            ObjectSetText(Zi_10_st, DoubleToString(Zi_8_do + Zi_9_do, 2) + "$", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, Brown);
            Lin_ui_211 = Honeydew;
            Lin_lo_212 = 0;
            if(ObjectFind(0, Zong_17_st_D0 + "EAshowtotalprofit") <  0)
              {
               ObjectCreate(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_XDISTANCE, 190);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_YDISTANCE, Zi_4_in);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_XSIZE, 171);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_YSIZE, 60);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BORDER_TYPE, 0);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_CORNER, 1);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_COLOR, 8421376);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_STYLE, 0);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BACK, 0);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_SELECTABLE, 0);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_SELECTED, 0);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_HIDDEN, 1);
               ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_ZORDER, 0);
              }
            ObjectSetInteger(Lin_lo_212, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BGCOLOR, Lin_ui_211);
           }
         else
           {
            if(AccountProfit() < 0.0)
              {
               Lin_in_213 = int(Zong_19_in_EC * 1.5);
               Lin_st_214 = Zong_21_st_F8;
               Lin_ui_215 = Brown;
               Lin_st_216 = "EA浮亏：";
               if(ObjectFind(Zi_3_st) == -1)
                 {
                  ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
                  ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
                  ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 188);
                  ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
                  ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
                  ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
                 }
               ObjectSetText(Zi_3_st, Lin_st_216, Lin_in_213, Lin_st_214, Lin_ui_215);
               Lin_in_217 = Zong_19_in_EC;
               Lin_st_218 = Zong_21_st_F8;
               Lin_ui_219 = Brown;
               Lin_st_220 = DoubleToString(Zi_8_do + Zi_9_do, 2) + "$";
               if(ObjectFind(Zi_10_st) == -1)
                 {
                  ObjectCreate(Zi_10_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
                  ObjectSet(Zi_10_st, OBJPROP_CORNER, Zong_22_in_104);
                  ObjectSet(Zi_10_st, OBJPROP_XDISTANCE, 30);
                  ObjectSet(Zi_10_st, OBJPROP_YDISTANCE, Zi_4_in - Zong_19_in_EC);
                  ObjectSet(Zi_10_st, OBJPROP_BACK, 0.0);
                  ObjectSetString(0, Zi_10_st, 1001, Zong_21_st_F8);
                 }
               ObjectSetText(Zi_10_st, Lin_st_220, Lin_in_217, Lin_st_218, Lin_ui_219);
               Lin_in_221 = Zong_19_in_EC;
               Lin_st_222 = Zong_21_st_F8;
               Lin_ui_223 = Brown;
               Lin_st_224 = DoubleToString((Zi_8_do + Zi_9_do) / Zong_23_do_108 * 100.0, 2) + "%";
               if(ObjectFind(Zi_11_st) == -1)
                 {
                  ObjectCreate(Zi_11_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
                  ObjectSet(Zi_11_st, OBJPROP_CORNER, Zong_22_in_104);
                  ObjectSet(Zi_11_st, OBJPROP_XDISTANCE, 50);
                  ObjectSet(Zi_11_st, OBJPROP_YDISTANCE, Zi_4_in + Zong_19_in_EC * 2);
                  ObjectSet(Zi_11_st, OBJPROP_BACK, 0.0);
                  ObjectSetString(0, Zi_11_st, 1001, Zong_21_st_F8);
                 }
               ObjectSetText(Zi_11_st, Lin_st_224, Lin_in_221, Lin_st_222, Lin_ui_223);
               ObjectSetText(Zi_3_st, "EA浮亏：", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, Crimson);
               ObjectSetText(Zi_10_st, DoubleToString(Zi_8_do + Zi_9_do, 2) + "$", int(Zong_19_in_EC * 1.5), Zong_21_st_F8, Crimson);
               Lin_ui_225 = MistyRose;
               Lin_lo_226 = 0;
               if(ObjectFind(0, Zong_17_st_D0 + "EAshowtotalprofit") <  0)
                 {
                  ObjectCreate(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_XDISTANCE, 190);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_YDISTANCE, Zi_4_in);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_XSIZE, 171);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_YSIZE, 60);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BORDER_TYPE, 0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_CORNER, 1);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_COLOR, 8421376);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_STYLE, 0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_WIDTH, 1);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BACK, 0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_SELECTABLE, 0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_SELECTED, 0);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_HIDDEN, 1);
                  ObjectSetInteger(0, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_ZORDER, 0);
                 }
               ObjectSetInteger(Lin_lo_226, Zong_17_st_D0 + "EAshowtotalprofit", OBJPROP_BGCOLOR, Lin_ui_225);
              }
           }
        }
      Zi_4_in += Zong_19_in_EC * 4;
      Zi_4_in = int(Zi_4_in + Zong_19_in_EC * 0.5) ;
      Zi_3_st = Zong_17_st_D0 + "BuyOrders" + "N" ;
      Lin_in_227 = Zong_19_in_EC;
      Lin_st_228 = Zong_21_st_F8;
      Lin_ui_229 = CadetBlue;
      Lin_st_230 = "买单:";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 255);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_230, Lin_in_227, Lin_st_228, Lin_ui_229);
      Zi_3_st = Zong_17_st_D0 + "BuyOrders" + "L" ;
      Lin_in_231 = Zong_19_in_EC;
      Lin_st_232 = Zong_21_st_F8;
      Lin_ui_233 = DarkBlue;
      Lin_st_234 = DoubleToString(Zi_6_do, 2) + "手";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 120);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_234, Lin_in_231, Lin_st_232, Lin_ui_233);
      Zi_3_st = Zong_17_st_D0 + "BuyOrders" + "P" ;
      Lin_in_235 = Zong_19_in_EC;
      Lin_st_236 = Zong_21_st_F8;
      Lin_in_237 = Zong_22_in_104;
      Lin_ui_238 = (Zi_8_do >= 0.0) ? 9109504 : 3937500 ;
      Lin_st_239 = DoubleToString(Zi_8_do, 2) + Zi_1_st;
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Lin_in_237);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 25);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Lin_st_236);
        }
      ObjectSetText(Zi_3_st, Lin_st_239, Lin_in_235, Lin_st_236, Lin_ui_238);
      Zi_2_in ++;
      Zi_4_in += Zong_19_in_EC * 2;
      Zi_3_st = Zong_17_st_D0 + "SellOrders" + "N" ;
      Lin_in_240 = Zong_19_in_EC;
      Lin_st_241 = Zong_21_st_F8;
      Lin_ui_242 = Tomato;
      Lin_st_243 = "卖单:";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 255);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_243, Lin_in_240, Lin_st_241, Lin_ui_242);
      Zi_3_st = Zong_17_st_D0 + "SellOrders" + "L" ;
      Lin_in_244 = Zong_19_in_EC;
      Lin_st_245 = Zong_21_st_F8;
      Lin_ui_246 = Tomato;
      Lin_st_247 = DoubleToString(Zi_7_do, 2) + "手";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 120);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_247, Lin_in_244, Lin_st_245, Lin_ui_246);
      Zi_3_st = Zong_17_st_D0 + "SellOrders" + "P" ;
      Lin_in_248 = Zong_19_in_EC;
      Lin_st_249 = Zong_21_st_F8;
      Lin_in_250 = Zong_22_in_104;
      Lin_ui_251 = (Zi_9_do >= 0.0) ? 9109504 : 3937500 ;
      Lin_st_252 = DoubleToString(Zi_9_do, 2) + Zi_1_st;
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Lin_in_250);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 25);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Lin_st_249);
        }
      ObjectSetText(Zi_3_st, Lin_st_252, Lin_in_248, Lin_st_249, Lin_ui_251);
      Zi_2_in ++;
      Zi_4_in += Zong_19_in_EC * 2;
      Zi_3_st = Zong_17_st_D0 + "AllOrders" + "N" ;
      Lin_in_253 = Zong_19_in_EC;
      Lin_st_254 = Zong_21_st_F8;
      Lin_ui_255 = Green;
      Lin_st_256 = "总共:";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 255);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_256, Lin_in_253, Lin_st_254, Lin_ui_255);
      Zi_3_st = Zong_17_st_D0 + "AllOrders" + "L" ;
      Lin_in_257 = Zong_19_in_EC;
      Lin_st_258 = Zong_21_st_F8;
      Lin_ui_259 = DarkBlue;
      Lin_st_260 = DoubleToString(Zi_6_do + Zi_7_do, 2) + "手";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 120);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_260, Lin_in_257, Lin_st_258, Lin_ui_259);
      Zi_3_st = Zong_17_st_D0 + "AllOrders" + "P" ;
      Lin_in_261 = Zong_19_in_EC;
      Lin_st_262 = Zong_21_st_F8;
      Lin_in_263 = Zong_22_in_104;
      Lin_ui_264 = (Zi_8_do + Zi_9_do >= 0.0) ? 9109504 : 3937500 ;
      Lin_st_265 = DoubleToString(Zi_8_do + Zi_9_do, 2) + Zi_1_st;
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Lin_in_263);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 25);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Lin_st_262);
        }
      ObjectSetText(Zi_3_st, Lin_st_265, Lin_in_261, Lin_st_262, Lin_ui_264);
      Zi_4_in = int(Zi_4_in + Zong_19_in_EC * 2.5) ;
      Lin_ui_266 = PowderBlue;
      Lin_lo_267 = 0;
      if(ObjectFind(0, Zong_17_st_D0 + "Separetor1") <  0)
        {
         ObjectCreate(0, Zong_17_st_D0 + "Separetor1", OBJ_RECTANGLE_LABEL, 0, 0, 0.0);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_XDISTANCE, 298);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_XSIZE, 280);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_YSIZE, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_BORDER_TYPE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_CORNER, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_COLOR, 15453831);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_STYLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_BACK, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_SELECTABLE, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_SELECTED, 0);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_HIDDEN, 1);
         ObjectSetInteger(0, Zong_17_st_D0 + "Separetor1", OBJPROP_ZORDER, 0);
        }
      ObjectSetInteger(Lin_lo_267, Zong_17_st_D0 + "Separetor1", OBJPROP_BGCOLOR, Lin_ui_266);
      Zi_4_in = int(Zi_4_in + Zong_19_in_EC * 0.5);
      Zi_3_st = Zong_17_st_D0 + "copyright" + "N" ;
      Lin_in_268 = Zong_19_in_EC;
      Lin_st_269 = Zong_21_st_F8;
      Lin_ui_270 = Green;
      Lin_st_271 = MQLInfoString(MQL_PROGRAM_NAME);
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 125);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_271, Lin_in_268, Lin_st_269, Lin_ui_270);
      Zi_4_in += Zong_19_in_EC * 2;
      Zi_3_st = Zong_17_st_D0 + "Expiration" + "N" ;
      Lin_in_272 = Zong_19_in_EC;
      Lin_st_273 = Zong_21_st_F8;
      Lin_ui_274 = Green;
      Lin_st_275 = " "; // "授权剩余时间:";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 203);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_275, Lin_in_272, Lin_st_273, Lin_ui_274);
      Zi_3_st = Zong_17_st_D0 + "Expiration" + "V" ;
      Lin_in_276 = Zong_19_in_EC;
      Lin_st_277 = Zong_21_st_F8;
      Lin_ui_278 = Green;
      Lin_st_279 = "";//string(Zong_14_in_C8) + "天";
      if(ObjectFind(Zi_3_st) == -1)
        {
         ObjectCreate(Zi_3_st, OBJ_LABEL, 0, 0, 0.0, 0, 0.0, 0, 0.0);
         ObjectSet(Zi_3_st, OBJPROP_CORNER, Zong_22_in_104);
         ObjectSet(Zi_3_st, OBJPROP_XDISTANCE, 155);
         ObjectSet(Zi_3_st, OBJPROP_YDISTANCE, Zi_4_in);
         ObjectSet(Zi_3_st, OBJPROP_BACK, 0.0);
         ObjectSetString(0, Zi_3_st, 1001, Zong_21_st_F8);
        }
      ObjectSetText(Zi_3_st, Lin_st_279, Lin_in_276, Lin_st_277, Lin_ui_278);
      Zi_12_st = "▼" ;
      if(Zong_16_bo_CD == true)
        {
         Zi_12_st = "▲" ;
        }
      lizong_22(Zong_17_st_D0 + "OpenBoard", Zi_12_st, Zi_12_st, 80, Zi_4_in, 40, 20, Zong_22_in_104, 0, 0, Snow, Snow, Zong_21_st_F8, Zong_19_in_EC);
     }
   Zong_24_in_110 = Zi_4_in + Zong_19_in_EC + 25;
  }
//lizong_20 <<==--------   --------
void lizong_21(long Mu_0_lo, string Mu_1_st, int Mu_2_in, int Mu_3_in, int Mu_4_in, int Mu_5_in, int Mu_6_in, string Mu_7_st, string Mu_8_st, int Mu_9_in, bool Mu_10_bo)
  {
   int       Zi_1_in;
   int       Zi_2_in;
//----- -----
   Zi_1_in = (int) ChartGetInteger(Mu_0_lo, 106, 0) ;
   Zi_2_in = (Zi_1_in - Mu_5_in) / 2;
   if(Mu_3_in != 0)
     {
      Zi_2_in = Mu_3_in ;
     }
   if(ObjectFind(Mu_0_lo, Mu_1_st) <  0)
     {
      ObjectCreate(Mu_0_lo, Mu_1_st, OBJ_BITMAP_LABEL, 0, 0, 0.0);
      ObjectSetString(Mu_0_lo, Mu_1_st, 1017, 0, Mu_7_st);
      ObjectSetString(Mu_0_lo, Mu_1_st, 1017, 1, Mu_8_st);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_XDISTANCE, Zi_2_in);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_YDISTANCE, Mu_4_in);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_XSIZE, Mu_5_in);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_YSIZE, Mu_6_in);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_XOFFSET, 0);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_YOFFSET, 0);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_STATE, 0);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_ANCHOR, Mu_9_in);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_COLOR, 255);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_STYLE, 0);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_WIDTH, 1);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_BACK, Mu_10_bo);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_SELECTABLE, 1);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_SELECTED, 0);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_HIDDEN, 1);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_CORNER, Mu_9_in);
      ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_ZORDER, 0);
     }
   ObjectSetInteger(Mu_0_lo, Mu_1_st, OBJPROP_XDISTANCE, Zi_2_in);
  }
//lizong_21 <<==--------   --------
void lizong_22(string Mu_0_st, string Mu_1_st, string Mu_2_st, int Mu_3_in, int Mu_4_in, int Mu_5_in, int Mu_6_in, int Mu_7_in, uint Mu_8_ui, uint Mu_9_ui, uint Mu_10_ui, uint Mu_11_ui, string Mu_12_st, int Mu_13_in)
  {
   if(ObjectFind(0, Mu_0_st) == -1)
     {
      ObjectCreate(0, Mu_0_st, OBJ_BUTTON, 0, 0, 0.0);
     }
   ObjectSetInteger(0, Mu_0_st, OBJPROP_XDISTANCE, Mu_3_in);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_YDISTANCE, Mu_4_in);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_XSIZE, Mu_5_in);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_YSIZE, Mu_6_in);
   ObjectSetString(0, Mu_0_st, OBJPROP_FONT, Mu_12_st);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_FONTSIZE, Mu_13_in);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_CORNER, Mu_7_in);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_HIDDEN, 1);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_BACK, 0);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_SELECTABLE, 0);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_SELECTED, 0);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_BORDER_TYPE, 0);
   if(ObjectGetInteger(0, Mu_0_st, OBJPROP_STATE, 0) == 1)
     {
      ObjectSetInteger(0, Mu_0_st, OBJPROP_COLOR, Mu_8_ui);
      ObjectSetInteger(0, Mu_0_st, OBJPROP_BGCOLOR, Mu_10_ui);
      ObjectSetInteger(0, Mu_0_st, OBJPROP_BORDER_COLOR, Mu_10_ui);
      ObjectSetString(0, Mu_0_st, OBJPROP_TEXT, Mu_2_st);
      return;
     }
   ObjectSetInteger(0, Mu_0_st, OBJPROP_COLOR, Mu_9_ui);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_BGCOLOR, Mu_11_ui);
   ObjectSetInteger(0, Mu_0_st, OBJPROP_BORDER_COLOR, Mu_11_ui);
   ObjectSetString(0, Mu_0_st, OBJPROP_TEXT, Mu_1_st);
  }
//<<==lizong_22 <<==


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool UseCheck()
  {
   bool res = false;
   string promptMsg = "";
   string setAccount = Bind_Account;
   string setCompany = Company;
   datetime useExpiration = Use_Expiration_Time;
   if(Account_Control)
     {
      string useAccount[];
      int k = StringSplit(setAccount, useAccount, "+");
      for(int i = 0; i < k; i++)
        {
         if(AccountInfoInteger(ACCOUNT_LOGIN) == (int)useAccount[i])
           {
            res = true;
            break;
           }
        }
      if(!res)
         promptMsg = Account_Error_Reminder_Content;
     }
   else
     {
      res = true;
     }
   if(Time_Control && TimeCurrent() > useExpiration)
     {
      AddToPrompt(promptMsg, The_Deadline_Has_Reached_The_Reminder_Content);
      res = false;
     }
   if(Company_control && setCompany != "")
     {
      string company = AccountInfoString(ACCOUNT_COMPANY);
      if(StringFind(company, setCompany) < 0)
        {
         AddToPrompt(promptMsg, Company_Error_Reminder_Content);
         res = false;
        }
     }
   if(!res && promptMsg != "")
     {
      Alert(promptMsg);
     }
   return res;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AddToPrompt(string &msg, string newMsg)
  {
   if(msg != "")
      msg += "\n" + newMsg;
   else
      msg = newMsg;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int StringSplit(string string_value, string &result[], string separator, string SEP = NULL)
  {
   StringTrimLeft(string_value);
   StringTrimRight(string_value);
   if(SEP != NULL)
      StringReplace(string_value, SEP, separator);
   ArrayFree(result);
   ushort u_sep = StringGetCharacter(separator, 0);
   return StringSplit(string_value, u_sep, result);
  }
//+------------------------------------------------------------------+
