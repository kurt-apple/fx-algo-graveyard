//old zone trading bot with old observations in comments

//TEST: save profit trades
//TEST: maximum stops
#property copyright "2016, Kurt Apple"
#property version   "9.00"
#property strict
extern double RISK = 0.012;
//VERDICT: I never want a trade entry to be below $1 risk. Otherwise the commissions will eat everything.
//VERDICT: ORDERSMAX is no longer extern because it is algorithmically determined in adjustORDERSMAX and once a week.
double ORDERSMAX = 10.0;
//OBSERVATION: ordersmax needs to rely on acctmin
//TEST: MINRISKDOLLARS
//OBERVATION: minRISKusd could also be programmatically set.
//OBSERVATION: minRISKusd does not affect the result of the program.
extern double minRISKusd = 1.0;
void adjustORDERSMAX(double MinRiskDollars) { while(((RISK*AccountBalance())/ORDERSMAX) < MinRiskDollars && (ORDERSMAX >= 2)) ORDERSMAX--;}
//OBSERVATION: at this moment, still in a situation where ORDERSMAX might become out of proportion and force itself into much too large an entry
extern double stoplossmultiplier = 3.5;
extern double acctminratio = 0.95;
double ACCTMIN = acctminratio * AccountBalance();
extern int ATRperiod = 20;
double savings = 0;
datetime lasttimeclose = 0;
//TEST: adjust period w/extern for acctmin adjust
int TICKET;
enum INDICATOR_SIGNAL_COLORS {XGREEN = 2, XGRAY, XRED};
double LOTS()
{	//TEST: decrease ORDERSMAX in order to minimize risk per trade when necessary.
	//OBSERVATION: I will then need something to raise ORDERSMAX.
	//TEST: place in Event Timer?
	return MathMax(NormalizeDouble((RISK/ORDERSMAX) * (AccountBalance()-savings) / (MarketInfo(Symbol(), MODE_LOTSIZE) * stoplossmultiplier * iATR(NULL, 0, ATRperiod, 0)), 2), 0.01);
}
int IndAC(int POS = 0) {return (iAC(NULL, 0, POS) < iAC(NULL, 0, POS + 1)) ? 2 : 1;}
int IndAO(int POS = 0) {return (iAO(NULL, 0, POS) < iAO(NULL, 0, POS + 1)) ? 2 : 1;}
int IndColor(int POS = 0) {return IndAO(POS) + IndAC(POS);}
void OnInit()
{	EventSetTimer(PeriodSeconds());
}
//TEST: vary timer period based on PeriodSeconds()
//VERDICT: varying timer period does minimal effect on the processing of this strategy.
void OnTimer()
{	//TEST: first monday of the month on the first hour: change account min stops.
	if(Day() < 7 && DayOfWeek() == 1 && Hour() == 0)
	{	ACCTMIN = acctminratio * AccountBalance();
		//TEST: the first monday of each month, chance to increase ORDERSMAX by 1.
		if(((RISK*(AccountBalance()-savings))/ORDERSMAX) > minRISKusd) ORDERSMAX++;
	}
	if(OrdersTotal() != 0)
	{	if(!OrderSelect(0, SELECT_BY_POS)) Alert("Failed to select last order");
		if(OrderType() == OP_BUY && IndColor() == XGREEN && OrdersTotal() < ORDERSMAX)
		{	adjustORDERSMAX(minRISKusd);
			TICKET = OrderSend(NULL, OP_BUY, LOTS(), Ask, 10, Ask - stoplossmultiplier*iATR(NULL, 0, ATRperiod, 0), 0, NULL, 0, 0, clrAliceBlue);
		}
		if(OrderType() == OP_SELL && IndColor() == XRED	&& OrdersTotal() < ORDERSMAX)
		{	adjustORDERSMAX(minRISKusd);
			TICKET = OrderSend(NULL, OP_SELL, LOTS(), Bid, 10, Bid + stoplossmultiplier*iATR(NULL, 0, ATRperiod, 0), 0, NULL, 0, 0, clrAntiqueWhite);
		}
		for(int i = 1; i < OrdersTotal(); i++)
		{	if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
			{	if(IndColor() == XRED && OrderType() == OP_BUY && OrderLots()>0.01)
				{	if(!OrderClose(OrderTicket(), 0.01, Bid, 10, clrAliceBlue)) Alert("Failed to partial close trade");
					continue;
				}
				if(IndColor() == XGREEN && OrderType() == OP_SELL && OrderLots()>0.01)
				{	if(!OrderClose(OrderTicket(), 0.01, Ask, 10, clrAntiqueWhite)) Alert("Failed to partial close trade");
					continue;
}	}	}	}	}

void OnTick()
{	if(OrderSelect(0, SELECT_BY_POS,MODE_HISTORY) && OrderSymbol()==Symbol() && OrderProfit()>minRISKusd && OrderCloseTime() > lasttimeclose)
	{	savings += minRISKusd;
		lasttimeclose = OrderCloseTime();
	}
	if(AccountBalance() <= ACCTMIN) ExpertRemove();
	//OBSERVATION: DayOfWeek() code for ACCTMIN would execute too frequently on the first day and not give accurate results.
	//TEST: place into event timer.
	//OBSERVATION: my program in early test was hedging. In order to eliminate this behavior, it has to have a mechanism to detect what has previously been put on.
	//TEST: if orderstotal != 0 then only add to position in the correct direction. otherwise add any new order.
	//OBSERVATION: my program will not size its entry appropriately if it checks indicators every tick.
	//TEST: move all order entry into Event Timer.
	//VERDICT: moving order entry to event timer ensured that positions were entered at a sane time and pace
	else if(OrdersTotal()==0)
	{	if(IndColor() == XGREEN)
		{	adjustORDERSMAX(minRISKusd);
			if(OrdersTotal() < ORDERSMAX) TICKET = OrderSend(NULL, OP_BUY, LOTS(), Ask, 10, Ask - stoplossmultiplier*iATR(NULL, 0, ATRperiod, 0), 0, NULL, 0, 0, clrAliceBlue);
		}
		else if(IndColor() == XRED)
		{	adjustORDERSMAX(minRISKusd);
			if(OrdersTotal() < ORDERSMAX) TICKET = OrderSend(NULL, OP_SELL, LOTS(), Bid, 10, Bid + stoplossmultiplier*iATR(NULL, 0, ATRperiod, 0), 0, NULL, 0, 0, clrAntiqueWhite);
	}	}
	for(int i = OrdersTotal() - 1; i >= 0; i--)
	{	if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
		{	//VERDICT: by testing if OrderLots is greater or equal to LOTS, you are seeing if the account can still handle the position. This limits risk.
			//a multiplier was on LOTS but I tested and it made little difference for any multiplier > 0.5. Values over 1 have limited meaning.
			//VERDICT: reactive partial closes of more than 0.01 lot did not have perceptible benefit in tests.
			//temporarily moved to ontimer
			//VERDICT: after testing I have concluded that an increment or step > 1 in a trailing stop is not beneficial to this strategy.
			//OBSERVATION: the code currently gives a virtual trailing stop of just 1 point.
			//TEST: trail 1 ATR
			//TEST: trail stoplossmultiplier ATR
			if(OrderType() == OP_BUY && (OrderStopLoss() + Point < Bid-stoplossmultiplier*iATR(NULL, 0, 10, 0)) /*&& (OrderOpenPrice() + Point < Bid-stoplossmultiplier*iATR(NULL, 0, 10, 0))*/)
			{	if(!OrderModify(OrderTicket(), OrderOpenPrice(), Bid-stoplossmultiplier*iATR(NULL, 0, 10, 0), OrderTakeProfit(), 0, clrAliceBlue)) Alert("Failed to modify stoploss on BUY");
				continue;
			}
			if(OrderType() == OP_SELL && (OrderStopLoss() - Point > Ask+stoplossmultiplier*iATR(NULL, 0, 10, 0)) /*&& (OrderOpenPrice() - Point > Ask+stoplossmultiplier*iATR(NULL, 0, 10, 0))*/)
			{	if(!OrderModify(OrderTicket(), OrderOpenPrice(), Ask+stoplossmultiplier*iATR(NULL, 0, 10, 0), OrderTakeProfit(), 0, clrAntiqueWhite)) Alert("Failed to modify stoploss on SELL");
				continue;
}	}	}	}