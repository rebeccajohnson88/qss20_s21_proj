#######
### Code to run ML models
#######

### imports
import re
import time
import numpy as np
import pandas as pd
import os
import pickle5 as pickle
import matplotlib.pyplot as plt

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
from sklearn.utils import resample

## modeling functions 
def get_metrics(y_test, y_predicted):
    '''generate evaluation scores accroding predicted y'''
    accuracy = accuracy_score(y_test, y_predicted)
    precision = precision_score(y_test, y_predicted, average='binary')
    recall = recall_score(y_test, y_predicted, average='binary')
    f1 = f1_score(y_test, y_predicted, average='binary')
    return accuracy, precision, recall, f1

def estimate_models(model_list, model_list_names, X_train, y_train, X_test, y_test):
    '''takes in a list of models, fit and test each one, generates a df with evaluation parameters of all models ran'''
    all_fi = []
    for i in range(0, len(model_list)):
        ## pull out model
        one_model = model_list[i]

        print("fitting model: " + str(one_model))
        ## fit the model and evaluate
        one_model.fit(X_train, y_train)
        if model_list_names[i] == "gb_shallow":
            fi = one_model.feature_importances_
        else:
            fi = one_model.coef_
        fi_df = pd.DataFrame({'value': fi[0],
                         'coef_name': X_train.columns})
        fi_df['model'] = model_list_names[i]
        all_fi.append(fi_df)

    fi_df = pd.concat(all_fi)
    print("concatenated and returned object")
    return fi_df

## shortened list of model objects
model_list = [GradientBoostingClassifier(criterion='friedman_mse', n_estimators=100),
              LogisticRegression(penalty = "l1",max_iter=10000, C = 0.01, solver='liblinear')]
model_list_names = ["gb_shallow", "lasso"]

assert len(model_list) == len(model_list_names)


## define paths and read in data
DROPBOX_YOUR_PATH = "Dropbox/qss20_finalproj_rawdata/summerwork/"
MODEL_OUTPUT_PATH = "Dropbox/qss20_s21_proj/output/model_outputs/"
whd_train_init = pd.read_pickle(DROPBOX_YOUR_PATH + "clean/whd_training.pkl")
whd_test = pd.read_pickle(DROPBOX_YOUR_PATH + "clean/whd_testing.pkl")
focal_outcome = "outcome_is_investigation_overlapsd" 

## upsample minority class in training
df_majority = whd_train_init[whd_train_init[focal_outcome] == False].copy()
df_minority = whd_train_init[whd_train_init[focal_outcome] == True].copy()
df_minority.shape[0]/whd_train_init.shape[0]
df_minority_upsamp = resample(df_minority, 
                              replace = True, 
                              n_samples = df_majority.shape[0],
                              random_state = 91988)

whd_train = pd.concat([df_majority, df_minority_upsamp])


## remove non-pverlapping features

id_cols = ['jobs_group_id', "merge_index", "index", "jobs_row_id", "level_0", "index_x", "index_y"]
common_cols = set(whd_train.columns).intersection(set(whd_test.columns)).difference(id_cols)

## then, subset to each, separate out outcome var, 
## and work on code inside
outcomes_WHD = [col for col in whd_train if "outcome" in col]
X_train = whd_train[[col for col in whd_train.columns if col not in outcomes_WHD and col in common_cols]].copy()
X_test = whd_test[[col for col in whd_test.columns if col not in outcomes_WHD and col in common_cols]].copy()
y_train = whd_train[[focal_outcome]].copy().iloc[:, 0].to_numpy()
y_test = whd_test[[focal_outcome]].copy().iloc[:, 0].to_numpy()


fi_results  = estimate_models(model_list,
                                     model_list_names,
                                     X_train, y_train, X_test, y_test)

## save results




