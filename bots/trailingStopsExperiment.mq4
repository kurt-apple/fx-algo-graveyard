//early trailing stops experiments

enum INDICATOR_SIGNAL_COLORS {XGREEN = 2, XGRAY, XRED};
int IndAC(int POS = 0) {return (iAC(NULL, 0, POS) < iAC(NULL, 0, POS + 1)) ? 2 : 1;}
int IndAO(int POS = 0) {return (iAO(NULL, 0, POS) < iAO(NULL, 0, POS + 1)) ? 2 : 1;}
int IndColor(int POS = 0) {return IndAO(POS) + IndAC(POS);}

extern double RISKp = 0.01;		//step 0.005
extern double SLfactor = 2.0;		//step 0.1
extern double SLaccount = 0.8;		//step 0.1
extern int ATRperiod = 6;		//step 2
extern double TrailStopRatioIn = 0.1;	//step 0.1
double TrailStopRatio = TrailStopRatioIn;
double StopLoss() {return MathMax(NormalizeDouble(SLfactor*iATR(NULL, NULL, ATRperiod, 0), Digits), 10*Point);}
double LOTS(double RISK) {return NormalizeDouble(RISK * AccountBalance() / (MarketInfo(Symbol(), MODE_LOTSIZE) * StopLoss()), 2);}
double ACCTMIN = SLaccount*AccountBalance();
datetime lastBar = Time[0];

void OnTick()
{	if(Time[0] != lastBar)
	{	if(AccountBalance() <= ACCTMIN) ExpertRemove();
		if(DayOfWeek() == 1 && Hour() == 0 && Minute() == 0)
		{	ACCTMIN *= 1.001;
			if(OrdersTotal() != 0)
			{	if(OrderSelect(0, SELECT_BY_POS, MODE_TRADES))
				{	if(OrderType() == OP_BUY) OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit()*1.001, NULL, clrNONE);
					else if(OrderType() == OP_SELL) OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit()*1.001, NULL, clrNONE);
		}	}	}
		lastBar = Time[0];
	}
	if(OrdersTotal() == 0)
	{	TrailStopRatio = TrailStopRatioIn;
		if(IndColor() == XGREEN){OrderSend(NULL, OP_BUY, LOTS(RISKp), Ask, 10*Point, Ask-StopLoss(), Ask+2*StopLoss(), NULL, 0, 0, clrNONE);}
		if(IndColor() == XRED){OrderSend(NULL, OP_SELL, LOTS(RISKp), Bid, 10*Point, Bid+StopLoss(), Bid-2*StopLoss(), NULL, 0, 0, clrNONE);}
	}
	else if(OrdersTotal() != 0)
	{	if(OrderSelect(0, SELECT_BY_POS, MODE_TRADES))
		{	if(OrderType() == OP_BUY && (OrderStopLoss() + Point < Bid-TrailStopRatio*StopLoss()))
			{	if(IndColor() == XRED) TrailStopRatio *= 0.99; 
				if(!OrderModify(OrderTicket(), OrderOpenPrice(), Bid-TrailStopRatio*StopLoss(), 0, 0, clrNONE)) Alert("Failed to modify stoploss on BUY");
			}
			if(OrderType() == OP_SELL && (OrderStopLoss() - Point > Ask+TrailStopRatio*StopLoss()))
			{	if(IndColor() == XGREEN) TrailStopRatio *= 0.99;
				if(!OrderModify(OrderTicket(), OrderOpenPrice(), Ask+TrailStopRatio*StopLoss(), 0, 0, clrNONE)) Alert("Failed to modify stoploss on SELL");
}	}	}	}