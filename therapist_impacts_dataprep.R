# TITLE: therapist_impacts_dataprep.do
# DESCRIPTION: clean and prepare TalkSpace data for analysis in "Measuring the Impacts of Therapists: Evidence from a Value-Added Approach"
# AUTHOR: Mitch Zufelt
# CREATED: 09/19/2022
# 
# INPUTS:
#   - 1-1-2014 to 12-31-2016 Data:
#   - GenDemogs2014-16.csv
# - Diagnoses2014-16.csv
# - LiveVideo2014-16.csv
# - MediaMessgCounts2014-16.csv
# - MessageCounts2014-16.csv
# - Outcomes2014-2016.csv

#Libraries
library(tidyverse)
library(data.table)

#directories
setwd("C:/Users/mitch/OneDrive/Desktop")

#####2014-2016 data#####
therapy14_16 <- read.csv("1-1-2014 to 12-31-2016 Data/GenDemogs2014-16.csv") %>% select(-starts_with("status"),
                                                                                        -starts_with("partner"),
                                                                                        -starts_with("voucher"),-with_video,
                                                                                        -claim_date,-starts_with("employer"),
                                                                                        -Total_Covered_Lives, -US_Covered_Lives,
                                                                                        -Go_Live_Date,-payment_type,-plan_type_id,
                                                                                        -date_of_birth,-year_of_birth,
                                                                                        -primary_condition)

#remove duplicated elements
therapy14_16 <- therapy14_16[!duplicated(therapy14_16),]

#remove "couples therapy" subscribers; beyond the scope of this analysis
therapy14_16 <- therapy14_16[grepl("Couples",therapy14_16$plan_name)==F,]

#import live video counts
live_video <- read.csv("1-1-2014 to 12-31-2016 Data/LiveVideo2014-16.csv")

#merge with main
therapy14_16 <- left_join(therapy14_16,live_video,by="room_id")

#import audio message counts
audio_message <- read.csv("1-1-2014 to 12-31-2016 Data/MediaMessgCounts2014-16.csv") %>% filter(media_type=="audio") %>%
  select(-"media_type",-"media_message_count") %>%
  group_by(room_id,user_id) %>%
  mutate(audio_duration_total = sum(total_duration)) %>%
  select(-"total_duration")
audio_message <- audio_message[!duplicated(audio_message),]

#merge with main
therapy14_16 <- left_join(therapy14_16,audio_message, by=c("room_id"="room_id","user_id"="user_id"))

#import video message counts
video_message <- read.csv("1-1-2014 to 12-31-2016 Data/MediaMessgCounts2014-16.csv") %>% filter(media_type=="video") %>%
  select(-"media_type",-"media_message_count") %>%
  group_by(room_id,user_id) %>%
  mutate(video_duration_total = sum(total_duration)) %>%
  select(-"total_duration")
video_message <- video_message[!duplicated(video_message),]

#merge with main
therapy14_16 <- left_join(therapy14_16,video_message, by=c("room_id"="room_id","user_id"="user_id"))

#import photo message counts
photo_message <- read.csv("1-1-2014 to 12-31-2016 Data/MediaMessgCounts2014-16.csv") %>% filter(media_type=="photo") %>%
  select(-"media_type",-"total_duration") %>%
  group_by(room_id,user_id) %>%
  mutate(photo_count_total = sum(media_message_count)) %>%
  select(-"media_message_count")
photo_message <- photo_message[!duplicated(photo_message),]

#merge with main
therapy14_16 <- left_join(therapy14_16,photo_message, by=c("room_id"="room_id","user_id"="user_id"))

#import text message counts
message_counts <- read.csv("C:/Users/mitch/OneDrive/Desktop/1-1-2014 to 12-31-2016 Data/MessageCounts2014-16.csv")

#remove rooms with multiple clients (some exist because of couples packages, others unexplained/anomalous)
mult_client <- message_counts %>% group_by(room_id) %>% count(user_type) %>% filter(user_type=="client"&n>1)
clients <- message_counts %>% filter(user_type=="client" & !(room_id %in% mult_client$room_id)) # rooms where there is only one client
message_counts <- message_counts %>% filter(room_id %in% clients$room_id) # now down to only those rooms which have one client

#reshape so that there is one record per client/therapist pairing (key user_id therapist_id, as sometimes room_id reused--always only one client per room_id though!)
clients <- message_counts %>% filter(user_type=="client") %>% select(c("room_id","user_id","user_type",
                                                                       "total_messages","total_word_count",
                                                                       "total_char_count","distinct_days"))
names(clients) <- c("room_id","user_id","user_type","total_messages_client","total_word_count_client",
                    "total_char_count_client","distinct_days_client")
therapists <- message_counts %>% filter(user_type=="therapist") %>% arrange(room_id)
names(therapists) <- c("room_id","user_id","user_type","total_messages_therapist","total_word_count_therapist",
                       "total_char_count_therapist","distinct_days_therapist","total_messages_uncanned_therapist",
                       "total_word_count_uncanned_therapist","total_char_count_uncanned_therapist","distinct_days_uncanned_therapist")

message_counts <- merge(clients,therapists,by="room_id") #85k clean client-therapist interactions occurring in ~38k rooms
message_counts <- message_counts %>% rename(
                      user_id = user_id.x,
                      therapist_id = user_id.y
                      ) %>%
                          select(-c("user_type.x","user_type.y")) #rename variables appropriately, drop irrelevant ones

#merge with main
therapy14_16 <- full_join(therapy14_16,message_counts,by=c("room_id"="room_id","user_id"="user_id"))
therapy14_16$therapist_id.y <- ifelse(is.na(therapy14_16$therapist_id.y),
                                      therapy14_16$therapist_id.x,
                                      therapy14_16$therapist_id.y) # remove NA's from outer join so each record has a therapist_id
therapy14_16 <- therapy14_16 %>% select(-"therapist_id.x") %>%
                  rename(
                      therapist_id = therapist_id.y
                        ) %>%
                          arrange(room_id, user_id, therapist_id) #we can remove therapist_id.x bc during the join, it becomes a repeat over the room_id-user_id combo. therapist_id.y keeps each of the therapist records


#import diagnoses
diagnoses <- read.csv("1-1-2014 to 12-31-2016 Data/Diagnoses2014-16.csv") %>% select(c("user_id","condition")) 


#create indicator for each condition type (about 285 indicators create!)
diagnoses <- dcast(diagnoses,
                   user_id ~ condition,
                   value.var = "condition")

#make variable names Stata-manageable. Condition names tracked in data dictionary
x <- rep("cond",times=286)
x[1] <- "user_id"
for (val in 2:286) {
  d <- val-1
  s <- toString(d)
  x[val] <- paste(x[val],s, sep = "")
}
names(diagnoses) <- x

#merge with main
therapy14_16 <- left_join(therapy14_16,diagnoses,by="user_id")

#import outcomes
outcomes <- read.csv("1-1-2014 to 12-31-2016 Data/Outcomes2014-2016.csv")

#merge with main
therapy14_16 <- full_join(therapy14_16,outcomes,by=c("room_id"="room_id","therapist_id"="therapist_id"))

##and here it is: our 33,554 observations of unique client-therapist pairings from the 2014-2016 time period, 
  ##256,329 observations of surveys administered
  
