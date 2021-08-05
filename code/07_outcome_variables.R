##########################
# This code constructs outcome variables on the matched data
# Author: Cam Guage 
# Written: 7/16/2021
##########################

##########################
# Packages and Imports
##########################
library(lubridate)
library(fastLink)

RUN_FROM_CONSOLE = FALSE
if(RUN_FROM_CONSOLE){
  args <- commandArgs(TRUE)
  DATA_DIR = args[1]
} else{
  DATA_DIR = "~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
}


setwd(DATA_DIR)

#####################
# Loading in Data
#####################
# approved_only before deduping
approved_only_pre_deduping <- readRDS("intermediate/approved_only_pre_deduping.RDS")

# investigations_filtered before deduping
investigations_filtered_pre_deduping <- readRDS("intermediate/investigations_filtered_pre_deduping.RDS")

# matched data with de-duped datasets
matched_data <- readRDS("intermediate/fuzzy_matching_final.RDS")


###################
# Re-duplication
###################

# find the indices we need to replace 
# make sure that x and y are correct
indices_to_replace_approved_only <- setdiff(approved_only_pre_deduping$merging_index, matched_data$merging_index.y)
indices_to_replace_investigations_filtered <- setdiff(investigations_filtered_pre_deduping$merging_index, matched_data$merging_index.x) 

# grab the observations with those indices
approved_only_discarded_obs <- approved_only_pre_deduping %>%
  filter(merging_index %in% indices_to_replace_approved_only)

investigations_filtered_discarded_obs <- investigations_filtered_pre_deduping %>%
  filter(merging_index %in% indices_to_replace_investigations_filtered)

# rename columns for merging
approved_only_discarded_obs <- approved_only_discarded_obs %>%
  rename(name.y = name,
         city.y = city,
         dedupe.ids.y = dedupe.ids,
         merging_index.y = merging_index)


# merge them back onto the dataset
matched_data_intermediate <- merge(matched_data, approved_only_discarded_obs, all.x = TRUE)
matched_data_final <- rbind(matched_data_intermediate, investigations_filtered_discarded_obs)

# now this is tricky, we need to replace the na's of the duplicates with the actual match


#####################
# Cleaning the Data
#####################

matched_deduped <- matched_deduped %>%
  mutate(findings_start_date = ymd(findings_start_date)) %>%
  mutate(JOB_START_DATE = ymd_hms(JOB_START_DATE))
# will UTC thing in JOB_START_DATE present an issue?

#############################
# Creating outcome variables
#############################

matched_data <- matched_data %>%
  mutate(outcome_is_any_investigation = ifelse(!is.na(id.y), FALSE, TRUE)) %>%
  mutate(outcome_is_investigation_aftersd = ifelse((!is.na(id.y) & findings_start_date >= JOB_START_DATE & findings_end_date > JOB_END_DATE), TRUE, FALSE)) %>%
  mutate(outcome_is_investigation_before_sd = ifelse((!is.na(id.y) & findings_start_date < JOB_START_DATE), TRUE, FALSE)) %>%
  mutate(outcome_is_investigation_overlapsd = ifelse((!is.na(id.y) & findings_start_date >= JOB_START_DATE & findings_start_date <= JOB_END_DATE), TRUE, FALSE))

table(matched_data$outcome_1)
table(matched_data$outcome_2)
table(matched_data$outcome_3)
table(matched_data$outcome_4)

