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


*Order variables intuitively
order therapist_id room_id user_id user_room_survey_id survey_id overall_score om_scale_id scale_score created_survey completed_survey
sort therapist_id room_id user_id


*Save file: Full and clean.
save "therapy.dta", replace


*** BEGIN VA ESTIMATION ***

**Establishing panel data analysis sample

*Restrict to survey_id == 2 (second most ubiquitous survey_id in dataset)
use "therapy.dta", clear
keep if survey_id == 2  

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
//keep if country == "US" //SHOULD I KEEP THIS RESTRICTION?

****This below should work, following CFR and BHKS. Will likely want to check it against Stepner computations, however.
*therapist_id is panel. What about time_var?
*Hb this: First, create one outcome var per client: overall assessment score gains.
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
