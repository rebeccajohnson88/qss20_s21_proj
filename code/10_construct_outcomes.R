##########################
# Packages and Imports
##########################
library(lubridate)
library(fastLink)
library(tidyverse)
library(data.table)
library(reshape2)



RUN_FROM_CONSOLE = FALSE
if(RUN_FROM_CONSOLE){
  args <- commandArgs(TRUE)
  DATA_DIR = args[1]
} else{
  DATA_DIR = "~/Dropbox/qss20_finalproj_rawdata/summerwork"
  #DATA_DIR = "C:/Users/Austin Paralegal/Dropbox/qss20_finalproj_rawdata/summerwork"
  #DATA_DIR = "/Users/euniceliu/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
}

setwd(DATA_DIR)

#####################
# Read output from matching jobs to WHD
#####################

# matched data with de-duped datasets
matched_data_WHD <- read.csv("clean/h2a_WHD_matched.csv", 
                             colClasses = c("is_matched_investigations" = "logical")) 

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
  rename(reg_act = Registration.Act) 


#############################
# Creating outcome variables with WHD
#############################

## use case-when logic so false if not true
matched_data_WHD <- matched_data_WHD %>%
  mutate(outcome_is_any_investigation = is_matched_investigations,
         outcome_is_investigation_aftersd = case_when(is_matched_investigations & findings_start_date >= JOB_START_DATE ~ TRUE, 
                                                      TRUE ~ FALSE),
         outcome_is_investigation_before_sd = case_when(is_matched_investigations & findings_start_date < JOB_START_DATE~ TRUE, 
                                                      TRUE ~ FALSE),
         outcome_is_investigation_overlapsd = case_when(is_matched_investigations & findings_start_date >= JOB_START_DATE & findings_start_date <= JOB_END_DATE ~ TRUE, 
                                                      TRUE ~ FALSE),
         outcome_is_viol_overlapsd = case_when(is_matched_investigations & findings_start_date >= JOB_START_DATE & findings_start_date <= JOB_END_DATE & h2a_violtn_cnt > 0 ~  TRUE, 
                                               TRUE ~ FALSE),
         outcome_is_h2aflsamspaviol_overlapsd = case_when(is_matched_investigations & findings_start_date >= JOB_START_DATE & findings_start_date <= JOB_END_DATE & 
                                              (h2a_violtn_cnt > 0 | flsa_violtn_cnt > 0 |
                                               mspa_violtn_cnt) ~  TRUE, 
                                               TRUE ~ FALSE))
                              

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
  mutate(outcome_is_any_investigation_trla = is_matched_investigations,
         ## in case of trla since the dates aren't a timespan but instead a sngle intake date
         outcome_is_investigation_overlapsd_trla = case_when(is_matched_investigations & intake_date >= JOB_START_DATE ~ TRUE, 
                                                             TRUE ~ FALSE),
         outcome_is_investigation_before_sd_trla = case_when(is_matched_investigations & intake_date < JOB_START_DATE ~ TRUE, 
                                                             TRUE ~ FALSE))



#####################
# next merge ACS onto each
# and create two datasets:
## (1) all states (used only for WHD modeling)
## (2) trla states (used for TRLA versus WHD comparisons)
#####################

acs_pred = fread("intermediate/job_combined_acs_premerging.csv") %>% select(-V1)

## here- fix renaming so that it's the renamed census vars and not the original ones
## (1) subset acs data
acs_subset <- acs_pred %>% select(intersect(starts_with('B') , ends_with('E')),"CASE_NUMBER", "EMPLOYER_FULLADDRESS",
                                  GEO_ID)


## (2) melt to long format
acs_subset_long <- melt(setDT(acs_subset), id.vars = c("CASE_NUMBER","EMPLOYER_FULLADDRESS",
                                                       "GEO_ID"), variable.name = "variable")

## (3) merge with codebook
codebook_tab = read.csv("intermediate/predictors_acs_varname.csv") %>%
            mutate(variable = sprintf("%sE", name))
merged_acs_codebook = merge(acs_subset_long ,
                            codebook_tab,
                            all.x = TRUE,
                            by = "variable") 


merged_acs_codebook = merged_acs_codebook %>%
                mutate(renamed_variable_name = sprintf("acs_%s_%s", gsub("Estimate!!Total!!", "", label),
                                                      gsub("\\s+|\\(|\\)", "_", concept))) 
## (4) renamed col
merged_acs_codebook_subset <- merged_acs_codebook %>%
  select(CASE_NUMBER, EMPLOYER_FULLADDRESS, value, renamed_variable_name, GEO_ID) %>%
  distinct()

## (5) reshape back to wide
merged_acs_codebook_wide <- dcast(CASE_NUMBER + EMPLOYER_FULLADDRESS + GEO_ID ~ renamed_variable_name,
                                  value.var = "value",
                                  data = merged_acs_codebook_subset,
                                  fun.aggregate = mean)

#####################
# Finish merges
#####################

## find variables to merge on; address and case number (7 with 2 that will be duplicated)
merge_vars = c("CASE_NUMBER", "EMPLOYER_FULLADDRESS")


## merge onto WHD dataset using case_number and full address
matched_data_WHD_wACS = merge(matched_data_WHD ,
                              merged_acs_codebook_wide,
                              all.x = TRUE,
                              by = c("CASE_NUMBER", "EMPLOYER_FULLADDRESS"))

## then, merge onto TRLA 
matched_data_WHD_wTRLA = merge(matched_data_WHD_wACS %>% filter(EMPLOYER_STATE %in% c("AL",
                                                                                 "AR", "KY", "LA", "MS", "TN", "TX")),
                               matched_data_trla %>% select(jobs_row_id, contains("outcome")),
                               by = "jobs_row_id",
                               all.x = TRUE) %>%
  mutate(outcome_compare_TRLA_WHD = case_when(outcome_is_investigation_overlapsd &
                                                outcome_is_investigation_overlapsd_trla ~ "Both TRLA and WHD",
                                              outcome_is_investigation_overlapsd &
                                                !outcome_is_investigation_overlapsd_trla ~ "WHD; not TRLA",
                                              !outcome_is_investigation_overlapsd &
                                                outcome_is_investigation_overlapsd_trla ~ "TRLA; not WHD",
                                              TRUE ~ "Neither WHD nor TRLA"))

## trla file 
saveRDS(matched_data_WHD_wTRLA, "clean/whd_violations_wTRLA_catchmentonly.RDS")
fwrite(matched_data_WHD_wTRLA, "clean/whd_violations_wTRLA_catchmentonly.csv")

## general file 
saveRDS(matched_data_WHD_wACS, "clean/whd_violations.RDS")
fwrite(matched_data_WHD_wACS, "clean/whd_violations.csv")

