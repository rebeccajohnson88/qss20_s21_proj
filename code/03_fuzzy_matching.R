##########################
# This code fuzzy matches between H2A applications data and the WHD investigations data
# Author: Cam Guage 
# Written: 08/02/2021
##########################

##########################
# Packages and Imports
##########################

library(dplyr)
library(stringr)
library(fastLink)
library(readr)
library(data.table)
library(splitstackshape)

RUN_FROM_CONSOLE = FALSE
if(RUN_FROM_CONSOLE){
  args <- commandArgs(TRUE)
  DATA_DIR = args[1]
} else{
  DATA_DIR = "~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
}


setwd(DATA_DIR)

########################
# User-defined functions 
########################

## function to pull out certification status from a given h2a application
find_status <- function(one){
  
  string_version <- toString(toupper(one)) # convert to string
  pattern <- "\\-\\s(.*)$"
  found <- str_extract(string_version, pattern)
  return(found)
  
}

# function to clean the EMPLOYER_NAME in approved_only (h2a apps) and legal_name in violations (WHD data)
clean_names <- function(one){
  
  string_version = toString(one) # convert to string
  upper_only <- toupper(string_version) # convert to uppercase
  pattern <- "(LLC|CO|INC)\\." # locate the LLC, CO, or INC that are followed by a period
  replacement <- '\1' # replace the whole pattern with the LLC/CO/INC component
  res <- str_replace_all(upper_only, pattern, replacement)
  return(res)
  
}

#####################
# Fuzzy Matching Functions
#####################

## function to generate matches using fastlink
generate_save_matches <- function(dbase1, dbase2, matchVars, string_threshold){
  
  matches.out <- fastLink(dfA = dbase1,
                          dfB = dbase2,
                          varnames = matchVars,
                          stringdist.match = matchVars,
                          partial.match = matchVars,
                          verbose = TRUE,
                          cut.a = string_threshold)
  return(matches.out)
  
}

## function to merged matched objects with each other
merge_matches <- function(dbase1, dbase2, match_object){
  
  merged_data = merge(dbase2, 
                      match_object$matches,
                      by.x = "index",
                      by.y = "inds.b",
                      all.x = TRUE) %>%
    left_join(dbase1, by = c("inds.a" = "index"))
  
  return(merged_data)
}

#####################
# Loading in Data
#####################

# load in h2a data
h2a <- read.csv("intermediate/h2a_combined_2014-2021.csv")

# load in investigations/violations data
investigations <- fread("raw/enforcement_registration20210720.csv")


################
# Cleaning the Data
################

# use the find status function and put into a new column
status = unlist(lapply(h2a$CASE_STATUS, find_status))
h2a$status_cleaned = status

# filter to applications that have received certification or partial certification
approved_only <- h2a %>%
  filter(status_cleaned == "- CERTIFICATION" | status_cleaned == "- PARTIAL CERTIFICATION") %>%
  filter(EMPLOYER_NAME != "")

sprintf("After filtering to approved only and non-missing names, we go from %s rows to %s rows",
        nrow(h2a),
        nrow(approved_only))


# filtering to just h2a violations
investigations_filtered <- investigations %>%
  filter(`Registration Act` == "H2A" | h2a_violtn_cnt > 0)

sprintf("After filtering to H2A investigations only, we go from %s rows to %s rows",
        nrow(investigations),
        nrow(investigations_filtered))


# make new "name" columns for the cleaned versions of the names
emp_name_app = unlist(lapply(approved_only$EMPLOYER_NAME, clean_names))
approved_only$name <- emp_name_app  

emp_name_i =  unlist(lapply(investigations_filtered$legal_name, clean_names))
investigations_filtered$name <- emp_name_i 

# Clean up the city names
approved_only <- approved_only %>%
  mutate(city = toupper(EMPLOYER_CITY))

investigations_filtered <- investigations_filtered %>%
  mutate(city = toupper(cty_nm))


################
# De-duping
###############

# job postings data

RUN_DEDUPE_JOBS = TRUE
if(RUN_DEDUPE_JOBS){
  dedupe_fields = c("name")
  
  approved_matches <- fastLink(dfA = approved_only,
                               dfB = approved_only,
                               varnames = dedupe_fields,
                               stringdist.match = dedupe_fields,
                               dedupe.matches = FALSE)
  saveRDS(approved_matches, "intermediate/jobs_dedupe.RDS")
  
} else{
  approved_matches = readRDS(approved_matches, "intermediate/jobs_dedupe.RDS")
}

approved_deduped = getMatches(dfA = approved_only,
                              dfB = approved_only,
                              fl.out = approved_matches)

sprintf("After deduplicating job clearance data, we go from %s unique employers to %s unique",
        length(unique(approved_deduped$CASE_NUMBER)),
        length(unique(approved_deduped$dedupe.ids)))

approved_deduped$merging_index = 1:nrow(approved_deduped)


approved_deduped <- approved_deduped %>%
  group_by(dedupe.ids) %>%
  filter(DECISION_DATE == min(DECISION_DATE))

approved_deduped <- approved_deduped %>%
  group_by(dedupe.ids) %>%
  sample_n(1)


# investigations

RUN_DEDUPE_I = TRUE
if(RUN_DEDUPE_I){
  
  investigations_matches <- fastLink(dfA = investigations_filtered,
                                     dfB = investigations_filtered,
                                     varnames = dedupe_fields,
                                     stringdist.match = dedupe_fields,
                                     dedupe.matches = FALSE)
  
  investigations_deduped = getMatches(dfA = investigations_filtered,
                                      dfB = investigations_filtered,
                                      fl.out = investigations_matches)
  saveRDS(investigations_matches, "intermediate/investigations_dedupe_matchobj.RDS") 
  
  
}

sprintf("After deduplicating the filtered investigations data, we go from %s unique employers to %s unique",
        length(unique(investigations_deduped$case_id)),
        length(unique(investigations_deduped$dedupe.ids)))

investigations_deduped$merging_index = 1:nrow(investigations_deduped)


investigations_deduped <- investigations_deduped %>%
  group_by(dedupe.ids) %>%
  filter(findings_end_date == min(findings_end_date))

investigations_deduped <- investigations_deduped %>%
  group_by(dedupe.ids) %>%
  sample_n(1)


#################
# Driver Function for Fuzzy Matching
#################
fuzzy_matching <- function(state){
  
  print(sprintf("Working on %s", state))
  
  # subset datasets to just the desired state
  approved_deduped_temp <- approved_deduped %>%
    filter(EMPLOYER_STATE == state) # EMPLOYER_STATE or WORKSITE_STATE?
  
  investigations_deduped_temp <- as.data.frame(investigations_deduped) %>%
    filter(st_cd == state)
  
  # create index variable for merging
  approved_deduped_temp$index = 1:nrow(approved_deduped_temp)
  
  investigations_deduped_temp$index = 1:nrow(investigations_deduped_temp)
  
  # carry out the merge
  matches.out <- generate_save_matches(dbase1 = approved_deduped_temp,
                                       dbase2 = investigations_deduped_temp,
                                       matchVars = c("name", "city"),
                                       string_threshold = .85)
  
  merging <- merge_matches(dbase1 = approved_deduped_temp,
                           dbase2 = investigations_deduped_temp,
                           match_object = matches.out)
  
  saveRDS(merging, sprintf("intermediate/fuzzy_matching_%s.RDS", state))
  
  return(merging)
}

# find all states in one of the datasets
all_states <- unique(investigations_deduped$st_cd)

# make sure states are in both data sets
all_states_both <- all_states[(all_states %in% approved_deduped$EMPLOYER_STATE)]

# States "MP" and "" throwing an error- I think this is because "MP" only has one row in approved_only_temp...
# Error is "cannot coerce class ‘c("fastLink", "matchesLink")’ to a data.frame" for the 2 states
# Error is "wrong sign in 'by' argument" for ""
remove <- c("MP", "", "AK")
all_states_both <- all_states_both[!all_states_both %in% remove]

all_states_post_fuzzy <- lapply(all_states_both, fuzzy_matching)
all_states_final_df <- do.call(rbind.data.frame, all_states_post_fuzzy)
saveRDS(all_states_final_df, "intermediate/fuzzy_matching_final.RDS")
