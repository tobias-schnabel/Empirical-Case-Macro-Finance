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
dis normalden(Citi_log_loss_std==0.25, 0, 1)
dis normal(0.25) //check N(0,1) value for comparison

/*(ii) Assume that the stock returns are fat tailed like in eq. (1) of the academic paper above. Estimate the parameters C (the scaling constant) and α (the tail index) with the estimators (21) and (22). Select the number of extremes to be used in estimation to be equal to k=150. Attention: use the left tail data! */


****END
translate "CaseReport.do" "Dofile.pdf", t(txt2pdf) replace
