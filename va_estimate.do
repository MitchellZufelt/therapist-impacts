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
import delimited "therapy_full.csv", varnames(1) stringcols(1 27) numericcols(13 17 18 19 20 21 22 23 24 25 26 28 29 30 31 32 33 34 35 39 40 41 4 2 53 54 55 56 57 58 59 60 61) 
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

*Replace missing diagnoses with 0
qui: forvalues i = 1/705 {
		replace cond`i' = 0 if cond`i' == .
}

*Replace missing live video duration/media message counts
replace num_live_video_calls = 0 if num_live_video_calls == .
replace num_30_plus_sec_live_video_calls = 0 if num_30_plus_sec_live_video_calls == .
replace total_live_video_duration = 0 if total_live_video_duration == .
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


*Drop irrelevant variables
drop *payfirst



save "therapy.dta", replace


