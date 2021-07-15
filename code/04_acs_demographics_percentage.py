import pandas as pd
import numpy as np
import re
import openpyxl as openpyxl
import os
from os import listdir
from pathlib import Path
import re
import numpy as np

## file path
data_raw_dir = '../../qss20_finalproj_rawdata/summerwork/raw/'
data_id_dir = '../../qss20_finalproj_rawdata/summerwork/intermediate/'
df_acs_path = data_raw_dir + "ACS_TRACT_DEMOGRAPHICSacs_dem_year2014.pkl"
df_acs = pd.read_pickle(df_acs_path)
acs_variable_path = data_id_dir + "predictors_acs_varname.csv"
acs_variable = pd.read_csv(acs_variable_path)

## predictors dataset cleaning
acs_variable_forcal=acs_variable[acs_variable.predictors=="yes"]
acs_variable_forcal['name_edit'] = acs_variable_forcal['name'].astype("string")+"E"

## melt to long format
df_acs_long = pd.melt(df_acs, id_vars=['county', 'state', 'tract']).sort_values(by=['tract', 'county'])
df_acs_long.replace(to_replace=[None], value=np.nan, inplace=True)
df_acs_long.shape[0] #13734528 rows

## manually indicate which prefix columns don't follow the pattern
prefixes_perc_notrelevant = ['B05004_001E','B05004_013E','B05004_014E',"B05004_015E","B06011_001E","B19113_001E","B20004_001E","B22008_001E","B24031_002E","B24041_002E","B24121_017E"]

## filter acs_variable_forcal to only exclude the predictors relevant
acs_variable_forcal["keep"]=np.where(acs_variable_forcal.name_edit.isin(prefixes_perc_notrelevant),
                                  1, 0)
acs_variable_forcal=acs_variable_forcal[acs_variable_forcal.keep==0]
variable_tokeep= acs_variable_forcal.name_edit.tolist()

## filter df_acs_long to only retain variables that are predictors
df_acs_long.variable.astype("string")
df_acs_long["maintain"]=np.where(df_acs_long.variable.isin(variable_tokeep),
                                  1, 0)
df_acs_long=df_acs_long[df_acs_long.maintain==1]
# df_acs_long.shape[0] #12857856 rows

## create prefix and suffix columns
df_acs_long['variable_prefix'], df_acs_long['variable_suffix'] = df_acs_long['variable'].str.split('_', 1).str
df_acs_long['perc_NA'] = np.where(df_acs_long.variable_prefix.isin(prefixes_perc_notrelevant),
                                  1, 0)

prefixes_perc_extrahier = ['B25026', 'B25123']
df_acs_long['perc_extrahier'] = np.where(df_acs_long.variable_prefix.isin(prefixes_perc_extrahier),
                                         1, 0)

## group by county, tract, and variable prefix to generate
## percentages (and later variable names)
df_acs_long_toiterate = df_acs_long[df_acs_long.perc_NA == 0].copy()
group_co_tract_varg = df_acs_long_toiterate.groupby(['county', 'tract', 'variable_prefix'])
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
