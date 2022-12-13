
use "therapy.dta", clear
order user_id
sort user_id completed_survey //Y'all they completin surveys approximately monthly
	by user_id : gen days_to_complete = completed_survey - completed_survey[_n-1], after(completed_survey) //Yeah a significant percentage of them are approximately a month

//for simplicity, for now:
keep if om_scale_id == 4
drop if user_id == ""
drop cond* //revisit this later


destring user_id, replace
xtset user_id //works

gen month = month(completed_survey)
gen year = year(completed_survey)
egen monthyear = group(year month)
order user_id monthyear
*xtset user_id monthyear //doesn't work (repeated time values within panel)
//for simplicity, let's deal w/ it like this for now: average of the month when there's two in a month and then just keep the second one
sort user_id monthyear
gen placehold = 0
replace placehold =1 if user_id == user_id[_n-1] & monthyear == monthyear[_n-1]
replace placehold = placehold[_n+1] if user_id == user_id[_n+1] & monthyear == monthyear[_n+1] & placehold < placehold[_n+1]
gen placehold2 = overall_score*placehold, after(placehold)
bys user_id : egen sumplacehold2 = sum(placehold2)
bys user_id : egen sumplacehold = sum(placehold)
gen placehold3 = sumplacehold2 / sumplacehold, after(placehold2)
replace overall_score = placehold3 if placehold == 1
drop placehold* sumplacehold*

drop if user_id == user_id[_n+1] & monthyear == monthyear[_n+1]

xtset user_id monthyear


*Encode client covariates which currently saved as strings
foreach i in gender_customer education_level ethnicity marital_status country state age_customer plan_name{
	rename `i' placehold
	encode placehold, gen(`i')
	drop placehold
}

destring therapist_id, replace

*Standardize assessment score
sum overall_score
gen zscore = (overall_score-r(mean))/r(sd), before(overall_score)

*Create lagged score varby user_id : 
gen zscore_lag = zscore[_n-1], after(zscore)
replace zscore_lag = 0 if zscore_lag == .

*Create first_score variable (may be redundant?)
by user_id : egen initial = min(completed_survey)
gen placehold = 0
replace placehold = zscore if completed_survey == initial
by user_id: egen first_score = max(abs(placehold))
replace first_score = first_score*-1 if placehold < 0

drop initial placehold

*1: Estimate model of client assessment scores using client characteristics + therapist fixed effects
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time, fe//PRETTY sure that this is not actually what i want, as it groups on client... try:

reg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time //i.therapist_id

set maxvar 120000
reg zscore i.therapist_id

***

*Steps 1 
xtset therapist_id
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time, fe
predict fitted
gen resid = zscore - fitted, after(zscore)  //damn did i just do it? 


xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time first_score, fe
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time zscore_lag, fe
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time first_score zscore_lag, fe //varied specifications using past scores
														//ayo and what about polynomials? useful for fit?
														//check the distribution of each variable (two way w zscore)
														//and yo fixed effects for year/month?

*Step 2
bys therapist_id monthyear: egen mnthyr_mean_resid = mean(resid) //collapsing to monthyear now, but could collapse further to quarters and precision-weight by monthyear cohorts (similar to BHKS eq. 3)

*Step 3 

//Ok phewwwww... starts about 254 in Stepner doc. Check it out. 
//I bet I could manually compute this stuff... but it would be a lot messier that way. 
//Predicting therapist 680's VA in monthyear 20:
	keep if therapist_id == 680
	
	gen period_of_interest = 0, after(therapist_id)
	replace period_of_interest = 1 if monthyear == 20
	drop if monthyear > 20 //Should i use periods after the period_of_interest? I'm not for now
	
	gen placehold = 0
	replace placehold = mnthyr_mean_resid if monthyear == 20
	egen actual_score_20 = min(placehold)
	order user_id monthyear therapist_id period_of_interest actual_score_20 room_id user_room_survey_id survey_id zscore mnthyr_mean_resid
	drop placehold
	
	drop if period_of_interest == 1
	drop if monthyear == monthyear[_n-1]
	tsset monthyear
	keep monthyear actual_score_20 mnthyr_mean_resid
	reg actual_score_20 mnthyr_mean_resid


	
order user_id monthyear therapist_id room_id user_room_survey_id survey_id zscore mnthyr_mean_resid







***
	*** Estimate the covariance of years t and t+i for every i, and store in vector m
		tsset therapist_id monthyear /*, noquery*/
		
		tempvar minyear maxyear diff validyear minvalidyear maxvalidyear diffvalid
		
		 bys therapist_id: egen mintime=min(monthyear)
		 by therapist_id: egen maxtime=max(monthyear)
		 g diff=maxtime-mintime
		 sum diff
		local maxspan=r(max)
		
		qui gen `validyear'=`year' if !missing(`class_mean')
		qui by `teacher': egen `minvalidyear'=min(`validyear')
		qui by `teacher': egen `maxvalidyear'=max(`validyear')
		qui g `diffvalid'=`maxvalidyear'-`minvalidyear'
		qui sum `diffvalid'
		local maxscorespan=`r(max)'
		
		if (`maxscorespan'<`maxspan') & (`driftlimit'<=0) {
			di as error _n	"error: The maximum lags of teacher data is `maxspan', but the maximum lags of teacher data with class scores is `maxscorespan'."
			di as error		"       You must either set driftlimit() <= `maxscorespan', or drop observations so that the spans are no longer mismatched."
			exit 499
		}
		if (`driftlimit'>`maxscorespan') {
			di as error "error: driftlimit(`driftlimit') was specified, which is greater than the number of lags (`maxscorespan') in the data."
			exit 499
		}
		
		mata:CC=compute_cov_corr("mnthyr_mean_resid",`maxscorespan',"therapist_id")
		
		if (`driftlimit'>0)	mata:m=create_m(CC[.,1],st_numscalar("`cov_sameyear'"),`maxspan',`driftlimit')
		else				mata:m=create_m(CC[.,1],st_numscalar("`cov_sameyear'"))
