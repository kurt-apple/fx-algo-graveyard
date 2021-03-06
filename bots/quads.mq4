//attempted to make a bot that leveraged a "quad" of related currency exchanges.
//No testing has been done since MetaTrader 4 can only backtest upon one pair at a time, but I still am intrigued by the idea.
//I also want to use a DAG to hop from one pair to another. All problems are solved with DAGs.
#property copyright	"Kurt Apple"
#property link		"kapplepi@gmail.com"
#property version	"11.85" //versioning. loosely, intuitively defined
#property strict	//conforms to newest standard of MQL4 language
#define PRDCUR PRDARR[PRDIND] //grabs current period
const datetime tstart = TimeLocal(); //start time variable for use in time tracking
int errorcheck = 0; //generic error checking variable
//externs: startup settings set by human before launch
extern double	DailyGoal	= 0.003;//read as 0.2% per day
extern int	PeriodATR	= 10;   //period for all iATR function calls
extern int	MAXORDERS	= 6;   //max orders at any given time
extern double	RISKEXPOSURE	= 0.03; //max risk at any time
extern bool	useacctstop	= true; //toggle monthly stop
extern double	MAXRISKMONTHLY	= 0.05; //monthly risk of account balance
extern double	multiplebase	= 1.1;  //multiples of ATR (base)
/*this internal method to retrieve current period is handy for transferring period from one chart to another    **      
**it is also essential when iterating between different timeframes frequently. i++ versus hardcoded period changes
**this is because each constant is valued at the amount of time it represents. Not smooth in default format */
int PRDARR[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
int PRDIND = 0; //current period (index of period selection array)
void ExitProgram() //good to immediately kill the program
{	SendNotification("final vault value: " + DoubleToStr(AccountVault)); //saving to file is sandboxed and weird, so push notification
	ExpertRemove(); //goodbye cruel world
} 
void GetChartPeriodIndex()//during init we need to fetch current chart period and convert it to a more friendly format
{	int chartperiod = ChartPeriod(ChartID()); //get the chartperiod of the current chart
	for(int i = 0; i < 8; i++) //iterate through all different possible chart periods.
	{	if(chartperiod == PRDARR[i]) //if they are the same, then set the index
		{	PRDIND = i;
			return;
	}	} 
	return; //if it gets to here then it will start on the first chart and all charts may switch to it
} 
void SetAllChartPeriod(int NewPeriodIndex) //change all charts to current chart period active on the bot
{	long CurrentChart, PreviousChart = ChartFirst(); //variables that will be used to iterate through
	ChartSetSymbolPeriod(PreviousChart, ChartSymbol(PreviousChart), PRDCUR); //set the period of the chart
	for(int i = 0; i < 100; i++) //iterate through all the charts. 100 chosen as "ad nauseum" max
	{	CurrentChart = ChartNext(PreviousChart); //iterate to next chart
		ChartSetSymbolPeriod(CurrentChart, ChartSymbol(CurrentChart), PRDCUR); //set period of current chart
		PreviousChart = CurrentChart; //swap previous and current
	} 
	EventSetTimer(60*PRDCUR); //set timer for every bar of current period, in seconds
} 
double OnePoint(string CurrencyPair) { return MarketInfo(CurrencyPair, MODE_POINT); } //this is to take into account yen pair vs dollar pair and their point offset differences
double PTVAL(string pair) { return MarketInfo(pair, MODE_TICKVALUE)/(MarketInfo(pair, MODE_TICKSIZE)/OnePoint(pair)); } //value of a single point
double Spread(string CurrencyPair) { return MarketInfo(CurrencyPair, MODE_SPREAD)*OnePoint(CurrencyPair); } //grab the spread of the pair specified
extern double AccountVault = 1406; //money kept out of trades - effectively account-level stoploss
bool VolatilityCheck() //BidAskSpread vs actual market movement for the chart as measured by iATR
{	if	(Spread(top)*2 >= iATR(top, PRDCUR, PeriodATR, 1)) return false; //check top
	else if	(Spread(left)*2 >= iATR(left, PRDCUR, PeriodATR, 1)) return false; //check left
	else if	(Spread(right)*2 >= iATR(right, PRDCUR, PeriodATR, 1)) return false; //check right
	else if	(Spread(bottom)*2 >= iATR(bottom, PRDCUR, PeriodATR, 1)) return false; //check bottom
	else return true; //if it gets to here then it passes the volatility check
} 
void VolatilityCheckAndAdjust() //magical function checks volatility and then changes chart period if necessary
{	if(!VolatilityCheck()) //check for volatility problems, if problems, proceed
	{	PRDIND += (PRDIND >= 8 ? -8 : 1); //channel surf to next chart time period
		SetAllChartPeriod(PRDIND);	//change all chart visuals to period running
}	} 
enum xcolors {xgreen = 2, xgray, xred}; //xcolors is an enum to better visualize the zones determined by AC/AO comparisons
//the buy/sell signals (correlating iAC and iAO)
short zonA(string pair, int shift = 0) { return iAC(pair, PRDCUR, shift+1) > iAC(pair, PRDCUR, shift) ? 2 : 1; } //AC: Accelerator/Decelerator Oscillator, indicates momentum
short zonB(string pair, int shift = 0) { return iAO(pair, PRDCUR, shift+1) > iAO(pair, PRDCUR, shift) ? 2 : 1; } //AO: Awesome Oscillator, indicates direction inclination
short zone(string pair, int shift = 0) { return zonA(pair, shift) + zonB(pair, shift); } //if both point the same direction, green/red. else, gray.
const string CURRENCY[] = {"AUD","USD","EUR","JPY"}; //symbol constants construction
const string top = CURRENCY[0]+CURRENCY[1];	//AUD∙USD
const string left = CURRENCY[1]+CURRENCY[3];	//USD∙JPY
const string right = CURRENCY[2]+CURRENCY[0];	//EUR∙AUD
const string bottom = CURRENCY[2]+CURRENCY[3];	//EUR∙JPY
short QueueTOP = 0;	
short QueueLEFT = 0;	
short QueueRIGHT = 0;	
short QueueBOTTOM = 0;	
short signal; //buy/sell signal variable before signals functions
//top signal
short QUADS_SignalTOP()
{	signal = 0;
	if(zone(top) == xgreen)
	{	signal++;
		if(zone(left) == xred)
		{	signal++;
			if(zone(bottom) != xgreen) signal++;
		}
		if(zone(right) == xred)
		{	signal++;
			if(zone(bottom) != xgreen) signal++;
	}	} 
	else if(zone(top) == xred)
	{	signal--;
		if(zone(left) == xgreen)
		{	signal--;
			if(zone(bottom) != xred) signal--;
		}
		if(zone(right) == xgreen)
		{	signal--;
			if(zone(bottom) != xred) signal--;
	}	}
	if(signal > 2) return signal - 2;
	else if(signal < -2) return signal + 2;
	else return 0;
} 
//left signal
short QUADS_SignalLEFT()
{	signal = 0;
	if(zone(left) == xgreen)
	{	signal++;
		if(zone(top) == xred)
		{	signal++;
			if(zone(right) != xred) signal++;
		}
		if(zone(bottom) == xgreen)
		{	signal++;
			if(zone(right) != xred) signal++;
	}	} 
	else if(zone(left) == xred)
	{	signal--;
		if(zone(top) == xgreen)
		{	signal--;
			if(zone(right) != xgreen) signal--;
		}
		if(zone(bottom) == xred)
		{	signal--;
			if(zone(right) != xgreen) signal--;
	}	} 
	if(signal > 2) return signal - 2;
	else if(signal < -2) return signal + 2;
	else return 0;
} 
//right signal
short QUADS_SignalRIGHT()
{	signal = 0;
	if(zone(right) == xgreen)
	{	signal++;
		if(zone(bottom) == xgreen)
		{	signal++;
			if(zone(left) != xred) signal++;
		}
		if(zone(top) == xred)
		{	signal++;
			if(zone(left) != xred) signal++;
	}	} 
	else if(zone(right) == xred)
	{	signal--;
		if(zone(bottom) == xred)
		{	signal--;
			if(zone(left) != xgreen) signal--;
		}
		if(zone(top) == xgreen)
		{	signal--;
			if(zone(left) != xgreen) signal--;
	}	} 
	if(signal > 2) return signal - 2;
	else if(signal < -2) return signal + 2;
	else return 0;
} 
//bottom signal
short QUADS_SignalBOTTOM()
{	signal = 0;
	if(zone(bottom) == xgreen)
	{	signal++;
		if(zone(right) == xgreen)
		{	signal++;
			if(zone(top) != xgreen) signal++;
		}
		if(zone(left) == xgreen)
		{	signal++;
			if(zone(top) != xgreen) signal++;
	}	} 
	else if(zone(bottom) == xred)
	{	signal--;
		if(zone(right) == xred)
		{	signal--;
			if(zone(top) != xred) signal--;
		}
		if(zone(left) == xred)
		{	signal--;
			if(zone(top) != xred) signal--;
	}	} 
	if(signal > 2) return signal - 2;
	else if(signal < -2) return signal + 2;
	else return 0;
} 
double xAsk(string pair) {return MarketInfo(pair, MODE_ASK); } //ask price of specified pair
double xBid(string pair) {return MarketInfo(pair, MODE_BID); } //bid price of specified pair
int AdjustedOrdersHistory() //untested: give number of orders since program start
{	int adjhist = 0; //create var to store quantity of fitting orders
	for(int i = OrdersHistoryTotal() - 1; i >= 0; i--) //iterate through all orders in history
	{	if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) //try selecting them
		{ if(OrderOpenTime() > tstart) adjhist++; } //simply check open time > program start time
		else{ Alert("order selection failed. 027"); } //else there was an error selecting order.
	} 
	return adjhist;
} 
double SuccessRate() //untested: this determines, for all order history with magic number mod1111: percent win
{	double ProfitOrdersHistory = 0;
	if(OrdersHistoryTotal() != 0)
	{	for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
		{	if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
			{	if(OrderMagicNumber() % 1111 == 0)
				{	if(OrderProfit() > 0) ProfitOrdersHistory++;
			}	} 
			else { Alert("order selection failed. 028"); } //028
		} 
		return ProfitOrdersHistory / OrdersHistoryTotal();
	} 
	else return 1.0;
} 
double TradeBalance(double liq) { return AccountBalance() - AccountVault; } //this determines the balance to trade in relation to liquid asset balance
bool Trail(int ticket, double stop_delta) //shortened ordermodify for stoploss tightening
{	errorcheck = OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); //
	if(errorcheck < 0) Alert("failed order select 030");
	double new_stop = OrderStopLoss();
	new_stop += (OrderType() == OP_BUY) ? stop_delta : -1.0*stop_delta;
	return OrderModify(ticket, OrderOpenPrice(), NormalizeDouble(new_stop, (int)MarketInfo(OrderSymbol(), MODE_DIGITS)), 0, 0, clrNONE);
}

//OP_BUY: 0. OP_SELL: 1.
int OrdersTotalType(int magic)
{	for(int i = OrdersTotal() - 1; i >= 0; i--)
	{	if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
		{	Alert("error selecting order");
			ExitProgram();
		}
		else if(OrderMagicNumber() == magic) return OrderType();
	}
	return -1;
}

bool isGoodEntry(int ordertype, string pair)
{	if(ordertype == OP_BUY)
	{	if(zone(pair, 3) != xgreen || zone(pair, 1) == xgreen)
		{	if(zone(pair, 0) == xgreen)
			{	if(xAsk(pair) < iOpen(pair, PRDCUR, 0))
				{	if((xAsk(pair) - iLow(pair, PRDCUR, 0)) < (activetrail(pair, multiplebase)/5)) return true;
	        }	}	}
                else if(zone(pair, 1) == xgreen)
                {       if(zone(pair, 0) == xgreen) return true;
        }       }
	else if(ordertype == OP_SELL)
	{	if(zone(pair, 3) != xred)
		{	if(zone(pair, 0) == xred)
			{	if(xBid(pair) > iOpen(pair, PRDCUR, 0))
				{	if((xBid(pair) + iHigh(pair, PRDCUR, 0)) > (activetrail(pair, multiplebase)/5)) return true;
	        }	}	}
                else if(zone(pair, 1) == xred)
                {       if(zone(pair, 0) == xred) return true;
        }	}
	return false;
}

int cycles = 0;

double activetrail(string pair, double multiple) { return MathMax(50*OnePoint(pair), multiple*MathMin(160*OnePoint(pair), iATR(pair, PRDCUR, PeriodATR, 0))); }
double TradeBalance() { return AccountBalance() - AccountVault; }

double dynamiclots(string pair)
{   double risk = (activetrail(pair, multiplebase)/OnePoint(pair))*PTVAL(pair);
    double lots = (TradeBalance()/MAXORDERS)*(RISKEXPOSURE/MAXORDERS);
    lots /= risk;
    return MathMax(NormalizeDouble(lots, 2), 0.01);
}

short OrderQueueFulfill(string pair, short queue, int magic, double liquidity)
{	double MaxLots = dynamiclots(pair);
	errorcheck = 0;
	if(OrdersTotal() > 0)
	{	for(int i = OrdersTotal() - 1; i >= 0; i--)
		{	if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
			{	Alert("error selecting order");
				return queue;
			}
			else
			{	if(OrdersTotalType(magic) == OP_BUY)
				{	if(queue < 0)
					{	if(OrderLots() > 0.01)
						{	if(!OrderClose(OrderTicket(), 0.01, xBid(OrderSymbol()), 10, clrNONE))
							{	Alert("error closing order: " + IntegerToString(GetLastError()));
							}
						}
						if(OrderStopLoss()+5*OnePoint(pair) <= xBid(pair) - 5*OnePoint(pair))
						{	if(!Trail(OrderTicket(), 5*OnePoint(pair)))
							{	Alert("error closing order: " + IntegerToString(GetLastError()));
								ExitProgram();
							}
							return ++queue;
				}	}	}
				else if(OrdersTotalType(magic) == OP_SELL)
				{	if(queue > 0)
					{	if(OrderLots() > 0.01)
						{	if(!OrderClose(OrderTicket(), 0.01, xAsk(OrderSymbol()), 10, clrNONE))
							{	Alert("error closing order: " + IntegerToString(GetLastError()));
						}	}
						if(OrderStopLoss()-5*OnePoint(pair) <= xAsk(pair) + 5*OnePoint(pair))
						{	if(!Trail(OrderTicket(), 5*OnePoint(pair)))
							{	Alert("error closing order: " + IntegerToString(GetLastError()));
								ExitProgram();
							}
							return --queue;
	}	}	}	}	}	}
	if(queue != 0)
	{	if(OrdersTotal() < MAXORDERS)
		{	if(queue > 0)
			{	if(OrdersTotalType(magic) != OP_SELL && isGoodEntry(OP_BUY, pair))
				{	errorcheck = OrderSend(pair, OP_BUY, MaxLots, xAsk(pair), 10, xBid(pair) - activetrail(pair, multiplebase), 0, NULL, magic, 0, clrNONE);
					queue--;
			}	}
			else if(queue < 0)
			{	if(OrdersTotalType(magic) != OP_BUY && isGoodEntry(OP_SELL, pair))
				{	errorcheck = OrderSend(pair, OP_SELL, MaxLots, xBid(pair), 10, xAsk(pair) + activetrail(pair, multiplebase), 0, NULL, magic, 0, clrNONE);
					queue++;
	}	}	}	}
	if(errorcheck < 0)
	{	Alert("OrderERR: " + pair + " L:" + DoubleToStr(MaxLots,1) + " | ATR:"+DoubleToStr(activetrail(pair, 1.0), (int)MarketInfo(pair, MODE_DIGITS)));
		Alert("ErrorCode: " + IntegerToString(GetLastError()));
		ExitProgram();
	}
	return queue;
}

//simply a function that returns true if trade is allowed
bool isOpen(string pair) { return MarketInfo(pair, MODE_TRADEALLOWED); }
bool isMarketOpen()
{ // Josh Was Here
    return (isOpen(top)&&
            isOpen(left)&&
            isOpen(right)&&
            isOpen(bottom));
}

int OnInit()
{	SendNotification("bot started");
	Sleep(1000*(90-TimeSeconds(TimeLocal())));	//the Sleep function (milliseconds) is designed to make sure the bot runs at certain time each bar
	GetChartPeriodIndex();	//sets variable PeriodIndex in charge of recording current trading timeframe
	VolatilityCheckAndAdjust();	//check volatility; if not enough, then change timeframe of system
	EventSetTimer(60*PRDCUR);
	QueueTOP += QUADS_SignalTOP();
	QueueLEFT += QUADS_SignalLEFT();
	QueueRIGHT += QUADS_SignalRIGHT();
	QueueBOTTOM += QUADS_SignalBOTTOM();
	return(INIT_SUCCEEDED);
}

double MonthPerformance;
double MonthPerformancePercent;
double PreviousMonthAccountBalance = AccountBalance();
double MonthRisk;
double MonthRiskPercent = 0.05;
const double MonthRiskPercentMax = 0.08;
const double MonthRiskPercentMin = 0.02;
double MonthStopLoss;

double DayPerformance;
double DayPerformancePercent;
double PreviousDayAccountBalance = AccountBalance();

double PeriodPerformance;
double PeriodPerformancePercent;
double PreviousPeriodAccountBalance = AccountBalance();

datetime timelastrun;

void OnTimer()
{	timelastrun = TimeLocal();
	if(TimeMinute(TimeLocal()) == 0)
	{	if(TimeHour(TimeLocal()) == 0)
		{	if(TimeDay(TimeLocal()) == 1)
			{	MonthPerformance = AccountBalance() - PreviousMonthAccountBalance;
				MonthPerformancePercent = MonthPerformance/PreviousMonthAccountBalance;
				PreviousMonthAccountBalance = AccountBalance();
				MonthRiskPercent = MathMax(MonthRiskPercentMin, MonthRiskPercentMax*SuccessRate());
				MonthRisk = MonthRiskPercent * AccountBalance();
				MonthStopLoss = AccountBalance() - MonthRisk;
				SendNotification("Month: BAL " + DoubleToStr(AccountBalance(), 2) + ". new risk " + DoubleToStr(MonthRiskPercent, 3));
			}
			AccountVault *= DailyGoal;
			DayPerformance = AccountBalance() - PreviousDayAccountBalance;
			DayPerformancePercent = DayPerformance/PreviousDayAccountBalance;
			PreviousDayAccountBalance = AccountBalance();
			SendNotification("Daily Digest: " + (DayPerformancePercent > 0 ? "+" : "-") + DoubleToStr(DayPerformancePercent, 2) + "; BAL $" + DoubleToStr(AccountBalance(), 2));
	}	}
	PeriodPerformance = AccountBalance() - PreviousPeriodAccountBalance;
	PeriodPerformancePercent = PeriodPerformance/PreviousPeriodAccountBalance;
	PreviousPeriodAccountBalance = AccountBalance();
	SendNotification((PeriodPerformancePercent > 0 ? "+" : "-") + DoubleToStr(PeriodPerformancePercent, 2) + "% ... made " + (PeriodPerformance > 0 ? "+" : "-") + "$" + DoubleToStr(PeriodPerformance, 2));
	VolatilityCheckAndAdjust();
	QueueTOP += QUADS_SignalTOP();
	QueueLEFT += QUADS_SignalLEFT();
	QueueRIGHT += QUADS_SignalRIGHT();
	QueueBOTTOM += QUADS_SignalBOTTOM();
	
	if(AccountEquity() < PreviousMonthAccountBalance*(1-MAXRISKMONTHLY))
	{	Alert("Hit Monthly Stop");
		ExitProgram();
	}

	if(MathAbs(QueueTOP) > 1)	//if all queues are greater than 1, reduce all by one. tetris
	{	if(MathAbs(QueueLEFT) > 1)
		{	if(MathAbs(QueueRIGHT) > 1)
			{	if(MathAbs(QueueBOTTOM) > 1)
				{	short DropValue = 	MathMin(MathAbs(QueueTOP), MathAbs(QueueLEFT));
					DropValue = 		MathMin(DropValue, MathAbs(QueueRIGHT));
					DropValue = 		MathMin(DropValue, MathAbs(QueueBOTTOM));
					QueueTOP += QueueTOP > 1 ? -1*DropValue : DropValue;
					QueueLEFT += QueueLEFT > 1 ? -1*DropValue : DropValue;
					QueueRIGHT += QueueRIGHT > 1 ? -1*DropValue : DropValue;
					QueueBOTTOM += QueueBOTTOM > 1 ? -1*DropValue : DropValue;
	}	}	}	}
	cycles++;
	Comment(StringConcatenate(	"running! cycles ", IntegerToString(cycles),"; success ", DoubleToStr(SuccessRate(), 1), "\n",
					"vault: $",DoubleToString(AccountVault, 2),"; interval ", IntegerToString(PRDCUR),"\n",
					"Qtop|",IntegerToString(QueueTOP)," Qleft|",IntegerToString(QueueLEFT)," Qright|",IntegerToString(QueueRIGHT)," Qbottom|",IntegerToString(QueueBOTTOM)));
}

void OnTick()
{	if(AccountBalance() < MonthStopLoss && useacctstop) ExitProgram();
	if(isMarketOpen())
	{	QueueTOP = OrderQueueFulfill(top, QueueTOP, 1111, AccountVault);
		QueueLEFT = OrderQueueFulfill(left, QueueLEFT, 2222, AccountVault);
		QueueRIGHT = OrderQueueFulfill(right, QueueRIGHT, 3333, AccountVault);
		QueueBOTTOM = OrderQueueFulfill(bottom, QueueBOTTOM, 4444, AccountVault);
		Comment(StringConcatenate(	"cycles ", IntegerToString(cycles),"; success ", DoubleToStr(SuccessRate(), 1), "\n",
						"vault: $",DoubleToString(AccountVault, 2),"; interval ", IntegerToString(PRDCUR),"\n",
						"Qtop|",IntegerToString(QueueTOP)," Qleft|",IntegerToString(QueueLEFT)," Qright|",IntegerToString(QueueRIGHT)," Qbottom|",IntegerToString(QueueBOTTOM)));
		if(OrdersTotal() != 0)
		{	
                        /*for(int i = OrdersTotal() - 1; i >= 0; i--)
			{	errorcheck = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
				if(errorcheck < 0)
				{	Alert("order selection problem 029");
					break;
				}
				//breakeven stops II
				if(OrderProfit() >= 0.1*DailyGoal*AccountBalance())
				{	if((OrderType() == OP_BUY) && ((((1/(double)MAXORDERS)*DailyGoal*AccountBalance())/PTVAL(OrderSymbol())) > ((xBid(OrderSymbol())-OrderStopLoss())/OnePoint(OrderSymbol()))))
					{	if(!Trail(OrderTicket(), OnePoint(OrderSymbol())))
						{	Alert("Could not modify buy order for break even");
					}	}
					else if((OrderType() == OP_SELL) && ((((1/(double)MAXORDERS)*DailyGoal*AccountBalance())/PTVAL(OrderSymbol())) > ((OrderStopLoss() - xAsk(OrderSymbol()))/OnePoint(OrderSymbol()))))
					{	if(!Trail(OrderTicket(), OnePoint(OrderSymbol())))
						{	Alert("Could not modify sell order for break even");
				}	}	}
				if(OrderType() == OP_BUY)
				{	if(zone(OrderSymbol()) == xgreen)	//optimism stop
					{	if(OrderStopLoss()+OnePoint(OrderSymbol()) < xBid(OrderSymbol()) - activetrail(OrderSymbol(), multiplebase))
						{	if(!Trail(OrderTicket(), activetrail(OrderSymbol(), multiplebase)))
							{	Alert("Could not modify buy order on tick green");
					}	}	}
					else if(zone(OrderSymbol()) == xgray)	//uncertainty stop
					{	if(OrderStopLoss()+OnePoint(OrderSymbol()) < xBid(OrderSymbol()) - activetrail(OrderSymbol(), 0.75*multiplebase))
						{	if(!Trail(OrderTicket(), activetrail(OrderSymbol(), 0.75*multiplebase)))
							{	Alert("Could not modify buy order on tick gray");
					}	}	}
					else if(zone(OrderSymbol()) == xred)	//pessimism stop
					{	if(OrderStopLoss()+OnePoint(OrderSymbol()) < xBid(OrderSymbol()) - activetrail(OrderSymbol(), 0.5*multiplebase))
						{	if(!Trail(OrderTicket(), activetrail(OrderSymbol(), 0.5*multiplebase)))
							{	Alert("Could not modify buy order on tick red");
				}	}	}	}
				else if(OrderType() == OP_SELL)
				{	if(zone(OrderSymbol()) == xred)	//optimism stop
					{	if(OrderStopLoss()-OnePoint(OrderSymbol()) > xAsk(OrderSymbol()) + activetrail(OrderSymbol(), multiplebase))
						{	if(!Trail(OrderTicket(), activetrail(OrderSymbol(), multiplebase)))
							{	Alert("Could not modify sell order on tick red");
					}	}	}
					else if(zone(OrderSymbol()) == xgray)	//uncertainty stop
					{	if(OrderStopLoss()-OnePoint(OrderSymbol()) > xAsk(OrderSymbol()) + activetrail(OrderSymbol(), 0.75*multiplebase))
						{	if(!Trail(OrderTicket(), activetrail(OrderSymbol(), 0.75*multiplebase)))
							{	Alert("Could not modify sell order on tick gray");
					}	}	}
					else if(zone(OrderSymbol()) == xgreen)//pessimism stop
					{	if(OrderStopLoss()-OnePoint(OrderSymbol()) > xAsk(OrderSymbol()) + activetrail(OrderSymbol(), 0.5*multiplebase))
						{	if(!Trail(OrderTicket(), activetrail(OrderSymbol(), 0.5*multiplebase)))
							{	Alert("Could not modify sell order on tick green");
                        }       }	}	}	}	*/
                        for(int i = OrdersTotal() - 1; i >= 0; i--)
                	{	if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                		{	if(OrderType() == OP_BUY)
        				{	if(OrderStopLoss() + OnePoint(OrderSymbol()) < Bid - iATR(OrderSymbol(), PERIOD_CURRENT, PeriodATR, 0))
        					{	OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss()+Spread(OrderSymbol())+OnePoint(OrderSymbol()), 0, 0, clrNONE);
        					}
                                                if(OrderProfit() > (DailyGoal*AccountBalance())/(2*MAXORDERS))
                                                {       OrderClose(OrderTicket(), 0.01, xBid(OrderSymbol()), 10, clrNONE);
                                                }
        				}
        				if(OrderType() == OP_SELL)
        				{	if(OrderStopLoss() - OnePoint(OrderSymbol()) > iATR(OrderSymbol(), PERIOD_CURRENT, PeriodATR, 0) + Ask)
        					{	OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss()-(Spread(OrderSymbol())+OnePoint(OrderSymbol())), 0, 0, clrNONE);
        					}
                                                if(OrderProfit() > (DailyGoal*AccountBalance())/(2*MAXORDERS))
                                                {       OrderClose(OrderTicket(), 0.01, xBid(OrderSymbol()), 10, clrNONE);
                                                }
        				}
                		}
                	}
}       }	}
