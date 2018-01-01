// barebones forex pair scanner
// lists all symbols as a Comment(string) in top left corner of open chart.



//+------------------------------------------------------------------+
//|                                            symbol_scanner_01.mq4 |
//|                                                         void_xxx |
//+------------------------------------------------------------------+
#property copyright "void_xxx"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

string linecontent;
void commentsymbolstotal()
{       for(int i = 0; i < SymbolsTotal(false); i++)
        {       linecontent += IntegerToString(i) + "/" + IntegerToString(SymbolsTotal(false)) + " " + SymbolName(i, false) + ", ";
                if(i%11==0) linecontent+="\n";
        }
        Comment(linecontent);
}

int OnInit()
  {
//---
   commentsymbolstotal();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
