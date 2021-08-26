from math import isnan
import timeit
import os
import pandas as pd
import datetime



## Functions define
def create_address_from(address, city, state, zip):
    return handle_null(address) + ", " + handle_null(city) + " " + handle_null(state) + " " + handle_null(str(zip))


def handle_null(object):
    if isinstance(object, float):
        if object < 0:
            return ""
    elif isinstance(object, datetime.date):
        return ""
    elif isinstance(object, int):
        if object < 0:
            return""
    elif len(object) == 0:
        return ""

    return str(object)


## Read in data and create address
BASE_DIR = "/Users/rebeccajohnson/Dropbox/qss20_finalproj_rawdata/summerwork/"
df_matched = pd.read_csv(BASE_DIR + "intermediate/final_df.csv")

addresses = df_matched.apply(
        lambda df2: create_address_from(df2["EMPLOYER_ADDRESS1"], df2["EMPLOYER_CITY"], 
                    df2["EMPLOYER_STATE"], df2["EMPLOYER_POSTAL_CODE"]), axis=1).tolist()

df_matched[f"EMPLOYER_FULLADDRESS"] = addresses


df_matched.to_csv(BASE_DIR + "clean/h2a_WHD_matched.csv", encoding='utf-8', index=False)