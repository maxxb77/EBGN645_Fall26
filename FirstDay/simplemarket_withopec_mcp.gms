set r /USA, OPEC, ROW/ ; 

parameter
pbar(r) /USA 90, OPEC 90, ROW 100/, 
qbar_s(r) /USA 22, OPEC 32, ROW 50/, 
qbar_d(r) /USA 20.5, OPEC 10, ROW 73/,
e_d /-0.12/,
e_s /0.15/ ; 


*!!! fixing this on 9/21
qbar_d("row") = sum(r,qbar_s(r)) - qbar_d("USA") - qbar_d("OPEC") ; 

parameter a(r), b(r),  c(r),  d(r); 

b(r) = pbar(r) / (e_d * qbar_d(r)) ; 
a(r) = pbar(r) - b(r) * qbar_d(r) ; 
d(r) = pbar(r) / (e_s * qbar_s(r)) ; 
c(r) = pbar(r) - d(r) * qbar_s(r) ; 

scalar e ; 
e = pbar("ROW") - pbar("USA") ; 

positive variable Qd(r), Qs(r) ; 
positive variable X(r) "exports" ;
variable W "total welfare" ; 

equation objfn, market_clearing_usa, market_clearing_row ; 

objfn.. W =e=
    sum(r, a(r) * Qd(r) + b(r) * Qd(r) * Qd(r) / 2 
    - c(r) * Qs(r) - d(r) * Qs(r) * Qs(r) / 2 ) 
    - sum(r,e * X(r)); 

equation market_clearing_opec; 

market_clearing_usa.. Qd("USA") + X("USA") =e= Qs("USA") ;
market_clearing_opec.. Qd("OPEC") + X("OPEC") =e= Qs("OPEC") ;
market_clearing_row.. Qd("ROW") =e= Qs("ROW") + X("USA") + X("OPEC")  ; 

model simple /all/ ; 

solve simple using QCP maximizing W ; 

parameter rep ; 
rep("BAU","Qd",r) = qd.l(r) ; 
rep("BAU","Qs",r) = qs.l(r) ; 
rep("BAU","P",'USA') = market_clearing_usa.m ; 
rep("BAU","P",'ROW') = market_clearing_row.m ; 
rep("BAU","P",'OPEC') = market_clearing_row.m ; 



c("OPEC") = 0.5 * c("OPEC") ; 


solve simple using QCP maximizing W ; 
parameter rep ; 
rep("shock","Qd",r) = qd.l(r) ; 
rep("shock","Qs",r) = qs.l(r) ; 
rep("shock","P",'USA') = market_clearing_usa.m ; 
rep("shock","P",'ROW') = market_clearing_row.m ; 

execute_unload 'alldata_simple.gdx' ; 

