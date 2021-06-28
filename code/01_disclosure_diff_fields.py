# script that reads in yearly data and finds intersecting column names as well as which column names are added each year

# load necessary packages
import openpyxl as openpyxl
import pandas as pd

# read in datasets
df_2014 = pd.read_excel("/Users/euniceliu/Dropbox (Dartmouth College)/You-Chi Liu's files/qss20_finalproj_rawdata/summerwork/raw/H_2A_Disclosure_Data_FY2014.xlsx")
df_2015 = pd.read_excel("/Users/euniceliu/Dropbox (Dartmouth College)/You-Chi Liu's files/qss20_finalproj_rawdata/summerwork/raw/H_2A_Disclosure_Data_FY2015.xlsx")
df_2016 = pd.read_excel("/Users/euniceliu/Dropbox (Dartmouth College)/You-Chi Liu's files/qss20_finalproj_rawdata/summerwork/raw/H_2A_Disclosure_Data_FY2016.xlsx")
df_2017 = pd.read_excel("/Users/euniceliu/Dropbox (Dartmouth College)/You-Chi Liu's files/qss20_finalproj_rawdata/summerwork/raw/H_2A_Disclosure_Data_FY2017.xlsx")
df_2018 = pd.read_excel("/Users/euniceliu/Dropbox (Dartmouth College)/You-Chi Liu's files/qss20_finalproj_rawdata/summerwork/raw/H_2A_Disclosure_Data_FY2018.xlsx")
df_2019 = pd.read_excel("/Users/euniceliu/Dropbox (Dartmouth College)/You-Chi Liu's files/qss20_finalproj_rawdata/summerwork/raw/H_2A_Disclosure_Data_FY2019.xlsx")
df_2020 = pd.read_excel("/Users/euniceliu/Dropbox (Dartmouth College)/You-Chi Liu's files/qss20_finalproj_rawdata/summerwork/raw/H_2A_Disclosure_Data_FY2020.xlsx")
df_2021 = pd.read_excel("/Users/euniceliu/Dropbox (Dartmouth College)/You-Chi Liu's files/qss20_finalproj_rawdata/summerwork/raw/H_2A_Disclosure_Data_FY2021.xlsx")
# combine into a list
full_data = [df_2014, df_2015, df_2016, df_2017, df_2018, df_2019, df_2020, df_2021]

# get and print intersecting columns
colnames = [set(df_2014.columns), set(df_2015.columns), set(df_2016.columns), set(df_2017.columns), set(df_2018.columns), set(df_2019.columns), set(df_2020.columns), set(df_2021.columns)]
intersecting_cols = list(set.intersection(*colnames))
print("Intersecting columns: " + str(intersecting_cols))

# print column names unique to 2014
colnames_short = colnames[1:]
union_cols_short = set.union(*colnames_short)
print("Columns for year 2014 present in no other year: " + str(list(colnames[0].difference(union_cols_short))))

# find and print column names each year that were not present the year before
year = 2015
index = 1
while year < 2022:
    print("New columns for year " + str(year) + ": " + str(list(full_data[index].columns.difference(full_data[index - 1].columns))))
    year += 1
    index += 1


