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
gen portf_loss = -portf_return

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
qui sum citi_log_ret_std
sca normprob = normalden(citi_log_ret_std<=-0.25,0,1) - normalden(citi_log_ret_std==`r(min)')
dis %20.0e normprob

**a(ii)
sort citi_log_return //low to high so loss var is sorted high to low now
gen index = _n

*gen var with 150 biggest losses
gen citi_log_loss_150 = citi_log_loss if index <151

*gen scalar with 151st biggest value
gen citi_l_l_151 = citi_log_loss if index == 151
qui sum citi_l_l_151, meanonly
sca x151 = `r(mean)'
di x151
drop citi_l_l_151


***EQ 21
*gen sum150 = sum(ln(citi_log_loss_150/x151)), after(citi_log_loss)
gen sum_arg = ln(citi_log_loss_150/x151), after(citi_log_loss)
egen sum_total = total(sum_arg)
qui sum sum_total, meanonly
sca alphainv = 1/150* `r(mean)'
sca alpha_hat = 1/alphainv
dis alpha_hat

***EQ 22
qui sum index
sca c_hat = 150/`r(N)' * x151^alpha_hat

sca u = 0.25
sca paretoprob = c_hat * (u ^-alpha_hat)
di paretoprob
**EQ 23
sca VaR_0_25 = x151 * (150/`r(N)'*0.25)^alphainv
di VaR_0_25

***STILL TO DO: COMPARE MAGNITUDES OF LIKELIHOODS

****************
*******c********
****************
*sca I = 1000000/VaR_0_25
sort portf_return
gen index2 = _n

*gen var with 150 biggest losses
gen portf_loss_150 = portf_loss if index2 <151

*gen scalar with 151st biggest value
gen portf_l_151 = portf_loss if index2 == 151
qui sum portf_l_151, meanonly
sca x151_portf = `r(mean)'
di x151_portf
drop portf_l_151


***EQ 21
*gen sum150 = sum(ln(portf_loss_150/x151)), after(port_loss)
gen sum_arg_portf = ln(portf_loss_150/x151_portf), after(portf_loss)
egen sum_total_portf = total(sum_arg_portf)
qui sum sum_total_portf, meanonly
sca alphainv_portf = 1/150* `r(mean)'
sca alpha_hat_portf = 1/alphainv_portf
dis alpha_hat_portf

/*
***EQ 22
qui sum index2
sca c_hat_portf = 150/`r(N)' * x151_portf^alpha_hat

sca u = 0.001
sca paretoprob_portf = c_hat * (u ^-alpha_hat)
di paretoprob_portf
*/
**EQ 23
sca VaR_portf = x151 * (150/`r(N)'*0.001)^alphainv
di VaR_portf
di %20.3f 1000000/VaR_portf

sca dir
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
