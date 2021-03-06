/* Race/ethnicity */
data MEPS; set MEPS;
	ARRAY RCEVAR(4) RACETHX RACEV1X RACETHNX RACEX;
	if year >= 2012 then do;
		hisp   = (RACETHX = 1);
 		white  = (RACETHX = 2);
      	black  = (RACETHX = 3);
      	native = (RACETHX > 3 and RACEV1X in (3,6));
      	asian  = (RACETHX > 3 and RACEV1X in (4,5));
		white_oth = 0;
	end;

	else if year >= 2002 then do;
		hisp   = (RACETHNX = 1);
		white  = (RACETHNX = 4 and RACEX = 1);
		black  = (RACETHNX = 2);
		native = (RACETHNX >= 3 and RACEX in (3,6));
		asian  = (RACETHNX >= 3 and RACEX in (4,5));
		white_oth = 0;
	end;

	else do;
		hisp  = (RACETHNX = 1);
		black = (RACETHNX = 2);
		white_oth = (RACETHNX = 3);
		white  = 0;
		native = 0;
		asian  = 0;
	end;

	race = 1*hisp + 2*white + 3*black + 4*native + 5*asian + 9*white_oth;
run;

proc format;
	value race
	1 = "Hispanic"
	2 = "White"
	3 = "Black"
	4 = "Amer. Indian, AK Native, or mult. races"
	5 = "Asian, Hawaiian, or Pacific Islander"
	9 = "White and other"
	. = "Missing";
run;
