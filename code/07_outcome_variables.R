##########################
# This code constructs outcome variables on the matched data
# Author: Cam Guage 
# Written: 7/16/2021
##########################

##########################
# Packages and Imports
##########################
library(lubridate)
setwd("~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork")

#####################
# Loading in Data
#####################

matched_data <- readRDS("intermediate/fuzzy_matching_final.RDS")

#####################
# Cleaning the Data
#####################

matched_data <- matched_data %>%
  mutate(findings_start_date = ymd(findings_start_date)) %>%
  mutate(JOB_START_DATE = ymd_hms(JOB_START_DATE))
# will UTC thing in JOB_START_DATE present an issue?

#############################
# Creating outcome variables
#############################

# Is this how we find matches? 
temp <- matched_data %>%
  filter(!is.na(inds.a))

# Also, issues like DEL'S GRASS FARMS, LTD, SAN ANTONIO, TX, one without apostrophe, one with period after LTD., one without the LTD showing up as unique entries

# First shot at the investigations outcome
test_data_2 <- matched_data %>%
  mutate(outcome1 = ifelse((findings_start_date >= JOB_START_DATE & !is.na(inds.a)), 1, 0))








