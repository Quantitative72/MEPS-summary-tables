ods output Domain = out;
proc surveymeans data = RX sum ;
	stratum VARSTR;
	cluster VARPSU;
	weight PERWT&yy.F;
	var count;
	domain domain*RXDRGNAM;
run;

proc print data = out;
	where domain = 1;
run;
