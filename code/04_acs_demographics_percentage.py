import pandas as pd
import numpy as np
import re
import openpyxl as openpyxl
import os
from os import listdir
from pathlib import Path
import geopandas as gpd
from geopandas.tools import sjoin
import sys
import argparse

## Define script-levels args of year
# my_parser = argparse.ArgumentParser(description='Pull a specific ACS year')
# my_parser.add_argument('--dropbox', help = "Path to summer work Dropbox directory")
# my_parser.add_argument('--acsyear', type = int, help = "integer with year of ACS data to pull")
# my_parser.add_argument("--mode", default='client')
# my_parser.add_argument("--port", default=52162)
# args = my_parser.parse_args()
# # DROPBOX_DATA_PATH = args.dropbox
# YEAR = args.acsyear

## define pathnames
# dirname = os.path.dirname(__file__)
# dropbox_general = str(Path(dirname).parents[1])
dropbox_general = "/Users/euniceliu/Dropbox (Dartmouth College)/"
DROPBOX_DATA_PATH = os.path.join(dropbox_general,
                                "qss20_finalproj_rawdata/summerwork/")
DATA_RAW_DIR = os.path.join(DROPBOX_DATA_PATH, "raw/")
DATA_ID_DIR = os.path.join(DROPBOX_DATA_PATH, "intermediate/")
DF_ACS_PATH = os.path.join(DATA_RAW_DIR, "ACS_TRACT_DEMOGRAPHICS/acs_dem_year_" + "2019" + ".pkl")
# DF_ACS_PATH = os.path.join(DATA_RAW_DIR, "ACS_TRACT_DEMOGRAPHICS/acs_dem_year_" + str(YEAR) + ".pkl")
ACS_VARIABLE_PATH = os.path.join(DATA_ID_DIR, "predictors_acs_varname.csv")
H2AJOBS_TRACTS = os.path.join(DATA_ID_DIR, "unique_tracts_withjobs.pkl")

# PREDICTORS_WRITEFOLDER = os.path.join(DATA_RAW_DIR)

## read in data
df_acs = pd.read_pickle(DF_ACS_PATH)
acs_variable = pd.read_csv(ACS_VARIABLE_PATH)

# rj note: error when reading this pkl - see if can have csv or txt
# file of just the geoids of tracts with some h2ajobs
## h2ajobs = pd.read_pickle(H2AJOBS_TRACTS)

print("There are " + str(df_acs.shape[0]) + " rows and " + str(len(df_acs.GEO_ID.unique())) + " unique tracts")

## filter to tracts that have a non_zero count of jobs
h2ajobs = pd.read_pickle(H2AJOBS_TRACTS)
df_acs.GEO_ID.astype("string")
df_acs['GEO_ID'] = df_acs['GEO_ID'].str.replace('1400000US', '')
df_acs['GEO_ID_matches'] = np.where(df_acs.GEO_ID.isin(h2ajobs.GEOID), "MATCH", 'NO_MATCH')
df_acs = df_acs[df_acs["GEO_ID_matches"]=="MATCH"]
df_acs.drop(["GEO_ID_matches"], axis=1, inplace=True)

## predictors dataset cleaning
## first look at intersection between
## the variables and the rownames
## rj note: changed this from the predictors = yes filtering
## since not sure if that was used consistently (eg with the new unemployment ones)
acs_variable['name_edit'] = acs_variable.name.astype(str) + "E"
acs_predictors_pulled = set(df_acs.columns).intersection(set(acs_variable.name_edit))
acs_variable_forcal=acs_variable[acs_variable.name_edit.isin(acs_predictors_pulled)].copy()

## melt demographics to long format
## rj note- added name and geoid here
df_acs_long = pd.melt(df_acs, id_vars=['NAME', 'GEO_ID',
                                    'county', 'state', 'tract']).sort_values(by=['tract', 'county'])

df_acs_long.replace(to_replace=[None], value=np.nan, inplace=True)

## manually indicate which prefix columns don't follow the pattern
varnames_percnotrelevant = ['B05004_001E','B05004_013E','B05004_014E',"B05004_015E","B06011_001E",
                             "B19113_001E","B20004_001E","B22008_001E","B24031_002E","B24041_002E","B24121_017E"]

## create prefix and suffix columns
df_acs_long['variable_prefix'], df_acs_long['variable_suffix'] = df_acs_long['variable'].str.split('_', 1).str
df_acs_long['perc_NA'] = np.where(df_acs_long.variable.isin(varnames_percnotrelevant),
                                  1, 0)

## Merge on the ACS names- one didnt match and we're just dropping in inner join since unimportant
## (something on northern americas)
merged_df_acs = pd.merge(df_acs_long,acs_variable_forcal,left_on='variable',
                         right_on = "name_edit", how='inner')


## post merging cleaning (combining variables' description)
merged_df_acs.label.astype("string")
merged_df_acs.concept.astype("string")
merged_df_acs['label'] = merged_df_acs['label'].str.replace('Estimate!!Total!!', '')
merged_df_acs.drop(["predictors"], axis=1, inplace=True)
cols = ['variable', 'label', 'concept']
merged_df_acs['detailed_varname'] = merged_df_acs[cols].apply(lambda row: '_'.join(row.values.astype(str)), axis=1)

## group by county, tract, and variable prefix to generate
## percentages (and later variable names)
## rj note- switched from grouping by county and tract to geoid since that's the most unique
## might need to drop the county and state columns
df_acs_long_toiterate = merged_df_acs[merged_df_acs.perc_NA == 0].copy()
group_co_tract_varg = df_acs_long_toiterate.groupby(['GEO_ID', 'variable_prefix'])
print(merged_df_acs.columns)
print(df_acs_long_toiterate.head())
################################## Generate percentages: auto-calc #################################


df_acs_long_percentage = []
# flag = 0
for group, data in group_co_tract_varg:
    # if flag > 100: # flag to test code
    #   break
    #     print(data)
    tract = data.tract.iloc[0]
    county = data.county.iloc[0]
    prefix = data.variable_prefix.iloc[0]
    row_list_group = []
    for i in range(1, data.shape[0]):
        numerator = data.value.iloc[i]
        denominator = float(data.value.iloc[0])
        if denominator == 0:
            denominator = np.nan
        if denominator != 0:
            percentage = numerator / denominator
            row = [county, tract, prefix]
            row = row + [data.variable_suffix.iloc[i], percentage]
            row_list_group.append(row)
            # print(row)
            # print(row_list_group)
            # print('___________________________')

    #         break
    df_acs_long_percentage.append(pd.DataFrame(row_list_group))
    # flag = flag + 1

percentages_all_groups = pd.concat(df_acs_long_percentage)
print(percentages_all_groups.head())
percentages_all_groups.columns = ['county', 'tract', 'variable_prefix',
                                  'variable_suffix', 'percentage']

percentages_all_groups['variable_prefix_suffix'] = percentages_all_groups.variable_prefix + "_" + percentages_all_groups.variable_suffix
percentages_all_groups.drop(columns=['variable_prefix', 'variable_suffix'], inplace=True)

####################################### Reshape percentages to wide ##################################

percentages_all_groups['county_tract'] = percentages_all_groups.county.astype(
    str) + "_" + percentages_all_groups.tract.astype(str)

percentages_all_groups.drop(columns=['county', 'tract'], inplace=True)

## try the pivot -- before pivoting, creating county-tract
percentages_wide_pivot = percentages_all_groups.pivot_table(index='county_tract',
                                                      columns='variable_prefix_suffix',
                                                      values='percentage')

percentages_wide_pivot_reset = percentages_wide_pivot.reset_index()

## other cols to drop
percentages_wide_pivot_reset.drop(columns=['B01001_002E',
                                           'B01001_026E'], inplace=True)

####################################### Deal with nonpercentages variables ##################################

## drop and clean cols in nonpercentage variables
non_percentage_df_acs = df_acs_long[df_acs_long.perc_NA == 1].copy()
non_percentage_df_acs['county_tract'] = non_percentage_df_acs.county.astype(
    str) + "_" + non_percentage_df_acs.tract.astype(str)
non_percentage_df_acs = non_percentage_df_acs[non_percentage_df_acs.columns[non_percentage_df_acs.columns.isin(['county_tract', 'variable', "value"])]]
non_percentage_df_acs_beforenpnan = non_percentage_df_acs.copy()

## code <0 nonpercentage variables to np.nan
non_percentage_df_acs["value"] = pd.to_numeric(non_percentage_df_acs["value"], downcast="float")
non_percentage_df_acs["value"] = np.where((non_percentage_df_acs["value"]< 0), np.nan, non_percentage_df_acs["value"])
# non_percentage_df_acs['value'] = non_percentage_df_acs['value'].apply(lambda x : x if x > 0 else np.nan)
# non_percentage_df_acs.loc[~(non_percentage_df_acs['value'] > 0), 'value']=np.nan

## pivot long format nonpercentage variables to wide format
nonpercentages_wide_pivot = non_percentage_df_acs.pivot_table(index='county_tract',
                                                      columns='variable',
                                                      values='value')
nonpercentages_wide_pivot_reset = nonpercentages_wide_pivot.reset_index()


## check shape of nonpercentage and percentage data
print("nonpercentages_wide_pivot_reset shape")
print(nonpercentages_wide_pivot_reset.shape)
print("percentages_wide_pivot_reset shape")
print(percentages_wide_pivot_reset.shape)

## check what is lost in percentage/nonpercentage
# not_in_percentage_tract = nonpercentages_wide_pivot_reset.merge(non_percentage_df_acs_beforenpnan_pivot_reset, how = 'outer',indicator=True, on="county_tract").loc[lambda x : x['_merge']=='right_only']
# not_in_percentage_tract
# with pd.option_context('display.max_rows', None, 'display.max_columns', None):  # more options can be specified also
#     print(not_in_percentage_tract)

####################################### Merge percentage with nonpercentage variables ##################################
final_merge = nonpercentages_wide_pivot_reset.merge(percentages_wide_pivot_reset, how = 'left', on= "county_tract")
print("find merge shape")
print(final_merge.shape)

####################################### Find and add back missing tract ##################################

## find missing tract
## Note: the initial job data only has geo_id so in order to only retain county and tract number (final merge data doesnt have geo_id), the state code is stripped
h2ajobs["countytract"]= h2ajobs.GEOID.astype("string").str.strip().str[2:]
final_merge["countytract"]=final_merge.county_tract.astype("string").str.replace('_', '')
h2ajobs_tract=h2ajobs["countytract"].tolist()
final_merge_tract=final_merge["countytract"].tolist()
missing_tract = set(h2ajobs_tract).difference(final_merge_tract)

## pre-adding cleaning
final_merge=final_merge.drop(columns=["countytract"])
# add back the underscore for county_tract for later merging purposes
missing_tract=[s[:3] + '_' + s[3:] for s in missing_tract]
percentages_wide_pivot_reset['county_tract'].astype("string")
# if missing tract occurs in percentage data
missing_tract_inpercentage=percentages_wide_pivot_reset[percentages_wide_pivot_reset['county_tract'].isin(missing_tract)]
# if missing tract occurs in nonpercentage data
missing_tract_innonpercentage=nonpercentages_wide_pivot_reset[nonpercentages_wide_pivot_reset['county_tract'].isin(missing_tract)]

missing_tract_innonpercentage.empty
missing_tract_inpercentage.empty

## add back missing tract in the final percentage/nonpercentage data
def add_missing_tract():
    ## in the final merge's missing tracts compared to the job data, those missing tracts have percentage data
    ## and nonpercentage data
    if missing_tract_innonpercentage.empty is not True & missing_tract_inpercentage.empty is not True:
        missing_tract_var = pd.DataFrame(columns=final_merge.columns)
        tract_add_back = {'county_tract': missing_tract}
        missing_tract_var = missing_tract_var.append(pd.DataFrame(tract_add_back))
        missing_tract_var = pd.concat([missing_tract_var, missing_tract_inpercentage, missing_tract_innonpercentage])
        missing_tract_var=missing_tract_var.county_tract.drop_duplicates(keep="last")
        final_merge_with_missing = pd.concat([final_merge, missing_tract_var])
        return final_merge_with_missing
    ## in the final merge's missing tracts compared to the job data, those missing tracts have percentage data
    ## but not nonpercentage data (which is the case for 2014 data)
    if missing_tract_innonpercentage.empty is True & missing_tract_inpercentage.empty is not True:
        missing_tract_var = pd.DataFrame(columns=final_merge.columns)
        tract_add_back = {'county_tract': missing_tract}
        missing_tract_var = missing_tract_var.append(pd.DataFrame(tract_add_back))
        missing_tract_var = pd.concat([missing_tract_var, missing_tract_inpercentage])
        missing_tract_var=missing_tract_var.county_tract.drop_duplicates(keep="last")
        final_merge_with_missing = pd.concat([final_merge, missing_tract_var])
        return final_merge_with_missing
    ## in the final merge's missing tracts compared to the job data, those missing tracts have nonpercentage data
    ## but not percentage data
    if missing_tract_innonpercentage.empty is not True & missing_tract_inpercentage.empty is True:
        missing_tract_var = pd.DataFrame(columns=final_merge.columns)
        tract_add_back = {'county_tract': missing_tract}
        missing_tract_var = missing_tract_var.append(pd.DataFrame(tract_add_back))
        missing_tract_var = pd.concat([missing_tract_var, missing_tract_innonpercentage])
        missing_tract_var=missing_tract_var.county_tract.drop_duplicates(keep="last")
        final_merge_with_missing = pd.concat([final_merge, missing_tract_var])
        return final_merge_with_missing
    ## those missing tract does not exist in both percentage and nonpercentage data
    else:
        missing_tract_var = pd.DataFrame(columns=final_merge.columns)
        tract_add_back = {'county_tract':missing_tract}
        missing_tract_var = missing_tract_var.append(pd.DataFrame(tract_add_back))
        final_merge_with_missing = pd.concat([final_merge, missing_tract_var])
        return final_merge_with_missing

final_merge_with_missing = add_missing_tract()

## test: should be 6105 rows for 2014 data


## write final dataframe to pick
final_merge_with_missing.to_pickle("/Users/euniceliu/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork/intermediate/acs_tract_percentage_2019.pkl")

# final_merge_with_missing.to_pickle(PREDICTORS_WRITEFOLDER + "acs_tract_percentage" + str(YEAR) + ".pkl")
