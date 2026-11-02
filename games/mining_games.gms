set
    m "material"
/
$include material.csv
/,
    r "country/region"
/
$include country.csv
/,
    s "stage"
/
$include stage.csv
/
; 

set rep_m(m) "represented materials" ; 
rep_m(m) = no ; 
rep_m(m)$sameas(m,"cadmium") = yes ; 
rep_m(m)$sameas(m,"copper") = yes ; 
rep_m(m)$sameas(m,"manganese") = yes ; 
*rep_m(m)$sameas(m,"silicon") = yes ; 

* gets filtered later based on whether we have price/production information
$ontext
rep_m(m) = yes ; 
rep_m(m)$sameas(m,"indium") = no ; 
rep_m(m)$sameas(m,"gallium") = no ; 
$offtext

parameter data(m,r,s)
/
$ondelim
$include production.csv
$offdelim 
/
;

parameter pbar(m) "--$/tonne-- market price"
/   
$ondelim
$include prices.csv
$offdelim
/;

parameter qbar(m) ; 
qbar(m) = sum(r,data(m,r,"production")) ;
rep_m(m)$[not qbar(m)] = no ;  
rep_m(m)$[not pbar(m)] = no ; 


parameter delas(m) "demand elasticity" ; 
delas(m) = 0.5 ; 

*!!! parameters to be treated as variables
positive variable  cbar(m,r) "reference cost"; 
* fix to price to start
cbar.fx(m,r) = pbar(m) ; 

positive variable selas(m,r) "inverse elasticity of supply" ;
* set relatively inelastic to start
selas.fx(m,r) = 2 ; 

positive variable q(m,r), p(m) ;
equation zpc_q, mcc ; 

set v_mr(m,r) ; 
v_mr(m,r)$[data(m,r,"production")$rep_m(m)] = yes ; 


parameter dshock(m) ; 
dshock(m) = 0 ; 

parameter qbar_mr(m,r) ; 
qbar_mr(m,r) = data(m,r,"production") ; 

mcc(m)$rep_m(m).. sum(r$v_mr(m,r),q(m,r)) 
                    =g= 
* note no need for inverse here                    
                  qbar(m) * 
                  (p(m) / pbar(m)) ** (-delas(m)) + dshock(m) ; 

scalar sw_gameon /0/; 
scalar sw_gamemult /1000/ ; 

alias(r,rr) ; 

scalar cost_opt /0/ ; 

zpc_q(m,r)$[rep_m(m)$v_mr(m,r)].. 
    cbar(m,r) * (q(m,r) / qbar_mr(m,r)) ** (1/selas(m,r))$[not cost_opt]

    + q(m,r) * (pbar(m) * qbar(m) ** (1/delas(m)) 
      / (delas(m) * (sum(rr$v_mr(m,rr),q(m,rr))) ** (1/delas(m) + 1) )
      )$sw_gameon 

    =g= p(m) ; 

model game
/
mcc.p,
zpc_q.q
/;

q.l(m,r)$v_mr(m,r) = qbar_mr(m,r) ; 
p.l(m)$rep_m(m) = pbar(m) ; 

parameter rep ; 
game.iterlim = 0 ; 
solve game using mcp ; 


rep("bau",m,r)$v_mr(m,r) = q.l(m,r) ; 


sw_gameon = 1 ; 
solve game using mcp ; 



game.iterlim = 1e5 ; 
solve game using mcp ; 
rep("game",m,r)$v_mr(m,r) = q.l(m,r) ; 


equation eq_mpec_obj ; 
variable mpec_obj ; 
eq_mpec_obj.. mpec_obj =e= 1e-5 * (
                        sum((m,r)$v_mr(m,r), power((q(m,r)-qbar_mr(m,r))/qbar_mr(m,r), 2)) 
*                        + 1e5 *  sum((m)$rep_m(m), power(pbar(m)-p(m), 2)) 
                    ); 

cbar.lo(m,r)$v_mr(m,r) = 0.1 * pbar(m) ; 
cbar.up(m,r)$v_mr(m,r) = 0.999 * pbar(m) ; 
cbar.l(m,r)$v_mr(m,r) = pbar(m) ; 


model mpec_calib
/
eq_mpec_obj,
mcc.p,
zpc_q.q
/;

solve mpec_calib using mpec minimizing mpec_obj ; 

$exit

parameter rep_mpec ; 
rep_mpec("cbar_calib",m,r,"cbar")$v_mr(m,r) = cbar.l(m,r) ; 
rep_mpec("cbar_calib",m,r,"ratio")$v_mr(m,r) = cbar.l(m,r) / pbar(m) ; 
rep_mpec("cbar_calib",m,r,"q_ratio")$v_mr(m,r) = q.l(m,r) / qbar_mr(m,r) ; 


cbar.fx(m,r) = cbar.l(m,r) ; 
selas.lo(m,r)$v_mr(m,r) = 0.15; 
selas.up(m,r)$v_mr(m,r) = 5 ; 
selas.l(m,r)$v_mr(m,r) = 2 ; 

solve mpec_calib using mpec minimizing mpec_obj ; 
rep_mpec("selas_calib",m,r,"selas")$v_mr(m,r) = selas.l(m,r) ; 


selas.fx(m,r) = selas.l(m,r) ; 




* check to see if we can re-create the equilibrium
game.iterlim = 0 ;
solve game using mcp ;
execute_unload 'fitted.gdx' ; 



game.iterlim = 1e6 ; 
solve game using mcp ;
set iter /0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50/ ; 
parameter rep_iter_q, rep_iter_p ; 

q.up("cadmium","china") = qbar_mr("cadmium","china") ; 

loop(iter,
    dshock(m) = qbar(m) * iter.val / 100 ; 
    solve game using mcp ;
    rep_iter_q(iter,m,r,"abs")$v_mr(m,r) = q.l(m,r) ; 
    rep_iter_q(iter,m,r,"ratio")$v_mr(m,r) = qbar_mr(m,r) ; 
    rep_iter_p(iter,m,"abs")$rep_m(m) = p.l(m) ; 
    rep_iter_p(iter,m,"ratio")$rep_m(m) = p.l(m) / rep_iter_p("0",m,"abs") ; 
) ; 

execute_unload 'alldata.gdx' ; 

