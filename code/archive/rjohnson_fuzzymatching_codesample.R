


###############################
# Fuzzy matching code for project 
# SOAR
# Author: Rebecca Johnson
# Written: 02.18.2020
################################

###############################
# Packages and Imports
################################

rm(list = ls())
library(dplyr)
library(excel.link)
library(rjson)
library(xlsx)
library(data.table)
library(digest)
library(ggplot2)
library(scales)
library(kableExtra)
library(readxl)
library(crosswalkr)
library(fastLink)


###############################
# User-defined functions
################################

## function to convert dates
convert_dates_hudformat <- function(var){
  
  remove_time = gsub("\\s+.*", "", var)
  date_format = as.POSIXct(remove_time, format = "%d%b%Y")
  return(date_format)
  
}

## function to clean up names
clean_names = function(name_vector){
  
  remove_punct = gsub("[[:punct:]]+", "", name_vector)
  remove_extra_space = gsub("\\s\\s", " ", remove_punct)
  upper = toupper(remove_extra_space)
  return(upper)
}

## function to check age eligibility of residents
check_age_eligible <- function(agevar){
  
  if (is.na(agevar)){
    
    return(NA)
  }
  
  else if(agevar >= as.Date("1997-10-01") & agevar <= as.Date("2004-03-31")){
    
    return(1)
  } else{
    
    return(0)
  }
}

## function to standardize colnames b/t
## data sources
standardize_colnames <- function(data, cw_file = matchvars_crosswalk, which_data = "residents"){
  
  
  if(which_data == "residents"){
    
    cleaned_data = renamefrom(data, cw_file = cw_file, raw = res_varname, 
                              clean = clean, label = label, drop_extra = FALSE) %>%
      mutate(index = 1:nrow(data))
    return(cleaned_data)
    
  } else{
    
    cleaned_data = renamefrom(data, cw_file = cw_file, 
                              raw = tracker_varname, 
                              clean = clean, label = label, drop_extra = FALSE) %>%
      mutate(index = 1:nrow(data),
             age_eligible = unlist(lapply(dob, check_age_eligible)))
    
    return(cleaned_data)
    
  }
}

## function to generate matches using fast link
## and to save a copy/return
generate_save_matches <- function(res_data, participant_data, 
                                  pha_code,
                                  string_threshold = 0.9){
  
  matches.out = fastLink(dfA = res_data,
                         dfB = participant_data,
                         varnames = c("firstname", "lastname", "dob"),
                         stringdist.match = c("firstname", "lastname", "dob"),
                         partial.match = c("firstname", "lastname", "dob"),
                         verbose = TRUE, 
                         cut.a = string_threshold) # default is 0.94 in the package; 
  # set slightly lower to 0.9
  
  saveRDS(matches.out, sprintf("../../Intermediate_objects/%s_matchresults.RDS", pha_code))
  return(matches.out)
  
}

## function to merge matched object with other
## attributes
merge_matches <- function(res_data,
                          participant_data,
                          match_object){
  
  participants_withresinfo = merge(participant_data,
                                   match_object$matches,
                                   by.x = "index",
                                   by.y = "inds.b",
                                   all.x = TRUE) %>%
    left_join(res_data %>%
                rename(pic_first = firstname, 
                       pic_last = lastname,
                       pic_dob = dob),
              by = c("inds.a" = "index")) %>%
    mutate(matched = ifelse(!is.na(inds.a), 1, 0),
           identical_first = ifelse(firstname == pic_first &
                                      !is.na(pic_first), 1, 0),
           identical_last = ifelse(lastname == pic_last &
                                     !is.na(pic_last), 1, 0),
           identical_dob = ifelse(dob == pic_dob &
                                    !is.na(pic_dob), 1, 0),
           match_exactdob = ifelse(matched == 1 & 
                                     identical_dob == 1, 1, 0),
           match_exactname = ifelse(matched == 1 & 
                                      identical_first == 1 &
                                      identical_last == 1, 1, 0),
           match_exactdob_orname = ifelse(match_exactdob == 1 | 
                                            match_exactname == 1, 1, 0))
  
  return(participants_withresinfo)
  
}

## function to summarize match statistics
summarize_matches <- function(merged_match_df, cleaned_participants, 
                              cleaned_residents, pha_code,
                              return_match = FALSE){
  
  ## first, summarize general matching
  participants_notmatched = cleaned_participants %>% filter(!index %in% matches.out$matches$inds.b & 
                                                              age_eligible == 1) 
  participants_matched = cleaned_participants %>% filter(index %in% matches.out$matches$inds.b &
                                                           age_eligible == 1)
  residents_notmatched = cleaned_residents %>% filter(!index %in% matches.out$matches$inds.a)
  ## look at participants not matched
  print(sprintf("For pha %s, before restricting to matches where dob exactly matched, out of %s age-eligible participants in navigator tracker, %s, or %s percent, were matched to residents in PIC",
                pha_code,
                length(unique(cleaned_participants$Case_ID[cleaned_participants$age_eligible == 1])),
                length(unique(participants_matched$Case_ID)),
                round((length(unique(participants_matched$Case_ID))/length(unique(cleaned_participants$Case_ID[cleaned_participants$age_eligible == 1])))*100), 2))
  participants_matchedexact = merged_match_df %>%
    filter(match_exactdob_orname == 1)
  #for dx: return(participants_matchedexact)
  participants_notmatchedexact = merged_match_df %>%
    filter(match_exactdob_orname == 0) 
  residents_notmatchedexact = cleaned_residents %>% filter(!index %in% 
                                                             participants_matchedexact$inds.a)
  
  residents_matchedexact = cleaned_residents %>% filter(index %in%
                                                          participants_matchedexact$inds.a)
  ## write non-matched
  write.csv(participants_notmatchedexact, 
            sprintf("../../Intermediate_objects/%s_nonmatched_navparticipants.csv",
                    pha_code),
            row.names = FALSE)
  write.csv(residents_notmatchedexact, 
            sprintf("../../Intermediate_objects/%s_nonmatched_residents.csv",
                    pha_code),
            row.names = FALSE)
  print(sprintf("After restricting to matches where dob or first/last name exactly matched, out of %s age-eligible participants in navigator tracker, %s, or %s percent, were matched to residents",
                length(unique(merged_match_df$Case_ID[merged_match_df$age_eligible == 1])),
                length(unique(participants_matchedexact$Case_ID)),
                round((length(unique(participants_matchedexact$Case_ID))/length(unique(cleaned_participants$Case_ID[cleaned_participants$age_eligible == 1])))*100), 2))
  
  if(return_match == TRUE){
    
    return(list(participants = participants_matchedexact,
                residents = residents_matchedexact))
    
  } else{
    
    return("Done dx")
    
  }
  
  
}



###############################
# Load residents data
################################

activity_folder = "G:/Shared drives/OES data 1732/Activity tracker/"
#passcodes = read.csv(sprintf("%ssoar_passwords.csv", activity_folder))
res_data = read.csv("G:/Shared drives/OES data 1732/Intermediate_objects/expfile_withclusters.csv")
## make sure dob is encoded as date
res_data = res_data %>%
  mutate(mbr_dob_dateformat = convert_dates_hudformat(mbr_dob),
         mbr_dob_string = as.character(mbr_dob_dateformat),
         mbr_first_name_clean = clean_names(mbr_first_name),
         mbr_last_name_clean = clean_names(mbr_last_name))
## create crosswalk to use for varsnames
## standardize names
matchvars_crosswalk = data.frame(clean = c("firstname", "lastname", "dob"),
                                 label = c("Member first name", "Member last name",
                                           "Member dob"),
                                 tracker_varname = c("tracker_fname_clean", 
                                                     "tracker_lname_clean",
                                                     "dob_string"),
                                 res_varname = c("mbr_first_name_clean", 
                                                 "mbr_last_name_clean",
                                                 "mbr_dob_string")) 



###############################
# Apply matching to Chicago PHA
################################

## try reading in passwords file
chi_pwd = passcodes$Final[passcodes$community == "CHA"]
chi_path = sprintf("%sCHA/decrypt/",
                   activity_folder)
## participants
cha_participants = read_excel(sprintf("%scha_participant_tracker.xlsx",
                                      chi_path),
                              col_types = c(rep("guess", 3),
                                            "date",
                                            rep("guess",
                                                14)))
## remove spaces from cols
colnames(cha_participants) = gsub("\\s+", "_", colnames(cha_participants))
cha_participants = cha_participants %>%
  mutate(dob_string = as.character(Date_of_Birth))
## interactions
cha_interactions = read_excel(sprintf("%scha_interaction_tracker.xlsx",
                                      chi_path)) %>%
  mutate(full_name = sprintf("%s_%s", FNAME, LNAMe))


## 1.2 Compare N to resident file

sprintf("In the chi participants file, there are %s unique members; there were %s residents in treatment group in residents file HUD provided",
        length(unique(cha_participants$Case_ID)),
        nrow(res_data %>% filter(participant_code == "IL002") %>%
               filter(treatment == 1)))
sprintf("In the chi interactions file, there are %s unique names; there were %s residents in treatment group",
        length(unique(cha_interactions$full_name)),
        nrow(res_data %>% filter(participant_code == "IL002") %>%
               filter(treatment == 1)))




## 1.5 Fuzzy matching to resident file


pha_code = "IL002"
gen_new_matches = FALSE #for MD-- if you want to play with matching alg, change this to true, otherwise reads in existing matching object
res_pha = res_data %>%
  filter(participant_code == pha_code) %>%
  dplyr::select(mbr_id, mbr_first_name_clean, 
                mbr_last_name_clean, 
                mbr_dob_string,
                treatment, 
                participant_code)
cleaned_residents = standardize_colnames(data = res_pha)
write.csv(cleaned_residents, 
          sprintf("../../Intermediate_objects/%s_allresidents.csv",
                  pha_code),
          row.names = FALSE)
cha_participants_tomatch = cha_participants %>%
  mutate(tracker_fname_clean = clean_names(Participant_First_Name),
         tracker_lname_clean = clean_names(Participant_Last_Name)) %>%
  dplyr::select(contains("tracker"), dob_string, Case_ID)
cleaned_participants = standardize_colnames(data = cha_participants_tomatch,
                                            which_data = "participants")
if(gen_new_matches == FALSE){
  
  matches.out = readRDS(sprintf("../../Intermediate_objects/%s_matchresults.RDS",
                                pha_code))
  
} else{
  matches.out = generate_save_matches(res_data = cleaned_residents, 
                                      participant_data = cleaned_participants,
                                      pha_code = pha_code)
  
}
##  merge onto main data
participants_withresinfo = merge_matches(res_data = cleaned_residents,
                                         participant_data = cleaned_participants,
                                         match_object = matches.out)
matchexact_list = summarize_matches(merged_match_df = participants_withresinfo,
                                    cleaned_participants = cleaned_participants,
                                    cleaned_residents = cleaned_residents, 
                                    pha_code = pha_code,
                                    return_match = TRUE)
if(nrow(matchexact_list$participants) == length(unique(matchexact_list$participants$inds.a))){
  
  print("One to one matching: no need to deduplicate")
  write.csv(matchexact_list$participants, 
            sprintf("../../Intermediate_objects/%s_matched_navparticipants.csv",
                    pha_code),
            row.names = FALSE)
  
  write.csv(matchexact_list$residents, 
            sprintf("../../Intermediate_objects/%s_matched_residents.csv",
                    pha_code),
            row.names = FALSE)
  
} else{
  
  print("One PIC resident matched to multiple participants; deduplicate")
}


###############################
# Apply matching to LA PHA
################################

pha_code = "CA004"
gen_new_matches = FALSE
hacla_path = sprintf("%sHACLA/decrypt/",
                     activity_folder)
hacla_participants = read_excel(sprintf("%shacla_participant_tracker.xlsx",
                                        hacla_path),
                                col_types = c(rep("guess", 3),
                                              "date",
                                              rep("guess",
                                                  16)))
colnames(hacla_participants) = gsub("\\s+", "_", colnames(hacla_participants))
sprintf("In the LA participants file, there are %s unique members; there were %s residents in treatment group in residents file HUD provided",
        length(unique(hacla_participants$Case_ID)),
        nrow(res_data %>% filter(participant_code == "CA004") %>%
               filter(treatment == 1)))
res_pha = res_data %>%
  filter(participant_code == pha_code) %>%
  dplyr::select(mbr_id, mbr_first_name_clean, 
                mbr_last_name_clean, 
                mbr_dob_string,
                treatment, 
                participant_code)
cleaned_residents = standardize_colnames(data = res_pha)
write.csv(cleaned_residents, 
          sprintf("../../Intermediate_objects/%s_allresidents.csv",
                  pha_code),
          row.names = FALSE)
hacla_participants_tomatch = hacla_participants %>%
  mutate(tracker_fname_clean = clean_names(First_Name),
         tracker_lname_clean = clean_names(Last_Name),
         dob_string = as.character(Birthdate)) %>%
  dplyr::select(contains("tracker"), dob_string, Case_ID)
cleaned_participants = standardize_colnames(data = hacla_participants_tomatch,
                                            which_data = "participants")
if(gen_new_matches == FALSE){
  
  matches.out = readRDS(sprintf("../../Intermediate_objects/%s_matchresults.RDS",
                                pha_code))
  
} else{
  matches.out = generate_save_matches(res_data = cleaned_residents, 
                                      participant_data = cleaned_participants,
                                      pha_code = pha_code)
  
}
##  merge onto main data
participants_withresinfo = merge_matches(res_data = cleaned_residents,
                                         participant_data = cleaned_participants,
                                         match_object = matches.out)
participants_matchexact = summarize_matches(merged_match_df = participants_withresinfo,
                                            cleaned_participants = cleaned_participants,
                                            cleaned_residents = cleaned_residents, 
                                            pha_code = pha_code,
                                            return_match = TRUE)
matchexact_list = summarize_matches(merged_match_df = participants_withresinfo,
                                    cleaned_participants = cleaned_participants,
                                    cleaned_residents = cleaned_residents, 
                                    pha_code = pha_code,
                                    return_match = TRUE)
if(nrow(matchexact_list$participants) == length(unique(matchexact_list$participants$inds.a))){
  
  print("One to one matching: no need to deduplicate")
  write.csv(matchexact_list$participants, 
            sprintf("../../Intermediate_objects/%s_matched_navparticipants.csv",
                    pha_code),
            row.names = FALSE)
  
  write.csv(matchexact_list$residents, 
            sprintf("../../Intermediate_objects/%s_matched_residents.csv",
                    pha_code),
            row.names = FALSE)
  
} else{
  
  print("One PIC resident matched to multiple participants; deduplicate")
}
