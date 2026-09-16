set t 'years' /0*20/ ; 
set v "vintage" /new, exist/ ; 


scalar r 'discount rate' /0.03/ ; 

parameter discfact(t) ; 
discfact(t) = 1/[(1+r)**t.val] ; 

scalar demgrowth /0.01/ ; 

parameter d(t) ; 
d(t) = 5 * (1+demgrowth)** t.val ; 

scalar kbar /10/ ;

scalar inv_cost /10/; 

parameter op_cost(v) ; 
op_cost("exist") = 1 ; 
op_cost("new") = 1 ; 

positive variables X(v,t) "production", K(v,t), I(t) ; 
variable C ; 

equation objfn_eq, capacity_limit_exist, capacity_limit_new, cap_gen ; 

objfn_eq.. C =e= sum(t,discfact(t) * (inv_cost * I(t) + sum(v, op_cost(v) * X(v,t)))) ; 

capacity_limit_exist(t).. kbar =g= K("exist",t) ; 

alias(t,tt) ; 
capacity_limit_new(t).. sum(tt$[tt.val<=t.val],I(tt)) =g= K("new",t) ; 

cap_gen(v,t).. K(v,t) =g= X(v,t) ; 

equation demand ; 
demand(t)..  sum(v,x(v,t)) =g= d(t) ; 

model invest /all/ ; 

solve invest using LP minimizing C ; 

set looper /1*100/ ; 

parameter rep; 

loop(looper,
    inv_cost = looper.val  ; 
    solve invest using lp minimizing C ; 
    rep(looper,"X",v,t) = x.l(v,t) ; 
    rep(looper,"I","new",t) = I.l(t) ; 
); 

execute_unload 'invest.gdx' ; 