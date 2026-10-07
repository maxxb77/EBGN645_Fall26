set r /USA, ROW/ ; 

parameter
pbar(r) /USA 4, ROW 6/, 
qbar_s(r) /USA 120, ROW 180/, 
qbar_d(r) /USA 100, ROW 200/,
e_d /-0.4/,
e_s /0.8/ ; 

scalar xref; 
xref = qbar_d("row") - qbar_s("row") ; 

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

equation objfn; 

objfn.. W =e=
    sum(r, a(r) * Qd(r) + b(r) * Qd(r) * Qd(r) / 2 
    - c(r) * Qs(r) - d(r) * Qs(r) * Qs(r) / 2 ) 
    - e * X; 

equation market_clearing(r) ; 

market_clearing(r).. Qs(r) + X$sameas(r,"ROW") 
                 =g= Qd(r) + X$sameas(r,"USA")  ;

model simple /all/ ; 

solve simple using QCP maximizing W ; 

parameter rep ; 
rep("BAU","Qd",r) = qd.l(r) ; 
rep("BAU","Qs",r) = qs.l(r) ; 
rep("BAU","P",r) = market_clearing.m(r) ; 

equations
foc_qs(r), foc_qd(r), foc_x ; 
positive variable P(r) ; 

foc_qs(r).. c(r)+d(r)*Qs(r) =g= P(r) ; 
foc_qd(r).. P(r)=g=a(r)+b(r)*Qd(r) ; 
foc_x.. e+P("USA") =g= P("ROW") ;  

model simplest_mcp 
/
foc_qs.Qs,
foc_qd.Qd,
foc_x.X,
market_clearing.P
/;

P.l(r) = -market_clearing.m(r) ; 

*set the iteration limit to zero
simplest_mcp.iterlim = 0 ; 
solve simplest_mcp using mcp ; 
parameter rep ; 
rep("MCP","P",r) = p.l(r) ;
rep("MCP","Qs",r) = qs.l(r) ; 
rep("MCP","Qd",r) = qd.l(r) ;  

equation eq_profit_usa ; 
variable profit_usa ; 

eq_profit_usa.. profit_usa =e= 
    P("USA") * Qd("USA") 
    + (P("ROW") - e) * x
    - c("USA") * Qs("USA") 
    - d("USA") * Qs("USA") * Qs("USA") / 2 ; 

*foc_qd
equation foc_qs_mpec ; 
foc_qs_mpec(r)$[not sameas(r,"USA")].. 
    c(r)+d(r)*Qs(r) =g= P(r) ; 

model simple_mpec 
/
eq_profit_usa,
foc_qd.Qd,
market_clearing.P,
foc_qs_mpec.Qs
/ ; 

solve simple_mpec using mpec maximizing profit_usa ; 

rep("MPEC","P",r) = a(r) + b(r) * Qd.l(r) ;
rep("MPEC","Qs",r) = qs.l(r) ; 
rep("MPEC","Qd",r) = qd.l(r) ;  

execute_unload 'mpec_data.gdx' ; 

equation mpec_foc_qs, mpec_foc_qd, mpec_foc_x, mpec_market_clearing ; 

* conversion to mpec_mcp
mpec_foc_qs(r).. 
c(r)+d(r)*Qs(r) =g= P(r) + (b("USA") * Qd("USA"))$sameas(r,"USA") ; 

mpec_foc_qd(r).. P(r)=g=a(r)+b(r)*Qd(r) ; 

scalar beta ; 

beta = d("row") * b("row") / (d("row")-b("row")) ; 

mpec_foc_x.. e+P("USA") + (b("USA") * Qd("USA"))  
             =g= 
             P("ROW") + beta * X ;  

mpec_market_clearing(r)..     Qs(r) + X$sameas(r,"ROW") 
                          =g= Qd(r) + X$sameas(r,"USA")  ;

model mpec_mcp 
/
mpec_foc_qs.Qs,
mpec_foc_qd.Qd,
mpec_foc_x.X,
mpec_market_clearing.P
/;

solve mpec_mcp using mcp ; 

rep("MPEC_MCP","P",r) = a(r) + b(r) * Qd.l(r) ;
rep("MPEC_MCP","Qs",r) = qs.l(r) ; 
rep("MPEC_MCP","Qd",r) = qd.l(r) ;  


*========= BEGIN FITTING MPEC =============
equations alma_foc_qs(r), alma_foc_qd(r), alma_foc_x,
          alma_market_clearing(r), fitting_objective ;

variable chat(r), Z ;
positive variable dhat(r) ;
negative variable bhat(r) ;

alma_foc_qs(r)..
   chat(r) + dhat(r) * Qs(r)
   =g= P(r) + (bhat("USA") * Qd("USA"))$sameas(r,"USA") ;

alma_foc_qd(r)..
   P(r) =g= pbar(r) + bhat(r) * (Qd(r) - qbar_d(r)) ;

alma_foc_x..
   e + P("USA") + bhat("USA") * Qd("USA")
   =g= P("ROW")
       + dhat("ROW") * bhat("ROW")
         / (dhat("ROW") - bhat("ROW")) * X ;

alma_market_clearing(r)..
   Qs(r) + X$sameas(r,"ROW")
   =g= Qd(r) + X$sameas(r,"USA") ;

fitting_objective.. Z =e=
   sum(r,
       power((P(r) - pbar(r)) / pbar(r), 2)
     + power((Qs(r) - qbar_s(r)) / qbar_s(r), 2)
     + power((Qd(r) - qbar_d(r)) / qbar_d(r), 2) ) ;

model alma_fitting
/
   fitting_objective,
   alma_foc_qs.Qs,
   alma_foc_qd.Qd,
   alma_foc_x.X,
   alma_market_clearing.P
/ ;

dhat.fx(r) = d(r) ;
bhat.up(r) = -1e-6 ;
bhat.fx("ROW") = b("ROW") ;
chat.l(r) = c(r) ;
bhat.l(r) = b(r) ;
P.l(r) = pbar(r) ;
Qs.l(r) = qbar_s(r) ;
Qd.l(r) = qbar_d(r) ;
X.l = xref ;
solve alma_fitting using mpec minimizing Z ;

parameter rep_fitted ;
rep_fitted(r,"pbar") = pbar(r) ;
rep_fitted(r,"p") = P.l(r) ;
rep_fitted(r,"qbar_d") = qbar_d(r) ;
rep_fitted(r,"qd") = Qd.l(r) ;
rep_fitted(r,"qbar_s") = qbar_s(r) ;
rep_fitted(r,"qs") = Qs.l(r) ;

execute_unload 'alma_fitted.gdx' ;
