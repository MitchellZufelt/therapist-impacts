/* 2 parts
1. estimate VA
2. check VA
*/

*Bring in ref data
use "client_therapist_pairings.dta", clear

*Bring in detail data (left join)
merge 1:m user_id therapist_id using "example_file.dta"
drop if _merge == 2
sort therapist_id user_id
order user_id monthyear therapist_id num_clients obs survey_id overall_score zscore
drop _merge

/*
*Create variables that will be useful for regression.
bys monthyear: egen mean_z_score = mean(zscore)
by monthyear: egen mean_first_score = mean(first_score)
sort user_id monthyear
by user_id : gen assess_num = _n

drop if num_clients == 1
*/

save "to_work_with.dta", replace

/*********************************
 Estimate VA.
**********************************/
xtset therapist_id

*Eq. 1: Estimate model of client assessment scores using client characteristics + therapist fixed effects
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time zscore_lag, fe 
	
*Eq. 2: Predict residuals.
predict resid, residual

*Therapist VA: Calculate each therapist's average effect in each monthyear period 
bys therapist_id monthyear: egen mnthyr_mean_resid = mean(resid) 
	//collapsing to monthyear now, but could collapse further to quarters and precision-weight by monthyear cohorts. Note that larger cohorts DO equal more obs, but might also have a detrimental effect on quality, bc larger cohorts stretch the therapist thinner. Things to think about.

	
*Save Naive estimates. (Not naive, though; really more of an actual estimate rather than a predicted one)
//order user_id monthyear therapist_id num_clients obs survey_id mnthyr_mean_resid zscore
save "tva_ests.dta", replace
	
*BOOM. There's your VA ests. Great work. There are a couple things to really fine tune to improve them (namely, specification in Eq. 1 and weighted collapse in part 2), but you've got the basics to start with. But say you're trying to predict VA for a time period that you don't have yet... (you would do this in practice, or in this lil test I'm gonna administer) In this case, you would want to use past scores adjusted for drift in quality over time. We have a method for that, below. 
 
*When we go to check that our method works we'll want to start with the scores generated in line 31, then adjust for drift right up till the most recent client (11th in 12-client sample). This is bc we are using the VA strategy to predict MH gains in the client	

*For simplicity, reduce only to data necessary for autocorrelation computations		
keep therapist_id monthyear mnthyr_mean_resid
sort therapist_id monthyear
drop if monthyear == monthyear[_n-1] & therapist_id == therapist_id[_n-1]

save "auto_tva_ests_base.dta", replace

***Compute predicted VA adjusted for drift***
use "auto_tva_ests_base.dta", clear
bys therapist_id : egen N = count(therapist_id) //number of months therapist was active in

*Create lag/lead variables 
sort therapist_id monthyear
by therapist_id : gen time = _n

forvalues i = 1/60 {
	by therapist_id : gen lag`i' = mnthyr_mean_resid[_n-`i']
}	

forvalues i = 1/60 {
	by therapist_id : gen lead`i' = mnthyr_mean_resid[_n+`i']
}

*Regress each lag/lead individually to assess covariance between each of these and present. Save coefficients as these are our estimates
forvalues i = 1/13 {
	reg mnthyr_mean_resid lag`i'
	scalar lg`i' = _b[lag`i']
	
	reg mnthyr_mean_resid lead`i'
	scalar ld`i' = _b[lead`i']
}
  //Would be great to graph point estimates/SE's sometime! The magnitude decreases as distance from present increases (as is to be expected), and lose all statistical significance around lag/lead 14 or 15 (set those = 0)

*Replace missing with zero prior to making predictions
forvalues i = 1/60 {
	replace lag`i' = 0 if lag`i' ==.
	replace lead`i' = 0 if lead`i' == .
}
  
*Predict VA adjusted for drift. 
gen pred_tva = lag1*lg1 + lag2*lg2 + lag3*lg3 + lag4*lg4 + lag5*lg5 + lag6*lg6 + lag7*lg7 + lag8*lg8 + lag9*lg9 + lag10*lg10 + lag11*lg11 + lag12*lg12 + lag13*lg13 + lead1*ld1 + lead2*ld2 + lead3*ld3 + lead4*ld4 + lead5*ld5 + lead6*ld6 + lead7*ld7 + lead8*ld8 + lead9*ld9 + lead10*ld10 + lead11*ld11 + lead12*ld12 + lead13*ld13, after(mnthyr_mean_resid)
  
save "auto_tva_ests_base.dta", replace

/**********************************************************************
					PRUFUNGZEIT
***********************************************************************/

***1: Direct Comparison by period--predicted vs actual***

use "to_work_with.dta", clear

*Generate actual monthly improvement by client
sort user_id monthyear
by user_id : gen user_improve = zscore - zscore[_n-1], after(zscore)

*Generate actual average of monthly improvement by clients assigned to each therapist
sort therapist_id monthyear user_id
by therapist_id monthyear: egen actual_improvement = mean(user_improve)
order user_id monthyear therapist_id num_clients obs survey_id overall_score zscore user_improve actual_improvement

*Merge in VA preds data
merge m:1 therapist_id monthyear using "auto_tva_ests_base.dta"

*Evaluate differences between predictions and actuals. T-Tests may be useful?
gen diff = pred_tva - actual_improvement, after(mnthyr_mean_resid) //diff between predicted VA and actual outcome
gen diff2 = mnthyr_mean_resid - actual_improvement, after(diff) //diff between actual VA and actual outcme
gen diff3 = pred_tva - mnthyr_mean_resid, after(diff2) //diff between predicted VA and actual VA

ttest pred_tva == actual_improvement
ttest mnthyr_mean_resid == actual_improvement
ttest pred_tva == mnthyr_mean_resid

sum diff*, detail


***2: Application Test--predict the VA to client i joining the platform with therapist j in monthyear t***

use "auto_tva_ests_base.dta", replace
keep therapist_id monthyear mnthyr_mean_resid pred_tva

merge m:m therapist_id monthyear using "to_work_with.dta"
drop if _merge == 2

sort therapist_id user_id monthyear

*Let's pick an arbitrary monthyear for which we have a decent amount of values: 52
gen temp = 0
replace temp = 1 if monthyear == 52

bys user_id : egen on_52 = max(temp)
save "temp.dta", replace

keep if on_52 == 1
sort user_id monthyear
by user_id : gen gains_52 = zscore - zscore[_n-1], after(zscore)
keep if monthyear == 52
keep therapist_id monthyear user_id gains_52 on_52
save "monthyear52.dta", replace

use "temp.dta", clear
drop if monthyear >= 52 //Pretend with me: it is monthyear 52


*Predict each therapist's VA in monthyear 52

xtset therapist_id

*Eq. 1
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time zscore_lag, fe 

*Eq. 2
predict resid, residual

*Therapist VA: Calculate each therapist's average effect in each monthyear period 
bys therapist_id monthyear: egen mnthyr_mean_resid_52 = mean(resid) 
order user_id monthyear therapist_id num_clients obs survey_id mnthyr_mean_resid_52 zscore

*Bring in data to predict on
append using "monthyear52.dta"

*Now make preds adjusted for drift
keep therapist_id monthyear mnthyr_mean_resid_52 on_52
sort therapist_id monthyear
drop if monthyear == monthyear[_n-1] & therapist_id == therapist_id[_n-1]
bys therapist_id : egen N = count(therapist_id) //number of months therapist was active in

*Create lag/lead variables 
sort therapist_id monthyear
by therapist_id : gen time = _n

forvalues i = 1/60 {
	by therapist_id : gen lag`i' = mnthyr_mean_resid[_n-`i']
}	

forvalues i = 1/60 {
	by therapist_id : gen lead`i' = mnthyr_mean_resid[_n+`i']
}

*Regress each lag/lead individually to assess covariance between each of these and present. Save coefficients as these are our estimates
forvalues i = 1/13 {
	reg mnthyr_mean_resid lag`i'
	scalar lg`i' = _b[lag`i']
	
	reg mnthyr_mean_resid lead`i'
	scalar ld`i' = _b[lead`i']
}

*Replace missing with zero prior to making predictions
forvalues i = 1/60 {
	replace lag`i' = 0 if lag`i' ==.
	replace lead`i' = 0 if lead`i' == .
}
  
*Predict VA adjusted for drift. 
gen pred_tva = lag1*lg1 + lag2*lg2 + lag3*lg3 + lag4*lg4 + lag5*lg5 + lag6*lg6 + lag7*lg7 + lag8*lg8 + lag9*lg9 + lag10*lg10 + lag11*lg11 + lag12*lg12 + lag13*lg13 + lead1*ld1 + lead2*ld2 + lead3*ld3 + lead4*ld4 + lead5*ld5 + lead6*ld6 + lead7*ld7 + lead8*ld8 + lead9*ld9 + lead10*ld10 + lead11*ld11 + lead12*ld12 + lead13*ld13
  
order therapist_id monthyear mnthyr_mean_resid pred_tva 
keep therapist_id monthyear mnthyr_mean_resid_52 pred_tva on_52
keep if monthyear == 52

merge 1:m therapist_id using "monthyear52.dta" 
gen diff = gains_52 - pred_tva 
sum diff, detail //This seems to be saying that about 80% of our predictions are within .3 SD of the actual... sounds good right? 
ttest pred_tva == gains_52, unpaired //Statistically insignificant differences!! Unless unpaired...
scalar pval_52 = r(p)

sum diff, detail
scalar p10_52 = r(p10)
scalar p90_52 = r(p90)




/*
*****************************************
*Can be replicated for any period in the data
forvalues k = 50/60 {
	use "auto_tva_ests_base.dta", replace
	keep therapist_id monthyear mnthyr_mean_resid pred_tva

	merge m:m therapist_id monthyear using "to_work_with.dta"
	drop if _merge == 2

	sort therapist_id user_id monthyear
	
	*Let's pick an arbitrary monthyear for which we have a decent amount of values: `i'
	gen temp = 0
	replace temp = 1 if monthyear == `k'
	
	bys user_id : egen on_`k' = max(temp)
	save "temp.dta", replace
	
	keep if on_`k' == 1
	sort user_id monthyear
	by user_id : gen gains_`k' = zscore - zscore[_n-1], after(zscore)
	keep if monthyear == `k'
	keep therapist_id monthyear user_id gains_`k' on_`k'
	save "monthyear`k'.dta", replace

	use "temp.dta", clear
	drop if monthyear >= `k' //Pretend with me: it is monthyear `k'

	
	*Predict each therapist's VA in monthyear `k'
	
	xtset therapist_id

	*Eq. 1
	xtreg zscore i.gender_customer i.education_level i.marital_status i.country i.state i.age_customer i.plan_name first_time first_score zscore_lag, fe

	*Eq. 2
	predict resid, residual

	*Therapist VA: Calculate each therapist's average effect in each monthyear period 
	bys therapist_id monthyear: egen mnthyr_mean_resid_`k' = mean(resid) 
	order user_id monthyear therapist_id num_clients obs survey_id mnthyr_mean_resid_`k' zscore

	*Bring in data to predict on
	append using "monthyear`k'.dta"

	*Now make preds adjusted for drift
	keep therapist_id monthyear mnthyr_mean_resid_`k' on_`k'
	sort therapist_id monthyear
	drop if monthyear == monthyear[_n-1] & therapist_id == therapist_id[_n-1]
	bys therapist_id : egen N = count(therapist_id) //number of months therapist was active in 

	*Create lag/lead variables 
	sort therapist_id monthyear
	by therapist_id : gen time = _n

	forvalues i = 1/60 {
		by therapist_id : gen lag`i' = mnthyr_mean_resid[_n-`i']
	}	

	forvalues i = 1/60 {
		by therapist_id : gen lead`i' = mnthyr_mean_resid[_n+`i']
	}

	*Regress each lag/lead individually to assess covariance between each of these and present. Save coefficients as these are our estimates
	forvalues i = 1/13 {
		reg mnthyr_mean_resid lag`i'
		scalar lg`i' = _b[lag`i']
	
		reg mnthyr_mean_resid lead`i'
		scalar ld`i' = _b[lead`i']
	}

	*Replace missing with zero prior to making predictions
	forvalues i = 1/60 {
		replace lag`i' = 0 if lag`i' ==.
		replace lead`i' = 0 if lead`i' == .
	}
  
	*Predict VA adjusted for drift. 
	gen pred_tva = lag1*lg1 + lag2*lg2 + lag3*lg3 + lag4*lg4 + lag5*lg5 + lag6*lg6 + lag7*lg7 + lag8*lg8 + lag9*lg9 + lag10*lg10 + lag11*lg11 + lag12*lg12 + lag13*lg13 + lead1*ld1 + lead2*ld2 + lead3*ld3 + lead4*ld4 + lead5*ld5 + lead6*ld6 + lead7*ld7 + lead8*ld8 + lead9*ld9 + lead10*ld10 + lead11*ld11 + lead12*ld12 + lead13*ld13
  
	order therapist_id monthyear mnthyr_mean_resid pred_tva 
	keep therapist_id monthyear mnthyr_mean_resid_`k' pred_tva on_`k'
	keep if monthyear == `k'

	merge 1:m therapist_id using "monthyear`k'.dta" 
	gen diff = gains_`k' - pred_tva 

	ttest pred_tva == gains_`k' //Statistically insignificant differences!! Unless unpaired...
	scalar tval_`k' = r(p)
	
	sum diff, detail
	scalar p10_`k' = r(p10)
	scalar p90_`k' = r(p90)
}

forvalues i = 50/60 {
	di "pval for " `i' " is " tval_`i'
	di p10_`i'
	di p90_`i' 
}
*/



***3: CFR-Style Bias Checks***

use "auto_tva_ests_base.dta", replace

*Merge with main data to get data attached to these therapists
merge m:m therapist_id monthyear using "to_work_with.dta"
keep if _merge == 3
	
*Naive estimate assuming random assignment
//xtreg zscore pred_tva  //B = 1-coefficient on VA preds
	
*Better estimate given consistently non-random assignment
*Keep records where t-2 assessment scores are available
sort user_id monthyear
by user_id : gen zscore_lag2 = zscore[_n-2], after(zscore_lag)
keep if zscore_lag2 != .
	
*Estimate VA as before, but specific to this sample
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time first_score zscore_lag, fe 
predict resid, residual
bys therapist_id monthyear: egen test_mnthyr_mean_resid = mean(resid) 

*Calculate bias assuming twice-lagged scores as a major component for epsilon
xtreg zscore_lag2 i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time first_score zscore_lag, fe
predict resid2, residual
xtreg zscore resid2, fe
predict preds
reg preds test_mnthyr_mean_resid //B = coefficient on test_mnthyr_mean_resid
	


	
