# Authors: JG, DC
# Date: 6/1/2021
# Purpose: fuzzy matches between the H2A applications data and the WHD investigations data
# Filename: A1_fuzzy_matching.py

# imports
import pandas as pd
import numpy as np
import random
import re
import recordlinkage
import time

# -------- USER DEFINED FUNCTIONS --------


# this function will pull out the certification status from a given h2a application
def find_status(one):
    string_version = str(one)                    # convert to string
    pattern = r'\-\s(.*)$'                       # define regex pattern
    found = re.findall(pattern, string_version)  # search for pattern and return what's found
    return found[0]


# this function will clean the EMPLOYER_NAME in approved_only (h2a apps) and legal_name in violations (WHD data)
def clean_names(one):
    string_version = str(one)               # convert to string
    upper_only = string_version.upper()     # convert to uppercase
    pattern = r"(LLC|CO|INC)\."             # locate the LLC, CO, or INC that are followed by a period
    replacement = r'\1'                     # replace the whole pattern with the LLC/CO/INC component
    res = re.sub(pattern, replacement, upper_only)  # compute and return the result
    return res


# Function to do the fuzzy matching
def fuzzy_match(dbase1, dbase2, blockLeft, blockRight, matchVar1, matchVar2, distFunction,
               threshold, colsLeft, colsRight):
    print('*** Starting Fuzzy Matching ***')
    link_jobs_debar = recordlinkage.Index()  # initialize our Index
    link_jobs_debar.block(left_on=blockLeft, right_on=blockRight)         # block on the given block variable

    # form our index with the two given databases
    candidate_links = link_jobs_debar.index(dbase1, dbase2)

    compare = recordlinkage.Compare()       # initialize our compare class
    if len(matchVar1) != len(matchVar2):  # ensure matching num. of matching vars
        print("Need to pass in your matching variables in an array and you need to have "
              "the same number of matching variables. Please try again. ")
        return

    for i in range(len(matchVar1)):         # for each matching pair, add to our comparator
        compare.string(matchVar1[i], matchVar2[i], method=distFunction, threshold=threshold)

    compare_vectors = compare.compute(candidate_links, dbase1, dbase2)  # compute
    # compare_vectors

    # rename columns
    temp_array = []
    for i in range(len(matchVar1)):
        colName = str(matchVar1[i])
        temp_array.append(colName)
    compare_vectors.columns = temp_array

    # Find the correct selection
    conditions = []
    for one in matchVar1:
        condition_string = "({one_input} == 1)".format(one_input = one)
        conditions.append(condition_string)
    if len(conditions) > 1:
        comparison = "&".join(conditions)
    else:
        comparison = conditions[0]
    selected = compare_vectors.query(comparison).copy()

    # Extract index from selection
    n = selected.shape[0]
    index_dbase1_values = []
    index_dbase2_values = []
    for i in range(n):
        index = selected.index[i]
        index_dbase1_values.append(index[0])
        index_dbase2_values.append(index[1])
    selected["index_dbase1"] = index_dbase1_values.copy()
    selected["index_dbase2"] = index_dbase2_values.copy()

    # merge jobs with original columns
    # this will throw an error if jobs is not the left
    dbase1["index_dbase1"] = dbase1.index
    dbase1_columns = colsLeft
    m1 = pd.merge(selected, dbase1[dbase1_columns], on="index_dbase1", how="inner")

    # merge debar with original columns
    dbase2["index_dbase2"] = dbase2.index
    dbase2_columns = colsRight
    m2 = pd.merge(m1, dbase2[dbase2_columns], on="index_dbase2", how="inner", suffixes=["_left", "_right"])

    print('**** DONE WITH FUZZY MATCHING ****')
    return m2


# -------- DRIVER CODE --------
# load in h2a data
h2a = pd.read_excel("../data/h2a_2018.xlsx")
print('*** H2A Loaded ***')

# load in investigations/violations data
# url = "../my_data/whd_whisard.csv"
url = "https://enfxfr.dol.gov/data_catalog/WHD/whd_whisard_20210415.csv.zip"
investigations = pd.read_csv(url, index_col=None, dtype={7:'str'})
print('*** WHD Investigations Loaded ***')

# convert the dates in investigations to datetime objects
investigations['findings_start_date'] = pd.to_datetime(investigations['findings_start_date'], errors='coerce')
investigations['findings_end_date'] = pd.to_datetime(investigations['findings_end_date'], errors="coerce")
print('*** WHD Investigations Dates Converted ***')

# use the find status function and put into a new column
h2a["status"] = [find_status(one) for one in h2a.CASE_STATUS]   # put the status in a new column
print('*** Status Generated in H2A applications data ***')

# filter to applications that have received certification or partial certification
approved_only = h2a.loc[((h2a.status == "CERTIFICATION") | (h2a.status == "PARTIAL CERTIFICATION")),:].copy()
print('*** Filtered to certified and partially certified applications***')

# make new "name" columns for the cleaned versions of the names
approved_only["name"] = [clean_names(one) for one in approved_only.EMPLOYER_NAME]
approved_only_pure = approved_only.copy()
investigations["name"] = [clean_names(one) for one in investigations.legal_name]
investigations_cleaned = investigations.loc[investigations.name != "NAN", :].copy()     # get rid of NAN names
print('*** Cleaned Names in WHD investigations data ***')

print('*** Converting ld_dt to datetime ***')
investigations_cleaned['ld_dt'] = pd.to_datetime(investigations_cleaned['ld_dt'], errors='coerce')
print('*** Converted ld_dt to datetime ***')

# relevant investigations are those after 2017
print('*** Subsetting to only investigations after 2017-01-01 ***')
relevant_investigations = investigations_cleaned[investigations_cleaned.ld_dt > '2017-01-01'].copy()

# Clean up the city names
print('*** Cleaning up City Names in both Datasets ***')
approved_only["city"] = [str(one).upper() for one in approved_only.EMPLOYER_CITY]
relevant_investigations["city"] = [str(one).upper() for one in relevant_investigations.cty_nm]

# fuzzy match the two datasets
blockLeft = "EMPLOYER_STATE"
blockRight = "st_cd"
matchingVarsLeft = ["name", "city"]
matchingVarsRight = ["name", "city"]
colsLeft = ["status", "JOB_START_DATE", "JOB_END_DATE", "EMPLOYER_STATE", "name", "index_dbase1", "city"]
colsRight = ["st_cd", "name", "h2a_violtn_cnt", "findings_start_date", "findings_end_date",
             "index_dbase2", "city", "ld_dt"]

approved_only.to_csv("../output/approvedOnly.csv")
res = fuzzy_match(approved_only, relevant_investigations, blockLeft, blockRight, matchingVarsLeft, matchingVarsRight, "jarowinkler",
                 0.85, colsLeft, colsRight)

# Update this at some point to provide a unique file name so we don't overwrite files
csv_path = '../output/fuzzyMatchResult.csv'
print('*** SAVING %s ***' % csv_path)
res.to_csv("../output/fuzzyMatchResult.csv")

