//+------------------------------------------------------------------+
//|                 MT5_AVWAP_PRO_V2_MASTER.mq5                      |
//|        Professional Anchored VWAP System (All Buffer Mode)       |
//|        CORE MASTER BUILD - Stable Foundation Version             |
//|                                                                  |
//| 포함 기능                                                        |
//| [자동 앵커]                                                      |
//| 1 Today Open                                                     |
//| 2 Today High                                                     |
//| 3 Today Low                                                      |
//| 4 Yesterday High                                                 |
//| 5 Yesterday Low                                                  |
//| 6 Asia Open (01:00 fixed)                                        |
//| 7 London Open                                                    |
//| 8 New York Open                                                  |
//|                                                                  |
//| 다음 단계 확장 예정                                              |
//| - 뉴스 앵커                                                      |
//| - Ctrl+Click 수동 앵커                                           |
//| - DST 자동화                                                     |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 16
#property indicator_plots   8

//====================================================
// Plot Settings
//====================================================
#property indicator_label1  "Today Open"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime,clrRed
#property indicator_width1  2

#property indicator_label2  "Today High"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrLime,clrRed
#property indicator_width2  2

#property indicator_label3  "Today Low"
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  clrLime,clrRed
#property indicator_width3  2

#property indicator_label4  "Yesterday High"
#property indicator_type4   DRAW_COLOR_LINE
#property indicator_color4  clrLime,clrRed
#property indicator_width4  2

#property indicator_label5  "Yesterday Low"
#property indicator_type5   DRAW_COLOR_LINE
#property indicator_color5  clrLime,clrRed
#property indicator_width5  2

#property indicator_label6  "Asia Open"
#property indicator_type6   DRAW_COLOR_LINE
#property indicator_color6  clrLime,clrRed
#property indicator_width6  2

#property indicator_label7  "London Open"
#property indicator_type7   DRAW_COLOR_LINE
#property indicator_color7  clrLime,clrRed
#property indicator_width7  2

#property indicator_label8  "New York Open"
#property indicator_type8   DRAW_COLOR_LINE
#property indicator_color8  clrLime,clrRed
#property indicator_width8  2

//====================================================
// Inputs
//====================================================
input bool UseTodayOpen     = true;
input bool UseTodayHigh     = true;
input bool UseTodayLow      = true;
input bool UseYHigh         = true;
input bool UseYLow          = true;
input bool UseAsia          = true;
input bool UseLondon        = true;
input bool UseNY            = true;

input int  AsiaOpenHour     = 1;    // Asia session open hour (server time)
input int  LondonOpenHour   = 8;    // London session open hour (server time)
input int  NYOpenHour       = 13;   // New York session open hour (server time)

//====================================================
// Buffers
//====================================================
double B1[], C1[];
double B2[], C2[];
double B3[], C3[];
double B4[], C4[];
double B5[], C5[];
double B6[], C6[];
double B7[], C7[];
double B8[], C8[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0,  B1, INDICATOR_DATA);
   SetIndexBuffer(1,  C1, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(2,  B2, INDICATOR_DATA);
   SetIndexBuffer(3,  C2, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(4,  B3, INDICATOR_DATA);
   SetIndexBuffer(5,  C3, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(6,  B4, INDICATOR_DATA);
   SetIndexBuffer(7,  C4, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(8,  B5, INDICATOR_DATA);
   SetIndexBuffer(9,  C5, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(10, B6, INDICATOR_DATA);
   SetIndexBuffer(11, C6, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(12, B7, INDICATOR_DATA);
   SetIndexBuffer(13, C7, INDICATOR_COLOR_INDEX);

   SetIndexBuffer(14, B8, INDICATOR_DATA);
   SetIndexBuffer(15, C8, INDICATOR_COLOR_INDEX);

   for(int i = 0; i < 8; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| 특정 시간 앵커 VWAP 계산                                         |
//| anchor == 0 이면 전 구간을 EMPTY_VALUE 로 채워 그리지 않음       |
//+------------------------------------------------------------------+
void CalcAVWAP(const int       rates_total,
               const datetime &time[],
               const double   &high[],
               const double   &low[],
               const double   &close[],
               const long     &vol[],
               datetime        anchor,
               double         &buf[],
               double         &clr[])
{
   // 앵커가 없으면 전 구간 숨김
   if(anchor == 0)
   {
      ArrayFill(buf, 0, rates_total, EMPTY_VALUE);
      return;
   }

   double pv      = 0.0;
   double vv      = 0.0;
   bool   started = false;

   for(int i = 0; i < rates_total; i++)
   {
      // 앵커 이전 구간은 표시하지 않음
      if(!started)
      {
         if(time[i] < anchor)
         {
            buf[i] = EMPTY_VALUE;
            clr[i] = 0.0;
            continue;
         }
         // 앵커 바 도달 — 누적 초기화
         started = true;
         pv = 0.0;
         vv = 0.0;
      }

      // Typical Price = (High + Low + Close) / 3
      double tp = (high[i] + low[i] + close[i]) / 3.0;
      double v  = (double)vol[i];

      if(v > 0)
      {
         pv += tp * v;
         vv += v;
      }

      buf[i] = (vv > 0) ? pv / vv : tp;

      // 색상: Close >= AVWAP → Lime(0, 상승), Close < AVWAP → Red(1, 하락)
      clr[i] = (close[i] >= buf[i]) ? 0.0 : 1.0;
   }
}

//+------------------------------------------------------------------+
//| 특정 시간(hour)의 세션 오픈 datetime 반환                        |
//| now 시각 기준 당일 해당 시간이 미래면 전일로 롤백                |
//+------------------------------------------------------------------+
datetime GetSessionOpen(int hourGMT, datetime now)
{
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = hourGMT;
   dt.min  = 0;
   dt.sec  = 0;
   datetime sessionTime = StructToTime(dt);
   if(sessionTime > now)
      sessionTime -= 86400; // 아직 오픈 전이면 어제로
   return sessionTime;
}

//+------------------------------------------------------------------+
//| Main calculation                                                 |
//+------------------------------------------------------------------+
int OnCalculate(const int      rates_total,
                const int      prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
   if(rates_total < 1)
      return 0;

   // 실거래량 없는 브로커는 tick_volume 사용
   const bool useRealVol = (volume[rates_total - 1] > 0);

   // 마지막 바 시각을 기준 시각으로 사용
   datetime now = time[rates_total - 1];

   //------------------------------------------------------------
   // 오늘 / 어제 경계 계산
   //------------------------------------------------------------
   MqlDateTime dtNow;
   TimeToStruct(now, dtNow);
   dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
   datetime todayStart     = StructToTime(dtNow);
   datetime yesterdayStart = todayStart - 86400;

   //------------------------------------------------------------
   // 앵커 datetime 초기화
   //------------------------------------------------------------
   datetime anchorTodayOpen = todayStart; // Today Open = 당일 자정
   datetime anchorTodayHigh = 0;
   datetime anchorTodayLow  = 0;
   datetime anchorYHigh     = 0;
   datetime anchorYLow      = 0;

   double todayHigh = -DBL_MAX, todayLow =  DBL_MAX;
   double yHigh     = -DBL_MAX, yLow     =  DBL_MAX;

   //------------------------------------------------------------
   // 전 바 스캔: 오늘 고/저, 어제 고/저 앵커 탐색
   //------------------------------------------------------------
   for(int i = 0; i < rates_total; i++)
   {
      if(time[i] >= todayStart)
      {
         if(high[i] > todayHigh) { todayHigh = high[i]; anchorTodayHigh = time[i]; }
         if(low[i]  < todayLow)  { todayLow  = low[i];  anchorTodayLow  = time[i]; }
      }
      else if(time[i] >= yesterdayStart)
      {
         if(high[i] > yHigh) { yHigh = high[i]; anchorYHigh = time[i]; }
         if(low[i]  < yLow)  { yLow  = low[i];  anchorYLow  = time[i]; }
      }
   }

   //------------------------------------------------------------
   // 세션 오픈 앵커
   //------------------------------------------------------------
   datetime anchorAsia   = GetSessionOpen(AsiaOpenHour,   now);
   datetime anchorLondon = GetSessionOpen(LondonOpenHour, now);
   datetime anchorNY     = GetSessionOpen(NYOpenHour,     now);

   //------------------------------------------------------------
   // 각 AVWAP 계산
   //------------------------------------------------------------
   // 공용 볼륨 배열 선택
   #define VOL (useRealVol ? volume : tick_volume)

   if(UseTodayOpen)
      CalcAVWAP(rates_total, time, high, low, close, VOL, anchorTodayOpen, B1, C1);
   else
      ArrayFill(B1, 0, rates_total, EMPTY_VALUE);

   if(UseTodayHigh)
      CalcAVWAP(rates_total, time, high, low, close, VOL, anchorTodayHigh, B2, C2);
   else
      ArrayFill(B2, 0, rates_total, EMPTY_VALUE);

   if(UseTodayLow)
      CalcAVWAP(rates_total, time, high, low, close, VOL, anchorTodayLow,  B3, C3);
   else
      ArrayFill(B3, 0, rates_total, EMPTY_VALUE);

   if(UseYHigh)
      CalcAVWAP(rates_total, time, high, low, close, VOL, anchorYHigh,     B4, C4);
   else
      ArrayFill(B4, 0, rates_total, EMPTY_VALUE);

   if(UseYLow)
      CalcAVWAP(rates_total, time, high, low, close, VOL, anchorYLow,      B5, C5);
   else
      ArrayFill(B5, 0, rates_total, EMPTY_VALUE);

   if(UseAsia)
      CalcAVWAP(rates_total, time, high, low, close, VOL, anchorAsia,      B6, C6);
   else
      ArrayFill(B6, 0, rates_total, EMPTY_VALUE);

   if(UseLondon)
      CalcAVWAP(rates_total, time, high, low, close, VOL, anchorLondon,    B7, C7);
   else
      ArrayFill(B7, 0, rates_total, EMPTY_VALUE);

   if(UseNY)
      CalcAVWAP(rates_total, time, high, low, close, VOL, anchorNY,        B8, C8);
   else
      ArrayFill(B8, 0, rates_total, EMPTY_VALUE);

   #undef VOL

   return rates_total;
}
//+------------------------------------------------------------------+
