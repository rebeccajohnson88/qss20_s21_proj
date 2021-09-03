#!/usr/bin/env python
# coding: utf-8

# In[1]:


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

#file paths
DROPBOX_INT_PATH = '../../qss20_finalproj_rawdata/summerwork/'
TRLA_DATA_FILE_NAME = "clean/whd_violations_wTRLA_catchmentonly.csv"
GENERAL_DATA_FILE_NAME = "clean/whd_violations.csv"
TRLA_DATA_FILE_PATH = os.path.join(DROPBOX_INT_PATH, TRLA_DATA_FILE_NAME)
GENERAL_DATA_FILE_PATH = os.path.join(DROPBOX_INT_PATH, GENERAL_DATA_FILE_NAME)

### local path for now
TRLA_DATA_WOUTCOMES = "/Users/grantanapolle/Dropbox/qss20_finalproj_rawdata/summerwork/clean/whd_violations_wTRLA_catchmentonly.csv"
WHD_DATA_WOUTCOMES = "/Users/grantanapolle/Dropbox/qss20_finalproj_rawdata/summerwork/clean/whd_violations.csv"
H2A_FEATURES = "/Users/grantanapolle/Dropbox/qss20_finalproj_rawdata/summerwork/intermediate/h2a_combined_2014-2021.pkl"


# In[2]:


#### functions

def get_ordinal(df, col):
    '''function that turns a col into datetime then ordinal timestamp, old input col will be replaced '''
    df[col] = pd.to_datetime(df[col],errors='coerce')
    df[col] = np.where(df[col].isna, df[col].mode(), df[col]) # change na to mode
    df[col] = [pd.Timestamp(date) for date in df[col]]
    df[col] = [tstamp.toordinal() for tstamp in df[col]]
    return df[col]


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


def process_data(df, outcomes):
    
    x = df[features_list]
    y = df[outcomes]
    
    for col in ['JOB_START_DATE', 'REQUESTED_START_DATE_OF_NEED', 'JOB_END_DATE', 'REQUESTED_END_DATE_OF_NEED']:
        x[col] = get_ordinal(x, col)
        
    ## change some row values to dummy "others" according to value count of the column
    for col in ['ATTORNEY_AGENT_CITY', 'JOB_TITLE', 'ATTORNEY_AGENT_NAME','WORKSITE_CITY', 'EMPLOYER_CITY']:
        x = gen_topk_dummies(x, col, 0.01)
    
    ##### do a train test split
    # split into train and test sets (80/20) -> returns index of the split, not the split df itself
    # group shuffle split on job group id: 'jobs_group_id'
    gs = GroupShuffleSplit(n_splits=2, train_size=.7, random_state=42)
    train_ix, test_ix = next(gs.split(x, y, groups=x.jobs_group_id))
    
    # now actually split the df before imputation
    x_train = x.loc[train_ix]
    x_test = x.loc[test_ix]
    
    # imputation
    x_train_imputed, cat_cols_train = imputation(x_train)
    x_test_imputed, cat_cols_test = imputation(x_test)
    
    
    # categorical dummies
    x_train_imputed_dummies = gen_dum_categorical(x_train_imputed, cat_cols_train)
    x_test_imputed_dummies = gen_dum_categorical(x_test_imputed, cat_cols_test)
    
    print(x_train_imputed_dummies.shape, x_test_imputed_dummies.shape)
    
    train_processed = pd.merge(x_train_imputed_dummies.reset_index(), y.loc[train_ix].reset_index(), 
                               how = 'left', on = 'index')
    train_processed = train_processed.drop(columns = 'index')
    
    test_processed = pd.merge(x_test_imputed_dummies.reset_index(), y.loc[test_ix].reset_index(), 
                              how = 'left', on = 'index')
    test_processed = test_processed.drop(columns = 'index')
    
    print(train_processed.shape, test_processed.shape)

        
    return train_processed, test_processed


def imputation(df):
    
    # seperate into numeric can categorical columns
    numeric_options = ["int64", "float64"]
    num_cols = [one for one in df.columns if df.dtypes[one] in numeric_options] # all nums are actually dates
    cat_cols = [one for one in df.columns if df.dtypes[one] not in numeric_options]
    print('number of numeric colums: ', len(num_cols))
    print('number of categorical colums: ', len(cat_cols))
    
    cat_df = df[cat_cols]
    num_df = df[num_cols]
    
    # SimpleImputer on the categorical features and apply a "missing_value" to NANs
    imputer_cat = SimpleImputer(strategy='constant', fill_value='missing_value')
    cat_df_imputed = pd.DataFrame(imputer_cat.fit_transform(cat_df))
    cat_df_imputed.columns = cat_df.columns

    # SimpleImputer on the date features and apply mode to NANs
    imputer_num = SimpleImputer(strategy='most_frequent', verbose=5)
    num_df_imputed = pd.DataFrame(imputer_num.fit_transform(num_df))
    num_df_imputed.columns = num_df.columns
    
    # merge the imputed num/cat dfs back
    imputed_combined = pd.merge(cat_df_imputed.reset_index(),
                                num_df_imputed.reset_index(), 
                                how='left', on='index')
    
    print('%s rows lost in merge' %(num_df_imputed.shape[0]-imputed_combined.shape[0]))
    imputed_combined = imputed_combined.drop(columns = 'index')
    print(imputed_combined.shape)
    
    return imputed_combined, cat_cols


def gen_dum_categorical(df, features):
    '''gen dummies columns for categorical variable'''
    for f in features:
        dummies = pd.get_dummies(df[f], prefix=df[f].name)
        df.drop(columns=[f], inplace=True)
        df = df.join(dummies)
    return df
    


# In[3]:


trla_df_pre = pd.read_csv(TRLA_DATA_WOUTCOMES)
whd_df_pre = pd.read_csv(WHD_DATA_WOUTCOMES)


# In[4]:


#read in features then manually decide which to keep based on nunique()
features_df = pd.read_pickle(H2A_FEATURES)
features_columns = features_df.columns.tolist()
print(whd_df_pre[features_columns].nunique())


# In[5]:


features_list = ['ATTORNEY_AGENT_CITY', 'JOB_TITLE', 'EMPLOYER_STATE', 'SOC_CODE', 'REQUESTED_END_DATE_OF_NEED', 
                 'SOC_TITLE', 'EMPLOYER_CITY', 'JOB_END_DATE', 'ATTORNEY_AGENT_STATE', 'JOB_START_DATE', 'REQUESTED_START_DATE_OF_NEED',
                 'WORKSITE_STATE', 'ATTORNEY_AGENT_NAME', 'WORKSITE_CITY', 'jobs_group_id', 'jobs_row_id']

print(whd_df_pre[features_list].nunique())


# In[6]:


print('length of features before acs: ', len(features_list))

acs_cols = [col for col in trla_df_pre if 'acs_' in col]
features_list += acs_cols

print('length of features after adding acs: ', len(features_list))

whd_outcomes = ['outcome_is_investigation_overlapsd', 'outcome_is_viol_overlapsd']

trla_outcome_dummies = pd.get_dummies(trla_df_pre['outcome_compare_TRLA_WHD'])
trla_df_pre = trla_df_pre.join(trla_outcome_dummies)
trla_outcomes = trla_outcome_dummies.columns.tolist()


# In[7]:


whd_train_processed, whd_test_processed = process_data(whd_df_pre, whd_outcomes)

trla_train_processed, trla_test_processed = process_data(trla_df_pre, trla_outcomes)


# In[8]:


whd_train_processed.to_pickle('../../qss20_finalproj_rawdata/summerwork/clean/whd_training.pkl')
whd_test_processed.to_pickle('../../qss20_finalproj_rawdata/summerwork/clean/whd_testing.pkl')
trla_train_processed.to_pickle('../../qss20_finalproj_rawdata/summerwork/clean/trla_training.pkl')
trla_test_processed.to_pickle('../../qss20_finalproj_rawdata/summerwork/clean/trla_testing.pkl')

