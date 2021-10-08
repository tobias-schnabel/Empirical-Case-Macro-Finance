clear all
version 17
set more off
cap log close

graph set eps fontface "Latin Modern Roman"

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

*switch to output folder
cd "${wd}/output"
des
ren Date date
*rename bank name vars
ren BankofNewYorkMellon bny
ren BankofAmerica bofa
ren Citigroup citi
la var bny "Bank of NY Mellon"
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

la var portf_return "Portfolio"

*export codebook and time series status report
quietly {
    log using tsreport+codebook.txt, text replace
    noisily codebook
	noisily tsreport
    log close
}

**set up collection a2 for export to tables
collect create a1
**set up collection a2 for export to tables
collect create a2
**set up collection b for export to tables
collect create b
**set up collection c for export to tables
collect create c
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
******
qui sum citi_log_loss
sca normcheck =normalden(citi_log_loss==0.25, `r(mean)', `r(sd)') - normalden(citi_log_loss== `r(mean)', `r(mean)', `r(sd)')
dis %20.0e normcheck

*7.42156E-22
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

*collect get r(x151) r(alphainv) r(alpha_hat) r(c_hat) r(normprob) ///
		*r(normcheck) r(paretoprob)	r(VaR_0_25) r(u), name(a)
		
***STILL TO DO: COMPARE MAGNITUDES OF LIKELIHOODS

*create vars with values of scalars for tables
foreach x in x151 alphainv alpha_hat c_hat normprob normcheck paretoprob {
	gen `x'_est = scalar(`x')
	}

**Build Table with Tail sum stats
qui table (result colname) (rowname), name(a1) ///
command(sum citi_log_loss_150) nformat(%12.2g) 
*adjust table
collect dims
collect label list result
collect label list statistics
*adjust labels
collect label levels colname citi_log_loss_150 "Right Tail of Loss Distr.",modify
*hide stat headers
collect style header statcmd, level(hide)
collect style column, width(equal)
**export table
collect export "Sumstats right tail.tex", tableonly name(a1) replace


**Build Table with results
qui table , name(a2) ///
statistic(mean x151_est normprob_est normcheck_est alphainv_est alpha_hat_est ///
		c_hat_est  paretoprob_est) ///
		nformat(%12.2g)
*adjust table
collect dims
collect label list result
collect label list var
*adjust labels
collect label levels var x151_est "151st largest loss" ,modify
collect label levels var alphainv_est "1/ alpha hat",modify
collect label levels var alpha_hat_est "alpha hat",modify
collect label levels var c_hat_est "C hat",modify
collect label levels var normprob_est ///
 "Prob. that Portf. loss > 25% (Normal) (stdized)" ,modify
collect label levels var normcheck_est ///
 "Prob. that Portf. loss > 25% (Normal) (not stdized)" ,modify
collect label levels var paretoprob_est ///
 "Prob. that Portf. loss > 25% (Pareto)" ,modify
*hide stat headers
collect style header statcmd, level(hide)
collect style column, width(equal)

**export table
collect export "Parameters and Probabilities.tex", tableonly name(a2) replace

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


***EQ 22
qui sum index2
sca c_hat_portf = 150/`r(N)' * x151_portf^alpha_hat

sca u = 0.001
sca paretoprob_portf = c_hat * (u ^-alpha_hat)
di paretoprob_portf

**EQ 23
sca VaR_portf = x151 * (150/`r(N)'*0.001)^alphainv
di VaR_portf
di %20.3f 1000000/VaR_portf

collect get r(x151_portf) r(alphainv_portf) r(alpha_hat_portf) ///
 r(c_hat_portf)  r(paretoprob_portf) r(VaR_portf), name()


****************
*******b********
****************
sort date
**make descriptive TS Graph of stock prices
local grtitle = "Bank stock prices"
tw tsline bny citi bofa,  ///
title(, color(black) size(medlarge) span ) ///
	lcolor(%60 %60 %60) ytitle("Share Price in USD", ///
	orientation(vertical) angle(-90) size(medium)) ///
	legend(position(6) symplacement(s)) graphregion(margin(1 5 1 1))
	
	gr export "stockprices.png", replace
	gr close

local grtitle = "Log Bank stock returns"
tw tsline bny_log_return citi_log_return bofa_log_return,  ///
	title(, color(black) size(medlarge) span ) ///
	lcolor(%60 %60 %60) ytitle("Logarithmic Returns", ///
	orientation(vertical) angle(-90) size(medium)) ///
	legend(position(6)  symplacement(s)) graphregion(margin(1 5 1 1))
	
	gr export "logstockreturn.png", replace
	gr close
	
local grtitle = "Log Portfolio returns"
tw tsline portf_return SP500_log_return,  ///
	title(, color(black) size(medlarge) span ) ///
	lcolor(%60 %60 %60) ytitle("Logarithmic Returns", ///
	orientation(vertical) angle(-90) size(medium)) ///
	legend(position(6) symplacement(s) label(1 "Portolio Return")) ///
	graphregion(margin(1 5 1 1))
	
	gr export "logportfreturn.png", replace
	gr close

***Build and combine 4 graphs of correlations
tw scat portf_return SP500_log_return, nodraw  ///
	graphregion(margin(1 1 1 1)) name(gr4, replace) ///
	mcolor("214 39 40"%50) ytitle(, j(center) alignment(middle) ///
	orientation(vertical) angle(-90) size(medium) ) ///
	yscale(titlegap(*-24))
	
tw scat bny_log_return bofa_log_return, nodraw ///
	graphregion(margin(1 1 1 1)) name(gr1, replace) ///
	mcolor("31 119 180"%50) ytitle(, j(center) alignment(middle) ///
	orientation(vertical) angle(-90) size(medium)) ///
	yscale(titlegap(*-5))
	
tw scat  bny_log_return citi_log_return, nodraw ///
	graphregion(margin(1 1 1 1)) name(gr2, replace) ///
	mcolor("255 127 14"%50) ytitle(, j(center) alignment(middle) ///
	orientation(vertical) angle(-90) size(medium)) ///
	yscale(titlegap(*-5))
	
tw scat  citi_log_return bofa_log_return , nodraw ///
	graphregion(margin(1 1 1 1)) name(gr3, replace) ///
	mcolor("44 160 44"%50) ytitle(, j(center) alignment(middle) ///
	orientation(vertical) angle(-90) size(medium)) ///
	yscale(titlegap(*-32))
	
gr combine gr1 gr2 gr3 gr4,  ///
	rows(2) title(, color(black) nobox fcolor() ) subtitle(, nobox) ///
	caption(, nobox)  name(corrs, replace) 
	
gr export "4waycorr.png", replace
gr close
gr drop _all
	
**Build Table wirth summary statistics and correlations

qui table (result rowname) (colname), name(b) ///
statistic(mean bny_log_return bofa_log_return citi_log_return portf_return) ///
statistic(sd bny_log_return bofa_log_return citi_log_return portf_return) ///
statistic(var bny_log_return bofa_log_return citi_log_return portf_return) ///
command(r(C): correlate bny_log_return bofa_log_return citi_log_return) ///
nformat(%8.2g)

collect dims
collect label list result
collect label list colname
*adjust labels
collect label levels colname bny_log_return "Log Ret. BNY", modify
collect label levels rowname bny_log_return "Log Ret. BNY", modify
collect label levels colname bofa_log_return "Log Ret. BofA", modify
collect label levels rowname bofa_log_return "Log Ret. BofA", modify
collect label levels colname citi_log_return "Log Ret. Citi", modify
collect label levels rowname citi_log_return "Log Ret. Citi", modify
collect label levels colname portf_return "Log Ret. Portfolio", modify
collect label levels rowname portf_return "Log Ret. Portfolio", modify
*hide stat headers
collect style header statcmd, level(hide)
collect style column, width(equal)
**export table
collect export "descriptives_corr.tex", tableonly name(b) replace



****END
translate "/Users/ts/Git/Empirical-Case-Macro-Finance/Case4.do" ///
"Dofile.pdf", t(txt2pdf) replace
copy "Dofile.pdf" "${wd}/output/Dofile.pdf", replace
