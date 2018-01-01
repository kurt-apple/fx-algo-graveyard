//SUGAR CRASH VERSION 3 - - BEGIN DATE: 02/08/2016

enum INDICATOR_SIGNAL_COLORS	{XGREEN = 2, XGRAY, XRED};
enum POSITION_PARAM    		{XTAKEPROFIT,  XSTOPLOSS};
extern int	ATR_PERIOD = 16; 
extern double	ATR_MULTIPLIER = 2;	
extern double	RISK_REWARD_RATIO = 2.5;
extern double	RISK = 0.02;	
double	STOPS_AMOUNT_TEMP, STOPS_AMOUNT_PREVIOUS, LOTS;
int	XPERIOD	= 3, TICKET;
void OnTick()
{ 	if((OrdersTotal() >= 1) && OrderSelect(TICKET, SELECT_BY_TICKET))
	{	if(OrderType() == OP_BUY)
        {	if((OrderStopLoss() < STOPS_INFO(OP_BUY, XSTOPLOSS)) && (OrderOpenPrice() <= STOPS_INFO(OP_BUY, XSTOPLOSS)))
            {	Alert("O R D E R M O D I F Y");
                if(!OrderModify(OrderTicket(), OrderOpenPrice(), STOPS_INFO(OP_BUY, XSTOPLOSS), OrderTakeProfit(), 0, MediumSeaGreen))
                {	Alert("ERROR VOLATILITY STOP");
        }	}	}
        else if(OrderType() == OP_SELL)
        {	if((OrderStopLoss() > STOPS_INFO(OP_SELL, XSTOPLOSS)) && (OrderOpenPrice() >= STOPS_INFO(OP_SELL, XSTOPLOSS)))
            {	Alert("O R D E R M O D I F Y");
                if(!OrderModify(OrderTicket(), OrderOpenPrice(), STOPS_INFO(OP_SELL, XSTOPLOSS), OrderTakeProfit(), 0, MediumSeaGreen))
                {	Alert("ERROR VOLATILITY STOP");
	}	}	}	}
	else if ((OrdersTotal()==0) && breakout())
 	{	LOTS = RISK * AccountBalance() / (MarketInfo(Symbol(),MODE_LOTSIZE) * STOPS_AMOUNT());
	LOTS = NormalizeDouble(LOTS, 2);
	if(IndColor()==XGREEN)
	{	Alert("LOTS:  " + LOTS);
		TICKET=OrderSend(Symbol(), OP_BUY, LOTS, Ask, 10*Point, STOPS_INFO(OP_BUY, XSTOPLOSS), STOPS_INFO(OP_BUY, XTAKEPROFIT), "MOAN", 9702, clrGreen);
 		if(TICKET == -1) Alert("BUY FAILED. " + STOPS_INFO(OP_BUY, XSTOPLOSS) + "; " + STOPS_INFO(OP_SELL, XTAKEPROFIT));
	}
	else if(IndColor()==XRED)
	{	Alert("LOTS:  " +LOTS);
		TICKET=OrderSend(Symbol(), OP_SELL, LOTS, Bid, 10*Point, STOPS_INFO(OP_SELL, XSTOPLOSS), STOPS_INFO(OP_SELL, XTAKEPROFIT), "MOAN", 9702, clrBlue);
    	if(TICKET == -1) Alert("SELL FAILED. " + STOPS_INFO(OP_SELL, XSTOPLOSS) + "; " + STOPS_INFO(OP_SELL, XTAKEPROFIT));
}	}	}
int IndAC(int POS=0)
{	int DirAC=1;
	double AC_0 = iAC(Symbol(),0,POS);
	double AC_1 = iAC(Symbol(),0,POS+1);
	if(AC_0>AC_1) { DirAC = 1; }
	if(AC_0<AC_1) { DirAC = 2; }
	return DirAC;
}
int IndAO(int POS=0)
{	int DirAO=1;
	double AO_0 = iAO(Symbol(),0,POS);
	double AO_1 = iAO(Symbol(),0,POS+1);
	if(AO_0>AO_1) { DirAO = 1; }
	if(AO_0<AO_1) { DirAO = 2; }
	return DirAO;
}
int IndColor(int POS=0) { return IndAO(POS)+IndAC(POS); }
int color_data[3] = {0, 0, 0}; //array size is XPERIOD
bool breakout()
{	for(int i = 0; i < XPERIOD; i++) color_data[i] = IndColor(i);
	if(((color_data[2] == color_data[1]) && (color_data[0] != color_data[1]) && (color_data[0] != XGRAY)) || ((color_data[0] != color_data[1]) && color_data[0] != XGRAY)) return true;
	else return false;
}
double STOP_CALCULATION = 0;
double STOP_MINALLOWED  = 0;
double STOPS_AMOUNT()
{	STOP_CALCULATION = iATR(NULL, 0, ATR_PERIOD, 0) * 10 * ATR_MULTIPLIER;
	STOP_MINALLOWED  = (MarketInfo(Symbol(), MODE_SPREAD) + 1) * Point * 10;
	return MathMax(STOP_CALCULATION, STOP_MINALLOWED);
}
double STOPS_INFO_TEMP = 0;
double STOPS_INFO(int TYPE, int PARAM)
{	STOPS_INFO_TEMP = STOPS_AMOUNT();
	if(PARAM == XTAKEPROFIT)
	{	if(TYPE == OP_BUY)	return NormalizeDouble(Bid + (RISK_REWARD_RATIO * STOPS_INFO_TEMP), Digits);
    	else			return NormalizeDouble(Ask - (RISK_REWARD_RATIO * STOPS_INFO_TEMP), Digits);
	}
	else
	{   if(TYPE == OP_BUY)	return NormalizeDouble(Bid - STOPS_INFO_TEMP, Digits);
    	else			return NormalizeDouble(Ask + STOPS_INFO_TEMP, Digits);
}	}