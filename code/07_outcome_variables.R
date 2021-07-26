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
setwd("~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork")

#####################
# Loading in Data
#####################

matched_data <- readRDS("intermediate/fuzzy_matching_final.RDS")

###################
# De-duplication
###################

dedupe_fields = c("name_city_state.y")

matches_within <- fastLink(dfA = matched_data,
                           dfB = matched_data,
                           varnames = dedupe_fields,
                           stringdist.match = dedupe_fields,
                           dedupe.matches = FALSE)

matched_deduped = getMatches(dfA = matched_data,
                     dfB = matched_data,
                     fl.out = matches_within)

saveRDS(deduped, "intermediate/fuzzy_matching_deduped.RDS")

# getting Error: vector memory exhausted (limit reached?) both in RStudio and using screen


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
  mutate(outcome_1 = ifelse(!is.na(id.y), FALSE, TRUE)) %>%
  mutate(outcome_2 = ifelse((!is.na(id.y) & findings_start_date >= JOB_START_DATE & findings_end_date > JOB_END_DATE), TRUE, FALSE)) %>%
  mutate(outcome_3 = ifelse((!is.na(id.y) & findings_start_date < JOB_START_DATE), TRUE, FALSE)) %>%
  mutate(outcome_4 = ifelse((!is.na(id.y) & findings_start_date >= JOB_START_DATE & findings_start_date <= JOB_END_DATE), TRUE, FALSE))

table(matched_data$outcome_1)
table(matched_data$outcome_2)
table(matched_data$outcome_3)
table(matched_data$outcome_4)

# Error in `$<-.data.frame`(`*tmp*`, "dedupe.ids", value = c(1, 1, 1, 1972,  : 
# replacement has 22105 rows, data has 23659
# Calls: getMatches -> $<- -> $<-.data.frame

# Error: vector memory exhausted (limit reached?)





