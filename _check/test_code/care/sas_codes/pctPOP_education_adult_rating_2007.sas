ods graphics off;

/* Read in dataset and initialize year */
FILENAME h113 "C:\MEPS\h113.ssp";
proc xcopy in = h113 out = WORK IMPORT;
run;

data MEPS;
 SET h113;
 year = 2007;
 ind = 1;
 count = 1;

 /* Create AGELAST variable */
 if AGE07X >= 0 then AGELAST=AGE07x;
 else if AGE42X >= 0 then AGELAST=AGE42X;
 else if AGE31X >= 0 then AGELAST=AGE31X;
run;

proc format;
 value ind 1 = "Total";
run;

/* Education */
data MEPS; set MEPS;
 ARRAY EDUVARS(4) EDUCYR07 EDUCYR EDUCYEAR EDRECODE;
 if year <= 1998 then EDUCYR = EDUCYR07;
 else if year <= 2004 then EDUCYR = EDUCYEAR;

 if year >= 2012 then do;
  less_than_hs = (0 <= EDRECODE and EDRECODE < 13);
  high_school  = (EDRECODE = 13);
  some_college = (EDRECODE > 13);
 end;

 else do;
  less_than_hs = (0 <= EDUCYR and EDUCYR < 12);
  high_school  = (EDUCYR = 12);
  some_college = (EDUCYR > 12);
 end;

 education = 1*less_than_hs + 2*high_school + 3*some_college;

 if AGELAST < 18 then education = 9;
run;

proc format;
 value education
 1 = "Less than high school"
 2 = "High school"
 3 = "Some college"
 9 = "Inapplicable (age < 18)"
 0 = "Missing"
 . = "Missing";
run;

/* Rating for care (adults) */
data MEPS; set MEPS;
 adult_rating = ADHECR42;
 domain = (ADAPPT42 >= 1 & AGELAST >= 18);
 if domain = 0 and SAQWT07F = 0 then SAQWT07F = 1;
run;

proc format;
 value adult_rating
 9-10 = "9-10 rating"
 7-8 = "7-8 rating"
 0-6 = "0-6 rating"
 -9 - -7 = "Don't know/Non-response"
 -1 = "Inapplicable";
run;

ods output CrossTabs = out;
proc surveyfreq data = MEPS missing;
 FORMAT adult_rating adult_rating. education education.;
 STRATA VARSTR;
 CLUSTER VARPSU;
 WEIGHT SAQWT07F;
 TABLES domain*education*adult_rating / row;
run;

proc print data = out;
 where domain = 1 and adult_rating ne . and education ne .;
 var adult_rating education WgtFreq StdDev Frequency RowPercent RowStdErr;
run;
