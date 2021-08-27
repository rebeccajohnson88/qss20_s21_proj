##########################
# Packages and Imports
##########################
library(lubridate)
library(fastLink)
library(tidyverse)
library(data.table)
library(reshape2)
library('xml2')
library(RCurl)
library(rlist)
install.packages("rlist")
install.packages("RCurl")

RUN_FROM_CONSOLE = FALSE
if(RUN_FROM_CONSOLE){
  args <- commandArgs(TRUE)
  DATA_DIR = args[1]
} else{
  #DATA_DIR = "~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
  #DATA_DIR = "C:/Users/Austin Paralegal/Dropbox/qss20_finalproj_rawdata/summerwork"
  DATA_DIR = "/Users/euniceliu/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
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
  mutate(outcome_is_any_investigation_trla = is_matched_investigations,
         ## in case of trla since the dates aren't a timespan but instead a sngle intake date
         outcome_is_investigation_overlapsd_trla = ifelse(is_matched_investigations & intake_date >= JOB_START_DATE, TRUE, FALSE),
         outcome_is_investigation_before_sd_trla = ifelse(is_matched_investigations & intake_date < JOB_START_DATE, TRUE, FALSE))



#####################
# next merge ACS onto each
# and create two datasets:
## (1) all states (used only for WHD modeling)
## (2) trla states (used for TRLA versus WHD comparisons)
#####################

acs_pred = fread("intermediate/job_combined_acs_premerging.csv") %>% select(-V1)
head(acs_pred)
head(matched_data_WHD)

## here- fix renaming so that it's the renamed census vars and not the original ones
## (1) subset acs data
acs_subset <- acs_pred %>% select(intersect(starts_with('B') , ends_with('E')),"CASE_NUMBER", "EMPLOYER_FULLADDRESS" )

head(acs_subset)
## (2) melt to long format
acs_subset_long <- melt(setDT(acs_subset), id.vars = c("CASE_NUMBER","EMPLOYER_FULLADDRESS"), variable.name = "variable")

## (3) merge with codebook
url <- "https://api.census.gov/data/2014/acs/acs5/variables.html"
install.packages("rvest")
library(rvest)
codebook_tab <- url %>%  read_html() %>%  html_table()
codebook_tab <- as.data.frame(codebook_tab)
codebook_tab = codebook_tab[-(1:5), , drop = FALSE]
head(acs_subset_long)
colnames(codebook_tab)[which(names(codebook_tab) == "Name")] <- "variable"
merged_acs_codebook = merge(acs_subset_long ,
                            codebook_tab,
                            all.x = TRUE,
                            by = "variable")
## (4) renamed col
merged_acs_codebook$renamed_variable_name <- paste(merged_acs_codebook$Label, "-", merged_acs_codebook$Concept)
head(merged_acs_codebook)
merged_acs_codebook_subset <- merged_acs_codebook %>%
  select(CASE_NUMBER, EMPLOYER_FULLADDRESS, value, renamed_variable_name)

## (5) melt back to wide
#merged_acs_codebook_wide <- dcast(merged_acs_codebook_subset, CASE_NUMBER ~ renamed_variable_name)
merged_acs_codebook_wide <-reshape(merged_acs_codebook_subset, id.var = c("CASE_NUMBER","EMPLOYER_FULLADDRESS") , timevar = "renamed_variable_name", direction = "wide")


## find variables to merge on; address and case number (7 with 2 that will be duplicated)
merge_vars = c("CASE_NUMBER", "EMPLOYER_FULLADDRESS")
jobs_noacs = setdiff(matched_data_WHD$EMPLOYER_FULLADDRESS, acs_pred$EMPLOYER_FULLADDRESS)
new_acsvars = setdiff(colnames(acs_pred), colnames(matched_data_WHD))
acs_pred_tomerge = acs_pred %>% select(all_of(new_acsvars), all_of(merge_vars))

## merge onto WHD dataset using case_number and full address
matched_data_WHD_wACS = merge(matched_data_WHD ,
                              acs_pred_tomerge,
                              all.x = TRUE,
                              by = c("CASE_NUMBER", "EMPLOYER_FULLADDRESS"))

## look at ones that are duplicated and filter to 1



## Write two outputs:
## one with WHD only (matched_data_WHD_wACS)
## another with that + TRLA outcomes (merge using job_row_id) filtered to the 7 TRLA catchment states 
