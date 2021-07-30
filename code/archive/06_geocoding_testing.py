from math import isnan
import timeit
import os
import pickle
import pandas as pd
from geocodio import GeocodioClient


## keys
key = "a00cb79ec4f97e6760c49740b8ea7a7be6b77bb"
client = GeocodioClient(key)

## Define pathname parameter
## going two-levels up from the current directory which is nested within Dropbox
DROPBOX_INT_PATH = "../../qss20_finalproj_rawdata/summerwork/intermediate/"
DATA_FILE_NAME = "h2a_combined_2014-2021.pkl"
DATA_FILE_PATH = os.path.join(DROPBOX_INT_PATH, DATA_FILE_NAME)


## Functions define
def create_address_from(address, city, state, zip):
    return handle_null(address) + ", " + handle_null(city) + " " + handle_null(state) + " " + handle_null(str(zip))


def handle_null(object):
    if len(object) == 0:
        return ""
    else:
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


def geocode_table(df, testing=True):
    print(f"Geocoding start...")

    start = timeit.default_timer()

    if not df.empty:
        # for testing geocoding runtime, geocode the first 100 rows
        if testing:
            df = df[:100]

        addresses = df.apply(
        lambda df2: create_address_from(df2["EMPLOYER_ADDRESS1"], df2["EMPLOYER_CITY"], df2["EMPLOYER_STATE"],
                                        df2["EMPLOYER_POSTAL_CODE"]), axis=1).tolist()

        addresses_split = split_into_parts(addresses, 9999)
        geocoding_results = []
        for these_addresses in addresses_split:
            geocoding_results += client.geocode(these_addresses)
        assert len(geocoding_results) == len(addresses)

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

        i = len(df.columns)
        df[f"geo_lat"] = latitudes
        df[f"geo_long"] = longitudes
        df[f"geo_accuracy"] = accuracies
        df[f"geo_accuracy_type"] = accuracy_types

    stop = timeit.default_timer()
    print('Time used: ', stop - start)

    return df

## Read in data
h2a_data = pickle.load(open("/Users/Firstclass/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork/intermediate/" + "h2a_combined_2014-2021.pkl", "rb"))
# using relative path name
print("Read in h2a data...")
#h2a_data = pickle.load(open(DATA_FILE_PATH, "rb"))

# testing
test_df = geocode_table(h2a_data)