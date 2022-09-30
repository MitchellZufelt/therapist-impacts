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
gen created_survey = clock(created_at, "YMD hms")
format created_survey %tc
gen completed_survey = clock(completed_at, "YMD hms")
format completed_survey %tc

*Drop irrelevant variables
drop *payfirst


*Order variables intuitively
order therapist_id room_id user_id user_room_survey_id survey_id overall_score om_scale_id scale_score created_at completed_at
sort therapist_id room_id user_id


*Save file: Full and clean.
save "therapy.dta", replace


*** BEGIN VA ESTIMATION ***

*Restrict to survey_id == 2 (second most ubiquitous survey_id in dataset)
use "therapy.dta", clear
keep if survey_id == 2  //YO SHOULD I BE GOING DOWN TO THE survey_id lvl or the om_scale_id lvl????

*Restrict to complete data (15,074 obs of 664 therapists, 2,355 clients, 2,457 rooms, and 6,211 survey admins)
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


*Define panel var
egen panel_id = group(therapist_id room_id)



**Define time var: count of how many times the therapist has administered the survey to the client in that room (i.e., is this the first, second, third time... etc)
gen time_var = 1, after(user_room_survey_id)

forvalues i = 1/100 {
	bys panel_id: replace time_var = time_var[_n-1] + 1 if user_room_survey_id != user_room_survey_id[_n-1]
	replace time_var = 1 if time_var == .
	by panel_id: replace time_var = time_var[_n-1] if user_room_survey_id == user_room_survey_id[_n-1] & time_var != time_var[_n-1]
}


*Collapse to remove repeat time_vars within user_room_survey_id
(need to address survey_id vs om_scale_id first)

**Establish as panel data
order panel_id time_var
xtset panel_id time_var
 
 
 


save "analysis_1.dta", replace


*** FIRST PASS AT ANALYSIS ***







///MISSINGNESS ISSUES: A first-pass consideration

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

//down to 50,815 obs

drop if user_room_survey_id == "NA" | user_room_survey_id == "NULL"

//down to 39,272 obs ft 4,784 clients with 466 therapists

keep if survey_id == 9

//this gives us 26,004 observations with 3,805 clients and 119 therapists 


/*

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

	
	
	//Gen period: time between survey administrations
sort panel_id created_survey
gen placehold = 0, after(user_room_survey_id)
by panel_id : replace placehold = created_survey - created_survey[_n-1] if user_room_survey_id != user_room_survey_id[_n-1]
replace placehold = 0 if placehold == .
bys panel_id user_room_survey_id: egen period = max(placehold) //great. note: a very right-skewed variable

