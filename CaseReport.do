clear all
version 17
set more off
cap log close

cls
/*!!requires following packages: 

net install cleanplots, from("https://tdmize.github.io/data/cleanplots")

net install tsg_schemes, from("https://raw.githubusercontent.com/asjadnaqvi/Stata-schemes/main/schemes/"), replace

ssc install labutil2
*/
*cleanplots
set scheme white_tableau

/////// CASE 4 EMPIRICAL REPORT /////////
*Kurris, Tim; Schnabel, Tobias; Tiemens, Jurre; Udo, Matthijs

*set wd
global wd "/Users/ts/Library/Mobile Documents/com~apple~CloudDocs/Uni/UM/Year 2/Macro and Finance/Empirical Case"

cd "${wd}"

*create duplicate of raw data
copy "bankstocks.xlsx" "bankstocks_workingdata.xlsx", replace
*import raw data
import excel "bankstocks_workingdata.xlsx", sheet("Sheet1") firstrow

save "bankstocks.dta", replace

clear 
*load data
use "bankstocks.dta"

des
*rename bank name vars
ren BankofNewYorkMellon BNY
ren BankofAmerica BofA
ren Citigroup Citi

*declare Data as Time Series
tsset Date

*drop excel artifact "variables"
drop C D F H I

des

****************
*****prep*******
****************
**sorted DATE***

*create log return vars
foreach x in BNY Citi BofA SP500 {
	clonevar `x'_log_return = `x'
	order `x'_log_return, after(`x')
	replace `x'_log_return=ln(`x'/L.`x')
	gen `x'_log_loss = - `x'_log_return, after(`x'_log_return)
}

*show codebook and times series report
codebook
tsreport

*export codebook
quietly {
    log using tsreport+codebook.txt, text replace
    noisily codebook
	noisily tsreport
    log close
}


**make descriptive TS Graph of stock prices
local grtitle = "Bank stock prices"
tw tsline BNY Citi BofA, nodraw ///
title(`grtitle', color(black) span) ///
	lcolor(%60 %60 %60)
	gr save "stockprices.png", replace

local grtitle = "Log Bank stock returns"
tw tsline BNY_log_return Citi_log_return BofA_log_return, nodraw ///
	title(`grtitle', color(black) span) ///
	lcolor(%60 %60 %60)
	gr save "logstockprices.png", replace
	
*sort data by loss high to low (right tail of loss=left tail of return)
sort Citi_log_return //sort sorts low-high
gen index = _n

****************
*****part a*****
****************
***sorted RET***

* a(i) Assume that the returns are normally distributed.
*get sumstats
sum Citi_log_return 
sum Citi_log_loss

dis `r(mean)'
dis `r(Var)'



**ALTERNATIVE: STANDARDIZE LOSS VAR
clonevar Citi_log_loss_std = Citi_log_loss
replace Citi_log_loss_std = (Citi_log_loss-`r(mean)'/`r(Var)')
sca a1 = normalden(Citi_log_loss_std==0.25, 0, 1)
dis a1
dis normal(0.25) //check N(0,1) value for comparison

**export the estimated values to table
collect create a
collect get r(), name(a)

/*(ii) Assume that the stock returns are fat tailed like in eq. (1) of the academic paper above. Estimate the parameters C (the scaling constant) and α (the tail index) with the estimators (21) and (22). Select the number of extremes to be used in estimation to be equal to k=150. Attention: use the left tail data! */

*create var that holds only 151 biggest (tail) observations
clonevar c_l_l_tail = Citi_log_loss
replace c_l_l_tail =. if index > 151
list c_l_l_tail in 150/151

*create var that holds only 300 biggest (tail) observations
clonevar c_l_l_tail2 = Citi_log_loss
replace c_l_l_tail2 =. if index > 300


*create var that only holds 151st  value
clonevar c_l_l_151 = Citi_log_loss
replace c_l_l_151 =. if index != 151
*convert to scalar
qui sum c_l_l_151
sca x151 = `r(min)'


qui sum index
sca  obs = `r(N)' //number of observations n
*equation 21
sca alphainv= 1/150*(sum(Citi_log_loss/.0497235)) //this is equation (21) in the paper
*inverse of alphainv is alpha
sca alpha_hat = 1/alphainv
*equation 22
sca  C_hat = 150/obs * (x151^alpha_hat)


*******estimate likelihood given that Citi_log_loss is Pareto-distributed
sca pareto_ll = 1- (0.25 / C_hat) ^(-alpha_hat)
dis pareto_ll

******COMPARISON WITH ML-FITTED PARETO DISTRIBUTION: 
paretofit c_l_l_tail2, stats cdf(paretocdf) pdf(paretopdf)
sum paretopdf if Citi_log_loss>0.2495 & paretopdf<0.2505
**export the estimated values to table

collect get r(), name(a)

/*Compare the order of magnitude of the `normal' tail likelihood and the fat-tailed tail likelihood. Give economic interpretation.*/

sca dir

****END
translate "CaseReport.do" "Dofile.pdf", t(txt2pdf) replace
