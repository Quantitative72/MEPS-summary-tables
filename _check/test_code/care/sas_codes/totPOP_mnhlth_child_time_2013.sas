ods graphics off;

/* Read in dataset and initialize year */
FILENAME h163 "C:\MEPS\h163.ssp";
proc xcopy in = h163 out = WORK IMPORT;
run;

data MEPS;
 SET h163;
 year = 2013;
 ind = 1;
 count = 1;

 /* Create AGELAST variable */
 if AGE13X >= 0 then AGELAST=AGE13x;
 else if AGE42X >= 0 then AGELAST=AGE42X;
 else if AGE31X >= 0 then AGELAST=AGE31X;
run;

proc format;
 value ind 1 = "Total";
run;

/* Perceived mental health */
data MEPS; set MEPS;
 ARRAY OLDMNH(2) MNTHLTH1 MNTHLTH2;
 if year = 1996 then do;
  MNHLTH53 = MNTHLTH2;
  MNHLTH42 = MNTHLTH2;
  MNHLTH31 = MNTHLTH1;
 end;

 if MNHLTH53 ge 0 then mnhlth = MNHLTH53;
 else if MNHLTH42 ge 0 then mnhlth = MNHLTH42;
 else if MNHLTH31 ge 0 then mnhlth = MNHLTH31;
 else mnhlth = .;
run;

proc format;
 value mnhlth
 1 = "Excellent"
 2 = "Very good"
 3 = "Good"
 4 = "Fair"
 5 = "Poor"
 . = "Missing";
run;

/* How often doctor spent enough time (children) */
data MEPS; set MEPS;
 child_time = CHPRTM42;
 domain = (CHAPPT42 >= 1 & AGELAST < 18);
run;


proc format;
  value freq
   4 = "Always"
   3 = "Usually"
   2 = "Sometimes/Never"
   1 = "Sometimes/Never"
  -7 = "Don't know/Non-response"
  -8 = "Don't know/Non-response"
  -9 = "Don't know/Non-response"
  -1 = "Inapplicable"
  . = "Missing";
run;


ods output CrossTabs = out;
proc surveyfreq data = MEPS missing;
 FORMAT child_time freq. mnhlth mnhlth.;
 STRATA VARSTR;
 CLUSTER VARPSU;
 WEIGHT PERWT13F;
 TABLES domain*mnhlth*child_time / row;
run;

proc print data = out;
 where domain = 1 and child_time ne . and mnhlth ne .;
 var child_time mnhlth WgtFreq StdDev Frequency RowPercent RowStdErr;
run;
