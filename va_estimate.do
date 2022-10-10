/******************************************************************
Title: Value-Added Estimates for Therapy Quality Project

Description: Creates valued-added estimates for each of the therapists in our Talkspace data

Author: Mitchell Zufelt

Created on: 09/27/2022


INPUTS:
		- therapy_full.csv
		- diagnoses.csv
		
*****************************************************************/

*** INITIALIZE ***
clear
set more off

cd "C:\Users\mitch\OneDrive\Desktop\cleaned_talkspace_data"


*** IMPORT DATA ***

*Import main dataset (includes client/therapist demographics, therapy details, outcomes)
import delimited "therapy_full.csv", varnames(1) stringcols(1 27) numericcols(13 17 18 19 20 21 22 23 24 25 26 28 29 30 31 32 33 34 35 39 40 41 42 53 54 55 56 57 58 59 60 61) 
save "therapy.dta", replace

*Import diagnoses dataset (includes conditions that each client was diagnosed with)
import delimited "diagnoses.csv", varnames(1) stringcols(1) clear 
save "diagnoses.dta", replace

*Merge the two together into one complete dataset
use "therapy.dta", clear
merge m:1 user_id using "diagnoses.dta"

*Drop observations with insufficient information
keep if _merge != 2
drop _merge


*** CLEAN DATA ***

*Replace missing diagnoses with 0
forvalues i = 1/705 {
		replace cond`i' = 0 if cond`i' == .
}

*Replace missing live video duration/media message counts
replace num_live_video_calls = 0 if num_live_video_calls == .
replace num_30_plus_sec_live_video_calls = 0 if num_30_plus_sec_live_video_calls == .
replace total_live_video_duration = 0 if total_live_video_duration == .
replace audio_duration_total = 0 if audio_duration_total == .
replace video_duration_total = 0 if video_duration_total == .
replace photo_count_total = 0 if photo_count_total == .
replace total_messages_client = 0 if missing(total_messages_client)
replace total_word_count_client = 0 if missing(total_word_count_client)
replace total_char_count_client = 0 if missing(total_char_count_client)
replace distinct_days_client = 0 if missing(distinct_days_client)
replace total_messages_therapist = 0 if missing(total_messages_therapist)
replace total_word_count_therapist = 0 if missing(total_word_count_therapist)
replace total_char_count_therapist = 0 if missing(total_char_count_therapist)
replace distinct_days_therapist = 0 if missing(distinct_days_therapist)
replace total_messages_uncanned_therapis = 0 if missing(total_messages_uncanned_therapis)
replace total_word_count_uncanned_therap = 0 if missing(total_word_count_uncanned_therap)
replace total_char_count_uncanned_therap = 0 if missing(total_char_count_uncanned_therap)
replace distinct_days_uncanned_therapist = 0 if missing(distinct_days_uncanned_therapist)
replace first_time = 0 if missing(first_time)


*Some rooms are missing text data. Fill this out using existing data within those rooms
bysort room_id (user_id) : replace user_id = user_id[_n-1] if user_id=="NA" 
bysort room_id (plan_name) : replace plan_name = plan_name[_n-1] if plan_name=="NA" 
bysort room_id (room_created_date) : replace room_created_date = room_created_date[_n-1] if room_created_date=="NA" 
bysort room_id (conversion_date) : replace conversion_date = conversion_date[_n-1] if conversion_date=="NA" 
bysort room_id (gender_customer) : replace gender_customer = gender_customer[_n-1] if gender_customer=="NA" 
bysort room_id (education_level) : replace education_level = education_level[_n-1] if education_level=="NA" 
bysort room_id (ethnicity) : replace ethnicity = ethnicity[_n-1] if ethnicity=="NA" 
bysort room_id (marital_status) : replace marital_status = marital_status[_n-1] if marital_status=="NA" 
bysort room_id (country) : replace country = country[_n-1] if country=="NA" 
bysort room_id (state) : replace state = state[_n-1] if state=="NA" 
bysort room_id (age_customer) : replace age_customer = age_customer[_n-1] if age_customer=="NA" 
bysort room_id (first_end_room_at) : replace first_end_room_at = first_end_room_at[_n-1] if first_end_room_at=="NA" 
bysort room_id (first_cancellation_at) : replace first_cancellation_at = first_cancellation_at[_n-1] if first_cancellation_at=="NA" 
bysort room_id (first_expiration_at) : replace first_expiration_at = first_expiration_at[_n-1] if first_expiration_at=="NA" 


*Some rooms are missing numeric data. Fill this out using existing data within those rooms
bys room_id : egen placehold = max(first_time)
replace first_time = placehold
drop placehold

bys room_id : egen placehold = max(num_live_video_calls)
replace num_live_video_calls = placehold
drop placehold

bys room_id : egen placehold = max(num_30_plus_sec_live_video_calls)
replace num_30_plus_sec_live_video_calls = placehold
drop placehold

bys room_id : egen placehold = max(total_live_video_duration)
replace total_live_video_duration = placehold
drop placehold

bys room_id : egen placehold = max(audio_duration_total)
replace audio_duration_total = placehold
drop placehold

bys room_id : egen placehold = max(video_duration_total)
replace video_duration_total = placehold
drop placehold

bys room_id : egen placehold = max(photo_count_total)
replace photo_count_total = placehold
drop placehold

bys room_id : egen placehold = max(total_messages_client)
replace total_messages_client = placehold
drop placehold

bys room_id : egen placehold = max(total_word_count_client)
replace total_word_count_client = placehold
drop placehold

bys room_id : egen placehold = max(total_char_count_client)
replace total_char_count_client = placehold
drop placehold

bys room_id : egen placehold = max(distinct_days_client)
replace distinct_days_client = placehold
drop placehold

*Put created_at and completed_at (the assessment times) into date format
gen created_survey = date(created_at, "YMD hms")
format created_survey %td
gen completed_survey = date(completed_at, "YMD hms")
format completed_survey %td

*Drop irrelevant variables
drop *payfirst

*Data are organized at the client level, and surveys are administered approximately monthly in most of the data
order user_id
sort user_id completed_survey 

*Generate variable counting number of days after a previous survey that the current survey was completed
by user_id : gen days_to_complete = completed_survey - completed_survey[_n-1], after(completed_survey) //A significant percentage of surveys within client are approximately a month a part

*Save file: Full and clean.
save "therapy.dta", replace


*** BEGIN VA ESTIMATION ***

use "therapy.dta", clear

*We will need to specifiy which data to use for our analysis sample. //
	*Several sub-samples could be used to test for robustness. //
	*For simplicity, for now:
	keep if om_scale_id == 4
	drop if user_id == ""
	drop cond* //Diagnoses Vars not useful currently. Revisit later. 

	/*
destring user_id, replace
xtset user_id
*/

*Create time variable: Month and year a given survey was completed by the client
gen month = month(completed_survey)
gen year = year(completed_survey)
egen monthyear = group(year month)
order user_id monthyear

*Some instances where a client too >1 survey in a monthyear period. For now: Just keep the month's average outcome when there's more than one survey in a month. (May want to revisit this.)
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

*Establish panel based on therapist_id
destring therapist_id, replace
xtset therapist_id

*Encode client covariates which currently saved as strings
foreach i in gender_customer education_level ethnicity marital_status country state age_customer plan_name{
	rename `i' placehold
	encode placehold, gen(`i')
	drop placehold
}

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
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time first_score, fe
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time zscore_lag, fe
xtreg zscore i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_time first_score zscore_lag, fe //varied specifications using past scores
														//ayo and what about polynomials? useful for fit?
														//check the distribution of each variable (two way w zscore)
														//and yo fixed effects for year/month?
														
predict fitted
gen resid = zscore - fitted, after(zscore)

*Step 2: Generate average therapist effect at monthyear level
bys therapist_id monthyear: egen mnthyr_mean_resid = mean(resid) //collapsing to monthyear now, but could collapse further to quarters and precision-weight by monthyear cohorts (similar to BHKS eq. 3)

*Step 3: Begin to caluclate a prediction for a therapist's VA in any given monthyear by first calculating a "drift" parameter for all the other years in the data. This is done by fitting an OLS regression of the therapists actual average VA in the monthyear we intend to predict on that therapist's actual average VA in each of all other monthyears in the data. 
//This is not difficult math, but I am not sure how to code it up. Will need to revisit, preferrably with someone better at programming than I am. The .do file by Michael Stepner (associated with CFR project) does something similar to this at about line 254 in that file. Uses mata and stuff.

*Step 4: Predict therapist's VA in monthyear t as muhat_jt = (transposed vector of coefficients estimated in Step 3)*(Their associated monthyears)



/*FAILED ATTEMPT
**Establishing panel data analysis sample (sample selection is something to vary later to test robustness)

*Restrict to survey_id == 2 (second most ubiquitous survey_id in dataset)
use "therapy.dta", clear
keep if survey_id == 2  

*Restrict to complete data 
drop if plan_name == "NA" | plan_name == "NULL" 
drop if gender_customer == "NA" | gender_customer == "NULL"
drop if education_level == "NA" | education_level == "NULL"
drop if ethnicity == "NA" | ethnicity == "NULL"
drop if marital_status == "NA" | marital_status == "NULL"
drop if age_customer == "NA" | age_customer == "NULL"
drop if therapist_type == "NA" | therapist_type == "NULL"
drop if therapist_dob == "NA" | therapist_dob == "NULL"
drop if therapist_gender == "NA" | therapist_gender == "NULL"
drop if therapist_experience == "NA" | therapist_experience == "NULL"
drop if license_type == "NA" | license_type == "NULL"
drop if user_room_survey_id == "NA" | user_room_survey_id == "NULL"  
//keep if country == "US" //SHOULD I KEEP THIS RESTRICTION?

*Keep only first and last assessment outcome per therapist-client match
bys therapist_id room_id : egen initial = min(created_survey)
bys therapist_id room_id : egen final = max(created_survey) 
keep if created_survey == initial | created_survey == final

sort therapist_id room_id user_room_survey_id created_survey
drop if user_room_survey_id == user_room_survey_id[_n-1]
drop if user_id == user_id[_n-1] & created_survey == created_survey[_n-1] //Fix an issue where a few had two surveys created at the same time

*Generate variable with overall improvement in assessment score from first time to last time
gen placehold = 0
replace placehold = overall_score if created_survey == initial
bys therapist_id room_id: egen first_score = max(placehold)

replace placehold = 0
replace placehold = overall_score if created_survey == final
bys therapist_id room_id: egen final_score = max(placehold)

gen overall_improvement = final_score - first_score

*Keep one row per client; include info on survey dates and time elapsed
bys therapist_id room_id : egen first_survey = min(created_survey)
keep if created_survey != first_survey
rename created_survey last_survey
gen time_elapsed = last_survey - first_survey, after(last_survey)

*Drop irrelevant vars
drop overall_score om_scale_id scale_score placehold 

*Make format human-readable
format first_survey %td
format last_survey %td

*Demarcate which monthy/year each therapy session concluded in
gen mnth = month(last_survey)
gen yr = year(last_survey)
egen monthyear = group(yr mnth)
drop mnth yr 

*Generate time variable (time_var): count of which ordinal # client this is for the therapist during their time on the platform
gen time_var = 1, 
sort therapist_id last_survey
by therapist_id : replace time_var = time_var[_n-1] + 1 if time_var <= time_var[_n-1] & therapist_id == therapist_id[_n-1]

*Rearrange to reasonable order
order therapist_id time_var room_id user_id user_room_survey_id survey_id overall_improvement first_survey last_survey 

*Establish panel
rename therapist_id t_id
encode t_id, gen(therapist_id)
drop t_id
xtset therapist_id time_var

*Save analysis_1
save "analysis_1.dta", replace

****This should work, following CFR and BHKS. Will likely want to check it against Stepner computations, however.

**Estimate VA for each therapist, following CFR and BHKS
use "analysis_1.dta", clear

*Standardize overall_improvement
sum overall_improvement
gen zscore = (overall_improvement-r(mean))/r(sd), before(overall_improvement)

*Encode client covariates which currently saved as strings
foreach i in gender_customer education_level ethnicity marital_status country state age_customer plan_name{
	rename `i' placehold
	encode placehold, gen(`i')
	drop placehold
}


*1: Estimate model of client assessment scores using client characteristics + therapist fixed effects
xtreg overall_improvement i.gender_customer i.education_level i.ethnicity i.marital_status i.country i.state i.age_customer i.plan_name first_score first_time monthyear, fe

*2: Isolate residual client assessment scores by removing the effect of observable characteristics
predict fitted //IS THIS THE CORRECT THING TO USE??
gen score_resid = zscore-fitted, after(zscore)

*/


/* NOTES

Note: diagnosis vars are currently going unused

missingness exists in         
	plan_name 37.77%
	gender_customer 34.94%
	education_level 58.84%%
	ethnicity 93.29%
	marital_status 41.8%
	country 3% (not concerned)
	state 10% (not concerned)
	age_customer 74.79%
	
	therapist_type 39%   
	therapist_dob 64.25%
	therapist_pro_degree 75.63%
	therapist_gender 39.08%
	therapist_experience 39.31%
	license_type 43.11%
	
	user_room_survey_id and all outcomes data 
	
	
. tab survey_id, sort

  survey_id |      Freq.     Percent        Cum.
------------+-----------------------------------
         27 |    915,560       31.17       31.17
          2 |    713,370       24.28       55.45
         10 |    324,114       11.03       66.49
          9 |    302,097       10.28       76.77
          4 |    197,790        6.73       83.50
          1 |    156,636        5.33       88.84
          6 |     57,738        1.97       90.80
         14 |     56,490        1.92       92.72
          8 |     39,990        1.36       94.09
         15 |     35,400        1.21       95.29
         22 |     34,158        1.16       96.45
         24 |     29,140        0.99       97.45
         20 |     21,078        0.72       98.16
         26 |     18,524        0.63       98.79
         18 |     16,858        0.57       99.37
         17 |      6,267        0.21       99.58
          3 |      5,313        0.18       99.76
         21 |      2,555        0.09       99.85
         16 |      1,570        0.05       99.90
         12 |      1,473        0.05       99.95
         25 |        664        0.02       99.97
         23 |        644        0.02      100.00
         19 |         63        0.00      100.00
         11 |         31        0.00      100.00
         13 |          4        0.00      100.00
------------+-----------------------------------
      Total |  2,937,527      100.00

	  
**Define time var by om_scale_id: count of how many times the therapist has administered the survey to the client in that room (i.e., is this the first, second, third time... etc)
gen time_var = 1, after(user_room_survey_id)

forvalues i = 1/100 {
	bys panel_id: replace time_var = time_var[_n-1] + 1 if user_room_survey_id != user_room_survey_id[_n-1]
	replace time_var = 1 if time_var == .
	by panel_id: replace time_var = time_var[_n-1] if user_room_survey_id == user_room_survey_id[_n-1] & time_var != time_var[_n-1]
}
	
	
	//Gen period: time between survey administrations
sort panel_id created_survey
gen placehold = 0, after(user_room_survey_id)
by panel_id : replace placehold = created_survey - created_survey[_n-1] if user_room_survey_id != user_room_survey_id[_n-1]
replace placehold = 0 if placehold == .
bys panel_id user_room_survey_id: egen period = max(placehold) //great. note: a very right-skewed variable

