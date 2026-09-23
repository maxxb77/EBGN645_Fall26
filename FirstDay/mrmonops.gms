scalar a /2/ , b /-1/ , c /0/, d /1/;

positive variable X ; 
variable profit ; 
variable social_surplus ; 
equation profit_max, social_surplus_max; 
profit_max.. profit =e= (a+b*X) * X - c *X - d * X * X / 2 ; 

social_surplus_max.. social_surplus =e= (a+b*X / 2 ) * X - c *X - d * X * X / 2 ; 

model maxmax /all/ ; 

solve maxmax using qcp maximizing profit ; 
parameter rep ; 
rep("X") = x.l ; 
rep("P") = a+b * X.l ; 

solve maxmax using qcp maximizing social_surplus ; 
parameter rep ; 
rep("X_soc") = x.l ; 
rep("P_soc") = a+b * X.l ; 

execute_unload 'mrmonops.gdx' ; 
