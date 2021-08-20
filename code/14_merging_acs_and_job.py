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

## define pathnames
dropbox_general = "/Users/euniceliu/Dropbox (Dartmouth College)/"
DROPBOX_DATA_PATH = os.path.join(dropbox_general,
                                "qss20_finalproj_rawdata/summerwork/")
DATA_RAW_DIR = os.path.join(DROPBOX_DATA_PATH, "raw/")
DATA_ID_DIR = os.path.join(DROPBOX_DATA_PATH, "intermediate/")
PREDICTORS_WRITEFOLDER = os.path.join(DATA_ID_DIR)
JOBS_INTERSECT_PATH = os.path.join(DATA_ID_DIR, "h2a_tract_intersections.pkl")
DF_ACS_PATH_2014 = os.path.join(DATA_ID_DIR, "acs_tract_percentage2014.pkl")
DF_ACS_PATH_2015 = os.path.join(DATA_ID_DIR, "acs_tract_percentage2015.pkl")
DF_ACS_PATH_2016 = os.path.join(DATA_ID_DIR, "acs_tract_percentage2016.pkl")
DF_ACS_PATH_2017 = os.path.join(DATA_ID_DIR, "acs_tract_percentage2017.pkl")
DF_ACS_PATH_2018 = os.path.join(DATA_ID_DIR, "acs_tract_percentage2018.pkl")
DF_ACS_PATH_2019 = os.path.join(DATA_ID_DIR, "acs_tract_percentage2019.pkl")

## read in dataset
tract_intersect_id = pd.read_pickle(JOBS_INTERSECT_PATH)
df_acs_2014 = pd.read_pickle(DF_ACS_PATH_2014)
df_acs_2015 = pd.read_pickle(DF_ACS_PATH_2015)
df_acs_2016 = pd.read_pickle(DF_ACS_PATH_2016)
df_acs_2017 = pd.read_pickle(DF_ACS_PATH_2017)
df_acs_2018 = pd.read_pickle(DF_ACS_PATH_2018)
df_acs_2019 = pd.read_pickle(DF_ACS_PATH_2019)

## add year's column
df_acs_2014['data_source']='file_2014'
df_acs_2015['data_source']='file_2015'
df_acs_2016['data_source']='file_2016'
df_acs_2017['data_source']='file_2017'
df_acs_2018['data_source']='file_2018'
df_acs_2019['data_source']='file_2019'

## rename GEOID to GEO_ID in job tract data for merging purpose
tract_intersect_id = tract_intersect_id.rename(columns={'GEOID': 'GEO_ID'})

## drop columns in job tract data
tract_intersect_id.drop(["geo_lat","geo_long", "geo_accuracy", "geo_accuracy_type", "geometry", "index_right", "INTPTLAT", "INTPTLON" ,"AWATER","ALAND"], axis=1, inplace=True)

## merge 2014-2019 acs data
combined_acs = pd.concat([df_acs_2014, df_acs_2015, df_acs_2016, df_acs_2017, df_acs_2018, df_acs_2019])
job_with_acs = tract_intersect_id.merge(combined_acs, on= ["data_source", "GEO_ID"], how="left")
# job_with_acs.shape
job_with_acs.to_pickle(PREDICTORS_WRITEFOLDER + "job_combined_acs_premerging" + ".pkl")
