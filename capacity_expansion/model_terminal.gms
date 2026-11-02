$title Capacity expansion: terminal conditions and quadratic costs

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
    t          "available calendar years" / 2027*2066 /
    base_year(t) "original comparison years from discount.csv"
    costType   / investment, fixed_om, vom /
    capType    / existing, maximum /
    txType     / existing, maximum, investment /;

* Load domains before loading indexed parameters.
* t includes 20 extra years; base_year identifies the original CSV horizon.
$gdxin discount.gdx
$load base_year=Dim1
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
    b(i)       "upfront new generation investment cost USD/MW"
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
    bF         "upfront new transmission investment cost USD/MW";

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

* Use the original model's 20-year conversion for BOTH investment inputs.
* These coefficients are charged once, in the year capacity is built.
b(i)       = 20 * rawCost(i,'investment');
m(i)       = rawCost(i,'fixed_om');
vcost(i)   = rawCost(i,'vom');
K0(r,i)    = rawCap(r,i,'existing');
Cmax(r,i)  = rawCap(r,i,'maximum');
F0         = rawTx('existing');
Fmax       = rawTx('maximum');
bF         = 20 * rawTx('investment');
valtran(r,rr)  = yes$(arcData(r,rr) > 0);


Scalars
    g                  "terminal annual COST growth rate" / 0.03 /
    drate              "discount rate (overrides discount.csv, as in model.gms)" / 0.04 /
    demand_growth      "annual demand growth after the input horizon" / 0.02 /
    extra_years        "additional years for extend_horizon" / 20 /
    lifetime           "generation accounting life in years" / 20 /
    tx_lifetime        "transmission accounting life in years" / 20 /
    gen_slope          "generation marginal-cost slope USD/MWh per MW" / 0.10 /
    build_premium      "fractional marginal build-cost increase at reference MW" / 0.50 /
    build_reference    "reference annual build MW for generation and transmission" / 100 /
    t0                 "first input year"
    tmax               "last input year"
    terminal_multiple  "present-value multiple including the terminal year"
    terminal_on        "one only in infinite_horizon case";

Sets
*!!!
    tc                 "terminal treatment"
        / do_nothing, extend_horizon, salvage_value, infinite_horizon /
    active_year(t)     "years in the current solve"
    terminal_year(t)   "last year in the original horizon"
    prev_year(t,tt)    "all investment years through t"
    prior_year(t,tt)   "immediately preceding year";

Parameters
    qGen(i)            "quadratic generation slope USD/MWh per MW"
    qBuild(i)          "quadratic generation-build slope USD/MW squared"
    qTx                "quadratic transmission-build slope USD/MW squared"
    remainder(i,t)     "generation lifetime fraction remaining after tmax"
    remainder_tx(t)    "transmission lifetime fraction remaining after tmax"
    capital_weight(t)  "discount factor including any terminal multiple"
    operating_weight(t) "discount factor including any terminal multiple"
    net_capital(i,t)   "fraction of generation build cost net of salvage"
    net_tx(t)          "fraction of transmission build cost net of salvage"
    rep(tc,*,*,*,*,t)  "case, decision, region, technology/destination, block, year";

abort$(card(base_year)<2) "At least two input years are required";
t0 = smin(t$base_year(t),t.val);
tmax = smax(t$base_year(t),t.val);

terminal_year(t) = yes$(t.val=tmax);
prev_year(t,tt) = yes$(tt.val<=t.val);
prior_year(t,tt) = yes$(tt.val=t.val-1);
delta(t) = 1 / (1+drate)**(t.val-t0);

d(r,h,t)$(t.val>tmax) = sum(tt$terminal_year(tt),d(r,h,tt))
                         * (1+demand_growth)**(t.val-tmax);

qGen(i) = gen_slope;
qBuild(i) = build_premium*b(i)/build_reference;
qTx = build_premium*bF/build_reference;

remainder(i,t) = max(0,lifetime-(tmax-t.val+1))/lifetime;
remainder_tx(t) = max(0,tx_lifetime-(tmax-t.val+1))/tx_lifetime;

terminal_multiple = (1+drate)/(drate-g);

Positive Variables
    x(r,i,t)           "new generation capacity MW"
    K(r,i,t)           "total installed generation capacity MW"
    GEN(r,i,h,t)       "generation MW"
    f(r,rr,h,t)        "directed power flow MW"
    z(t)               "new transmission capacity MW"
    KF(t)              "total installed transmission capacity MW";
Variable tot_cost      "discounted objective USD";

Equations
    eq_objfn
    eq_capaccumulation(r,i,t)
    eq_tx_accumulation(t)
    supply_demand(r,h,t)
    eq_caplim(r,i,h,t)
    eq_txlim(h,t)
    eq_terminal_gen(r,i,t)
    eq_terminal_tx(t);

eq_objfn.. tot_cost =e= sum(t$active_year(t),
    capital_weight(t) * (
        sum((r,i), net_capital(i,t) *
            (b(i)*x(r,i,t) + 0.5*qBuild(i)*sqr(x(r,i,t))))
        + net_tx(t)*(bF*z(t) + 0.5*qTx*sqr(z(t)))
    )
    + operating_weight(t) * (
        sum((r,i),m(i)*K(r,i,t))
        + sum((r,i,h),omega(h)*
            (vcost(i)*GEN(r,i,h,t) + 0.5*qGen(i)*sqr(GEN(r,i,h,t))))
    )
);

eq_capaccumulation(r,i,t)$active_year(t)..
    K(r,i,t) =e= K0(r,i)
        + sum(tt$(active_year(tt) and prev_year(t,tt)),x(r,i,tt));

eq_tx_accumulation(t)$active_year(t)..
    KF(t) =e= F0
        + sum(tt$(active_year(tt) and prev_year(t,tt)),z(tt));

supply_demand(r,h,t)$active_year(t)..
    sum(i,GEN(r,i,h,t))
    + sum(rr$valtran(rr,r),f(rr,r,h,t))
    - sum(rr$valtran(r,rr),f(r,rr,h,t)) =e= d(r,h,t);

eq_caplim(r,i,h,t)$active_year(t)..
    GEN(r,i,h,t) =l= phi(r,i,h)*K(r,i,t);

eq_txlim(h,t)$active_year(t)..
    sum((r,rr)$valtran(r,rr),f(r,rr,h,t)) =l= KF(t);

eq_terminal_gen(r,i,t)$(terminal_on and terminal_year(t))..
    x(r,i,t) =e= g*sum(tt$prior_year(t,tt),K(r,i,tt));

eq_terminal_tx(t)$(terminal_on and terminal_year(t))..
    z(t) =e= g*sum(tt$prior_year(t,tt),KF(tt));

Model cem_terminal / all /;
option limrow=0, limcol=0, solprint=off;

loop(tc,
    active_year(t) = base_year(t);
    terminal_on = 0;
    capital_weight(t) = delta(t);
    operating_weight(t) = delta(t);
    net_capital(i,t) = 1;
    net_tx(t) = 1;

    if(sameas(tc,'extend_horizon'),
        active_year(t) = yes$(t.val>=t0 and t.val<=tmax+extra_years);
    );

    if(sameas(tc,'salvage_value'),
        net_capital(i,t)$base_year(t) = 1
            - remainder(i,t)/(1+drate)**(tmax-t.val+1);
        net_tx(t)$base_year(t) = 1
            - remainder_tx(t)/(1+drate)**(tmax-t.val+1);
    );

    if(sameas(tc,'infinite_horizon'),
        terminal_on = 1;
        capital_weight(t)$terminal_year(t) = delta(t)*terminal_multiple;
        operating_weight(t)$terminal_year(t) = delta(t)*terminal_multiple;
    );

*reset level values
    x.lo(r,i,t) = 0;
    x.up(r,i,t) = 0;
    x.up(r,i,t)$active_year(t) = inf;
    K.lo(r,i,t) = 0;
    K.up(r,i,t) = 0;
    K.up(r,i,t)$active_year(t) = Cmax(r,i);
    GEN.lo(r,i,h,t) = 0;
    GEN.up(r,i,h,t) = 0;
    GEN.up(r,i,h,t)$active_year(t) = inf;
    f.lo(r,rr,h,t) = 0;
    f.up(r,rr,h,t) = 0;
    f.up(r,rr,h,t)$(active_year(t) and valtran(r,rr)) = inf;
    z.lo(t) = 0;
    z.up(t) = 0;
    z.up(t)$active_year(t) = inf;
    KF.lo(t) = 0;
    KF.up(t) = 0;
    KF.up(t)$active_year(t) = Fmax;
    x.l(r,i,t) = 0;
    K.l(r,i,t) = 0;
    GEN.l(r,i,h,t) = 0;
    f.l(r,rr,h,t) = 0;
    z.l(t) = 0;
    KF.l(t) = 0;
    tot_cost.l = 0;

    solve cem_terminal using qcp minimizing tot_cost;
    abort$(cem_terminal.solvestat<>1 or
        (cem_terminal.modelstat<>1 and cem_terminal.modelstat<>2))
        "Terminal case failed; comparison not exported", tc,
        cem_terminal.solvestat, cem_terminal.modelstat;

    rep(tc,'K',r,i,'all',t)$base_year(t) = K.l(r,i,t) + eps;
    rep(tc,'x',r,i,'all',t)$base_year(t) = x.l(r,i,t) + eps;
    rep(tc,'GEN',r,i,h,t)$base_year(t) = GEN.l(r,i,h,t) + eps;
    rep(tc,'generation_mwh',r,i,'all',t)$base_year(t) =
        sum(h,omega(h)*GEN.l(r,i,h,t)) + eps;
    rep(tc,'KF','all','all','all',t)$base_year(t) = KF.l(t) + eps;
    rep(tc,'z','all','all','all',t)$base_year(t) = z.l(t) + eps;
    rep(tc,'f',r,rr,h,t)$(base_year(t) and valtran(r,rr)) =
        f.l(r,rr,h,t) + eps;
    rep(tc,'annual_cost','all','all','all',t)$base_year(t) =
        sum((r,i),b(i)*x.l(r,i,t) + 0.5*qBuild(i)*sqr(x.l(r,i,t))
            + m(i)*K.l(r,i,t))
        + bF*z.l(t) + 0.5*qTx*sqr(z.l(t))
        + sum((r,i,h),omega(h)*(vcost(i)*GEN.l(r,i,h,t)
            + 0.5*qGen(i)*sqr(GEN.l(r,i,h,t)))) + eps;
    rep(tc,'pv_cost','all','all','all',t)$base_year(t) =
        delta(t)*rep(tc,'annual_cost','all','all','all',t) + eps;
* Method-specific objectives use DIFFERENT horizons/terminal credits.
* Compare pv_cost over the common years when comparing actual expenditure.
    rep(tc,'objective','all','all','all',t)$terminal_year(t) = tot_cost.l + eps;
    rep(tc,'modelstat','all','all','all',t)$terminal_year(t) = cem_terminal.modelstat;
    rep(tc,'solvestat','all','all','all',t)$terminal_year(t) = cem_terminal.solvestat;
);

execute_unload 'rep_terminal.gdx', rep;
execute 'gdxdump rep_terminal.gdx symb=rep format=csv epsOut=0 output=rep_terminal.csv header="case,decision,region,technology_or_destination,block,year,value"';

