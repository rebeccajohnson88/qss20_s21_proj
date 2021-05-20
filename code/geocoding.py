from math import isnan
import os
import pandas as pd
from geocodio import GeocodioClient
import requests
import sqlalchemy
from colorama import Fore, Style
from inspect import getframeinfo, stack
import smtplib, ssl
from datetime import datetime
from pytz import timezone
from sqlalchemy import create_engine
from dotenv import load_dotenv
load_dotenv()

geocodio_api_key = os.getenv("GEOCODIO_API_KEY")
client = GeocodioClient(geocodio_api_key)

# geocodes a DataFrame `df`, adding columns for latitude, longitude, accuracy, and accuracy type
# worksite_or_housing is either "worksite" or "housing" and specifies whether to geocode housing or worksite columns
# if `check_previously_geocoded, uses the materialized postgres view `previously_geocoded` to geocode addresses that
# we've already geocoded without using Geocodio so as to save credits
# return the DataFrame with geocoding results columns added
def geocode_table(df, worksite_or_housing, check_previously_geocoded=False):
    myprint(f"Geocoding {worksite_or_housing}...")

    if check_previously_geocoded:
        make_query("REFRESH MATERIALIZED VIEW previously_geocoded")

        if worksite_or_housing == "worksite":
            df["address_id"] = df.apply(lambda job: (handle_null(job["WORKSITE_ADDRESS"]) + handle_null(job["WORKSITE_CITY"]) +
                                                     handle_null(job["WORKSITE_STATE"]) + handle_null(job["WORKSITE_POSTAL_CODE"])).lower(), axis=1)
        else:
            df["address_id"] = df.apply(lambda job: (handle_null(job["HOUSING_ADDRESS_LOCATION"]) + handle_null(job["HOUSING_CITY"]) +
                                                     handle_null(job["HOUSING_STATE"]) + handle_null(job["HOUSING_POSTAL_CODE"])).lower(), axis=1)
        df["previously_geocoded"] = False
        df[f"{worksite_or_housing}_lat"] = None
        df[f"{worksite_or_housing}_long"] = None
        df[f"{worksite_or_housing} accuracy"] = None
        df[f"{worksite_or_housing} accuracy type"] = ""

        errors = 0
        for i, job in df.iterrows():
            # won't work if the full address has certain special characters. should probably fix this but it's rather rare
            try:
                previous_geocode = pd.read_sql(f"""SELECT * FROM previously_geocoded WHERE full_address = '{job["address_id"]}'""", con=engine)
            except:
                previous_geocode = pd.DataFrame()
                myprint(f"""Failed to query previously_geocoded for address '{job["address_id"]}', the {i + 1}th row.""")
                errors += 1
            if not previous_geocode.empty:
                myprint(f"""'{job["address_id"]}' - the {i + 1}th row - is previously geocoded.""")
                assert len(previous_geocode) == 1
                df.at[i, f"{worksite_or_housing}_lat"] = get_value(previous_geocode, "latitude")
                df.at[i, f"{worksite_or_housing}_long"] = get_value(previous_geocode, "longitude")
                df.at[i, f"{worksite_or_housing} accuracy"] = get_value(previous_geocode, "accuracy")
                df.at[i, f"{worksite_or_housing} accuracy type"] = get_value(previous_geocode, "accuracy_type")
                df.at[i, "previously_geocoded"] = True

        myprint(f"There were {errors} errors checking for previous geocoding.")
        df = df.drop(columns=["address_id"])

        previously_geocoded = df[df["previously_geocoded"]]
        df = df[~(df["previously_geocoded"])]

        myprint(f"{len(previously_geocoded)} rows have already been geocoded and {len(df)} rows still need to be geocoded.")

        df = df.drop(columns=["previously_geocoded"])
        previously_geocoded.drop(columns=["previously_geocoded"], inplace=True)

    if not df.empty:

        if worksite_or_housing == "worksite":
            addresses = df.apply(lambda job: create_address_from(job["WORKSITE_ADDRESS"], job["WORKSITE_CITY"], job["WORKSITE_STATE"], job["WORKSITE_POSTAL_CODE"]), axis=1).tolist()
        elif worksite_or_housing == "housing":
            addresses = df.apply(lambda job: create_address_from(job["HOUSING_ADDRESS_LOCATION"], job["HOUSING_CITY"], job["HOUSING_STATE"], job["HOUSING_POSTAL_CODE"]), axis=1).tolist()
        else:
            print_red_and_email("`worksite_or_housing` parameter in geocode_table function must be either `worksite` or `housing` or `housing addendum`", "Invalid Function Parameter")
            return

        # handles case of more than 10000 addresses - because geocodio api won't batch geocode with more than 10000 addresses at once
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
            i +=1

        i = len(df.columns)
        df[f"{worksite_or_housing}_lat"] = latitudes
        df[f"{worksite_or_housing}_long"] = longitudes
        df[f"{worksite_or_housing} accuracy"] = accuracies
        df[f"{worksite_or_housing} accuracy type"] = accuracy_types
        myprint(f"Finished geocoding {worksite_or_housing}.")

    if check_previously_geocoded:
        df = df.append(previously_geocoded)

    # # uncomment to save excel file with geocoding results
    # now = datetime.now(tz=timezone('US/Eastern')).strftime("%I.%M%.%S_%p_%B_%d_%Y")
    # df.to_excel(f"geocoded_{now}.xlsx")
    # myprint("Backed up geocoding results")

    return df

# geocodes `df` and returns two dataframes - one with accuratly geocoded rows and one with inaccurate rows
def geocode_and_split_by_accuracy(df, table=""):
    if table == "dol_h2b":
        df = geocode_table(df, "worksite", check_previously_geocoded=True)
    elif table == "housing addendum":
        df = geocode_table(df, "housing", check_previously_geocoded=True)
    elif table == "dol_h2a":
        df = geocode_table(df, "worksite", check_previously_geocoded=True)
        df = geocode_table(df, "housing", check_previously_geocoded=True)
    else:
        df = geocode_table(df, "worksite")
        if "HOUSING_ADDRESS_LOCATION" in df.columns:
            df = geocode_table(df, "housing")
        else:
            print_red_and_email("Not geocoding housing because HOUSING_ADDRESS_LOCATION is not present. This should be fine, and hopefully just means there were only H-2B jobs in today's run, but you may want to check.", "Not geocoding housing today")

    housing_addendum = (table == "housing addendum")
    accurate = df.apply(lambda job: is_accurate(job, housing_addendum=housing_addendum), axis=1)
    accurate_jobs, inaccurate_jobs = df.copy()[accurate], df.copy()[~accurate]
    inaccurate_jobs["fixed"] = False

    myprint(f"There were {len(accurate_jobs)} accurate jobs.\nThere were {len(inaccurate_jobs)} inaccurate jobs.")

    return accurate_jobs, inaccurate_jobs
