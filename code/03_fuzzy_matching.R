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
  pattern <- "(LLC|CO|INC)\\.|\\," # locate the LLC, CO, or INC that are followed by a period
  res <- trimws(gsub(pattern, "", upper_only))
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
merge_matches <- function(jobs_formerge, investigations_formerge, match_object){
  
  merged_data = merge(jobs_formerge, 
                      match_object$matches,
                      by.x = "index",
                      by.y = "inds.a",
                      all.x = TRUE) %>%
   left_join(investigations_formerge, by = c("inds.b" = "index"),
             suffix = c("_jobs", "_investigations")) %>%
  mutate(is_matched_investigations = case_when(!is.na(name_investigations) ~ TRUE, 
                                               TRUE ~ FALSE)) # create logical flag for whether it matched to investigations
  
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
  filter(EMPLOYER_NAME != "") %>%
  mutate(state_formatch = ifelse(EMPLOYER_STATE == "", 
                                 WORKSITE_STATE, EMPLOYER_STATE)) # typically use employer state but worksite state if missing

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
dedupe_fields = c("name")
RUN_DEDUPE_JOBS = FALSE
if(RUN_DEDUPE_JOBS){
  
  approved_matches <- fastLink(dfA = approved_only,
                               dfB = approved_only,
                               varnames = dedupe_fields,
                               stringdist.match = dedupe_fields,
                               dedupe.matches = FALSE)
  saveRDS(approved_matches, "intermediate/jobs_dedupe.RDS")
  
} else{
  approved_matches = readRDS("intermediate/jobs_dedupe.RDS")
}

approved_deduped = getMatches(dfA = approved_only,
                              dfB = approved_only,
                              fl.out = approved_matches)

sprintf("After deduplicating job clearance data, we go from %s unique employers to %s unique",
        length(unique(approved_deduped$CASE_NUMBER)),
        length(unique(approved_deduped$dedupe.ids)))

## construct two ids: (1) row_id (previously merging_index) and (2) rename dedupe_id to something more descriptive
approved_deduped_clean = approved_deduped %>%
            mutate(jobs_row_id = 1:nrow(approved_deduped)) %>%
            rename(jobs_group_id = dedupe.ids)

# save before we filter out duplicates pre match
saveRDS(approved_deduped_clean, "intermediate/approved_only_pre_deduping.RDS")

set.seed(1)

## within the full dataset, within each group of same
## employers, first filter to earliest decision date
## and then in the case of ties sample 1
approved_deduped_formatch <- approved_deduped_clean %>%
  group_by(jobs_group_id) %>%
  filter(DECISION_DATE == min(DECISION_DATE)) %>%
  sample_n(1) 

## throw error if more rows than unique ids
stopifnot(length(unique(approved_deduped_formatch$jobs_group_id)) == nrow(approved_deduped_formatch))


# deduping of  investigations

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
  saveRDS(investigations_deduped, "intermediate/investigations_dedupe.RDS") 
  
} else{
  investigations_deduped = readRDS("intermediate/investigations_dedupe.RDS") 
}

sprintf("After deduplicating the filtered investigations data, we go from %s unique employers to %s unique",
        length(unique(investigations_deduped$case_id)),
        length(unique(investigations_deduped$dedupe.ids)))

## similarly, create a row id and group id
## construct two ids: (1) row_id (previously merging_index) and (2) rename dedupe_id to something more descriptive
investigations_deduped_clean = investigations_deduped %>%
  mutate(investigations_row_id = 1:nrow(investigations_deduped)) %>%
  rename(investigations_group_id = dedupe.ids)

# save before we filter out duplicates
saveRDS(investigations_deduped_clean, "intermediate/investigations_filtered_pre_deduping.RDS")

investigations_deduped_formatch <- investigations_deduped_clean %>%
  group_by(investigations_group_id) %>%
  filter(findings_end_date == min(findings_end_date)) %>%
  sample_n(1)

stopifnot(length(unique(investigations_deduped_formatch$investigations_group_id)) == 
        nrow(investigations_deduped_formatch))


#################
# Driver Function for Fuzzy Matching
#################
fuzzy_matching <- function(state, jobs_df, investigations_df){
  
  print(sprintf("Working on %s", state))
  
  # subset datasets to just the desired state
  approved_deduped_temp <- jobs_df %>%
    filter(state_formatch == state) 
  
  investigations_deduped_temp <- as.data.frame(investigations_df) %>%
    filter(st_cd == state)
  
  # create index variable for merging
  approved_deduped_temp$index = 1:nrow(approved_deduped_temp)
  
  investigations_deduped_temp$index = 1:nrow(investigations_deduped_temp)
  
  # carry out the merge
  matches.out <- generate_save_matches(dbase1 = approved_deduped_temp,
                                       dbase2 = investigations_deduped_temp,
                                       matchVars = c("name", "city"),
                                       string_threshold = .85)
  
  merging <- merge_matches(jobs_formerge = approved_deduped_temp,
                         investigations_formerge =investigations_deduped_temp,
                        match_object = matches.out)
  
  saveRDS(merging, sprintf("intermediate/fuzzy_matching_%s.RDS", state))
  
  return(merging)
}

# find all states in one of the datasets
all_states <- unique(approved_deduped_clean$state_formatch)

# make sure states are in both data sets
all_states_both <- all_states[(all_states %in% investigations_deduped_clean$st_cd)]

# States "MP" and "" throwing an error
# Error is "cannot coerce class ‘c("fastLink", "matchesLink")’ to a data.frame" for "MP"
# Error is "wrong sign in 'by' argument" for ""
all_states_keep = setdiff(all_states_both, c("PR", "AK", "RI")) # removeones with very few jobs/no matches


RUN_FULL_MATCH = FALSE
if(RUN_FULL_MATCH){
  ## apply to all states
  print("starting match")
  all_states_post_fuzzy <- lapply(all_states_keep, fuzzy_matching,
                                  jobs_df = approved_deduped_formatch,
                                  investigations_df = investigations_deduped_formatch)
  
  ## read in results
  all_states_post_fuzzy <- lapply(grep("fuzzy\\_matching\\_[A-Z][A-Z].RDS", 
                              list.files("intermediate/"), value = TRUE),
                              function(x) readRDS(sprintf("intermediate/%s", x))) 
  ## rowbind results
  all_states_final_df <- do.call(rbind.data.frame, all_states_post_fuzzy)
  
  ## write
  saveRDS(all_states_final_df, "intermediate/fuzzy_matching_final.RDS")
} else{
  all_states_final_df = readRDS("intermediate/fuzzy_matching_final.RDS") %>% select(-index)
}

#################
# Add duplicates back in: investigations
#################

## first,  add additional investigations on using the investigations_group_id
## these are: (1) investigations filtered out in dedup, (2) in relevant states, and 
## (3) group id is in match results, indicating that other investigations in the group matched
investigations_toadd = investigations_deduped_clean %>% filter(!investigations_row_id %in% 
                                                                 investigations_deduped_formatch$investigations_row_id &
                                                                 st_cd %in% all_states_keep &
                                                                 investigations_group_id %in% 
                                                                 matchres_alljobs$investigations_group_id[!is.na(matchres_alljobs$investigations_group_id)])

## add additional matches and fill values within a group id
investigations_toadd_wjobid = merge(investigations_toadd,
                                    all_states_final_df %>% filter(is_matched_investigations) %>% 
                                      select(jobs_row_id,
                                             jobs_group_id,
                                            investigations_group_id),
                                    by = "investigations_group_id",
                                    all.x = TRUE) %>%
                    rename(city_investigations = city,
                           name_investigations = name)

## add blank cols for the jobs cols before rbind
cols_toadd = setdiff(colnames(all_states_final_df), colnames(investigations_toadd_wjobid))
cols_tocbind = data.frame(matrix(NA, nrow = nrow(investigations_toadd_wjobid),
                                 ncol = length(cols_toadd))) 
colnames(cols_tocbind) = cols_toadd
investigations_torbind = cbind.data.frame(investigations_toadd_wjobid,
                            cols_tocbind) %>% mutate(is_matched_investigations = TRUE)
matchres_allinvest = rbind.data.frame(all_states_final_df,
                                    investigations_torbind) 

## group by investigations group id and fill in values for jobs
jobs_cols = cols_toadd
matchres_allinvest_fill = matchres_allinvest %>% group_by(investigations_group_id) %>%
                  fill(jobs_cols, .direction = "downup") %>%
                  ungroup() 

### check: look at values for investigation added in
# test_investigation = investigations_torbind %>% slice(1) %>% pull(investigations_group_id)
# head(investigations_toadd_wjobid %>% filter(investigations_group_id %in% test_investigation))
#View(matchres_allinvest_fill %>% filter(investigations_group_id %in% test_investigation) %>% select(contains("id")))


#################
# Add duplicates back in: jobs
# above code adds investigations 
# removed during deduplication/ties
# them to relevant job
#################

## first, add in jobs removed during deduplication
jobs_removed_whendedup = approved_deduped_clean %>% filter(!jobs_row_id %in% approved_deduped_formatch$jobs_row_id &
                                                             state_formatch %in% all_states_keep) %>%
                rename(name_jobs = name,
                       city_jobs = city)

## rowbind them using NA for the new cols and fill values for those cols using the jobs_group_id so that
## all jobs within the same deduplicated group get same values for investigations
cols_toadd = setdiff(colnames(matchres_allinvest_fill), colnames(jobs_removed_whendedup))
cols_tocbind = data.frame(matrix(NA, nrow = nrow(jobs_removed_whendedup),
                                 ncol = length(cols_toadd)))
colnames(cols_tocbind) = cols_toadd
jobs_removed_whendedup_torbind = cbind.data.frame(jobs_removed_whendedup,
                                                cols_tocbind) 

matchres_allinvest_alljobs = rbind.data.frame(matchres_allinvest_fill,
                                    jobs_removed_whendedup_torbind) 

## pull group ids with any investigations and work on filling
## basically, within a group of jobs, want to (1) take values from
## the job within the group that matched to an investigation, (2) fill with the 
## investigation values, and (3) make sure this is done for all investigations
job_groups_with_investigations = matchres_allinvest_fill$jobs_group_id[matchres_allinvest_fill$is_matched_investigations]
job_groups_without_investigations = matchres_allinvest_fill$jobs_group_id[!matchres_allinvest_fill$is_matched_investigations]

## stopped here: remaining steps: (1) filter based on job_group_id to two dfs: (1) job groups with investigations and
## (2) job groups without (contains all jobs in the group); (2) with the ones with investigations, do above filling procedure - 
## i think grouping by job_group_id alone wont work because if a given job group matched to multiple investigations, 
## we want to fill with all those values - might necessitate change in jobs-focused rowbind code (i think investigations rowbind is fine)


