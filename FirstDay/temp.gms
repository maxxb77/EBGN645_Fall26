equation alma_foc_qs, alma_foc_qd, alma_foc_x, alma_market_clearing ; 

variable chat, dhat ; 

* conversion to alma_mcp
alma_foc_qs(r).. 
chat(r)+dhat(r)*Qs(r) =g= P(r) + (b("USA") * Qd("USA"))$sameas(r,"USA") ; 

alma_foc_qd(r).. P(r)=g=a(r)+b(r)*Qd(r) ; 

scalar beta ; 

beta = d("row") * b("row") / (d("row")-b("row")) ; 

alma_foc_x.. e+P("USA") + (b("USA") * Qd("USA"))  
             =g= 
             P("ROW") + dhat("row") * b("row") / (dhat("row")-b("row")) * X ;  

alma_market_clearing(r)..     Qs(r) + X$sameas(r,"ROW") 
                          =g= Qd(r) + X$sameas(r,"USA")  ;

equation fitting_objective ; 
variable Z ; 

fitting_objective.. Z =e= sum(r, ((p(r)-pbar(r)/ pbar(r)))**2 + ((qs(r)-qbar_s(r))/qbar_s(r))**2 + ((x-xref)/xref)**2) ; 

model alma_mcp 
/
fitting_objective,
alma_foc_qs.Qs,
alma_foc_qd.Qd,
alma_foc_x.X,
alma_market_clearing.P
/;