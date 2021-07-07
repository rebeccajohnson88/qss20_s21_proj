
##################
# Script to load ACS variables at tract level
# Authors: EL, GA, RJ
##################

############## Imports and functions
from census import Census
import pandas as pd
import os
from os import listdir
from pathlib import Path
import time
import sys
import argparse


## Define script-levels args of year
my_parser = argparse.ArgumentParser(description='Pull a specific ACS year')
my_parser.add_argument('--dropbox', help = "Path to summer work Dropbox directory")
my_parser.add_argument('--acsyear', type = int, help = "integer with year of ACS data to pull")
args = my_parser.parse_args()
#DROPBOX_DATA_PATH = my_parser.parse_args(sys.argv[1:]).DROPBOX_DIR
#YEAR = my_parser.parse_args(sys.argv[1:]).YEAR
DROPBOX_DATA_PATH = args.dropbox
YEAR = args.acsyear
#print(DROPBOX_DATA_PATH)
#print(YEAR)



## Define pathnames
# =============================================================================
# dirname = os.path.dirname(__file__)
# dropbox_general = str(Path(dirname).parents[1])
# DROPBOX_DATA_PATH = os.path.join(dropbox_general, 
#                                  "qss20_finalproj_rawdata/summerwork/") 
# =============================================================================
DROPBOX_RAW_PATH = os.path.join(DROPBOX_DATA_PATH,
                                "raw/")
DROPBOX_INT_PATH = os.path.join(DROPBOX_DATA_PATH,
                                "intermediate/")
ACS_PREDICTORS_FILENAME = "predictors_acs_varname.csv"
ACS_PREDICTORS_PATHNAME = os.path.join(DROPBOX_INT_PATH,
                                       ACS_PREDICTORS_FILENAME)
print(ACS_PREDICTORS_PATHNAME)
ACS_WRITEFOLDER = os.path.join(DROPBOX_RAW_PATH, "ACS_TRACT_DEMOGRAPHICS")
TESTING_PULL = True 





## API key 
censuskey = "8105419cada33ca0aaa48b111b8c44b9484e286a"
c = Census(censuskey)

def demographics(variables_list, fips_list, year = YEAR):
    
    list_of_dfs = [pd.DataFrame(c.acs5.state_county_tract(variables_list,
                                                          state_fips=fip,
                                                          year = year,
                                                          county_fips=Census.ALL,
                                                          tract=Census.ALL))
                   for fip in fips_list]
    
    full_df = pd.concat(list_of_dfs)
                   
    return full_df



############## Load and clean state FIPS codes
fips_url = 'https://gist.githubusercontent.com/dantonnoriega/bf1acd2290e15b91e6710b6fd3be0a53/raw/11d15233327c8080c9646c7e1f23052659db251d/us-state-ansi-fips.csv'

state_fips = pd.read_csv(fips_url)
state_fips = state_fips.rename(columns = {'stname': 'name', ' st': 'fip', ' stusps': 'abbr'})

fips = state_fips['fip'].astype(str)
if TESTING_PULL:
    fips_list = fips[0]
else:
    fips_list = fips


# In[4]:


for i in range(0, len(fips)):
    if len(fips[i]) < 2:
        fips[i] = '0' + fips[i]


############## Load data with names of ACS variables 
variables_df = pd.read_csv(ACS_PREDICTORS_PATHNAME)
print("Read in list of ACS predictors")

variables_df = variables_df[variables_df.predictors == 'yes']

variables_list = variables_df.name.to_list()

variables_list = [x + 'E' for x in variables_list]


variables_list.remove('yE')

variables_list = ['NAME', 'B05006_123E'] + variables_list



############# Use Census API to pull at the tract level for all fips codes
start_pull = time.time()
print("starting ACS pull at: " + str(start_pull))

all_dem = demographics(variables_list, fips_list = fips_list)
end_pull = time.time()
print("finished pull at: " + str(end_pull))

all_dem.to_pickle(ACS_WRITEFOLDER + "acs_dem_year" + str(YEAR) + ".pkl")
print("wrote pull")




