# Machine Learning Modeling of final dataset
# Aug 26, 2021
# Grant Anapolle and Yuchuan Ma

##### imports
import re
import time
import numpy as np
import pandas as pd
import os
# import pickle5 as pickle
# import matplotlib.pyplot as plt

# ML imports
from sklearn.compose import ColumnTransformer
from sklearn.datasets import make_classification
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier, AdaBoostClassifier
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression, LogisticRegressionCV
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score
from sklearn.model_selection import cross_val_score
from sklearn.naive_bayes import MultinomialNB
from sklearn.svm import SVC
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import GroupShuffleSplit

##### Input Path
DROPBOX_INT_PATH = '../../qss20_finalproj_rawdata/summerwork/'
TRLA_DATA_FILE_NAME = "clean/whd_violations_wTRLA_catchmentonly.csv"
GENERAL_DATA_FILE_NAME = "clean/whd_violations.csv"
TRLA_DATA_FILE_PATH = os.path.join(DROPBOX_INT_PATH, TRLA_DATA_FILE_NAME)
GENERAL_DATA_FILE_PATH = os.path.join(DROPBOX_INT_PATH, GENERAL_DATA_FILE_NAME)

# local path for now
TRLA_DATA_FILE_PATH2 = "/Users/euniceliu/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork/clean/whd_violations_wTRLA_catchmentonly.csv"
GENERAL_DATA_FILE_PATH2 = "/Users/euniceliu/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork/clean/whd_violations.csv"

#### functions

def get_ordinal(df, col):
    '''function that turns a col into datetime then ordinal timestamp, old input col will be replaced '''
    df[col] = pd.to_datetime(df[col],errors='coerce')
    df[col] = np.where(df[col].isna, pd.to_datetime('1/1/1'), df[col])
    df[col] = [pd.Timestamp(date) for date in df[col]]
    df[col] = [tstamp.toordinal() for tstamp in df[col]]
    return df

def gen_topk_dummies(df, feature, percentThreshold):
    '''
    generate dummies within a feature columns where the count of a specific row val that below certain threshold is
    replaced by "others" and missing values are replaced by "missing"
            percentThreshold input should be 0.01 -> means 1% threshold,
            the percent is calculated on "jobs_group_id"
    '''
    ## get count of addresses in each level of factor
    ## recoding na to missing before counts
    df[feature] = np.where(df[feature].isnull(), "missing", df[feature])
    count_feat = pd.value_counts(df[feature])

    ## calculate threshold
    sum = df["jobs_group_id"].nunique()
    threshold = int(sum * percentThreshold)

    ##get an indicator for whether the category is above threshold of count of addresses
    categories_abovethreshold = count_feat[count_feat >= threshold].index
    categories_abovethres_logic = df[feature].isin(categories_abovethreshold)

    ## copy data, create category for missing and other
    df_dummies = df.copy()
    df_dummies[feature][~categories_abovethres_logic] = 'OTHER'

    print(f"{feature}'s val count was "+ str(df[feature].nunique()) + ", count now:" + str(df_dummies[feature].nunique()))
    return(df_dummies)

def gen_dum_categorical(df, feature):
    '''gen dummies columns for categorical variable'''
    for f in feature:
        dummies = pd.get_dummies(df[f], prefix=df[f].name)
        df.drop(columns=[f], inplace=True)
        df = df.join(dummies)
    return df


#### Read in and investigate data
pre_df = pd.read_csv(TRLA_DATA_FILE_PATH2)
pre_df = pre_df.reset_index().copy()

# read in h2a jobs data for filtering job feature using h2a df's column names
h2a_data = pd.read_csv(GENERAL_DATA_FILE_PATH2)
# with open(GENERAL_DATA_FILE_PATH2, "rb") as df:
#   h2a_data = pickle.load(df)
job_feature = h2a_data.columns.tolist()
job_feature.append("jobs_group_id")

print(pre_df.info(verbose=True, show_counts=True))
#print(h2a_data.columns.values)

## Assign outcome boolean vars to y (value we are trying to predict)
outcome_cols = [col for col in pre_df.columns if 'outcome_' in col]
test_outcome = ['is_matched_investigations','outcome_is_investigation_overlapsd']
print("Outcome variables to predict are:" + str(outcome_cols))
y1 = pre_df[test_outcome[0]]

# remove them from the preMatrix ... because that would be too easy!
pre_df = pre_df.drop(columns=outcome_cols, axis=1)

## select columns that overlap with job_feature (col names from H2A_DATA)
cols = [c for c in pre_df.columns if c in job_feature]
preMatrix = pre_df[cols].copy()

## convert the dates to ordinal timestamps
for col in ['JOB_END_DATE','JOB_START_DATE']:
    get_ordinal(preMatrix, col)

print("shape after slicing out outcome cols and selecting feature cols:")
print(preMatrix.shape)
print(preMatrix.nunique(axis=0))
#print(preMatrix.info(verbose=True, show_counts=True))


##### seperate num/cat feature columns

numeric_options = ["int64", "float64", "datetime64[ns]"]
num_cols = [one for one in preMatrix.columns if preMatrix.dtypes[one] in numeric_options] # all nums are actually dates
cat_cols = [one for one in preMatrix.columns if preMatrix.dtypes[one] not in numeric_options]

## select cat columns with less than 1000 unique values
# choosing columns w/ nrow/2 unique values
selected_cat_large = [c for c in cat_cols if preMatrix[c].nunique()<=1000]

print('Numeric Columns:')
print(num_cols)
print('\nSelected Categorical Columns:')
print(selected_cat_large)


## change some row values to dummy "others" according to value count of the column
for col in ['ATTORNEY_AGENT_CITY','ATTORNEY_AGENT_NAME','WORKSITE_CITY']:
    preMatrix = gen_topk_dummies(preMatrix,col,0.01)

##### do a train test split
# split into train and test sets (80/20) -> returns index of the split, not the split df itself
# group shuffle split on job group id: 'jobs_group_id'
gs = GroupShuffleSplit(n_splits=2, train_size=.7, random_state=42)
train_ix, test_ix = next(gs.split(preMatrix, y1, groups=preMatrix.jobs_group_id))


#### data imputation
# get the categorical features in one dataframe
cat_feature_pre = preMatrix.loc[:, selected_cat_large].copy()
print("Shape of non-imputed: ")
print(cat_feature_pre.shape)
# and the numerical features into another dataframe
date_feature_pre = preMatrix.loc[:, num_cols].copy()
print(date_feature_pre.shape)

# SimpleImputer on the categorical features and apply a "missing_value" to NANs
imputer_cat = SimpleImputer(strategy='constant', fill_value='missing_value')
imputed_cat_feature_pre = pd.DataFrame(imputer_cat.fit_transform(cat_feature_pre))
imputed_cat_feature_pre.columns = cat_feature_pre.columns

# SimpleImputer on the date features and apply mode to NANs
imputer_date = SimpleImputer(strategy='most_frequent', verbose=5)
imputed_date_feature_pre = pd.DataFrame(imputer_date.fit_transform(date_feature_pre))
imputed_date_feature_pre.columns = date_feature_pre.columns

print("Shape of imputed: ")
print(imputed_cat_feature_pre.shape)
print(imputed_date_feature_pre.shape)
# merge the imputed num/cat dfs back
imputed_combined = pd.merge(imputed_cat_feature_pre.reset_index(),
                            imputed_date_feature_pre.reset_index(), how='left',
                            on='index')
print('%s rows lost in merge' %(imputed_date_feature_pre.shape[0]-imputed_combined.shape[0]))
print(imputed_combined.shape)
imputed_combined = imputed_combined.drop(columns = 'index')

imputed_dummy_df = gen_dum_categorical(imputed_combined, selected_cat_large)
print('shape after generating dummies for categorical var: ')
print(imputed_dummy_df.shape)
print(imputed_dummy_df.head)


# split out x and y test/train df according to the previous split index
X_train = imputed_dummy_df.loc[train_ix]
y_train = y1.loc[train_ix]

X_test = imputed_dummy_df.loc[test_ix]
y_test = y1.loc[test_ix]

