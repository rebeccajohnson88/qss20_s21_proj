##### imports
import random
import re
import time

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import os
import recordlinkage
from sklearn.compose import ColumnTransformer
from sklearn.datasets import make_classification
from sklearn.ensemble import RandomForestClassifier
# ML imports
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.impute import SimpleImputer
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score
from sklearn.model_selection import cross_val_score
from sklearn.model_selection import train_test_split
from sklearn.naive_bayes import MultinomialNB
from sklearn.preprocessing import LabelBinarizer
from sklearn.preprocessing import LabelEncoder
from sklearn.preprocessing import OneHotEncoder
from sklearn.svm import SVC
from sklearn.tree import DecisionTreeClassifier

##### Input Path
DROPBOX_INT_PATH = '../../qss20_finalproj_rawdata/summerwork/intermediate/'
DATA_FILE_NAME = "placeholderdata_formodeling.csv"
DATA_FILE_PATH = os.path.join(DROPBOX_INT_PATH, DATA_FILE_NAME)
# local path for now
DATA_FILE_PATH2 = "/Users/Firstclass/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork/intermediate/placeholderdata_formodeling.csv"


#### Read in and investigate data
pre_df = pd.read_csv(DATA_FILE_PATH2)
pre_df = pre_df.reset_index().copy()
#print(pre_df.columns.values)

## convert the dates to datetime objects
for col in ['REQUESTED_END_DATE_OF_NEED', 'JOB_END_DATE',
            'JOB_START_DATE', 'REQUESTED_START_DATE_OF_NEED',
            'DECISION_DATE']:
    pre_df[col] = pd.to_datetime(pre_df[col])

## Assign outcome boolean vars to y (value we are trying to predict)
df_y = pre_df.select_dtypes(bool)
print("Outcome variables to predict are:" + str(df_y.columns.values))
y1 = list(df_y.iloc[:, 0])
y2 = list(df_y.iloc[:, 1])
# remove the them from the preMatrix ... because that would be too easy!
pre_df = pre_df.select_dtypes(exclude=['bool'])

## select columns w/ capital letter column names
cols = [c for c in pre_df.columns if not str.islower(c)]
preMatrix = pre_df[cols]
preMatrix = preMatrix.drop(columns=['Registration Act'])

print(preMatrix.shape)
#print(preMatrix.info(verbose=True, show_counts=True))
print(preMatrix.nunique(axis=0))

#### seperate num/cat columns
numeric_options = ["int64", "float64", "datetime64[ns]"]
num_cols = [one for one in preMatrix.columns if preMatrix.dtypes[one] in numeric_options] # all nums are actually dates
cat_cols = [one for one in preMatrix.columns if preMatrix.dtypes[one] not in numeric_options]
#date_cols = [one for one in preMatrix.columns if preMatrix.dtypes[one] == "datetime64[ns]"]

## select cat columns with less than 1000 unique values
selected_cat_small = [c for c in cat_cols if preMatrix[c].nunique()<=60]
# choosing columns w/ nrow/2 unique values
selected_cat_large = [c for c in cat_cols if preMatrix[c].nunique()<=1000]

print('Numeric Columns:')
print(num_cols)
print('\nSelected Categorical Columns:')
print(selected_cat_large)

# get the categorical features in one dataframe
cat_feature_pre = preMatrix.loc[:, selected_cat_large].copy()
print("Shape of non-imputed: ")
print(cat_feature_pre.shape)
# and the numerical features into another dataframe
num_feature_pre = preMatrix.loc[:, num_cols].copy()
print(num_feature_pre.shape)

# SimpleImputer on the categorical features and apply a "missing_value" to NANs
imputer_cat = SimpleImputer(strategy='constant', fill_value='missing_value')
imputed_cat_feature_pre = pd.DataFrame(imputer_cat.fit_transform(cat_feature_pre))
imputed_cat_feature_pre.columns = cat_feature_pre.columns

# SimpleImputer on the numerical features and apply mode to NANs
#imputer_num = SimpleImputer(strategy='most_frequent', verbose=5)
#imputed_num_feature_pre = pd.DataFrame(imputer_num.fit_transform(num_feature_pre))
#imputed_num_feature_pre.columns = num_feature_pre.columns
imputed_num_feature_pre = num_feature_pre.copy()
print(num_feature_pre.isnull().sum())
for col in num_cols:
    imputed_num_feature_pre[col].replace(pd.NaT, imputed_num_feature_pre[col].mode().iloc[0])
    #a = (imputed_num_feature_pre[col].mode())
    #imputed_num_feature_pre[col].fillna(a)

print("Shape of imputed: ")
print(imputed_cat_feature_pre.shape)
print(imputed_num_feature_pre.shape)
print(imputed_num_feature_pre.isnull().sum())

# prepare input data with OneHotEncoder
def prepare_inputs(X_train, X_test):
    oe = OneHotEncoder(handle_unknown='ignore')
    oe.fit(X_train)
    X_train_enc = oe.transform(X_train)
    X_test_enc = oe.transform(X_test)
    return X_train_enc, X_test_enc

imputed_combined = pd.merge(imputed_cat_feature_pre.reset_index(),
                            imputed_num_feature_pre.reset_index(), how='left',
                            on='index')
print('%s rows lost in merge' %(imputed_num_feature_pre.shape[0]-imputed_combined.shape[0]))
print(imputed_combined.shape)
imputed_combined = imputed_combined.drop(columns = 'index')

# do a train test split
# split into train and test sets (80/20)

# X_train, X_test, y_train, y_test = train_test_split(imputed_cat_feature_pre, y, test_size=0.20, random_state=1)
X_train, X_test, y_train, y_test = train_test_split(imputed_combined, y1, test_size=0.20, random_state=3)

# apply the oneHotEncoder within prepare_inputs
X_train, X_test = prepare_inputs(X_train, X_test)
