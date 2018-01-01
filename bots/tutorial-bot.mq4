
//SUGAR CRASH VERSION 3 - - BEGIN DATE: 02/08/2016


//basic bot I made loaded with comments to introduce a friend to C99/MQL

//format notes
//comments precede the lines of code for which it is relevant

//enum: a way to make a bunch of related constants, labels to ints
//this enumeration is used for the functions IndAO and IndAC for their predictions
//red: price dropping. gray: not a clear movement. green: price rising.
//the specific numbers are for the sum of IndAO and IndAC to be readable elsewhere
enum	colors { XGREEN=2,XGRAY=3,XRED=4 };

//TakeProfit: this is the number of pips added to the current price of an invest
//for it to be automatically sold as a successful trade. optimization has
//concluded that 500 is generally the best amount and slightly less for StopLoss.
	//pips: the smallest recordable unit movement in the investment.
	//for instance: 1.5000 to 1.5001 would be 1 pip.
	//pip size and monetary value vary based on what is being invested and how
	//it is sold/presented by your broker.
uint 	TakeProfit 	= 500;
uint 	StopLoss 	= TakeProfit - 10;

//USERPERIOD is a variable that controls how far back the analysis of the invest
//looks in order to determine if the current movement is significant enough to
//place a new order.
uint 	USERPERIOD	= 2;

extern double investbalance = AccountBalance()/10;
extern double commission = 0.1;
//base currency over quote currency.
double LOT = investbalance / LotValue;

//Tt is an integer that holds the ticket number of the last trade placed in the
//trade system and sent to your broker.
//TtLast is used in some code in order to select and refer to specifically the
//previous trade successfully made in the trade system.
int     	Tt	= 0;
int   		TtLast	= 0;

//OnTick() is a built-in function that is run in production after every single
//chart movement, or tick.
void OnTick()
{	//these are the actual prices associated with TakeProfits and StopLosses
		//B stands for Buy, and S stands for Sell.
		//You can order either direction. If you have reason to believe the invest
		//will move downward in price, then you can short-sell it.
		//
		//Point	is a built-in function that is used to make the code compatible
		//between trade systems with 5 digits for the pricing and trade systems
		//with 6 digits, or any variance therein. It basically multiplies by 10.
	double TPB = Bid + TakeProfit * Point;
	double SLB = Bid - StopLoss * Point;
	double TPS = Ask - TakeProfit * Point;
	double SLS = Ask + StopLoss * Point;
	
	//the final calculation of how many lots should be ordered if we make an order
	LOT=NormalizeDouble(AccountBalance()/mult,2)+0.01;
 
 	//primarily for debugging with a starting balance of $10K, implying loss $9K.
   	if(AccountBalance()<1000)
     	{	//quit, essentially	
     		ExpertRemove();
     	}

	//if there are no current orders, and there is a significant movement occuring
	if((OrdersTotal()==0) && breakout(USERPERIOD))
     	{	//if the last order is selectable:
      		if(OrderSelect(TtLast,SELECT_BY_TICKET))
        	{	//if the last trade was profitable:	
        		if( OrderProfit() > 0 )
        		{	//change the multiplier used to determine lot amount.	
        			mult *= winmult;
        		}
        		
         		else
         		{	//change the multiplier used to determine lot amount.	
         			mult *= losmult;
         	}	}
         	//otherwise, if the ticket does not generate previous trade info:
         	else if(!OrderSelect(TtLast, SELECT_BY_TICKET))
         	{	//reduce risk.
         		//this doubles as a feature (3/28/2016) to lower LOTS if the bot
         		//becomes so confident that it tries to draw an impossible
         		//amount of funds.
         		mult *= 1.01;
         	}

			//if the analysis of the chart suggests it is going up:
      		if(IndColor()==XGREEN)
        	{	//order the appropriate amount at the broker's Ask price and
        		//store ticket info in Tt.
        		Tt=OrderSend(Symbol(),OP_BUY,LOT,Ask,10*Point,SLB,TPB,"SC USA",clrGreen);
         		TtLast=Tt;
        	}
		
		//if the analysis of the chart suggests it is going down:
		else if(IndColor()==XRED)
		{	//order the appropriate amount at the broker's Bid price and
			//store ticket info in Tt.	
			Tt=OrderSend(Symbol(),OP_SELL,LOT,Bid,10*Point,SLS,TPS,"SC USA",clrBlue);
	         	TtLast=Tt;
}	}	}

//AC is short for "Accelerator/Decelerator Oscillator." yes, really.
//oscillators are used to try to detect wave-like patterns in the chart.
//one disadvantage of most oscillators I've seen is that their output
//is single-dimensional... it tries to describe a wave in a single number
//which sometimes makes it as useless as just looking at the chart manually.
//this system uses AC as well as AO (below) to counteract some shortcomings
//of oscillators. These two oscillators were created by Bill Williams as
//part of his economic theories and trading practices and strategies that he
//teaches to people for crazy amounts of money.
int IndAC(int POS=0)
{	int DirAC=1;
	//the general format of any built-in indicator function is:
	//double iINDNAME(SYMBOLNAME, TIMEFRAME, POSITION).
		//the function is of type double, and double is a precise decimal-point type.
		//each indicator function begins its name with a lowercase "i"
		//the symbol name, for instance, USDCAD for the exchange between USD & Canadian
		//timeframe is the size of each bar for the symbol. 0 means the current period
		//position is the number of bars to count back from the current one. 0 is now.
	double AC_0 = iAC(Symbol(),0,POS);
	double AC_1 = iAC(Symbol(),0,POS+1);
	if(AC_0>AC_1) { DirAC = 1; }
	if(AC_0<AC_1) { DirAC = 2; }
	return DirAC;
}

//AO is short for "Awesome Oscillator." Something important to note is that
//not only does this system of two oscillators detect wave patterns, it also
//correlates the two values and finds only ups or downs that are of statistic
//significance. The movements are large enough that they suit trading upon.
int IndAO(int POS=0)
{	int DirAO=1;
	double AO_0 = iAO(Symbol(),0,POS);
	double AO_1 = iAO(Symbol(),0,POS+1);
	if(AO_0>AO_1) { DirAO = 1; }
	if(AO_0<AO_1) { DirAO = 2; }
	return DirAO;
}

//this method, using the two indicators, has been reverse-engineered from a
//strategy shared online. my adaptation has several advantages for readability
//compatibility with an automated trading system, and also will work with self
//optimization features to come. lastly, the breakout function below is OC.
int IndColor(int POS=0) { return IndAO(POS)+IndAC(POS); }

//breakout senses any significant shift up or down after the specified number
//of bars that simply didn't have enough movement to trade on for this strategy
bool breakout(int periodinput)
{	for(int i=1; i<=periodinput; i++)
	{	//see how nice and readable that becomes with the enum?
		if(IndColor(i) != XGRAY) return false;
	}
	if(IndColor(0) != XGRAY) return true;
	else return false;
}
