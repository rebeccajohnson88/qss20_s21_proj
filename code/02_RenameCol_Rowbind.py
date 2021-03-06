# script that builds on the column diagnostic code to rename cols as needed in order to to reconcile across years and then rowbinds the 2014-2021 datasets.

# load necessary packages

import pandas as pd
import openpyxl as openpyxl
import os
from os import listdir
from pathlib import Path
import re
import numpy as np

dirname = os.path.dirname(__file__)
dropbox_general = str(Path(dirname).parents[1])
DROPBOX_DATA_PATH = os.path.join(dropbox_general, 
                                 "qss20_finalproj_rawdata/summerwork/") 
DROPBOX_RAW_PATH = os.path.join(DROPBOX_DATA_PATH,
                                "raw/")
DROPBOX_INT_PATH = os.path.join(DROPBOX_DATA_PATH,
                                "intermediate/")  
all_disclosure_files = [file for file in listdir(DROPBOX_RAW_PATH) if
                        "H_2A_Disclosure_Data" in file]


## Read in datasets (storing in dictionary with key as year)
disc_files = {}
for file in all_disclosure_files:
    key_name = "df_" + re.findall("20[0-9][0-9]", file)[0]
    print("Reading file: " + file)
    disc_files[key_name] = pd.read_excel(DROPBOX_RAW_PATH + file)
    

# combine into a list
df_2014 = disc_files['df_2014']
df_2014['data_source'] = "file_2014"
df_2015 = disc_files['df_2015']
df_2015['data_source'] = "file_2015"
df_2016 = disc_files['df_2016'] 
df_2016['data_source'] = "file_2016"
df_2017 = disc_files['df_2017']
df_2017['data_source'] = "file_2017"
df_2018 = disc_files['df_2018']
df_2018['data_source'] = "file_2018"
df_2019 = disc_files['df_2019'] 
df_2019['data_source'] = "file_2019"
df_2020 = disc_files['df_2020']
df_2020['data_source'] = "file_2020"
df_2021 = disc_files['df_2021']
df_2021['data_source'] = "file_2021"


full_data = [df_2014, df_2015, df_2016, df_2017, df_2018, df_2019, df_2020, df_2021]

#print(full_data[0].head())
## get and print intersecting columns (before rename)
colnames = [set(df_2014.columns), set(df_2015.columns), set(df_2016.columns), set(df_2017.columns), set(df_2018.columns), set(df_2019.columns), set(df_2020.columns), set(df_2021.columns)]
intersecting_cols = list(set.intersection(*colnames))
print("Intersecting columns: " + str(intersecting_cols))

# ## Multiple years' rename
# # rename CASE_NO to CASE_NUMBER & PRIMARY/SUB and PRMARY/SUB to PRIMARY_SUB & NAIC_CODE to NAICS_CODE & AGENT_ATTORNEY_NAME to ATTORNEY_AGENT_NAME &
# # AGENT_ATTORNEY_CITY to ATTORNEY_AGENT_CITY & AGENT_ATTORNEY_STATE to ATTORNEY_AGENT_STATE
for df in full_data:
    df=df.rename(columns={"CASE_NO": "CASE_NUMBER", "PRIMARY/SUB": "PRIMARY_SUB", "PRMARY/SUB": "PRIMARY_SUB", "NAIC_CODE": "NAICS_CODE"
                          ,"AGENT_ATTORNEY_CITY":"ATTORNEY_AGENT_CITY", "AGENT_ATTORNEY_STATE":"ATTORNEY_AGENT_STATE",
                          "AGENT_ATTORNEY_NAME":"ATTORNEY_AGENT_NAME"}, inplace=True)

## Specific year rename
# rename MEALS_CHARGE to MEALS_CHARGED & HOURLY_SCHEDULE_BEGIN to HOURLY_WORK_SCHEDULE_START & HOURLY_SCHEDULE_END to HOURLY_WORK_SCHEDULE_END & TOTAL_WORKSITES_RECORDS to TOTAL_WORKSITE_RECORDS for 2021 data to match 2020 data
# (note: 'MEALS_PROVIDED'& 'MEALS_CHARGED' columns only start to exist from 2020 which can potentially show
# the lack of care in workers' basic needs in previous years; however, it might need further investigation...)
df_2021.rename(columns={"MEALS_CHARGE": "MEALS_CHARGED", "HOURLY_SCHEDULE_BEGIN":"HOURLY_WORK_SCHEDULE_START", "HOURLY_SCHEDULE_END":"HOURLY_WORK_SCHEDULE_END", "TOTAL_WORKSITES_RECORDS":"TOTAL_WORKSITE_RECORDS"}, inplace=True)

# rename FULL_TIME to FULL_TIME_POSITION for 2018 data
# (note: this specific column doesnt seem to occur from 2020 onwards)
df_2018.rename(columns={"FULL_TIME": "FULL_TIME_POSITION"}, inplace=True)

# # rename EMPLOYER_REP_BY_AGENT to AGENT_POC_EMPLOYER_REP_BY_AGENT for 2019 data
df_2019.rename(columns={"EMPLOYER_REP_BY_AGENT": "AGENT_POC_EMPLOYER_REP_BY_AGENT"}, inplace=True)

# remane WORKSITE_LOCATION_CITY to WORKSITE_CITY & WORKSITE_LOCATION_STATE to WORKSITE_STATE for 2014 data
# (note: WORKSITE_COUNTY info starts being include from 2017 onwards)
df_2014.rename(columns={"WORKSITE_LOCATION_CITY": "WORKSITE_CITY", "WORKSITE_LOCATION_STATE": "WORKSITE_STATE","SOC_CODE_ID":"SOC_CODE"}, inplace=True)

## check similarity between attorney information col
attorney2019 = [col for col in df_2019.columns if 'ATTORNEY' in col]
attorney2020 = [col for col in df_2020.columns if 'ATTORNEY' in col]
print("attorney related col in 2019 data:" + str(attorney2019))
print("attorney related col in 2020 data:" + str(attorney2020))

## combine Attroney First Name, Middle Name and Last Name into a single name for 2020 and 2021 data (in order to match the column from 2014-2019)
df_2020['ATTORNEY_AGENT_NAME'] = df_2020[['ATTORNEY_AGENT_FIRST_NAME', 'ATTORNEY_AGENT_MIDDLE_NAME', 'ATTORNEY_AGENT_LAST_NAME']].fillna('').agg(' '.join, axis=1)
df_2021['ATTORNEY_AGENT_NAME'] = df_2021[['ATTORNEY_AGENT_FIRST_NAME', 'ATTORNEY_AGENT_MIDDLE_NAME', 'ATTORNEY_AGENT_LAST_NAME']].fillna('').agg(' '.join, axis=1)

## (retain all rows for now but prob in the furture): delete ATTORNEY_AGENT_FIRST_NAME,ATTORNEY_AGENT_MIDDLE_NAME,ATTORNEY_AGENT_LAST_NAME col in 2020 and 2021 data
# df_2020.drop(['ATTORNEY_AGENT_FIRST_NAME',"ATTORNEY_AGENT_MIDDLE_NAME","ATTORNEY_AGENT_LAST_NAME"] ,axis=1, inplace=True)
# df_2021.drop(['ATTORNEY_AGENT_FIRST_NAME',"ATTORNEY_AGENT_MIDDLE_NAME","ATTORNEY_AGENT_LAST_NAME" ],axis=1, inplace=True)

## rename employer address columns
## df_2014-19 - employer_address1
## df_2020 and 2021: employer_address_1
df_2020.rename(columns = {'EMPLOYER_ADDRESS_1': 'EMPLOYER_ADDRESS1'}, inplace = True)
df_2021.rename(columns = {'EMPLOYER_ADDRESS_1': 'EMPLOYER_ADDRESS1'}, inplace = True)


## next to try to add back the job start and end date- pre-2020 it's 
## JOB_START_DATE and JOB_END_DATE
## after 2020 it becomes EMPLOYMENT_END_DATE AND EMPLOYMENT_START_DATE
## so rename those 
df_2020.rename(columns = {'REQUESTED_BEGIN_DATE': 'REQUESTED_START_DATE_OF_NEED',
                          'REQUESTED_END_DATE' : 'REQUESTED_END_DATE_OF_NEED',
                          'EMPLOYMENT_BEGIN_DATE': 'JOB_START_DATE',
                          'EMPLOYMENT_END_DATE': 'JOB_END_DATE'}, inplace = True)
df_2021.rename(columns = {'REQUESTED_BEGIN_DATE': 'REQUESTED_START_DATE_OF_NEED',
                          'REQUESTED_END_DATE' : 'REQUESTED_END_DATE_OF_NEED',
                          'EMPLOYMENT_BEGIN_DATE': 'JOB_START_DATE',
                          'EMPLOYMENT_END_DATE': 'JOB_END_DATE'}, inplace = True)
df_2014.rename(columns = {'CERTIFICATION_BEGIN_DATE': 'JOB_START_DATE',
                          'CERTIFICATION_END_DATE': 'JOB_END_DATE'}, inplace = True)
df_2015['REQUESTED_START_DATE_OF_NEED'] = np.nan
df_2015['REQUESTED_END_DATE_OF_NEED'] = np.nan


## compare intersecting columns (before and after rename)
colnames_rename = [set(df_2014.columns), set(df_2015.columns), set(df_2016.columns), set(df_2017.columns), 
                   set(df_2018.columns), set(df_2019.columns), set(df_2020.columns), set(df_2021.columns)]
intersecting_cols_rename = list(set.intersection(*colnames_rename))
print("Originally there are " + str(len(intersecting_cols)) +" intersecting columns. After renaming and cleaning, there are " + str(len(intersecting_cols_rename)) + " intersecting columns." )

## rowbind 2014-2021 H-2A data
## add indicator for what disclosure file it came from
h2a_combined_fillblanks = pd.concat([df_2014, df_2015, df_2016, df_2017, df_2018, df_2019, df_2020, df_2021])
print(h2a_combined_fillblanks.head())
pd.set_option('display.max_columns', None)
#print("Combined datasets' columns: " + str(h2a_combined_fillblanks.columns.tolist()))

## Write different forms of the data
h2a_combined_commoncols = h2a_combined_fillblanks[intersecting_cols_rename].copy()
print(h2a_combined_commoncols.head()) 
print("Combined datasets' columns that are non-blank are: " + str(h2a_combined_commoncols.columns.tolist()))

## get intersecting columns just for 2020 and 2021
intersect_2021 = list(set(df_2020.columns).intersection(df_2021.columns)) 
h2a_combined_20202021 = pd.concat([df_2020, df_2021]) 
h2a_combined_20202021_int = h2a_combined_20202021[intersect_2021].copy()


## write different files
### file set 1: jobs data across years restricted to columns common across years
h2a_combined_commoncols.to_csv(DROPBOX_INT_PATH + "h2a_combined_2014-2021.csv",
                        index = False)
h2a_combined_commoncols.to_pickle(DROPBOX_INT_PATH + "h2a_combined_2014-2021.pkl")

### file set 2: jobs data just 2020 and 2021 (since many more columns)
h2a_combined_20202021_int.to_csv(DROPBOX_INT_PATH + "h2a_combined_2020-2021.csv",
                        index = False)
h2a_combined_20202021_int.to_pickle(DROPBOX_INT_PATH + "h2a_combined_2020-2021.pkl")

## file set 3: jobs data all years/all columns (fills ones that don't exist with NA)
h2a_combined_fillblanks.to_csv(DROPBOX_INT_PATH + "h2a_combined_2014-2021_preserveallcols.csv",
                        index = False)
h2a_combined_fillblanks.to_pickle(DROPBOX_INT_PATH + "h2a_combined_2014-2021_preserveallcols.pkl")




# =============================================================================


