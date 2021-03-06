/* Reason for difficulty receiving needed care */
data MEPS; set MEPS;
	delay_MD  = (MDUNAB42=1|MDDLAY42=1);
	delay_DN  = (DNUNAB42=1|DNDLAY42=1);
	delay_PM  = (PMUNAB42=1|PMDLAY42=1);

	afford_MD = (MDDLRS42=1|MDUNRS42=1);
	afford_DN = (DNDLRS42=1|DNUNRS42=1);
	afford_PM = (PMDLRS42=1|PMUNRS42=1);

	insure_MD = (MDDLRS42 in (2,3)|MDUNRS42 in (2,3));
	insure_DN = (DNDLRS42 in (2,3)|DNUNRS42 in (2,3));
	insure_PM = (PMDLRS42 in (2,3)|PMUNRS42 in (2,3));

	other_MD  = (MDDLRS42 > 3|MDUNRS42 > 3);
	other_DN  = (DNDLRS42 > 3|DNUNRS42 > 3);
	other_PM  = (PMDLRS42 > 3|PMUNRS42 > 3);

	delay_ANY  = (delay_MD |delay_DN |delay_PM);
	afford_ANY = (afford_MD|afford_DN|afford_PM);
	insure_ANY = (insure_MD|insure_DN|insure_PM);
	other_ANY  = (other_MD |other_DN |other_PM);

	domain = (ACCELI42 = 1 & delay_ANY=1);
run;

proc format;
	value afford 1 = "Couldn't afford";
	value insure 1 = "Insurance related";
	value other 1 = "Other";
run;

ods output CrossTabs = out;
proc surveyfreq data = MEPS missing;
	FORMAT afford_ANY afford. insure_ANY insure. other_ANY other. &fmt.;
	STRATA VARSTR;
	CLUSTER VARPSU;
	WEIGHT PERWT&yy.F;
	TABLES domain*&gp.*(afford_ANY insure_ANY other_ANY) / row;
run;

proc print data = out;
	where domain = 1 and (afford_ANY > 0 or insure_ANY > 0 or other_ANY > 0) &where.;
	var afford_ANY insure_ANY other_ANY &gp. WgtFreq StdDev Frequency RowPercent RowStdErr;
run;
