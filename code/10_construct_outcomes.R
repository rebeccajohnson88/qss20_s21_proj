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
library(tidyverse)

RUN_FROM_CONSOLE = FALSE
if(RUN_FROM_CONSOLE){
  args <- commandArgs(TRUE)
  DATA_DIR = args[1]
} else{
  #DATA_DIR = "~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
  #DATA_DIR = "C:/Users/Austin Paralegal/Dropbox/qss20_finalproj_rawdata/summerwork"
  DATA_DIR = "~/Dropbox/qss20_finalproj_rawdata/summerwork/"
}

setwd(DATA_DIR)

#####################
# Read output from matching jobs to WHD
#####################

# matched data with de-duped datasets
matched_data_WHD <- readRDS("intermediate/final_df.RDS")

####################
# Some descriptives
####################

matched_data_no_invesitgations <- matched_data_WHD %>%
  filter(is_matched_investigations == FALSE)

# dedupe jobs quick to check about percentage of employers with investigations
set.seed(1)

matched_data_deduped_byjob <- matched_data_WHD %>%
  group_by(jobs_group_id) %>%
  filter(DECISION_DATE == min(DECISION_DATE)) %>%
  sample_n(1) 

matched_data_deduped_byjob_invest <- matched_data_deduped_byjob %>%
  filter(is_matched_investigations == TRUE)


sprintf("Our matched data has %s rows, %s unique employers, has %s%% of rows with an investigation, and %s%% of employers with an investigation", 
        nrow(matched_data_WHD), length(unique(matched_data_WHD$jobs_group_id)), 
        (nrow(matched_data_no_invesitgations) / nrow(matched_data_WHD)) * 100,
        (nrow(matched_data_deduped_byjob_invest) / nrow(matched_data_deduped_byjob)) * 100)


#####################
# Cleaning cols relevant to outcome
#####################

matched_data_WHD <- matched_data_WHD %>%
  mutate(findings_start_date = mdy(findings_start_date),
         findings_end_date = mdy(findings_end_date),
         JOB_START_DATE = gsub(x = JOB_START_DATE, pattern = " 00:00:00", replacement = ""),
         JOB_START_DATE = ymd(JOB_START_DATE),
         JOB_END_DATE = gsub(x = JOB_END_DATE, pattern = " 00:00:00.000000", replacement = ""),
         JOB_END_DATE = ymd(JOB_END_DATE)) %>%
      rename(reg_act = `Registration Act`) 


#############################
# Creating outcome variables with WHD
#############################

matched_data_WHD <- matched_data_WHD %>%
  mutate(outcome_is_any_investigation = is_matched_investigations,
         outcome_is_investigation_aftersd = ifelse(is_matched_investigations & findings_start_date >= JOB_START_DATE, TRUE, FALSE),
         outcome_is_investigation_before_sd = ifelse(is_matched_investigations & findings_start_date < JOB_START_DATE, TRUE, FALSE),
         outcome_is_investigation_overlapsd = ifelse(is_matched_investigations & findings_start_date >= JOB_START_DATE & findings_start_date <= JOB_END_DATE, TRUE, FALSE),
         outcome_is_viol_overlapsd = ifelse(is_matched_investigations & findings_start_date >= JOB_START_DATE & findings_start_date <= JOB_END_DATE & h2a_violtn_cnt > 0, TRUE, FALSE),
         outcome_is_h2areg_investigation_overlapsd = ifelse(is_matched_investigations & findings_start_date >= JOB_START_DATE & findings_start_date <= JOB_END_DATE &
                                                          reg_act == "H2A", TRUE, FALSE))

## see that broader definition of including registration acts other than h2a only picks up 15 additional
## investigations so use normal one
#table(matched_data_WHD$outcome_is_h2areg_investigation_overlapsd, matched_data_WHD$outcome_is_investigation_overlapsd)

#####################
# Repeat for TRLA data 
#####################

##- TRLA outcomes; restricted to seven intake states
matched_data_trla <- readRDS("intermediate/trla_final_df.RDS")


sprintf("In the TRLA data, there are %s rows and %s unique employers", nrow(matched_data_trla),
        length(unique(matched_data_trla$jobs_group_id)))

## make sure that all job_group_ids in the TRLA data are in the main merge to WHD data
stopifnot(length(setdiff(unique(matched_data_trla$jobs_group_id), unique(matched_data_WHD$jobs_group_id))) == 0)

## do similar cleaning / outcomes construction 
matched_data_trla <- matched_data_trla %>%
  mutate(intake_date = ymd(derived_intakedate),
         JOB_START_DATE = gsub(x = JOB_START_DATE, pattern = " 00:00:00", replacement = ""),
         JOB_START_DATE = ymd(JOB_START_DATE),
         JOB_END_DATE = gsub(x = JOB_END_DATE, pattern = " 00:00:00.000000", replacement = ""),
         JOB_END_DATE = ymd(JOB_END_DATE)) %>%
  rename(reg_act = `Registration Act`) %>%
  mutate(outcome_is_any_investigation_trla = is_matched_investigations,
         ## in case of trla since the dates aren't a timespan but instead a 
         outcome_is_investigation_overlapsd_trla = ifelse(is_matched_investigations & intake_date >= JOB_START_DATE, TRUE, FALSE),
         outcome_is_investigation_before_sd_trla = ifelse(is_matched_investigations & intake_date < JOB_START_DATE, TRUE, FALSE))



#####################
# next merge ACS onto each
# and create two datasets:
## (1) all states (used only for WHD modeling)
## (2) trla states (used for TRLA versus WHD comparisons)
#####################


#############################
# LAter create outcome variables with TRLA
#############################

saveRDS(matched_data, "clean/jobs_formod.RDS")
write.csv(matched_data, "clean/jobs_formod.csv", row.names = FALSE) 

## save version with col classes
matched_data_colclass = data.frame(vars = colnames(matched_data),
                                   class = sapply(matched_data, function(x) class(x)))


