
**Just getting a record of each therapist/client combo and how many obs we have of them

cd "C:\Users\mitch\OneDrive\Desktop\cleaned_talkspace_data"

use "example_file.dta", clear
order user_id monthyear therapist_id survey_id overall_score zscore

*Keep only needed data
keep therapist_id user_id

*How many obs do we have in each pairing? (Think I'll keep only obs>2 bc <=2 may not be helpful statistically) (THO YOU MAY WANT TO COME BACK AND FACTOR THIS IN -- WHY ARE PEOPLE LEAVING THE THERAPIST AFTER 1 OR 2 MTGS?)
bys therapist_id user_id : gen obs = _N
keep if obs > 2

*Keep one row per pairing
sort user_id therapist_id
drop if user_id == user_id[_n-1] & therapist_id == therapist_id[_n-1]

*Give each of a therapist's client a unique within-therapist enumeration
sort therapist_id user_id
egen tag = tag(user_id therapist_id)
egen num_clients = total(tag), by (therapist_id)
drop tag 

*Save
order user_id therapist_id num_clients obs
save client_therapist_pairings.dta, replace




/**Steps beyond this point: 

	- Use this reference to cleanly estimate VA , as in example_va_estimate.do
	- Use this reference to cleanly check VA , as in va_test.do
	
	I will do this in a new file, va_work.do
