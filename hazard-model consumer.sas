options ls = 70 nodate nocenter ;
/*setting path*/
libname InPath "P:\hw6data\";
libname InPath2 "Q:\Data-ReadOnly\LendingClub";
libname mypath "Q:\Scratch\RR\A6.2";
libname oldpath "Q:\Scratch\RR";

/*importing csv files*/
proc import out = mypath.loan_q1
datafile =  'P:\hw6data\LoanStats_2016Q1.csv'
dbms = csv replace;
datarow = 2;
getnames = yes;
run;

data mypath.loan_q1;
set mypath.loan_q1;
keep int_rate revol_util issue_d loan_status term total_pymnt loan_amnt last_pymnt_amnt delinq_2yrs mths_since_last_delinq dti annual_inc;
run;

proc import out = mypath.loan_q2
datafile =  'P:\hw6data\LoanStats_2016Q2.csv'
dbms = csv replace;
getnames = yes;
datarow = 2;
run;

data mypath.loan_q2;
set mypath.loan_q2;
keep int_rate revol_util issue_d loan_status term total_pymnt loan_amnt last_pymnt_amnt delinq_2yrs mths_since_last_delinq dti annual_inc;
run;

proc import out = mypath.loan_q3
datafile =  'P:\hw6data\LoanStats_2016Q3.csv'
dbms = csv replace;
getnames = yes;
datarow = 2;
run;

data mypath.loan_q3;
set mypath.loan_q3;
keep int_rate revol_util issue_d loan_status term total_pymnt loan_amnt last_pymnt_amnt delinq_2yrs mths_since_last_delinq dti annual_inc;
run;

proc import out = mypath.loan_q4
datafile =  'P:\hw6data\LoanStats_2016Q4.csv'
dbms = csv replace;
getnames = yes;
datarow = 2;
run;

data mypath.loan_q4;
set mypath.loan_q4;
keep int_rate revol_util issue_d loan_status term total_pymnt loan_amnt last_pymnt_amnt delinq_2yrs mths_since_last_delinq dti annual_inc;
run;

proc import out = mypath.loan_3a
datafile =  'Q:\Data-ReadOnly\LendingClub\LoanStats3a.csv'
dbms = csv replace;
getnames = yes;
datarow = 2;
run;

data mypath.loan_3a; 
set mypath.loan_3a; 
mths_since_last_record1 = input(mths_since_last_record,3.);
mths_since_last_major_derog1 = input(mths_since_last_major_derog,3.);
drop mths_since_last_record mths_since_last_major_derog; 
run;

proc import out = mypath.loan_3b
datafile =  'Q:\Data-ReadOnly\LendingClub\LoanStats3b.csv'
dbms = csv replace;
getnames = yes;
datarow = 2;
run;

proc import out = mypath.loan_3c
datafile =  'Q:\Data-ReadOnly\LendingClub\LoanStats3c.csv'
dbms = csv replace;
getnames = yes;
datarow = 2;
run;

proc import out = mypath.loan_3d
datafile =  'Q:\Data-ReadOnly\LendingClub\LoanStats3d.csv'
dbms = csv replace;
getnames = yes;
datarow = 2;
run;

/*merging datasets*/
data mypath.loans_q;
set mypath.loan_q1 mypath.loan_q2 mypath.loan_q3 mypath.loan_q4;
fyear =year(issue_d);
keep fyear int_rate revol_util loan_status term total_pymnt loan_amnt last_pymnt_amnt delinq_2yrs mths_since_last_delinq dti annual_inc;
run;

data mypath.loans_3;
set mypath.loan_3a mypath.loan_3b mypath.loan_3c mypath.loan_3d;
if length(issue_d)=6 then fyear=("20" || substr(issue_d,1,2))+ 0 ;
else fyear = ("200" || substr(issue_d,1,1))+0 ;
keep fyear int_rate revol_util loan_status term total_pymnt loan_amnt last_pymnt_amnt delinq_2yrs mths_since_last_delinq dti annual_inc;
run;

data mypath.loans;
set mypath.loans_q mypath.loans_3;
rate = input( substr(int_rate, 1, length(int_rate)-1),BEST12.)/100;
Utilization = input( substr(revol_util, 1, length(revol_util)-1),BEST12.)/100;
if loan_status="Fully Paid" then LoanDefFlag=0;
else if loan_status="Charged Off" then LoanDefFlag=1;
else if loan_status="Default" then LoanDefFlag=1;
else delete;
if term="36 months" then TermFlag=0;
else TermFlag=1;
if term="36 months" then duration=3;
else duration=5;
Fee_Ratio= ((loan_amnt/duration)*(1+rate))/annual_inc;
Paid_Rate=total_pymnt/(loan_amnt*(1+rate)**duration);
Last_Payment_Rate=last_pymnt_amnt/((loan_amnt/duration)*(1+rate)/12);
if mths_since_last_delinq=. then  mths_since_last_delinq=0;
keep fyear delinq_2yrs mths_since_last_delinq LoanDefFlag TermFlag dti total_pymnt loan_amnt Utilization Paid_Rate Last_Payment_Rate Fee_Ratio;
run;

/*dividing datasets*/
data mypath.loans_insample;
set mypath.loans(where = (2007<=fyear<=2014));
run;

data mypath.loans_outofsample;
set mypath.loans(where = (2015<=fyear<=2016));
run;

/*forward selection for full and insample datasets*/
proc logistic data = mypath.loans descending outest = mypath.loans_check covout;
model LoanDefFlag(event='1')= delinq_2yrs mths_since_last_delinq TermFlag dti total_pymnt loan_amnt Utilization Paid_Rate Last_Payment_Rate Fee_Ratio / selection=stepwise 
slentry=0.05 slstay=0.05 details lackfit;
output out=pred p=phat lower=lcl upper=ucl
predprob=(individual crossvalidate);
run;

proc logistic data = mypath.loans_insample descending outest = mypath.loans_insample_check covout;
model LoanDefFlag(event='1')= delinq_2yrs mths_since_last_delinq TermFlag dti total_pymnt loan_amnt Utilization Paid_Rate Last_Payment_Rate Fee_Ratio / selection=stepwise 
slentry=0.05 slstay=0.05 details lackfit;
output out=pred p=phat lower=lcl upper=ucl
predprob=(individual crossvalidate);
run;

/*pdf output*/
ods pdf file = "P:\A6.1\A6.2.2_Report.pdf";

/*logistic for full dataset*/
proc logistic data= mypath.loans descending outest=mypath.loans_log;
model LoanDefFlag(event = '1') = delinq_2yrs mths_since_last_delinq TermFlag dti total_pymnt loan_amnt Utilization Paid_Rate Last_Payment_Rate Fee_Ratio;
run;

data  mypath.loans_log (rename=(delinq_2yrs=d2y mths_since_last_delinq=msld TermFlag=tf dti=dt total_pymnt=tp loan_amnt=la Utilization=u Paid_Rate=pr Last_Payment_Rate=lpr Fee_Ratio=fr));
set mypath.loans_log;
run;

data mypath.fulloutput;
set mypath.loans;
if _n_= 1 then set mypath.loans_log;
Y = d2y*delinq_2yrs + msld*mths_since_last_delinq + tf*TermFlag + dt*dti + tp*total_pymnt + la*loan_amnt + u*Utilization + pr*Paid_Rate + lpr*Last_Payment_Rate + fr*Fee_Ratio;
p = exp(Y) / (1+exp(y));
keep d2y delinq_2yrs msld mths_since_last_delinq tf LoanDefFlag TermFlag dt dti tp total_pymnt la loan_amnt u Utilization pr Paid_Rate lpr Last_Payment_Rate fr Fee_Ratio Y p;
run;

proc rank data = mypath.fulloutput out = mypath.fulloutput_rank groups=10 descending;
var p;
ranks p_rank;
run;

proc sort data = mypath.fulloutput_rank;
by p_rank;
run;

data mypath.fulldefaults; 
set  mypath.fulloutput_rank;
if P = . then delete;
run;
 
proc sql;
title 'Bankruptcy';
select p_rank as RANK, count(RANK) as BUCKET_COUNT, sum(LoanDefFlag) as No_of_Defaults, (sum(LoanDefFlag)/count(LoanDefFlag))*100 as Bankrupt_Rate
from mypath.fulldefaults
group by p_rank;
quit;

/*logistic for divided dataset*/
proc logistic data= mypath.loans_insample descending outest=mypath.loans_insample_log;
model LoanDefFlag(event = '1') = delinq_2yrs mths_since_last_delinq TermFlag dti total_pymnt loan_amnt Utilization Paid_Rate Last_Payment_Rate Fee_Ratio;
run;

data  mypath.loans_insample_log (rename=(delinq_2yrs=d2y mths_since_last_delinq=msld TermFlag=tf dti=dt total_pymnt=tp loan_amnt=la Utilization=u Paid_Rate=pr Last_Payment_Rate=lpr Fee_Ratio=fr));
set mypath.loans_insample_log;
run;

data mypath.output;
set mypath.loans_outofsample;
if _n_= 1 then set mypath.loans_insample_log;
Y = d2y*delinq_2yrs + msld*mths_since_last_delinq + tf*TermFlag + dt*dti + tp*total_pymnt + la*loan_amnt + u*Utilization + pr*Paid_Rate + lpr*Last_Payment_Rate + fr*Fee_Ratio;
p = exp(Y) / (1+exp(y));
keep d2y delinq_2yrs msld mths_since_last_delinq tf LoanDefFlag TermFlag dt dti tp total_pymnt la loan_amnt u Utilization pr Paid_Rate lpr Last_Payment_Rate fr Fee_Ratio Y p;
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
if P = . then delete;
run;
 
proc sql;
title 'Bankruptcy';
select p_rank as RANK, count(RANK) as BUCKET_COUNT, sum(LoanDefFlag) as No_of_Defaults, (sum(LoanDefFlag)/count(LoanDefFlag))*100 as Bankrupt_Rate
from mypath.defaults
group by p_rank;
quit;

ods pdf close;
