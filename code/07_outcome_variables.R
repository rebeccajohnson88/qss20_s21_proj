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
# matched data with de-duped datasets
matched_data <- readRDS("intermediate/final_df.RDS")

####################
# Some descriptives
####################
matched_data_no_invesitgations <- matched_data %>%
  filter(is_matched_investigations == FALSE)

# dedupe jobs quick to check about percentage of employers with investigations
set.seed(1)

matched_data_deduped_byjob <- matched_data %>%
  group_by(jobs_group_id) %>%
  filter(DECISION_DATE == min(DECISION_DATE)) %>%
  sample_n(1) 

matched_data_deduped_byjob_invest <- matched_data_deduped_byjob %>%
  filter(is_matched_investigations == TRUE)

nrow(matched_data_deduped_byjob_invest)


sprintf("Our matched data has %s rows, %s unique employers, has %s%% of rows with an investigation, and %s%% of employers with an investigation", 
        nrow(matched_data), length(unique(matched_data$jobs_group_id)), 
        (nrow(matched_data_no_invesitgations) / nrow(matched_data)) * 100,
        (nrow(matched_data_deduped_byjob_invest) / nrow(matched_data_deduped_byjob)) * 100)


#####################
# Cleaning the Data
#####################

matched_data <- matched_data %>%
  mutate(findings_start_date = mdy(findings_start_date)) %>%
  mutate(findings_end_date = mdy(findings_end_date)) %>%
  mutate(JOB_START_DATE = ymd_hms(JOB_START_DATE)) %>% 
  mutate(JOB_END_DATE = ymd_hms(JOB_END_DATE))

# Getting the following messages: 1: Problem with `mutate()` input `JOB_END_DATE`.ℹ  17415 failed to parse. ℹ Input `JOB_END_DATE` is `ymd_hms(JOB_END_DATE)`. 2:  17415 failed to parse. 

#############################
# Creating outcome variables
#############################

matched_data <- matched_data %>%
  mutate(outcome_is_any_investigation = is_matched_investigations) %>%
  mutate(outcome_is_investigation_aftersd = ifelse(is_matched_investigations & findings_start_date >= JOB_START_DATE, TRUE, FALSE)) %>%
  mutate(outcome_is_investigation_before_sd = ifelse(is_matched_investigations & findings_start_date < JOB_START_DATE, TRUE, FALSE)) %>%
  mutate(outcome_is_investigation_overlapsd = ifelse(is_matched_investigations & findings_start_date >= JOB_START_DATE & findings_start_date <= JOB_END_DATE, TRUE, FALSE))

table(matched_data$outcome_is_any_investigation)
table(matched_data$outcome_is_investigation_aftersd)
table(matched_data$outcome_is_investigation_before_sd)
table(matched_data$outcome_is_investigation_overlapsd)
