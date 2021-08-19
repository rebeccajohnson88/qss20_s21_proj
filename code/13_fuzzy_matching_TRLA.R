##########################
# This code fuzzy matches between H2A applications data and the WHD investigations data
# Author: Cam Guage 
# Written: 6/29/2021
##########################
# 11:26
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
  DATA_DIR = "C:/Users/Austin Paralegal/Dropbox/qss20_finalproj_rawdata/summerwork"
  #DATA_DIR = "~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
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

# get a list of applicable NAICS codes
h2a_NAICS <- read.csv("intermediate/h2a_combined_2014-2021_preserveallcols.csv") %>%
  mutate(as.character(NAICS_CODE)) %>%
  group_by(NAICS_CODE) %>%
  summarise(n())

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

# filtering to H2a, FLSA, MSPA with a NAICS code applicable to agriculture or H2A program
investigations_filtered <- investigations %>%
  filter((`Registration Act` == "H2A" | `Registration Act` == "FLSA" | `Registration Act` == "MSPA") & 
           (str_detect(naic_cd, "^11") | naic_cd %in% h2a_NAICS$NAICS_CODE))

sprintf("After filtering to H2A, FLSA, and MSPA investigations with applicable NAICS codes only, we go from %s rows to %s rows",
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


#NOTE from ES: running into vector allocation issues here and can't continue

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

# adjust jobs_group_id, as it has some jobs that occurred in different states in the same group
# first see if any jobs groups contain more than one state
test <- approved_deduped_clean %>%
  group_by(jobs_group_id) %>%
  mutate(is_same_state = ifelse(length(unique(state_formatch)) == 1, TRUE, FALSE)) %>%
  ungroup()

table(test$is_same_state) # looks like we have some jobs that span multiple states

# Thus, adjust the jobs_group_id so that each combination of jobs_group_id and state maps to a unique index
# First create a part 2 of the index that will correspond to the state within a particular jobss_group_id
approved_deduped_clean <- approved_deduped_clean %>%
  group_by(jobs_group_id) %>%
  mutate(jobs_group_id_part2 = as.integer(factor(state_formatch))) %>%
  ungroup() %>%
  rename(jobs_group_id_part1 = jobs_group_id)

# Then concatenate this part2 index with the original index to create a new and more accurate index
approved_deduped_clean$jobs_group_id <- str_c(approved_deduped_clean$jobs_group_id_part1, approved_deduped_clean$jobs_group_id_part2, sep = "_")

# confirm that is_same_state is all TRUE now
test <- approved_deduped_clean %>%
  group_by(jobs_group_id) %>%
  mutate(is_same_state = ifelse(length(unique(state_formatch)) == 1, TRUE, FALSE)) %>%
  ungroup()

table(test$is_same_state) # all are TRUE,this was successful

# also confirm that investigations matched during de-deduping and in the same state have the same id
test <- approved_deduped_clean %>%
  group_by(jobs_group_id_part1, state_formatch) %>%
  mutate(is_same_id = ifelse(length(unique(jobs_group_id)) == 1, TRUE, FALSE)) %>%
  ungroup()

table(test$is_same_id) # all are TRUE,this was successful

# save before we filter out duplicates pre match
saveRDS(approved_deduped_clean, "intermediate/approved_only_pre_deduping.RDS")

set.seed(1)

## within the full dataset, within each group of same
## employers, first filter to earliest date
## and then in the case of ties sample 1
approved_deduped_formatch <- approved_deduped_clean %>%
  group_by(jobs_group_id) %>%
  filter(DECISION_DATE == min(DECISION_DATE)) %>%
  sample_n(1) 

## throw error if more rows than unique ids
stopifnot(length(unique(approved_deduped_formatch$jobs_group_id)) == nrow(approved_deduped_formatch))


# deduping of investigations

RUN_DEDUPE_I = TRUE
if(RUN_DEDUPE_I){
  
  investigations_matches <- fastLink(dfA = investigations_filtered,
                                     dfB = investigations_filtered,
                                     varnames = dedupe_fields,
                                     stringdist.match = dedupe_fields,
                                     #threshold.match = .75,
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

# adjust investigations_group_id, as it has some investigations that occurred in different states in the same group
# see if any investigations groups contain more than one state
test <- investigations_deduped_clean %>%
  group_by(investigations_group_id) %>%
  mutate(is_same_state = ifelse(length(unique(st_cd)) == 1, TRUE, FALSE)) %>%
  ungroup()

table(test$is_same_state) # looks like we have some investigations that span multiple states

# Thus, adjust the investigations_group_id so that each combination of investigations_group_id and state maps to a unique index
# First create a part 2 of the index that will correspond to the state within a particular investigations_group_id
investigations_deduped_clean <- investigations_deduped_clean %>%
  group_by(investigations_group_id) %>%
  mutate(investigations_group_id_part2 = as.integer(factor(st_cd))) %>%
  ungroup() %>%
  rename(investigations_group_id_part1 = investigations_group_id)

# Then concatenate this part2 index with the original index to create a new and more accurate index
investigations_deduped_clean$investigations_group_id <- str_c(investigations_deduped_clean$investigations_group_id_part1, investigations_deduped_clean$investigations_group_id_part2, sep = "_")

# confirm that this worked successfully
test <- investigations_deduped_clean %>%
  group_by(investigations_group_id) %>%
  mutate(is_same_state = ifelse(length(unique(st_cd)) == 1, TRUE, FALSE)) %>%
  ungroup()

table(test$is_same_state) # all are TRUE,this was successful

# also confirm that investigations matched during de-deduping and in the same state have the same id
test <- investigations_deduped_clean %>%
  group_by(investigations_group_id_part1, st_cd) %>%
  mutate(is_same_id = ifelse(length(unique(investigations_group_id)) == 1, TRUE, FALSE)) %>%
  ungroup()

table(test$is_same_id) # all are TRUE,this was successful

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

# first, a test
test_df <- job_groups_with_investigations_df %>%
  sample_n(5)

# create list
# id_4 <- "1378_3"
list_of_dfs_to_rbind <- list()

# for each group_id that matched to an investigation,
for (group_id in unique(job_groups_with_investigations_df$jobs_group_id))
  { 
  
  # isolate the investigations that matched to this jobs_group_id
  temp_data <- matchres_allinvest_fill %>%
    filter(jobs_group_id == group_id)
  
  rbound_df <- data.frame()
  
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
    #should include investigations_row_id somewhere in here for filling later
    jobs_removed_whendedup_torbind = cbind.data.frame(particular_jobs_removed_when_dedup,
                                                      cols_tocbind) %>% mutate(is_matched_investigations = TRUE)
    
    # bind onto the original observation in order to fill
    reduped_investigation <- rbind.data.frame(each_investigation, jobs_removed_whendedup_torbind)
    
    # fill in the NA investigations rows of duplicates
    investigations_cols = cols_toadd
    reduped_investigation_fill = reduped_investigation %>%
      fill(investigations_cols, .direction = "downup")

    
    # then bind these back onto "temp_data", updating it
    # global/local issue? 
    rbound_df <<- rbind.data.frame(rbound_df, reduped_investigation_fill)
    
    # i dont think this will include the jobs that were not removed- do we need to merge on ?

  }
  
  # update the vector
  list_of_dfs_to_rbind <- c(list_of_dfs_to_rbind, list(rbound_df))
}
# 2:21, 2:28

saveRDS(list_of_dfs_to_rbind, "intermediate/list_of_dfs_to_rbind.RDS")
# bind these all together
all_jobs_with_investigations <- do.call(rbind.data.frame, list_of_dfs_to_rbind)

# check that the output is as expected:
# choose 3 jobs that had investigations and confirm the re-duplication was correct

test_df <- job_groups_with_investigations_df[sample(nrow(job_groups_with_investigations_df), 3), ]

# Check the first
# grab its group_id
id_1 <- test_df$jobs_group_id[1]

# see if it had any duplicates
View(approved_deduped_clean %>%
  filter(jobs_group_id == id_1)) # it did not

# see how many investigations it mapped to
View(matchres_allinvest_fill %>%
  filter(jobs_group_id == id_1)) # just 1

# make sure we just get one row in re-duplication
View(all_jobs_with_investigations %>%
  filter(jobs_group_id == id_1)) # we do

# Check the second
# grab its group_id
id_2 <- test_df$jobs_group_id[2]

# see if it had any duplicates
View(approved_deduped_clean %>%
  filter(jobs_group_id == id_2)) # 12 duplicates

# see how many investigations it mapped to
View(matchres_allinvest_fill %>%
  filter(jobs_group_id == id_2)) # just 1

# make sure we get 13 rows in re-duplication, and that they're filled correctly
View(all_jobs_with_investigations %>%
  filter(jobs_group_id == id_2)) # we do

# Check the third
# grab its group_id
id_3 <- test_df$jobs_group_id[3]

# see if it had any duplicates
View(approved_deduped_clean %>%
  filter(jobs_group_id == id_3)) # 8 duplicates

# see how many investigations it mapped to
View(matchres_allinvest_fill %>%
  filter(jobs_group_id == id_3)) # just 1

# make sure we get 9 rows during re-duplication, and they are filled correctly
View(all_jobs_with_investigations %>%
  filter(jobs_group_id == id_3)) # we do

# find one with multiple investigations, no duplicates
matchres_allinvest_fill %>%
  group_by(jobs_row_id) %>%
  summarize(n = n()) %>%
  arrange(-n)

# now lets look for one with duplicates and multiple investigations
id_4 <- "1378_3"

View(approved_deduped_clean %>%
  filter(jobs_group_id == id_4)) # 24 duplicates

# see how many investigations it mapped to
View(matchres_allinvest_fill %>%
  filter(jobs_group_id == id_4)) # 11 investigations

# make sure we get 275 rows during re-duplication, and they are filled correctly
test <- all_jobs_with_investigations %>%
  filter(jobs_group_id == id_4) # we do!


#################
# Re-duplicate jobs that did not match to investigations
#################

# Isolate the jobs to merge on
jobs_removed_whendedup_no_invest <- jobs_removed_whendedup %>%
  filter(jobs_group_id %in% job_groups_without_investigations)

# carry out steps from before
cols_toadd = setdiff(colnames(job_groups_without_investigations_df), colnames(jobs_removed_whendedup_no_invest))
 cols_tocbind = data.frame(matrix(NA, nrow = nrow(jobs_removed_whendedup_no_invest),
 ncol = length(cols_toadd)))
 colnames(cols_tocbind) = cols_toadd
 jobs_removed_whendedup_torbind_no_invest = cbind.data.frame(jobs_removed_whendedup_no_invest,
                                                    cols_tocbind)
 all_jobs_without_investigations = rbind.data.frame(job_groups_without_investigations_df,
                                                jobs_removed_whendedup_torbind_no_invest) 
 
 # need to fill!
 investigations_cols = cols_toadd
 all_jobs_without_investigations = all_jobs_without_investigations %>% group_by(jobs_group_id) %>%
   fill(investigations_cols, .direction = "downup") %>%
   ungroup() 
 
# quick check
 test_df <- job_groups_without_investigations_df[sample(nrow(job_groups_with_investigations_df), 3), ]
 
 # Check the second, which has duplicates
 # grab its group_id
 id_2 <- test_df$jobs_group_id[2]
 
 # see if it had any duplicates
 View(approved_deduped_clean %>%
        filter(jobs_group_id == id_2)) # it had 7
 
 # see how many investigations it mapped to
 View(matchres_allinvest_fill %>%
        filter(jobs_group_id == id_2)) # none
 
 # make sure we get 8 rows in re-duplication and they are filled correctt
 View(all_jobs_without_investigations %>%
        filter(jobs_group_id == id_2)) # we do


# finally, combine all jobs with and without investigations
 final_df <- rbind.data.frame(all_jobs_with_investigations, all_jobs_without_investigations)
 
saveRDS(final_df, "intermediate/final_df.RDS")
write.csv(final_df, "intermediate/final_df.csv")
