//SUGAR CRASH VERSION 8 - - BEGIN DATE: 02/08/2016

//was trying for a while to get a self-optimization toolkit to work. Shelved for now!

//tdl
//jpy pair compatibility
enum INDICATOR_SIGNAL_COLORS {XGREEN = 2, XGRAY, XRED};
enum POSITION_PARAM {XTP,  XSL};
extern double ATR_STOP = 3;
extern int KPRD = 21;
extern int SLOW = 3;
extern int ATR_01 = 17;
extern int EMAperiod = 50;
extern double RISK = 0.04; //too many variables to optimize

//automatic backtesting!
extern int SetHour = 0;
extern int SetMinute = 1;
int TestDays = 7;
int TimeOutLevel = 1;
string NameOfBot = "fuckboy777";
string NameOfTestSet = "jenkins_test_test.set";
string PathToTester = "D:/PROGRAMS/MT4-OFFLINE-TESTER/MQL4/Experts/Files";
int Gross_Profit_Amount = 1;
int Profit_Factor_Amount = 2;
int Expected_Payoff_Amount = 3;
string Per_1 = "ATR_STOP";
string Per_2 = "";		//KPRD
string Per_3 = "";		//SLOW
string Per_4 = "";	//ATR_01
string Per_5 = "";	//EMAperiod
string Per_6 = "";		//unused: risk/etc
string Per_7 = "";
bool StartTest = false;
datetime TimeStart;

#include <AUTO_OPTIMIZATION_MOD.mqh>
void OnInit()
{	Comment(" ");
	Tester(TestDays, NameOfBot, NameOfTestSet, PathToTester, TimeOutLevel, Gross_Profit_Amount, Profit_Factor_Amount, Expected_Payoff_Amount, Per_1, Per_2, Per_3, Per_4, Per_5, Per_6, Per_7);
	ExpertRemove();
}

double ACCT_MIN = AccountBalance()*0.8;
double STOP_MINALLOWED() {return NormalizeDouble(((MarketInfo(NULL, MODE_SPREAD) + 2) * Point), Digits);}
double SL_LARGE_CALC()
{	double STOP_CALC01 = (iATR(NULL, 0, ATR_01, 0) + iATR(NULL, 0, ATR_01, 0)) * ATR_STOP;
	return NormalizeDouble(MathMax(STOP_CALC01, STOP_MINALLOWED()), Digits);
}
double SL_SMALL_CALC()
{	double STOP_CALC02 = iATR(NULL, 0, ATR_01, 0) * ATR_STOP;
	return NormalizeDouble(MathMax(STOP_CALC02, STOP_MINALLOWED()), Digits);
}
double stocheck(int shift = 0) {return iStochastic(NULL, NULL, KPRD, 2, SLOW, MODE_SMA, 0, 0, shift);}
double LOTS = NormalizeDouble(RISK * AccountBalance() / (MarketInfo(Symbol(), MODE_LOTSIZE) * SL_LARGE_CALC()), 2);
int TICKET;
bool broken_even = false;
void OnTick()
{ 	if(!IsTesting() && !IsOptimization())
	{	if(TimeHour(TimeLocal())==SetHour)
		{	if(!StartTest)
			{	if(TimeMinute(TimeLocal())>SetMinute-1)
				{	if(TimeMinute(TimeLocal())<SetMinute+1)
					{	TimeStart = TimeLocal();
						StartTest = true;
						Tester(TestDays, NameOfBot, NameOfTestSet, PathToTester, TimeOutLevel, Gross_Profit_Amount, Profit_Factor_Amount, Expected_Payoff_Amount, Per_1, Per_2, Per_3, Per_4, Per_5, Per_6, Per_7);
		}	}	}	}
		ATR_STOP	=GlobalVariableGet(Per_1);
		KPRD		=GlobalVariableGet(Per_2);
		SLOW		=GlobalVariableGet(Per_3);
		ATR_01		=GlobalVariableGet(Per_4);
		ATR_01		=GlobalVariableGet(Per_5);
		EMAperiod	=GlobalVariableGet(Per_6);
		RISK		=GlobalVariableGet(Per_7);
	}
	if(StartTest && (TimeLocal()-TimeStart > TimeOutLevel*60))
	{	StartTest = false;
		Comment("Timeout on Test...");
	}
	if(Bars<100)
	{	Print("Bars less than 100");
		ExpertRemove();
	}
	if((OrderSelect(0, SELECT_BY_POS) && OrderCloseTime() == 0) && (OrderSymbol() == Symbol()))
	{	if(OrderType() == OP_BUY)
		{	if(!broken_even && (Bid - OrderOpenPrice() > SL_SMALL_CALC()) && (OrderStopLoss() > Bid - SL_SMALL_CALC()))
			{	broken_even = true;
				change_SL(Bid - SL_SMALL_CALC());
			}
			else if((Bid - OrderOpenPrice() > SL_CALC(OP_BUY)) && (OrderStopLoss() < SL_PRICE(OP_BUY))) change_SL(SL_PRICE(OP_BUY));
		}
		else if(OrderType() == OP_SELL)
		{	if(!broken_even && (OrderOpenPrice() - Ask > SL_SMALL_CALC()) && (OrderStopLoss() < Ask + SL_SMALL_CALC()))
			{	broken_even = true;
				change_SL(Ask + SL_SMALL_CALC());
			}
			else if((OrderOpenPrice() - Ask > SL_CALC(OP_SELL)) && (OrderStopLoss() > SL_PRICE(OP_SELL))) change_SL(SL_PRICE(OP_SELL));
	}	}
	else if(OrdersTotal() == 0)
     	{	if(AccountBalance() < ACCT_MIN) ExpertRemove();
     		LOTS = NormalizeDouble(RISK * AccountBalance() / (MarketInfo(NULL, MODE_LOTSIZE) * SL_LARGE_CALC()), 2);
     		if(indication() == XGREEN)
        	{	TICKET = OrderSend(NULL, OP_BUY, LOTS, Ask, 10 * Point, SL_PRICE(OP_BUY), 0);
         		if(TICKET == -1) Alert("BUY FAILED.");
         		else broken_even = false;
         	}
		else if(indication() == XRED)
		{	TICKET = OrderSend(NULL, OP_SELL, LOTS, Bid, 10 * Point, SL_PRICE(OP_SELL), 0);
	        	if(TICKET == -1) Alert("SELL FAILED.");
	        	else broken_even = false;
}	}	}
int change_SL(double SL) {return OrderModify(OrderTicket(), OrderOpenPrice(), SL, OrderTakeProfit(), 0, clrGreen);}
int IndAC(int POS = 0) {return (iAC(NULL, 0, POS) < iAC(NULL, 0, POS + 1)) ? 2 : 1;}
int IndAO(int POS = 0) {return (iAO(NULL, 0, POS) < iAO(NULL, 0, POS + 1)) ? 2 : 1;}
int IndColor(int POS = 0) {return IndAO(POS) + IndAC(POS);}
double EMA() {return iMA(NULL, NULL, EMAperiod, 0, MODE_EMA, PRICE_CLOSE, 0);}
int indication(int shift = 0)
{	if((stocheck(1) < stocheck()) && (stocheck() >= 25) && (IndColor() == XGREEN) && (EMA() < Ask)) return XGREEN;
	else if((stocheck(1) > stocheck()) && (stocheck() <= 75) && (IndColor() == XRED) && (EMA() > Bid)) return XRED;
	return XGRAY;
}
double SL_CALC(int TYPE)
{	if (TYPE == OP_BUY) return stocheck() <= 25 ? SL_SMALL_CALC() : SL_LARGE_CALC();
	else return stocheck() >= 75 ? SL_SMALL_CALC() : SL_LARGE_CALC();
}
double TP_CALC(int TYPE) {return SL_LARGE_CALC() + SL_SMALL_CALC();}
double SL_PRICE(int TYPE) {return TYPE == OP_BUY ? Ask - SL_CALC(OP_BUY) : Bid + SL_CALC(OP_SELL);}
double TP_PRICE(int TYPE) {return TYPE == OP_BUY ? Bid + TP_CALC(OP_BUY) : Ask - TP_CALC(OP_SELL);}