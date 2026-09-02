
set i "products" /hamburger, hotdog, frenchfries/ ; 

parameter 
r(i) 
/hamburger 1.5, hotdog 0.75, frenchfries 0.25/,
c(i)
/hamburger 0.75, hotdog 0.1, frenchfries 0.05/,
h(i)
/hamburger 0.5, hotdog 0.2, frenchfries 0.1/
;

scalar hbar "hours per week" /40/ ; 

positive variables
X(i) "production" ; 

variable Z "objective function" ; 

equations eq_objfn, eq_hourlimit; 

eq_objfn.. Z =e= sum(i,(r(i)-c(i)) * X(i)) ; 

eq_hourlimit.. hbar =g= sum(i,h(i) * X(i)) ;

model ripley /all/ ;

solve ripley using lp maximizing Z ; 