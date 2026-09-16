set r /USA, ROW/ ; 

parameter
pbar(r) /USA 4, ROW 6/, 
qbar_s(r) /USA 120, ROW 180/, 
qbar_d(r) /USA 100, ROW 200/,
e_d /-0.4/,
e_s /0.8/ ; 

parameter a(r), b(r),  c(r),  d(r); 

b(r) = pbar(r) / (e_d * qbar_d(r)) ; 
a(r) = pbar(r) - b(r) * qbar_d(r) ; 
d(r) = pbar(r) / (e_s * qbar_s(r)) ; 
c(r) = pbar(r) - d(r) * qbar_s(r) ; 

scalar e ; 
e = pbar("ROW") - pbar("USA") ; 

positive variable Qd(r), Qs(r) ; 
positive variable X "exports" ;
variable W "total welfare" ; 

equation objfn, market_clearing_usa, market_clearing_row ; 

objfn.. W =e=
    sum(r, a(r) * Qd(r) + b(r) * Qd(r) * Qd(r) / 2 
    - c(r) * Qs(r) - d(r) * Qs(r) * Qs(r) / 2 ) 
    - e * X; 

market_clearing_usa.. Qd("USA") + X =e= Qs("USA") ;
market_clearing_row.. Qd("ROW") =e= Qs("ROW") + X  ; 

model simple /all/ ; 

solve simple using QCP maximizing W ; 
parameter rep ; 
rep("BAU","Qd",r) = qd.l(r) ; 
rep("BAU","Qs",r) = qs.l(r) ; 
rep("BAU","P",'USA') = market_clearing_usa.m ; 
rep("BAU","P",'ROW') = market_clearing_row.m ; 

execute_unload 'alldata_simple.gdx' ; 



c("ROW") = 0.5 * c("ROW") ; 


solve simple using QCP maximizing W ; 
parameter rep ; 
rep("shock","Qd",r) = qd.l(r) ; 
rep("shock","Qs",r) = qs.l(r) ; 
rep("shock","P",'USA') = market_clearing_usa.m ; 
rep("shock","P",'ROW') = market_clearing_row.m ; 

execute_unload 'alldata_simple.gdx' ; 

