/* 
Title: Example Therapist VA Estimate
Author: Mitch Zufelt
Date: 10/31/2022

Description: A snippet from the therapist value-added estimation code. This is the good part where we actually estimate therapist VA. 
*/

cd "C:\Users\mitch\OneDrive\Desktop\cleaned_talkspace_data"

use "example_file.dta", clear
order user_id monthyear therapist_id survey_id overall_score zscore

*Eq. 1: Estimate model of client assessment scores using client characteristics + therapist fixed effects
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time first_score zscore_lag, fe 
	//Note: we ought to explore alternative specifications here to see what combination of variables/polynomials produces the best fit.
	
*Eq. 2: Predict residuals.
predict resid, residual


*Intermediate step: Calculate each therapist's average effect in each monthyear period
bys therapist_id monthyear: egen mnthyr_mean_resid = mean(resid) 
	//collapsing to monthyear now, but could collapse further to quarters and precision-weight by monthyear cohorts 
	
	
*Eq. 3: Caluclate a prediction for a therapist's VA in any given monthyear by first calculating a "drift" parameter for all the other years in the data. This is done by fitting an OLS regression of the therapists actual average VA in the monthyear we intend to predict on that therapist's actual average VA in each of all other monthyears in the data. 
	
*We will just estimate VA in period 7, for now. 
	
	*Keep only relevant information for now
	keep therapist_id monthyear resid mnthyr_mean_resid
	drop if therapist_id == therapist_id[_n-1] & monthyear==monthyear[_n-1]
	bys therapist_id: egen N = count(therapist_id) 
	
	*pred will designate the final observation for a therapist, which I will predict a VA score for (1 if that row, 0 otherwise)
	gen pred = 0
	replace pred = 1 if therapist_id == therapist_id[_n-1] & therapist_id != therapist_id[_n+1] 
	
	*Keep only those therapists with 7 observations
	keep if N == 7

	*Generate lag variables (previous mnthyr_mean_resid)
	forvalues i = 1/6 {
		gen lag`i' = mnthyr_mean_resid[_n-`i']
	}	

	*Keep only one observation per therapist
	keep if pred == 1 & mnthyr_mean_resid != .

	*Finally, use regression to estimate phi coefficients, then fit predictions. 
		reg mnthyr_mean_resid lag* 
		predict fitted7 
		replace fitted7 = fitted7 - _b[_cons]	
		
	*Name therapist value-added variable: tva
	rename fitted7 tva
	
	drop lag* pred resid monthyear mnthyr_mean_resid
	
	
	
	
***** ***** ***** ***** ***** ***** ****** ****** ***** ***** *****
	*Testing Bias in this Preliminary Estimate*

	*Merge with main data to get data attached to these therapists
	merge 1:m therapist_id using "example_file.dta"
	keep if _merge == 3
	
	*Naive estimate assuming random assignment
	xtreg zscore tva  //B = 1-coefficient on mnthyr_mean_resid
	
	*Better estimate given consistently non-random assignment
	*Keep records where t-2 assessment scores are available
	sort user_id monthyear
	by user_id : gen zscore_lag2 = zscore[_n-2], after(zscore_lag)
	keep if zscore_lag2 != .
	
	*Estimate VA as before, but specific to this sample
	xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time first_score zscore_lag, fe 
	predict resid, residual
	bys therapist_id monthyear: egen mnthyr_mean_resid = mean(resid) 

	*Calculate bias assuming twice-lagged scores as a major component for epsilon
	xtreg zscore_lag2 i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time first_score zscore_lag, fe
	predict resid2, residual
	xtreg zscore resid2, fe
	predict preds
	reg preds mnthyr_mean_resid //B = coefficient on mnthyr_mean_resid
	
		***** ***** *****

		
		
		
		
	
/*
***ESTIMATING DRIFT PARAMETERS FOR MULTIPLE COUNTS***

*Keep only relevant information for now
	keep therapist_id monthyear resid mnthyr_mean_resid
	drop if therapist_id == therapist_id[_n-1] & monthyear==monthyear[_n-1]
	bys therapist_id: egen N = count(therapist_id) 
	
	*pred will designate the final observation for a therapist, which I will predict a VA score for (1 if that row, 0 otherwise)
	gen pred = 0
	replace pred = 1 if therapist_id == therapist_id[_n-1] & therapist_id != therapist_id[_n+1] 
	
	*Keep only those therapists with <=35 observations (observations are sparse above 35)
	drop if N > 35

	*Generate lag variables (previous mnthyr_mean_resid)
	forvalues i = 1/34 {
		gen lag`i' = mnthyr_mean_resid[_n-`i']
	}	

	*Keep only one observation per therapist
	keep if pred == 1 & mnthyr_mean_resid != .

	*Finally, use regression to estimate phi coefficients, then fit predictions. 
		qui: reg mnthyr_mean_resid lag* if N == 35
		predict fitted35 if N == 35
		replace fitted35 = fitted35 - _b[_cons]	if N == 35
		
	forvalues i = 34(-1)2 { //repeat above 3 lines for therapists of each number of counts
		
		drop lag`i'
		
		qui: reg mnthyr_mean_resid lag* if N == `i'
		predict fitted`i' if N == `i'
		replace fitted`i' = fitted`i' - _b[_cons] if N == `i'
		
	} 
	
	*Name therapist value-added variable: tva
	gen tva = 0, after(therapist_id)
	forvalues i = 2/35 {
		replace tva = fitted`i' if fitted`i' != .
	}
	
	drop fitted* lag* pred resid monthyear mnthyr_mean_resid
	
	
	
