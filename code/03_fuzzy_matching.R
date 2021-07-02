##########################
# This code fuzzy matches between H2A applications data and the WHD investigations data
# Author: Cam Guage and Rebecca Johnson
# Written: 7/2/2021
##########################

##########################
# Packages and Imports
##########################

library(dplyr)
library(stringr)
library(fastLink)
library(readr)
library(data.table)

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
investigations <- fread("raw/whd_whisard.csv")
# X <- read.csv(url("http://some.where.net/data/foo.csv"))


################
# Cleaning the Data
################

# use the find status function and put into a new column
status = unlist(lapply(h2a$CASE_STATUS, find_status))
h2a$status_cleaned = status

# filter to applications that have received certification or partial certification
approved_only <- h2a %>%
  filter(status_cleaned == "- CERTIFICATION" | status_cleaned == "- PARTIAL CERTIFICATION")

sprintf("After filtering to approved only, we go from %s rows to %s rows",
        nrow(h2a),
        nrow(approved_only))
table(approved_only$status_cleaned)

# make new "name" columns for the cleaned versions of the names
emp_name_app = unlist(lapply(approved_only$EMPLOYER_NAME, clean_names))
approved_only$name <- emp_name_app  

emp_name_i =  unlist(lapply(investigations$legal_name, clean_names))
investigations$name <- emp_name_i 

investigations_cleaned <- investigations %>%
  filter(is.na(name) == FALSE) # looks like there are no NA's

# Clean up the city names
approved_only <- approved_only %>%
  mutate(city = toupper(EMPLOYER_CITY))

investigations_cleaned <- investigations_cleaned %>%
  mutate(city = toupper(cty_nm))

#################
# Driver Function for Fuzzy Matching
#################
fuzzy_matching <- function(state){
  
  # subset datasets to just the desired state
  approved_only_temp <- approved_only %>%
    filter(WORKSITE_STATE == state) # EMPLOYER_STATE or WORKSITE_STATE?
  
  investigations_cleaned_temp <- investigations_cleaned %>%
    filter(st_cd == state)
  
  # create index variable for merging
  approved_only_temp$index = 1:nrow(approved_only_temp)
  
  investigations_cleaned_temp$index = 1:nrow(investigations_cleaned_temp)
  
  # carry out the merge
  matches.out <- generate_save_matches(dbase1 = approved_only_temp,
                                       dbase2 = investigations_cleaned_temp,
                                       matchVars = c("name", "city"),
                                       string_threshold = .85)
  
  merging <- merge_matches(dbase1 = approved_only_temp,
                           dbase2 = investigations_cleaned_temp,
                           match_object = matches.out)
  
  return(merging)
}

# run code on 3 random states
some_states <- sample(unique(investigations_cleaned$st_cd), 3)
some_states_post_fuzzy <- lapply(some_states, fuzzy_matching)
some_states_final_df <- do.call(rbind.data.frame, some_states_post_fuzzy)
