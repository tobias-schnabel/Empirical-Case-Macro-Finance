clear all
version 17
set more off
cap log close


/*!!requires following packages: 

net install cleanplots, from("https://tdmize.github.io/data/cleanplots")

net install tsg_schemes, from("https://raw.githubusercontent.com/asjadnaqvi/Stata-schemes/main/schemes/"), replace

ssc install labutil2
*/
*cleanplots
set scheme white_tableau

/////// CASE 4 EMPIRICAL REPORT /////////
*Kurris, Tim; Schnabel, Tobias; Tiemens, Jurre; Udo, Matthijs
/*
Download the excel file from Canvas `Bankstocks.xls" containing stock price data of three US bank stocks from 13/3/1980 until 6/11/2018. The formula numbers cited in the questions below refer to the equations in the academic paper above.

a) Calculate the likelihood of a -25% daily drop in the City Group (logarithmic) stock return series. The logarithmic return is defined as: R(t)=ln(p(t)/p(t-1)) with V(t) the stock prices from the excel file. Calculate the likelihood in two different ways:

(i) Assume that the returns are normally distributed.

(ii) Assume that the stock returns are fat tailed like in eq. (1) of the academic paper above. Estimate the parameters C (the scaling constant) and α (the tail index) with the estimators (21) and (22). Select the number of extremes to be used in estimation to be equal to k=150. Attention: use the left tail data!

Compare the order of magnitude of the `normal' tail likelihood and the fat-tailed tail likelihood. Give economic interpretation.

b) Make price and return graphs for the three considered bank stocks in `Bankstocks.xls'. The return graphs need to have a common vertical axis (choose the vertical axis of the most volatile of the three stocks). Calculate descriptive statistics (mean returns, standard deviations and correlations) across the three bank stocks as well as for the equally-weighted portfolio return. Calculate this equallyweighted portfolio return using the initial stock values (prices) p as follows:
( Assume now you are the risk manager of a pension fund that invests part of its cash into this equallyweighted bank stock portfolio. However, this is risky business as they also have to ensure cash outflows in terms of pension payments. Suppose the management specifies a critical loss level of S=€1,000,000, which represents the loss that can be incurred without running into trouble in paying out the fixed claims (pensions). As a risk manager you do not aim at completely eliminating the probability that the portfolio will lose more than this amount but one is typically interested in knowing the maximum allowable investment (I) or trading limit into this portfolio such that the probability of a loss greater than €1,000,000 is limited to a very low level p (prespecified by the management; depending on their risk aversion). How to determine I? This problem can be solved as follows. We start by considering the Value-at-Risk (VaR) for the portfolio return series  (as defined under b) and corresponding exceedance probability p:


The VaR is the quantile (percentile) of the portfolio return distribution which will be exceeded with likelihood p. The unknown is the maximum allowable investment I which can be `imported' in the above probability while leaving the likelihood invariant:


The maximum allowable investment now directly follows from the equality S= I that I=S/VaR=$1,000,000/VaR.

× VaR

which implies

c) Calculate the daily unconditional Value-at-Risk (VaR) for the equally-weighted bank stock portfolio. Take p=0,1% and k=150 using the VaR formula in (23) from the academic paper earlier discussed. today. What is the maximum allowable investment I in US$ terms?*/

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
use "${cd}/bankstocks.dta"

des
*rename bank name vars
ren BankofNewYorkMellon BNY
ren BankofAmerica BofA
ren Citigroup Citi

*declare Data as Time Series
tsset Date
tsreport

*drop excel artifact "variables"
drop C D F H I

des

****************
*****part a*****
****************

*create log return vars
foreach x in BNY Citi BofA SP500 {
	clonevar `x'_log = `x'
	replace `x'_log=ln(`x'/L.`x')
}

*show codebook
codebook

*export codebook
quietly {
    log using codebook.txt, text replace
    noisily codebook
    log close
}


**make descriptive TS Graph of stock prices
local grtitle = "Bank stock prices"
tw tsline BNY Citi BofA, nodraw ///
title(`grtitle', color(black) span) ///
	lcolor(%60 %60 %60)
	gr save "stockprices.tex"

local grtitle = "Bank stock prices"
tw tsline BNY_log Citi_log BofA_log, nodraw ///
	title(`grtitle', color(black) span) ///
	lcolor(%60 %60 %60)
	gr save "logstockprices.tex"
	
* a(i) Assume that the returns are normally distributed.

*get sumstats
sum Citi_log
