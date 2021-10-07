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
ren Date date
*rename bank name vars
ren BankofNewYorkMellon bny
ren BankofAmerica bofa
ren Citigroup citi

*declare Data as Time Series
tsset date

*drop excel artifact "variables"
drop C D F H I

des

****************
*****prep*******
****************
**sorted DATE***

*create log return vars
foreach x in bny citi bofa SP500 {
	*clonevar `x'_loss = -`x'
	clonevar `x'_log_return = `x'
	order `x'_log_return, after(`x')
	replace `x'_log_return=ln(`x'/L.`x')
	gen `x'_log_loss = - `x'_log_return, after(`x'_log_return)
}

*generate Portfolio Price variable for part bb
gen portf_price = 1/3*bny + 1/3*citi + 1/3*bofa
gen portf_return = ln(portf_price/L.portf_price)

*export codebook and time series status report
quietly {
    log using tsreport+codebook.txt, text replace
    noisily codebook
	noisily tsreport
    log close
}
****************
*******a********
****************

****estimate likelihood using normal distr
qui sum citi_log_return
*gen standardized var
gen citi_log_ret_std = ((citi_log_return-`r(mean)')/`r(sd)')
sca normprob = normalden(citi_log_ret_std==-0.25)
dis normprob

/*

****************
*******b********
****************

**make descriptive TS Graph of stock prices
local grtitle = "Bank stock prices"
tw tsline BNY Citi BofA, nodraw ///
title(`grtitle', color(black) span) ///
	lcolor(%60 %60 %60)
	gr save "stockprices.tex", replace

local grtitle = "Log Bank stock returns"
tw tsline BNY_log_return Citi_log_return BofA_log_return, nodraw ///
	title(`grtitle', color(black) span) ///
	lcolor(%60 %60 %60)
	gr save "logstockprices.tex", replace
	


****END
translate "CaseReport.do" "Dofile.pdf", t(txt2pdf) replace
