# Authors: JG, DC
# Date: 6/3/2021
# Purpose: cleans the csv resulting from fuzzy matching
# Filename: A2_post_fuzzy_cleaning.py

import pandas as pd
import numpy as np
import random
import re
import recordlinkage
import time

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

# adapts regex to find patter in a string
def find_pattern(string, pat):
    res = re.findall(pat, string)
    if (len(res) > 0):
        return True
    else:
        return False

# finds the most occuring item in the column
def find_mode(col_of_interest):
    list_version = list(col_of_interest.values)
    values = sorted(list_version, key = list_version.count, reverse=True)  ## sorted the adj_only list in descending order
    values_no_dups = list(dict.fromkeys(values))                           ## remove duplicates while preserving order to get top 5
    return values_no_dups[0]


# forms a representative application dataframe by using an assigned technique based on the column data type
def form_representative(df, col_to_groupby):
    print('**** FORMING REPS ****')
    list_of_reps = []
    for one in df[col_to_groupby].unique():
        temp_df = df.loc[df[col_to_groupby] == one].copy()
        to_add = {}
        for col in temp_df:
            col_type = df.dtypes[col]
            if (col_type == "int64"):
                to_add[col] = temp_df[col].mean(skipna = True)
            elif (col_type == "object"):
                to_add[col] = find_mode(temp_df[col])
            elif (col_type == "float64"):
                to_add[col] = temp_df[col].mean(skipna = True)
            elif (col_type == "datetime64[ns]"):
                if (find_pattern(str(col),r'START')):
                    to_add[col] = temp_df[col].min()
                elif (find_pattern(str(col),r'END')):
                    to_add[col] = temp_df[col].max()
                else:
                    to_add[col] = temp_df[col].min()
            else:
                print("Other type")
        list_of_reps.append(to_add)

    res = pd.DataFrame(list_of_reps)
    print("**** DONE FORMING REPS *****")
    return res

# -------- DRIVER CODE --------------

# Read in the fuzzy matching results csv from A1_fuzzy Matching
res = pd.read_csv('../output/fuzzyMatchResult.csv')
print(res.head())

# read in the approved csv from A1_fuzzy Matching
approved_only_pure = pd.read_csv('../output/approvedOnly.csv')

# convert these to datetimes
res["load_date_cleaned"] = pd.to_datetime(res['ld_dt'], errors='coerce')
res["JOB_START_DATE"] = pd.to_datetime(res['JOB_START_DATE'], errors='coerce')
# make both timezone unaware
res["load_date_cleaned"] = res["load_date_cleaned"].apply(lambda d: d.replace(tzinfo=None))
res["JOB_START_DATE"] = res["JOB_START_DATE"].apply(lambda d: d.replace(tzinfo=None))

# res["load_date_cleaned"] = res.load_date_cleaned.replace(tzinfo=utc)
# res["JOB_START_DATE"] = res.JOB_START_DATE.replace(tzinfo=utc)

# mode should be either 'predict_investigations' or 'predict_violations'
# CHOSE MODE HERE!
# mode = 'predict_investigations'
mode = 'predict_violations'

if (mode == 'predict_investigations'):
    # subset the fuzzymatches such that the load date is after the job start date
    # the below line gives us investigations
    fuzzy_match_violations = res.loc[(res.load_date_cleaned >= res.JOB_START_DATE), :].copy()
    print('**** subseting to %s' % mode)
else:
    # subset the fuzzymatches such that the load date is after the job start date and positive violaition
    fuzzy_match_violations = res.loc[(res.load_date_cleaned >= res.JOB_START_DATE) & (res.h2a_violtn_cnt >= 1), :].copy()
    print('**** subseting to %s' % mode)


print('**** we found %s unique employers in the fuzzy matched data ' %fuzzy_match_violations.name.nunique())

# Make a classifier for Y if the name in the H2A was fuzzy matched to the violations/investigations data
approved_only_pure["is_violator"] = np.where(approved_only_pure.name.isin(list(fuzzy_match_violations.name_y)), 1, 0)
approved_only_pure.is_violator.value_counts()
#approved_only_pure.head()
#approved_only_pure.dtypes

print("**** There are %s applications in the H2A approved Dataset" %len(approved_only_pure))
print('**** But only %s unique companies within those applications' %approved_only_pure.name.nunique())
print('**** %s ' % approved_only_pure.is_violator.value_counts())

test_res = form_representative(approved_only_pure, "name")
# test_res.head()
test_res.shape

test_res.to_csv('../output/repMatrixfor' + mode + '.csv')












