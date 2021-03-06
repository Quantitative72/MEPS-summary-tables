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

/* Sex */
proc format;
 value sex
 1 = "Male"
 2 = "Female";
run;

/* Adults advised to quit smoking */
data MEPS; set MEPS;
 ARRAY SMKVAR(2) ADDSMK42 ADNSMK42;
 if year <= 2002 then adult_nosmok = ADDSMK42;
 else adult_nosmok = ADNSMK42;

 domain = (ADSMOK42=1 & CHECK53=1);
 if domain = 0 and SAQWT13F = 0 then SAQWT13F = 1;
run;

proc format;
 value adult_nosmok
  1 = "Told to quit"
  2 = "Not told to quit"
  3 = "Had no visits in the last 12 months"
 -9 = "Not ascertained"
 -1 = "Inapplicable";
run;

ods output CrossTabs = out;
proc surveyfreq data = MEPS missing;
 FORMAT adult_nosmok adult_nosmok. sex sex.;
 STRATA VARSTR;
 CLUSTER VARPSU;
 WEIGHT SAQWT13F;
 TABLES domain*sex*adult_nosmok / row;
run;

proc print data = out;
 where domain = 1 and adult_nosmok ne . and sex ne .;
 var adult_nosmok sex WgtFreq StdDev Frequency RowPercent RowStdErr;
run;
