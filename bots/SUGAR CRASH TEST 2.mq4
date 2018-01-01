//SUGAR CRASH VERSION 3 - - BEGIN DATE: 02/08/2016
//github: kurt-apple

//old bot, needs testing and research (or a garbage bin)

enum	colors { XGREEN=2,XGRAY=3,XRED=4 };

uint 	TP 	= 500;
uint 	SL 	= TP / 2;
uint 	USERPRD	= 2;
extern double mult = 10000;
extern double losmult = 1.01;
extern double winmult = 0.7;
double	LOT	= AccountBalance() / mult;

int     	Tt	= 0;
int   		TtLast	= 0;

void OnTick()
{	double TPB = Bid + TP * Point;
	double SLB = Bid - SL * Point;
	double TPS = Ask - TP * Point;
	double SLS = Ask + SL * Point;
	
	LOT=NormalizeDouble(AccountBalance()/mult,2)+0.01;
 
   	if(AccountBalance()<1000)
 	{	ExpertRemove();
 	}

	if((OrdersTotal()==0) && breakout(USERPRD))
 	{	if(OrderSelect(TtLast,SELECT_BY_TICKET))
    	{	if( OrderProfit() > 0 )
    		{	mult *= winmult;
    		}
    		
     		else
     		{	mult *= losmult;
         	}	
        }
     	else if(!OrderSelect(TtLast, SELECT_BY_TICKET))
     	{	mult *= 1.01;
     	}
  		if(IndColor()==XGREEN)
    	{	Tt=OrderSend(Symbol(),OP_BUY,LOT,Ask,10*Point,SLB,TPB,"SC",clrGreen);
     		TtLast=Tt;
    	}
		else if(IndColor()==XRED)
		{	Tt=OrderSend(Symbol(),OP_SELL,LOT,Bid,10*Point,SLS,TPS,"SC",clrBlue);
	        TtLast=Tt;
		}
	}	

//
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

bool breakout(int periodinput)
{	for(int i=1; i<=periodinput; i++)
	{	if(IndColor(i) != XGRAY) return false;
	}
	if(IndColor(0) != XGRAY) return true;
	else return false;
}
