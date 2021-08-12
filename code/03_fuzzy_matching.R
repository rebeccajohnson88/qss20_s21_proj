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
library(tidyr)

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

# creates the desired vector to search for names with a "-" and then a state name or abbreviation
state_abbreviations <- state.abb
state_full_names <- state.name
state_abbreviations_and_names <- c(state_abbreviations, state_full_names)
state_abbreviations_and_names_upper <- toupper(state_abbreviations_and_names)
with_dash <- paste("- ", state_abbreviations_and_names_upper, sep = "")
with_semi <- paste("; ", state_abbreviations_and_names_upper, sep = "")
dash_and_semi <- c(with_dash, with_semi)
state_abbreviations_and_names_upper_collapsed <- paste(dash_and_semi, collapse = '|')


# function to clean the EMPLOYER_NAME in approved_only (h2a apps) and legal_name in violations (WHD data)
clean_names <- function(one){
  
  string_version = toString(one) # convert to string
  upper_only <- toupper(string_version) # convert to uppercase
  upper_only_cleaned <- gsub(state_abbreviations_and_names_upper_collapsed, "", upper_only)
  sub_2 <- "&NDASH| (LLC|CO|INC)" # locate the LLC, CO, or INC that come after a space, and get rid of weird ndash bug
  almost_done <- gsub(sub_2, "", upper_only_cleaned)
  pattern <- "[[:punct:]]+$"
  res <- trimws(gsub(pattern, "", almost_done))
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

## function to merge matched objects with each other
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

co = 0
inc = 0
llc = 0
for (name in approved_only$name) {
  if (word(name, -1) == "CO") {
    co = co + 1
    print(name)
  }
  if (word(name, -1) == "INC") {
    inc = inc + 1
    print(name)
  }
  if (word(name, -1) == "LLC") {
    llc = llc + 1
    print(name)
  }
}
sprintf("%s companies end in CO, %s companies end in INC, and %s companies end in LLC", co, inc, llc)


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
RUN_DEDUPE_JOBS = TRUE
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

all_states_keep = setdiff(all_states_both, c("PR", "AK", "RI")) # remove ones with very few jobs/no matches

RUN_FULL_MATCH = TRUE
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
# Adjust the jobs_group_id, will move this to end of script
#################

# see if any jobs groups contain more than one state
#test <- approved_deduped_clean %>%
  #group_by(jobs_group_id) %>%
  #mutate(is_same_state = ifelse(length(unique(state_formatch)) == 1, TRUE, FALSE)) %>%
  #ungroup()

#table(test$is_same_state) # we can see that many jobs that we assumed were the same were actually in different states
## thus we make a new jobs_group_id that will reflect this

#all_states_final_df <- all_states_final_df %>%
  #group_by(jobs_group_id) %>%
  #mutate(jobs_group_id_part2 = row_number()) %>%
  #ungroup() %>%
  #rename(jobs_group_id_part1 = jobs_group_id)

#all_states_final_df$jobs_group_id <- str_c(all_states_final_df$jobs_group_id_part1, all_states_final_df$jobs_group_id_part2, sep = "_")

# make sure job groups now do not contain more than one state
#test <- all_states_final_df %>%
  #group_by(jobs_group_id) %>%
  #mutate(is_same_state = ifelse(length(unique(state_formatch)) == 1, TRUE, FALSE)) %>%
  #ungroup()

#table(test$is_same_state)


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
                                                                 all_states_final_df$investigations_group_id[!is.na(all_states_final_df$investigations_group_id)])

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
test_investigation = investigations_torbind %>% slice(1) %>% pull(investigations_group_id)
head(investigations_toadd_wjobid %>% filter(investigations_group_id %in% test_investigation))
View(matchres_allinvest_fill %>% filter(investigations_group_id %in% test_investigation) %>% select(contains("id")))

# adjust investigations_group_id, as it has some investigations that occurred in different states in the same group
# see if any investigations groups contain more than one state
test <- matchres_allinvest_fill %>%
  group_by(investigations_group_id) %>%
  mutate(is_same_state = ifelse(length(unique(st_cd)) == 1, TRUE, FALSE)) %>%
  ungroup()

table(test$is_same_state) # looks like we have some investigations that span multiple states

# Thus, adjust the investigations_group_id so that each combination of investigations_group_id and state maps to a unique index
# First create a part 2 of the index that will correspond to the state within a particular investigations_group_id
matchres_allinvest_fill <- matchres_allinvest_fill %>%
  group_by(investigations_group_id) %>%
  mutate(investigations_group_id_part2 = row_number()) %>%
  ungroup() %>%
  rename(investigations_group_id_part1 = investigations_group_id)

# Then concatenate this part2 index with the original index to create a new and more accurate index
matchres_allinvest_fill$investigations_group_id <- str_c(matchres_allinvest_fill$investigations_group_id_part1, matchres_allinvest_fill$investigations_group_id_part2, sep = "_")

# confirm that this worked successfully
test <- matchres_allinvest_fill %>%
  group_by(investigations_group_id) %>%
  mutate(is_same_state = ifelse(length(unique(st_cd)) == 1, TRUE, FALSE)) %>%
  ungroup()

table(test$is_same_state) # all are TRUE,this was succesful

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

#############
# IGNORING THIS FOR NOW WHILE CONSTRUCTING NESTED LOOP
###############
# cols_toadd = setdiff(colnames(matchres_allinvest_fill), colnames(jobs_removed_whendedup))
# cols_tocbind = data.frame(matrix(NA, nrow = nrow(jobs_removed_whendedup),
                                 # ncol = length(cols_toadd)))
# colnames(cols_tocbind) = cols_toadd
# jobs_removed_whendedup_torbind = cbind.data.frame(jobs_removed_whendedup,
                                                  # cols_tocbind) 

# matchres_allinvest_alljobs = rbind.data.frame(matchres_allinvest_fill,
                                              # jobs_removed_whendedup_torbind) 

##############
# UN-IGNORING
##############

## pull group ids with any investigations and work on filling
## basically, within a group of jobs, want to (1) take values from
## the job within the group that matched to an investigation, (2) fill with the 
## investigation values, and (3) make sure this is done for all investigations
job_groups_with_investigations = matchres_allinvest_fill$jobs_group_id[matchres_allinvest_fill$is_matched_investigations]
job_groups_without_investigations = matchres_allinvest_fill$jobs_group_id[!matchres_allinvest_fill$is_matched_investigations]

# (1) filter based on job_group_id to two dfs: (1) job groups with investigations
job_groups_with_investigations_df <- matchres_allinvest_fill %>%
  filter(jobs_group_id %in% job_groups_with_investigations)

job_groups_without_investigations_df <- matchres_allinvest_fill %>%
  filter(jobs_group_id %in% job_groups_without_investigations)

# for each job with investigations, loop over each investigation it has, and bind it with
# the correct number of empty rows/columns for observations lost during de-duplication.
# then rbind each of these investigations together into a df, and add them to
# list_of_dfs_to_rbind. eventually we will use do.call to create our full re-duplicated
# data set, minus jobs that did NOT match to an investigation

# create empty list
list_of_dfs_to_rbind <- vector(mode = "list")

# for each group_id that matched to an investigation,
for (group_id in job_groups_with_investigations_df$jobs_group_id)
  {
  
  # isolate the investigations that matched to this jobs_group_id
  temp_data <- matchres_allinvest_fill %>%
    filter(jobs_group_id == group_id)
  
  
  # then for each investigation in this dataset,
  for (row_id in temp_data$investigations_row_id)
  {
    
    # isolate the row with the investigation
    each_investigation <- temp_data %>%
      filter(investigations_row_id == row_id)
    
    # re-duplicate for this particular investigation
    particular_jobs_removed_when_dedup <- jobs_removed_whendedup %>% # is there an issue if this is an empty dataset
      filter(jobs_group_id == group_id)
    
    cols_toadd = setdiff(colnames(each_investigation), colnames(jobs_removed_whendedup))
    
    cols_tocbind = data.frame(matrix(NA, nrow = nrow(particular_jobs_removed_when_dedup),
                                     ncol = length(cols_toadd)))
    
    colnames(cols_tocbind) = cols_toadd
    
    jobs_removed_whendedup_torbind = cbind.data.frame(particular_jobs_removed_when_dedup,
                                                      cols_tocbind) %>% mutate(is_matched_investigations = TRUE)
    
    
    # then bind these back onto "temp_data", updating it
    # global/local issue? 
    temp_data <<- rbind.data.frame(temp_data, jobs_removed_whendedup_torbind)

  }
  
  # update the list
  list_of_dfs_to_rbind <- c(list_of_dfs_to_rbind, temp_data)
}

# loop takes about 10 mins to run

saveRDS(list_of_dfs_to_rbind, "intermediate/list_of_dfs_to_rbind.RDS")
# bind these all together
all_jobs_with_investigations <- do.call(rbind.data.frame, list_of_dfs_to_rbind)

# getting "vector memory exhausted" error after ~6 mins

# from here we can group_by jobs_group_id and invesetigations_row_id to fill the NA's
