//2016 Kurt Apple
//This was I think my first custom indicator. I then moved from this to a custom chart interpretation
//Experimentations based on a strategy I believe is called "In The Zone," could be remembering that wrong
//uses AC and AO for direction.

#property strict
#property indicator_separate_window
#property indicator_minimum -1
#property indicator_maximum 1

#property indicator_buffers 3
#property indicator_color1 Black
#property indicator_color2 Red
#property indicator_color3 RoyalBlue

#property indicator_width2 3
#property indicator_width3 3

//buffers.
double ExtZTBuffer[], ExtBlueBuffer[], ExtRedBuffer[];

//+------------------------------------------------------------------+
//red = -1, green = 1
double zonA(string pair, int pos) { return iAC(pair, 0, pos+1) > iAC(pair, 0, pos) ? -1 : 1; }
double zonB(string pair, int pos) { return iAO(pair, 0, pos+1) > iAO(pair, 0, pos) ? -1 : 1; }
double zone(string pair, int pos) { return zonA(pair, pos) + zonB(pair, pos); }
//+------------------------------------------------------------------+

#define DATA_LIMIT 34

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
        SetIndexStyle(0,DRAW_NONE);
        SetIndexStyle(1, DRAW_HISTOGRAM);
        SetIndexStyle(2, DRAW_HISTOGRAM);
        SetIndexDrawBegin(0, DATA_LIMIT);
        SetIndexDrawBegin(1, DATA_LIMIT);
        SetIndexDrawBegin(2, DATA_LIMIT);
        SetIndexBuffer(0, ExtZTBuffer);
        SetIndexBuffer(1, ExtRedBuffer);
        SetIndexBuffer(2, ExtBlueBuffer);
        IndicatorShortName("ZTV");
        SetIndexLabel(1, NULL);
        SetIndexLabel(2, NULL);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
        int i, limit = rates_total-prev_calculated;
        double prev=0, current;
        if(rates_total<=DATA_LIMIT) return(0);
        if(prev_calculated>0)
        {       limit++;
                prev=ExtZTBuffer[limit];
        }
        for(i = 0; i < limit; i++) ExtZTBuffer[i] = zone(NULL, i);
        for(i = limit - 1; i >= 0; i--)
        {       current = ExtZTBuffer[i];
                if(current < 0)
                {       ExtRedBuffer[i] = current;
                        ExtBlueBuffer[i] = 0;
                }
                else if(current > 0)
                {       ExtBlueBuffer[i] = current;
                        ExtRedBuffer[i] = 0;
                }
                else
                {       ExtBlueBuffer[i] = 0.3;
                        ExtRedBuffer[i] = -0.3;
                }
                prev = current;
        }
//--- return value of prev_calculated for next call
   return(rates_total);
  }

