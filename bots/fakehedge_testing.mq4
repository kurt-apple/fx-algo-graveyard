
#property strict

//simple "hedge" bot

//I became interested in hedging strategies, and I think that under many circumstances, they can be valid (mind the broker fees)
//but FIFO (First in First out) and other regulations hamper a trader's ability to hedge if their strategy called for it.

//workarounds:
//      // place orders with slightly varying lot sizes. FIFO only applies (IIRC) to orders of same symbol and same lot size.
//      // partially close an existing order. if you have 1.0 lots, and you want to partially hedge, close half.
//      // this is not ultimately the same as hedging, but does offer its own advantages.

// personally, more testing is required, especially with my newer money management strategy.

extern double multiple = 2.5;
extern int PeriodATR = 20;
extern double orderlots = 0.05;
extern double closelots = 0.01;
extern double maxorders = 10;
double orders_current = 0;
double BotPeriod = ChartPeriod();

/*this internal method to retrieve current period is handy for transferring period from one chart to another    **      
**it is also essential when iterating between different timeframes frequently. i++ versus hardcoded period changes
**this is because each constant is valued at the amount of time it represents. Not smooth in default format */
int PRDARR[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
int PRDIND = 0; //current period (index of period selection array)

enum xcolors {xgreen = 2, xgray, xred}; //xcolors is an enum to better visualize the zones determined by AC/AO comparisons
short zonA(string pair, int periodindex) { return iAC(pair, PRDARR[periodindex], 1) > iAC(pair, PRDARR[periodindex], 0) ? 2 : 1; }
short zonB(string pair, int periodindex) { return iAO(pair, PRDARR[periodindex], 1) > iAO(pair, PRDARR[periodindex], 0) ? 2 : 1; }
short zone(string pair, int periodindex) { return zonA(pair, periodindex) + zonB(pair, periodindex); }
short uberzone(string pair, int periodindex)
{       if(periodindex == 8) return zone(pair, periodindex);
        else
        {       if(zone(pair, periodindex) == zone(pair, periodindex+1)) return zone(pair, periodindex);
                else return xgray;
}       }

void GetChartPeriodIndex()//during init we need to fetch current chart period and convert it to a more friendly format
{	int chartperiod = ChartPeriod(); //get the chartperiod of the current chart
	for(int i = 0; i < 8; i++) //iterate through all different possible chart periods.
	{	if(chartperiod == PRDARR[i]) //if they are the same, then set the index
		{	PRDIND = i;
			return;
	}	} //QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS
	return; //if it gets to here then it will start on the first chart and all charts may switch to it
} //QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS QUADS

//OP_BUY: 0. OP_SELL: 1.
int OrdersTotalType(int magicno)
{	for(int i = OrdersTotal() - 1; i >= 0; i--)
	{	if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
		{	Alert("error selecting order");
			ExitProgram();
		}
		else if (OrderMagicNumber() == magicno) return OrderType();
	}
	return -1;
}

bool CloseOldest(int magicno, double lots)
{       int histlength = OrdersTotal();
        for(int i = histlength - 1; i >= 0; i--)
        {       if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                {       Alert("error selecting order");
                        ExitProgram();
                }
                else if(OrderMagicNumber() == magicno)
                {       return OrderClose(OrderTicket(), lots, (OrderType() == OP_BUY ? Bid : Ask), 10, clrNONE);
        }       }
        return false;
}

void ExitProgram()
{       ExpertRemove();
}

int OnInit()
{       return(INIT_SUCCEEDED);
        GetChartPeriodIndex();
        Sleep(1000*(TimeSeconds(TimeLocal()) + 20));
        EventSetTimer(PRDARR[PRDIND]*60);
}

void OnTick()
{       if(uberzone(Symbol(), PRDIND) == xgreen && OrdersTotalType(magic) != OP_SELL)
        {       openticket = OrderSend(Symbol(), OP_BUY, orderlots, Ask, 10, Bid-multiple*iATR(Symbol(), PRDARR[PRDIND], PeriodATR, 0), Bid+(multiple*2*iATR(Symbol(), PRDARR[PRDIND], PeriodATR, 0)), NULL, magic, 0, clrNONE);
                orders_current += openticket > 0 ? 1 : 0;
        }
        else if(uberzone(Symbol(), PRDIND) == xred && OrdersTotalType(magic) != OP_BUY)
        {       openticket = OrderSend(Symbol(), OP_SELL, orderlots, Bid, 10, Ask+multiple*iATR(Symbol(), PRDARR[PRDIND], PeriodATR, 0), Ask-(multiple*2*iATR(Symbol(), PRDARR[PRDIND], PeriodATR, 0)), NULL, magic, 0, clrNONE);
                orders_current += openticket > 0 ? 1 : 0;
        }
        if(OrdersTotal() > 0)
        {       if(uberzone(Symbol(), PRDIND) == xgreen && OrdersTotalType(magic) != OP_BUY)
                {       CloseOldest(magic, closelots);
                        orders_current -= closeticket ? closelots/orderlots : 0;
                }
                else if(uberzone(Symbol(), PRDIND) == xred && OrdersTotalType(magic) != OP_SELL)
                {       CloseOldest(magic, closelots);
                        orders_current -= closeticket ? closelots/orderlots : 0;
                }
                for(int i = OrdersTotal() - 1; i >= 0; i--)
        	{	if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        		{	if(OrderSymbol() == ChartSymbol())
        			{	if(OrderType() == OP_BUY)
        				{	if(OrderStopLoss() + Point() < Bid - (multiple*iATR(OrderSymbol(), PRDARR[PRDIND], PeriodATR, 0)))
        					{	OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss()+Point(), 0, 0, clrNONE);
        			        }	}
        				if(OrderType() == OP_SELL)
        				{	if(OrderStopLoss() - Point() > (multiple*iATR(OrderSymbol(), PRDARR[PRDIND], PeriodATR, 0)) + Ask)
        					{	OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss()+Point(), 0, 0, clrNONE);
}	}	}	}       }       }       }
int openticket = 0;
bool closeticket = false;
void OnTimer()
{       if(uberzone(Symbol(), PRDIND) == xgreen && OrdersTotalType(magic) != OP_SELL)
        {       openticket = OrderSend(Symbol(), OP_BUY, orderlots, Ask, 10, Bid-multiple*iATR(Symbol(), PRDARR[PRDIND], PeriodATR, 0), Bid+(multiple*2*iATR(Symbol(), PRDARR[PRDIND], PeriodATR, 0)), NULL, magic, 0, clrNONE);
                orders_current += openticket > 0 ? 1 : 0;
        }
        else if(uberzone(Symbol(), PRDIND) == xred && OrdersTotalType(magic) != OP_BUY)
        {       openticket = OrderSend(Symbol(), OP_SELL, orderlots, Bid, 10, Ask+multiple*iATR(Symbol(), PRDARR[PRDIND], PeriodATR, 0), Ask-(multiple*2*iATR(Symbol(), PRDARR[PRDIND], PeriodATR, 0)), NULL, magic, 0, clrNONE);
                orders_current += openticket > 0 ? 1 : 0;
        }
        if(OrdersTotal() > 0)
        {       if(uberzone(Symbol(), PRDIND) == xgreen && OrdersTotalType(magic) != OP_BUY)
                {       closeticket = CloseOldest(magic, closelots);
                        orders_current -= closeticket ? closelots/orderlots : 0;
                }
                else if(uberzone(Symbol(), PRDIND) == xred && OrdersTotalType(magic) != OP_SELL)
                {       closeticket = CloseOldest(magic, closelots);
                        orders_current -= closeticket ? closelots/orderlots : 0;
}       }       }