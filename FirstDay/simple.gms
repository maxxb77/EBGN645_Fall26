$TITLE simple

scalar p /20/ ; 
scalar k /5/ ; 

positive variable x ; 
variable objfn ; 

equations eq_objfn, eq_capacity_limit ;

eq_objfn.. objfn =e= p * x - x * x ; 

eq_capacity_limit.. x =l= k ; 

model simple /all/ ; 

parameter rep ; 

solve simple using qcp maximizing objfn ;

rep("profit","5") = objfn.l ;
rep("x","5") = x.l ; 

k = 6 ;

solve simple using qcp maximizing objfn ;

rep("profit","6") = objfn.l ;
rep("x","6") = x.l ; 

execute_unload 'simpledata.gdx' ; 