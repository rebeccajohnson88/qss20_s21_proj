##########################
# This code fuzzy matches between H2A applications data and the WHD investigations data
# Author: Cam Guage 
# Written: 6/29/2021
##########################

##########################
# Packages and Imports
##########################

library(dplyr)
library(stringr)
library(fastLink)
library(readr)

########################
# User-defined functions 
########################

## function to pull out certification status from a given h2a application
find_status <- function(one){
  
  string_version <- toString(one) # convert to string
  pattern <- '\\-\\s(.*)$'
  found <- str_extract(string_version, pattern)
  return(found)
  
}

# function to clean the EMPLOYER_NAME in approved_only (h2a apps) and legal_name in violations (WHD data)
clean_names <- function(one){
  
  string_version = toString(one) # convert to string
  upper_only <- toupper(string_version) # convert to uppercase
  pattern <- "(LLC|CO|INC)\\." # locate the LLC, CO, or INC that are followed by a period
  replacement <- '/1' # replace the whole pattern with the LLC/CO/INC component
  res <- str_replace_all(upper_only, pattern, replacement)
  return(res)
  
}

## function to standardize column names b/t data sources (need to write cw_file later)

## is this a necessary function? It seems like it is so that we can use the new "index" column for merging later
standardize_colnames <- function(data, cw_file = matchvars_crosswalk){
  cleaned_data = renamefrom(data, cw_file = cw_file, raw = varname, clean = clean, label = label, drop_extra = FALSE) %>%
    mutate(index = 1:nrow(data))
  return(cleaned_data)
}

#####################
## Fuzzy Matching
#####################

## function to generate matches using fastlink and to save a copy/return
generate_save_matches <- function(dbase1, dbase2, matchVars, string_threshold){
  
  matches.out <- fastLink(dfA = dbase1,
                          dfB = dbase2,
                          varnames = matchVars,
                          stringdist.match = matchVars,
                          partial.match = matchVars,
                          verbose = TRUE,
                          cut.a = threshold)
  saveRDS(matches.out, "intermediate/matchresults.RDS")
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

# load in h2a data
h2a <- read.csv("intermediate/h2a_combined_2014-2021.csv")

# load in investigations/violations data
investigations <- read.csv("raw/whd_whisard.csv") # downloaded rather than scraped, should I be scraping instead?

# use the find status function and put into a new column
h2a <- h2a %>%
  mutate(status = find_status(CASE_STATUS)) # RStudio is taking forever to view so hard for me to tell if this worked

# filter to applications that have received certification or partial certification
approved_only <- h2a %>%
  filter(status == "CERTIFICATION" | status == "PARTIAL CERTIFICATION") # this is not working (0 observationsr registering)

# make new "name" columns for the cleaned versions of the names
approved_only <- approved_only %>%
  mutate(name = clean_names(EMPLOYER_NAME))

investigations <- investigations %>%
  mutate(name = clean_names(legal_name))

investigations_cleaned <- investigations %>%
  filter(name != "NAN") # should I do this or is.na()

# prob should filter to get only investigations after 2014. What does ld_dt mean

# Clean up the city names
approved_only <- approved_only %>%
  mutate(city = toupper(EMPLOYER_CITY))

investigations_cleaned <- investigations_cleaned %>%
  mutate(city = toupper(cty_nm))


for (state in investigations_cleaned$st_cd) {
  
  # create temporary datasets to fuzzy match on
  approved_only_temp <- approved_only %>%
    filter(WORKSITE_STATE == state) # EMPLOYER_STATE or WORKSITE_STATE?
  
  investigations_cleaned_temp <- investigations_cleaned %>%
    filter(st_cd == state)
  
  matches.out <- generate_save_matches(dbase1 = approved_only_temp,
                                       dbase2 = investigations_cleaned_temp,
                                       matchVars = c(name, city),
                                       string_threshold = .85)
  
  merging <- merge_matches(dbase1 = approved_only_temp,
                           dbase2 = investigations_cleaned_temp,
                           match_object = matches.out)
  
}
