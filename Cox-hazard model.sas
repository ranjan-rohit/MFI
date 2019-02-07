options ls = 70 nodate nocenter ;
/*setting path*/
libname InPath "Q:\Data-ReadOnly\CRSP\";
libname InPath2 "Q:\Data-ReadOnly\COMP\";
/*libname OpPath "P:\hw_5";*/
/*libname gpath "P:\hw_5.2\Graph\";*/
libname mypath "Q:\Scratch\RR\A6.1";
libname oldpath "Q:\Scratch\RR";

/*data read*/
data mypath.dsf;
set InPath.dsf(where = (1962<=year(DATE)<=2014));
YEAR = year(DATE);
SHROUT = SHROUT*1000;
E = abs(PRC)*SHROUT;
keep PERMNO CUSIP DATE YEAR PRC SHROUT RET E;
run;

data mypath.funda_data;
set InPath2.funda ( where=(1962< year(datadate)<2014 and indfmt='INDL' and datafmt='STD' 
and popsrc='D' and fic='USA' and consol='C'));
CUSIP = substr(CUSIP,1,8);
DLC = DLC*1000000;
DLTT = DLTT*1000000;
F = DLC+0.5*DLTT;
YEAR = fyear;
lagYEAR = year + 1;
if AT ne 0;
if LCT ne 0;
if SALE ne 0;
if OIADP ne 0;
if XINT ne 0;
current_ratio = ACT/LCT;
quick_ratio = (CHE+RECT)/LCT;
/*ROA = OIADP/((AT+ LAG(AT))/2);*/
ROS = OIADP/SALE;
interest_burden = (OIADP-XINT)/OIADP;
interest_coverage = OIADP/XINT;
EBITA = EBIT/AT;
keep CUSIP F YEAR lagYEAR current_ratio quick_ratio ROA ROS interest_burden interest_coverage EBITA;
run;

proc sort data=mypath.funda_data;
by CUSIP YEAR;
run;

proc import out=mypath.bankruptcy
datafile = 'Q:\Data-ReadOnly\SurvivalAnalysis\BR1964_2014.csv'
DBMS=CSV REPLACE;
GETNAMES=YES;
DATAROW=2;
run;

data mypath.bankruptcy;
set mypath.bankruptcy;
br_year = year(bankruptcy_dt);
drop bankruptcy_dt;
run;

data mypath.bankruptcy;
set mypath.bankruptcy;
br_flag = 1;
run;

proc sort data = mypath.bankruptcy;
by PERMNO br_YEAR;
run;


/*annualizing and merging datasets*/
PROC SQL;
CREATE TABLE mypath.dsf_data AS
SELECT PERMNO, CUSIP, year(date) as YEAR, 
EXP(SUM(LOG(1+ret)))-1 AS annret, 
STD(ret)*SQRT(250) as sigma_e, 
year + 1 as lagYEAR, 
avg(E) as E
FROM mypath.dsf_data
group BY CUSIP, YEAR;
quit;

proc sql;
create table mypath.dsf_data2 as
select distinct * from mypath.dsf_data
order by cusip, year;
quit;


data mypath.funda_dsf_data;
merge mypath.funda_data(in = a) mypath.dsf_data2 (in = b);
where 1962 <= year <= 2014;
by CUSIP YEAR;
if a and b;
run;

proc sort data = mypath.funda_dsf_data;
by PERMNO YEAR;
run;

proc sql;
create table mypath.raw_funda_dsf_bankruptcy as
select A.*, b.br_flag
from mypath.funda_dsf_data A
left join mypath.bankruptcy b
on a.permno = b.permno and a.lagyear = b.br_year
order by permno, year;
quit;

proc sort data = mypath.raw_funda_dsf_bankruptcy;
by year;
run;

proc sort data= oldpath.dtb nodupkey;
by year;
run;

proc sql;
create table mypath.funda_dsf_bankruptcy_dtb as
select A.*, B.*
from mypath.raw_funda_dsf_bankruptcy A
join oldpath.dtb B on A.YEAR = B.YEAR 
order by YEAR;
quit;

data mypath.final;
set mypath.funda_dsf_bankruptcy_dtb;
if (E+F) ne 0;
if F ne 0;
if sigma_v1 ne 0;
sigma_v1 = E/(E+F)*sigma_e + F/(E+F)*(0.05+0.25*sigma_e);
DD_naive1 = (log((E+F)/F) + r-sigma_v1**2/2)/sigma_v1;
V=E+F;
PD_naive1 = CDF("normal", -DD_naive1);
run;

data mypath.final;
set mypath.final;
if BR_Flag=. then BR_Flag=0;
run;

/*dividing dataset*/
data mypath.final_insample;
set mypath.final(where = (1962<=year(DATE)<=1990));
if current_ratio=. or quick_ratio=. or interest_burden=. or interest_coverage=. or
ROS=. or DD_Naive1=. or PD_Naive1=. or EBITA =. or R=. or sigma_v1 =. or V =. or F=. then delete;
run;

data mypath.final_outofsample;
set mypath.final(where = (1991<=year(DATE)<=2014));
if current_ratio=. or quick_ratio=. or interest_burden=. or interest_coverage=. or
ROS=. or DD_Naive1=. or PD_Naive1=. or EBITA =. or R=. or sigma_v1 =. or V =. or F=. then delete;
run;

/*checking which variables to consider*/
proc logistic data = mypath.final_insample descending outest = mypath.final_insample_check covout;
model BR_Flag(event='1')= current_ratio quick_ratio interest_burden interest_coverage ROS EBITA F V sigma_v1 R DD_Naive1 PD_Naive1 / selection=stepwise 
slentry=0.15 slstay=0.15 details lackfit;
output out=pred p=phat lower=lcl upper=ucl
predprob=(individual crossvalidate);
run;


/*pdf output*/
ods pdf file = "P:\A6.1\A6.1_Report.pdf";

proc logistic data= mypath.final_insample descending outest=mypath.final_insample_log;
model BR_Flag (event = '1') = current_ratio quick_ratio EBITA PD_Naive1;
run;

data  mypath.final_insample_log (rename=(current_ratio=bcr quick_ratio=bqr EBITA=be PD_Naive1=bpd));
set mypath.final_insample_log;
run;

/*calculation*/
data mypath.output;
set mypath.final_outofsample;
if _n_= 1 then set mypath.final_insample_log;
Y = bcr*current_ratio + bqr*quick_ratio + be*EBITA + bpd*PD_Naive1 + Intercept;
p = exp(Y) / (1+exp(y));
keep bcr current_ratio bqr quick_ratio be EBITA bpd PD_Naive1 Intercept Y p CUSIP lagYEAR BR_Flag;
run;

proc rank data = mypath.output out = mypath.output_rank groups=10 descending;
var p;
ranks p_rank;
run;

proc sort data = mypath.output_rank;
by p_rank;
run;

data mypath.defaults; 
set  mypath.output_rank;
if BR = 0 then delete;
run;
 
proc sql;
title 'Defaults';
select p_rank as RANK, count(RANK) as BUCKET_COUNT, sum(BR_Flag) as No_of_Defaults, (sum(BR_Flag)/count(BR_Flag))*100 as Default_Rate
from mypath.output_rank
group by p_rank;
quit;

ods pdf close;



