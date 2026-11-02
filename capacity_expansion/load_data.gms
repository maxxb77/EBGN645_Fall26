$title Capacity expansion CSV loader

$call csv2gdx "technology_costs.csv" output="technology_costs.gdx" id=rawCost index=1,2 value=3 useHeader=y storeZero=y trace=0
$if errorlevel 1 $abort Failed to import technology_costs.csv

$call csv2gdx "generation_capacity.csv" output="generation_capacity.gdx" id=rawCap index=1,2,3 value=4 useHeader=y storeZero=y trace=0
$if errorlevel 1 $abort Failed to import generation_capacity.csv

$call csv2gdx "availability.csv" output="availability.gdx" id=phi index=1,2,3 value=4 useHeader=y storeZero=y trace=0
$if errorlevel 1 $abort Failed to import availability.csv

$call csv2gdx "demand.csv" output="demand.gdx" id=d index=1,2,3 value=4 useHeader=y storeZero=y trace=0
$if errorlevel 1 $abort Failed to import demand.csv

$call csv2gdx "discount.csv" output="discount.gdx" id=delta index=1 value=2 useHeader=y storeZero=y trace=0
$if errorlevel 1 $abort Failed to import discount.csv

$call csv2gdx "block_hours.csv" output="block_hours.gdx" id=omega index=1 value=2 useHeader=y storeZero=y trace=0
$if errorlevel 1 $abort Failed to import block_hours.csv

$call csv2gdx "transmission.csv" output="transmission.gdx" id=rawTx index=1 value=2 useHeader=y storeZero=y trace=0
$if errorlevel 1 $abort Failed to import transmission.csv

$call csv2gdx "arcs.csv" output="arcs.gdx" id=arcData index=1,2 value=3 useHeader=y storeZero=y trace=0
$if errorlevel 1 $abort Failed to import arcs.csv

Sets
    r          "regions"
    i          "technologies"
    h          "operating blocks"
    t          "investment years"
    costType   / investment, fixed_om, vom /
    capType    / existing, maximum /
    txType     / existing, maximum, investment /;

* Load domains before loading indexed parameters.
* t is loaded in chronological CSV order, before any other year-indexed data.
$gdxin discount.gdx
$load t=Dim1
$gdxin technology_costs.gdx
$load i=Dim1
$gdxin generation_capacity.gdx
$load r=Dim1
$gdxin block_hours.gdx
$load h=Dim1
$gdxin

Alias (r,rr);
Alias (t,tt);

Set valtran(r,rr) "allowed directed transmission flows";

Parameters
    rawCost(i,costType)
    rawCap(r,i,capType)
    rawTx(txType)
    arcData(r,rr)
    b(i)       "annualized new generation investment cost USD/MW/year"
    m(i)       "fixed generation maintenance cost USD/MW/year"
    vcost(i)   "variable generation cost USD/MWh"
    K0(r,i)    "existing generation capacity MW"
    Cmax(r,i)  "maximum TOTAL generation capacity MW"
    phi(r,i,h) "available fraction of generation capacity"
    d(r,h,t)   "electricity demand MW"
    delta(t)   "discount factor"
    omega(h)   "hours represented by each block per year";

Scalars
    F0         "existing transmission capacity MW"
    Fmax       "maximum TOTAL transmission capacity MW"
    bF         "annualized new transmission investment cost USD/MW/year";

* Domain-checked loads catch labels that are outside the declared sets.
$gdxin technology_costs.gdx
$loadDC rawCost
$gdxin generation_capacity.gdx
$loadDC rawCap
$gdxin availability.gdx
$loadDC phi
$gdxin demand.gdx
$loadDC d
$gdxin discount.gdx
$loadDC delta
$gdxin block_hours.gdx
$loadDC omega
$gdxin transmission.gdx
$loadDC rawTx
$gdxin arcs.gdx
$loadDC arcData
$gdxin

b(i)       = 20 * rawCost(i,'investment');
m(i)       = rawCost(i,'fixed_om');
vcost(i)   = rawCost(i,'vom');
K0(r,i)    = rawCap(r,i,'existing');
Cmax(r,i)  = rawCap(r,i,'maximum');
F0         = rawTx('existing');
Fmax       = rawTx('maximum');
bF         = rawTx('investment');
valtran(r,rr)  = yes$(arcData(r,rr) > 0);

* GAMS is case-insensitive: vcost represents mathematical c_i, leaving
* the symbol C available for the installed capacity decision variable.
* For cumulative investment, use sum(tau$(ord(tau)<=ord(t)), ...).

abort$(sum((r,i)$(K0(r,i)>Cmax(r,i)),1)>0)
    "Existing generation exceeds maximum generation capacity";
abort$(F0>Fmax) "Existing transmission exceeds maximum transmission capacity";
abort$(abs(sum(h,omega(h))-8760)>1e-6) "Block hours must sum to 8760";
abort$(sum((r,i,h)$((phi(r,i,h)<0) or (phi(r,i,h)>1)),1)>0)
    "Generation availability must lie between zero and one";
abort$(sum(r$valtran(r,r),1)>0) "Self-flows are not allowed";


*--- end codex-written code ---*


scalar g /0.03/, 
       drate /0.04/, 
       t0 ; 

parameter delta ; 
t0 = smin(t,t.val) ; 
delta(t) = (1/((1+drate)**[t.val-t0])) ; 


positive variable
x(r,i,t) "new generation capacity",
K(r,i,t) "total installed capacity",
GEN(r,i,h,t) "generation",
f(r,rr,h,t) "power flow"
z(t) "new transmission builds"
KF(t) "total transmission capacity" ; 

variable tot_cost 'objective function' ; 

equation eq_objfn ; 


set prev_year(t,tt) ; 
prev_year(t,tt)$[t.val>=tt.val] = yes ; 
display prev_year ; 

parameter remainder(i,t), s(i,t) ; 
scalar lifetime /20/ ; 
scalar tmax ; 
tmax = smax(t,t.val) ; 
remainder(i,t) = max(0, (lifetime - (tmax - t.val +1))) / lifetime ; 



eq_objfn.. tot_cost =e= sum(t, 
        delta(t) * 
        ( sum((r,i), b(i) * X(r,i,t) + m(i) * K(r,i,t))
            + bF * z(t)
            + sum((r,i,h),omega(h) * vcost(i) * GEN(r,i,h,t)) 
        ) ) ;



equation eq_capaccumulation(r,i,t) ; 

execute_unload 'input_data.gdx' ; 

eq_capaccumulation(r,i,t).. K(r,i,t) =e= K0(r,i) 
        + sum(tt$prev_year(t,tt), X(r,i,tt)) ; 

equation eq_tx_accumulation ; 

eq_tx_accumulation(t).. KF(t) =e= f0 + sum(tt$prev_year(t,tt),Z(tt)) ; 

equation supply_demand ; 
supply_demand(r,h,t).. sum(i,GEN(r,i,h,t)) 
    + sum(rr$[not sameas(r,rr)], F(rr,r,h,t) + F(r,rr,h,t) )
    =g= D(r,h,t) ; 

equation eq_caplim(r,i,h,t) ;
eq_caplim(r,i,h,t)..
GEN(r,i,h,t) =l= K(r,i,t) ;  


equation eq_txlim ; 
eq_txlim(h,t)..
    sum((r,rr),F(r,rr,h,t)) =l= KF(t) ; 

model cem /all/ ; 

solve cem using lp minimizing tot_cost ; 

parameter 
