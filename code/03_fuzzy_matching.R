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
generate_save_matches <- function(dbase1, dbase2, matchVars, blockVar, string_threshold){
  
  matches.out <- fastLink(dfA = dbase1,
                          dfB = dbase2,
                          varnames = matchVars,
                          stringdist.match = matchVars,
                          partial.match = matchVars,
                          verbose = TRUE,
                          cut.a = threshold)
  saveRDS(matches.out, sprintf("../../intermediate/matchresults.RDS", blockVar))
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

# load in investigations/violations data
investigations <- read.csv("raw/whd_whisard.csv")

# what is other dataset?

