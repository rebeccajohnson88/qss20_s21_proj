from math import isnan
import timeit
import os
import pickle5 as pickle
import pandas as pd
import clients
from geocodio import GeocodioClient
import clients
import datetime



## keys
key = "a00cb79ec4f97e6760c49740b8ea7a7be6b77bb"
client = GeocodioClient(key)

## Define pathname parameter
## going two-levels up from the current directory which is nested within Dropbox
DROPBOX_INT_PATH = "../../qss20_finalproj_rawdata/summerwork/intermediate/"
DATA_FILE_NAME = "h2a_combined_2014-2021.pkl"
DATA_FILE_PATH = os.path.join(DROPBOX_INT_PATH, DATA_FILE_NAME)
###### local path for testing
DATA_FILE_PATH = "/Users/Firstclass/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork/intermediate/h2a_combined_2014-2021.pkl"



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


def split_into_parts(a_list, max_items_per_part):
    if len(a_list) < max_items_per_part:
        return [a_list]
    else:
        num_parts = len(a_list) // max_items_per_part
        res = []
        start = 0
        end = max_items_per_part
        for num in range(num_parts):
            res.append(a_list[start:end])

            if num != num_parts - 1:
                start += max_items_per_part
                end += max_items_per_part

        res.append(a_list[end:])
        return res


def geocode_table(df, testing=True, test_size=100):
    print(f"Geocoding start...")

    start = timeit.default_timer()

    if not df.empty:
        # for testing geocoding runtime, geocode the first 100 rows
        if testing:
            print(f"This is a test, sample size is {test_size}")
            df = df[:test_size]

        addresses = df.apply(
        lambda df2: create_address_from(df2["EMPLOYER_ADDRESS1"], df2["EMPLOYER_CITY"], df2["EMPLOYER_STATE"], df2["EMPLOYER_POSTAL_CODE"]), axis=1).tolist()
        df[f"EMPLOYER_FULLADDRESS"] = addresses

        dedup_addr = list(set(addresses))
        print (f"length of original: {len(addresses)}")
        print (f"after removing duplicates : {len(dedup_addr)}")

        addresses_split = split_into_parts(dedup_addr, 9999)
        geocoding_results = []
        for these_addresses in addresses_split:
            if(len(these_addresses)>0):
                geocoding_results += client.geocode(these_addresses)
        assert len(geocoding_results) == len(dedup_addr)

        df_addr = pd.DataFrame(dedup_addr,columns =['EMPLOYER_FULLADDRESS'])
        latitudes, longitudes, accuracies, accuracy_types, i = [], [], [], [], 0
        for result in geocoding_results:
            try:
                results = result['results'][0]
                accuracies.append(results['accuracy'])
                accuracy_types.append(results['accuracy_type'])
                latitudes.append(results['location']['lat'])
                longitudes.append(results['location']['lng'])
            except:
                accuracies.append(None)
                accuracy_types.append(None)
                latitudes.append(None)
                longitudes.append(None)
            i += 1

        #i = len(df.columns)
        df_addr[f"geo_lat"] = latitudes
        df_addr[f"geo_long"] = longitudes
        df_addr[f"geo_accuracy"] = accuracies
        df_addr[f"geo_accuracy_type"] = accuracy_types

    dfinal = pd.merge(df, df_addr, on="EMPLOYER_FULLADDRESS", how="left")
    dfinal = dfinal.set_index(df.index)

    stop = timeit.default_timer()
    print('Runtime (sec): ', stop - start)

    return dfinal

## Read in data
# using relative path name
print("Read in h2a data...")
with open(DATA_FILE_PATH, "rb") as df:
  h2a_data = pickle.load(df)

print(len(h2a_data))

# testing
print("Testing with 100 samples:")
#test_df1 = geocode_table(h2a_data)
print("Testing with larger samples:")
test_df2 = geocode_table(h2a_data, testing=False) # 10000 samples, time used:  294.22878647100003 sec

DATA_SAVE_PATH = "/Users/Firstclass/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork/intermediate/h2a_combined_2014-2021_geocoded.pkl"

with open(DATA_SAVE_PATH, "wb") as name:
    pickle.dump(test_df2, name)
name.close()

test_df2.to_csv("h2a_combined_2014-2021_geocoded.csv", encoding='utf-8', index=False)