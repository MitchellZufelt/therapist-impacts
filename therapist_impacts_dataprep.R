########################################################>
# TITLE: therapist_impacts_dataprep.R
# DESCRIPTION: clean and prepare TalkSpace data for analysis in "Measuring the Impacts of Therapists: Evidence from a Value-Added Approach"
# AUTHOR: Mitch Zufelt
# CREATED: 09/19/2022
# 
# INPUTS:
#   - 1-1-2014 to 12-31-2016 Data: a folder containing the following 6 files
#       - GenDemogs2014-16.csv
#       - Diagnoses2014-16.csv
#       - LiveVideo2014-16.csv
#       - MediaMessgCounts2014-16.csv
#       - MessageCounts2014-16.csv
#       - Outcomes2014-2016.csv
# 
#   - 1-1-2017 to 12-2-2019 Data: a folder containing the following 6 files
#       - GenDemogs2017-19.csv
#       - Diagnoses2017-19.csv
#       - LiveVideo2017-19.csv
#       - MediaMessgCounts2017-19.csv
#       - MessageCounts2017-19.csv
#       - Outcomes2017-2019.csv
#
#   (...)
# 
########################################################>

#####Initialize#####
#Libraries
library(tidyverse)
library(data.table)
library(readxl)

#directories
setwd("C:/Users/mitch/OneDrive/Desktop")


#####2014-2016 data#####

#import demographics to create main file
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
message_counts <- read.csv("1-1-2014 to 12-31-2016 Data/MessageCounts2014-16.csv")

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


# #import diagnoses
# diagnoses <- read.csv("1-1-2014 to 12-31-2016 Data/Diagnoses2014-16.csv") %>% select(c("user_id","condition")) 
# 
# 
# #create indicator for each condition type (about 285 indicators create!)
# diagnoses <- dcast(diagnoses,
#                    user_id ~ condition,
#                    value.var = "condition")
# 
# 
# #merge with main
# therapy14_16 <- left_join(therapy14_16,diagnoses,by="user_id")

#import outcomes
outcomes <- read.csv("1-1-2014 to 12-31-2016 Data/Outcomes2014-2016.csv")

#merge with main
therapy14_16 <- full_join(therapy14_16,outcomes,by=c("room_id"="room_id","therapist_id"="therapist_id"))

##and here it is: our 33,554 observations of unique client-therapist pairings from the 2014-2016 time period, 
  ##256,329 observations of surveys administered
  

#####2017-2019 data#####

#import demographics to create main file
therapy17_19 <- read.csv("1-1-2017 to 12-2-2019 Data/GenDemogs2017-19.csv") %>% select(-starts_with("status"),
                                                                                        -starts_with("partner"),
                                                                                        -starts_with("voucher"),-with_video,
                                                                                        -claim_date,-starts_with("employer"),
                                                                                        -Total_Covered_Lives, -US_Covered_Lives,
                                                                                        -Go_Live_Date,-payment_type,-plan_type_id,
                                                                                        -date_of_birth,-year_of_birth,
                                                                                        -primary_condition)

#remove duplicated elements
therapy17_19 <- therapy17_19[!duplicated(therapy17_19),]

#remove "couples therapy" subscribers; beyond the scope of this analysis
therapy17_19 <- therapy17_19[grepl("Couples",therapy17_19$plan_name)==F,]

#import live video counts
live_video <- read.csv("1-1-2017 to 12-2-2019 Data/LiveVideo2017-19.csv")

#merge with main
therapy17_19 <- left_join(therapy17_19,live_video,by="room_id")

#import audio message counts
audio_message <- read.csv("1-1-2017 to 12-2-2019 Data/MediaMessages2017-19.csv") %>% filter(media_type=="audio") %>%
  select(-"media_type",-"media_message_count") %>%
  group_by(room_id,user_id) %>%
  mutate(audio_duration_total = sum(total_duration_secs)) %>%
  select(-"total_duration_secs")
audio_message <- audio_message[!duplicated(audio_message),]

#merge with main
therapy17_19 <- left_join(therapy17_19,audio_message, by=c("room_id"="room_id","user_id"="user_id"))

#import video message counts
video_message <- read.csv("1-1-2017 to 12-2-2019 Data/MediaMessages2017-19.csv") %>% filter(media_type=="video") %>%
  select(-"media_type",-"media_message_count") %>%
  group_by(room_id,user_id) %>%
  mutate(video_duration_total = sum(total_duration_secs)) %>%
  select(-"total_duration_secs")
video_message <- video_message[!duplicated(video_message),]

#merge with main
therapy17_19 <- left_join(therapy17_19,video_message, by=c("room_id"="room_id","user_id"="user_id"))

#import photo message counts
photo_message <- read.csv("1-1-2017 to 12-2-2019 Data/MediaMessages2017-19.csv") %>% filter(media_type=="photo") %>%
  select(-"media_type",-"total_duration_secs") %>%
  group_by(room_id,user_id) %>%
  mutate(photo_count_total = sum(media_message_count)) %>%
  select(-"media_message_count")
photo_message <- photo_message[!duplicated(photo_message),]

#merge with main
therapy17_19 <- left_join(therapy17_19,photo_message, by=c("room_id"="room_id","user_id"="user_id"))

#import text message counts
message_counts <- read.csv("1-1-2017 to 12-2-2019 Data/MessageCounts2017-19.csv")

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
therapy17_19 <- full_join(therapy17_19,message_counts,by=c("room_id"="room_id","user_id"="user_id"))
therapy17_19$therapist_id.y <- ifelse(is.na(therapy17_19$therapist_id.y),
                                      therapy17_19$therapist_id.x,
                                      therapy17_19$therapist_id.y) # remove NA's from outer join so each record has a therapist_id
therapy17_19 <- therapy17_19 %>% select(-"therapist_id.x") %>%
  rename(
    therapist_id = therapist_id.y
  ) %>%
  arrange(room_id, user_id, therapist_id) #we can remove therapist_id.x bc during the join, it becomes a repeat over the room_id-user_id combo. therapist_id.y keeps each of the therapist records


# #import diagnoses
# diagnoses <- read.csv("1-1-2017 to 12-2-2019 Data/Diagnoses2017-19.csv") %>% select(c("user_id","condition")) 
# 
# 
# #create indicator for each condition type (about 285 indicators create!)
# diagnoses <- dcast(diagnoses,
#                    user_id ~ condition,
#                    value.var = "condition")
# 
# 
# #merge with main
# therapy17_19 <- left_join(therapy17_19,diagnoses,by="user_id")

#import outcomes
outcomes <- read.csv("1-1-2017 to 12-2-2019 Data/Outcomes2017-19.csv")

#merge with main
therapy17_19 <- full_join(therapy17_19,outcomes,by=c("room_id"="room_id","therapist_id"="therapist_id"))

##801,249 observations of surveys administered


#####2020-2021 data#####

#import demographics to create main file
therapy20_21 <- read.csv("Jan2020 - Apr2021/Demogs Jan2020-Apr2021.csv") %>% select(-starts_with("status"),
                                                                                       -starts_with("partner"),
                                                                                       -starts_with("voucher"),-with_video,
                                                                                       -claim_date,-starts_with("Employer"),
                                                                                       -Go_Live_Date,-payment_type,-plan_type_id,
                                                                                       -year_of_birth,
                                                                                       -ends_with("_payfirst"))

#remove duplicated elements
therapy20_21 <- therapy20_21[!duplicated(therapy20_21),]

#No couples specified in this dataset.

#import live video counts
live_video <- read.csv("Jan2020 - Apr2021/LiveVideo Jan2020-Apr2021.csv")

#merge with main
therapy20_21 <- left_join(therapy20_21,live_video,by="room_id")

#import audio message counts
audio_message <- read.csv("Jan2020 - Apr2021/MediaMessages Jan2020-Apr2021.csv")%>% filter(media_type=="audio") %>%
  select(-"media_type",-"media_message_count",-"is_uploaded") %>%
  group_by(room_id,user_id) %>%
  mutate(audio_duration_total = sum(total_duration)) %>%
  select(-"total_duration")
audio_message <- audio_message[!duplicated(audio_message),]

#merge with main
therapy20_21 <- left_join(therapy20_21,audio_message, by=c("room_id"="room_id","user_id"="user_id"))

#import video message counts
video_message <- read.csv("Jan2020 - Apr2021/MediaMessages Jan2020-Apr2021.csv") %>% filter(media_type=="video") %>%
  select(-"media_type",-"media_message_count",-"is_uploaded") %>%
  group_by(room_id,user_id) %>%
  mutate(video_duration_total = sum(total_duration)) %>%
  select(-"total_duration")
video_message <- video_message[!duplicated(video_message),]

#merge with main
therapy20_21 <- left_join(therapy20_21,video_message, by=c("room_id"="room_id","user_id"="user_id"))

#import photo message counts
photo_message <- read.csv("Jan2020 - Apr2021/MediaMessages Jan2020-Apr2021.csv") %>% filter(media_type=="photo") %>%
  select(-"media_type",-"total_duration",-"is_uploaded") %>%
  group_by(room_id,user_id) %>%
  mutate(photo_count_total = sum(media_message_count)) %>%
  select(-"media_message_count")
photo_message <- photo_message[!duplicated(photo_message),]

#merge with main
therapy20_21 <- left_join(therapy20_21,photo_message, by=c("room_id"="room_id","user_id"="user_id"))

#import text message counts
message_counts <- read.csv("Jan2020 - Apr2021/WordCounts Jan2020-Apr2021.csv")

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
therapy20_21 <- full_join(therapy20_21,message_counts,by=c("room_id"="room_id","user_id"="user_id"))
therapy20_21$therapist_id.y <- ifelse(is.na(therapy20_21$therapist_id.y),
                                      therapy20_21$therapist_id.x,
                                      therapy20_21$therapist_id.y) # remove NA's from outer join so each record has a therapist_id
therapy20_21 <- therapy20_21 %>% select(-"therapist_id.x") %>%
  rename(
    therapist_id = therapist_id.y
  ) %>%
  arrange(room_id, user_id, therapist_id) #we can remove therapist_id.x bc during the join, it becomes a repeat over the room_id-user_id combo. therapist_id.y keeps each of the therapist records

# #import diagnoses
# diagnoses <- read.csv("Jan2020 - Apr2021/Diagnoses Jan2020-Apr2021.csv") %>% select(c("user_id","condition")) 
# 
# 
# #create indicator for each condition type 
# diagnoses <- dcast(diagnoses,
#                    user_id ~ condition,
#                    value.var = "condition")
# 
# 
# #merge with main
# therapy20_21 <- left_join(therapy20_21,diagnoses,by="user_id")

#import outcomes
outcomes <- read.csv("Jan2020 - Apr2021/Outcomes Jan2020-Apr2021.csv")

#merge with main
therapy20_21 <- full_join(therapy20_21,outcomes,by=c("room_id"="room_id","therapist_id"="therapist_id"))

##1,732,127 observations of surveys administered in 159,498 rooms


#####Dec 2019 - midJune 2020 Data####

therapy19_20<- read.csv("Dec2019 to midJune202/Demogs Dec2019-midJune 2020.csv") %>% select("room_id","user_id","therapist_id",
                                                                                              "plan_name","room_created_date",
                                                                                              "conversion_date","gender_customer",
                                                                                              "education_level","ethnicity",
                                                                                              "marital_status","country","state",
                                                                                              "age_customer",
                                                                                              starts_with("first_"))

#remove duplicated elements
therapy19_20 <- therapy19_20[!duplicated(therapy19_20),]

#remove "couples therapy" subscribers; beyond the scope of this analysis
therapy19_20 <- therapy19_20[grepl("Couples",therapy19_20$plan_name)==F,]

#import live video counts
live_video <- read.csv("Dec2019 to midJune202/LiveVideo Dec2019-midJune2020.csv")

#merge with main
therapy19_20 <- left_join(therapy19_20,live_video,by="room_id")

#import audio message counts
audio_message <- read.csv("Dec2019 to midJune202/MediaMessages Dec2019-midJune2020.csv") %>% filter(media_type=="audio") %>%
  select(-"media_type",-"media_message_count",-"is_uploaded") %>%
  group_by(room_id,user_id) %>%
  mutate(audio_duration_total = sum(total_duration)) %>%
  select(-"total_duration")
audio_message <- audio_message[!duplicated(audio_message),]

#merge with main
therapy19_20 <- left_join(therapy19_20,audio_message, by=c("room_id"="room_id","user_id"="user_id"))

#import video message counts
video_message <- read.csv("Dec2019 to midJune202/MediaMessages Dec2019-midJune2020.csv") %>% filter(media_type=="video") %>%
  select(-"media_type",-"media_message_count",-"is_uploaded") %>%
  group_by(room_id,user_id) %>%
  mutate(video_duration_total = sum(total_duration)) %>%
  select(-"total_duration")
video_message <- video_message[!duplicated(video_message),]

#merge with main
therapy19_20 <- left_join(therapy19_20,video_message, by=c("room_id"="room_id","user_id"="user_id"))

#import photo message counts
photo_message <- read.csv("Dec2019 to midJune202/MediaMessages Dec2019-midJune2020.csv") %>% filter(media_type=="photo") %>%
  select(-"media_type",-"total_duration",-"is_uploaded") %>%
  group_by(room_id,user_id) %>%
  mutate(photo_count_total = sum(media_message_count)) %>%
  select(-"media_message_count")
photo_message <- photo_message[!duplicated(photo_message),]

#merge with main
therapy19_20 <- left_join(therapy19_20,photo_message, by=c("room_id"="room_id","user_id"="user_id"))

#import text message counts
message_counts <- read.csv("Dec2019 to midJune202/WordCounts Dec2019-midJune2020.csv")

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
therapy19_20 <- full_join(therapy19_20,message_counts,by=c("room_id"="room_id","user_id"="user_id"))
therapy19_20$therapist_id.y <- ifelse(is.na(therapy19_20$therapist_id.y),
                                      therapy19_20$therapist_id.x,
                                      therapy19_20$therapist_id.y) # remove NA's from outer join so each record has a therapist_id
therapy19_20 <- therapy19_20 %>% select(-"therapist_id.x") %>%
  rename(
    therapist_id = therapist_id.y
  ) %>%
  arrange(room_id, user_id, therapist_id) #we can remove therapist_id.x bc during the join, it becomes a repeat over the room_id-user_id combo. therapist_id.y keeps each of the therapist records


# #import diagnoses
# diagnoses <- read.csv("Dec2019 to midJune202/Diagnoses Dec2019-midJune2020.csv") %>% select(c("user_id","condition")) 
# 
# 
# #create indicator for each condition type (about 285 indicators create!)
# diagnoses <- dcast(diagnoses,
#                    user_id ~ condition,
#                    value.var = "condition")
# 
# 
# #merge with main
# therapy19_20 <- left_join(therapy19_20,diagnoses,by="user_id")

#import outcomes
outcomes <- read.csv("Dec2019 to midJune202/Outcomes Dec2019-midJune2020.csv")

#merge with main
therapy19_20 <- full_join(therapy19_20,outcomes,by=c("room_id"="room_id","therapist_id"="therapist_id"))

##584,606 survey observations in 62,431 rooms






#######


#we have 6 separate files, keep em sep for now and look at em closer next week.Check that they're good then you can combine together. 
#revisit 2019-2020 data to see if we're missing anything important from there #ALSO, need to think about how to address roll-over in treatment between datasets (eg, from 2016-2017)

#####Combine into one file####
rm(audio_message,clients,diagnoses,live_video,message_counts,mult_client,outcomes,photo_message,therapists,video_message)
memory.limit(size = 1000000000)
therapy <- rbind.fill(therapy14_16,therapy17_19,therapy20_21) #2,856,917



#import diagnoses
d1 <- read.csv("1-1-2014 to 12-31-2016 Data/Diagnoses2014-16.csv") %>% select(c("user_id","condition")) 
d2 <- read.csv("1-1-2017 to 12-2-2019 Data/Diagnoses2017-19.csv") %>% select(c("user_id","condition")) 
d3 <- read.csv("Dec2019 to midJune202/Diagnoses Dec2019-midJune2020.csv") %>% select(c("user_id","condition")) 
d4 <- read.csv("Jan2020 - Apr2021/Diagnoses Jan2020-Apr2021.csv") %>% select(c("user_id","condition")) 

d <- rbind(d1,d2,d3,d4)
d <- d[!duplicated(d),]

#create indicator for each condition type
diagnoses <- dcast(d,
                   user_id ~ condition,
                   value.var = "condition")

#clean up NA's and unneeded files
for (i in 2:ncol(diagnoses)) {
  diagnoses[,i] <- ifelse(is.na(diagnoses[,i]),0,diagnoses[,i])
}

rm(d1,d2,d3,d4,d)

#make diagnosis variable names Stata-manageable. Condition names tracked in data dictionary
x <- rep("cond",times=(ncol(diagnoses)))
x[1] <- "user_id"
for (val in 2:ncol(diagnoses)) {
  d <- val-1
  s <- toString(d)
  x[val] <- paste(x[val],s, sep = "")
}
names(diagnoses) <- x

#diagnoses dataset contains 261410 unique-to-client records and is ready for merge


#import therapist demographics
therapist_demographics <- read_excel("therapist_demographics.xlsx") %>% select(-c("...1"))

#convert format on indicator variables
for (i in 10:18) {
  therapist_demographics[,i] <- ifelse(therapist_demographics[,i]=="TRUE",1,0)
}

#parse expertise variable (NLP-ish?)

#therapist_demographics contains __ unique-to-therapist records and is (almost) ready to merge
