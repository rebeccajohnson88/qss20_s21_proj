import pandas as pd
import numpy as np
import re
import openpyxl as openpyxl
import os
from os import listdir
from pathlib import Path
import geopandas as gpd
from geopandas.tools import sjoin



## define pathnames
#dirname = os.path.dirname(__file__)
#dropbox_general = str(Path(dirname).parents[1])
dropbox_general = "/Users/rebeccajohnson/Dropbox/"
DROPBOX_DATA_PATH = os.path.join(dropbox_general, 
                                "qss20_finalproj_rawdata/summerwork/") 
DATA_RAW_DIR = os.path.join(DROPBOX_DATA_PATH, "raw/")
DATA_ID_DIR = os.path.join(DROPBOX_DATA_PATH, "intermediate/")
DF_ACS_PATH = os.path.join(DATA_RAW_DIR, "ACS_TRACT_DEMOGRAPHICS/acs_dem_year_2014.pkl")
ACS_VARIABLE_PATH = os.path.join(DATA_ID_DIR, "predictors_acs_varname.csv")
H2AJOBS_TRACTS = os.path.join(DATA_ID_DIR, "h2a_tract_intersections.pkl")
print(H2AJOBS_TRACTS)


## read in data
df_acs = pd.read_pickle(DF_ACS_PATH)
acs_variable = pd.read_csv(ACS_VARIABLE_PATH)


# rj note: error when reading this pkl - see if can have csv or txt
# file of just the geoids of tracts with some h2ajobs 
## h2ajobs = pd.read_pickle(H2AJOBS_TRACTS)

print("There are " + str(df_acs.shape[0]) + " rows and " + str(len(df_acs.GEO_ID.unique())) + " unique tracts")

## filter to tracts that have a non_zero count of jobs


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

## create a flag of ones that we want to keep but that
## percentages are not relevant for
#acs_variable_forcal["drop_forperc"]=np.where(acs_variable_forcal.name_edit.isin(varnames_percnotrelevant),
 #                                 1, 0)

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
group_co_tract_varg = df_acs_long_toiterate.groupby(['GEOID', 'variable_prefix'])
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
percentages_all_groups.columns = ['county', 'tract', 'variable_prefix',
                                  'variable_suffix', 'percentage']

percentages_all_groups['variable_prefix_suffix'] = percentages_all_groups.variable_prefix + "_" + percentages_all_groups.variable_suffix
percentages_all_groups.drop(columns=['variable_prefix', 'variable_suffix'], inplace=True)

####################################### Reshape percentages to wide ##################################

## subset to a few counties/tract (so even row numbers for wide reshape) (remove after testing)

### commented out testing code
## test_forwide = percentages_all_groups[(percentages_all_groups.county == 5) &
##                                   (percentages_all_groups.tract.isin([100, 200, 400]))].copy()

percentages_all_groups['county_tract'] = percentages_all_groups.county.astype(
    str) + "_" + percentages_all_groups.tract.astype(str)

percentages_all_groups.drop(columns=['county', 'tract'], inplace=True)

## try the pivot -- before pivoting, creating county-tract
percentages_wide_pivot = percentages_all_groups.pivot(index='county_tract',
                                                      columns='variable_prefix_suffix',
                                                      values='percentage')

percentages_wide_pivot_reset = percentages_wide_pivot.reset_index()

## other cols to drop
percentages_wide_pivot_reset.drop(columns=['b01001_002e',
                                           'b01001_026e'], inplace=True)
