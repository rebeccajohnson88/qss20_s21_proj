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
    evals_array = []
    confus_array = []
    pred_array = []
    for i in range(0, len(model_list)):
        ## pull out model
        one_model = model_list[i]

        print("fitting model: " + str(one_model))
        ## fit the model and evaluate
        one_model.fit(X_train, y_train)
        y_pred = one_model.predict(X_test)
        print("Order of classes is-------")
        print(one_model.classes_)
        print(y_pred)
        y_pred_continuous = one_model.predict_proba(X_test)
        print(y_pred_continuous)
        actual_v_pred = pd.DataFrame({'predicted': y_pred, 
                                       'actual': y_test,
                                       'predicted_cont_false': y_pred_continuous[:, 0],
                                       'predicted_cont_true': y_pred_continuous[:, 1]})
        actual_v_pred['model'] = model_list_names[i]
        pred_array.append(actual_v_pred)

        print("Calculating Confusion matrix \n")
        confus_mat = pd.crosstab(actual_v_pred['actual'], actual_v_pred['predicted'])
        confus_mat['model'] = model_list_names[i]
        confus_mat['actual'] = confus_mat.index
        confus_mat_long = pd.melt(confus_mat, id_vars = ["model", 'actual'])
        confus_array.append(confus_mat_long)

        accuracy, precision, recall, f1 = get_metrics(y_test, y_pred)
        print("accuracy = %.3f \nprecision = %.3f \nrecall = %.3f \nf1 = %.3f" % (accuracy, precision, recall, f1))

        evals_array.append(pd.DataFrame({'Model': [model_list_names[i]],
                                     'Accuracy': [accuracy], 'Precision': [precision], 'Recall':[recall], 'f1-score':[f1]
                                      }))
        


    evals_df = pd.concat(evals_array)
    confus_df = pd.concat(confus_array)
    pred_df = pd.concat(pred_array)
    print("concatenated and returned object")
    return evals_df, confus_df, pred_df

## create a list of model objects
#model_list_test = [LogisticRegression(penalty = "l1",max_iter=10000, C = 1, solver='liblinear'),
                #LogisticRegression(penalty = "l2",max_iter=10000, C = 1)]
#model_list_test_names = ['dt_shallow', 'dt_deep']
model_list = [DecisionTreeClassifier(random_state=0, max_depth = 5),
                    DecisionTreeClassifier(random_state=0, max_depth = 50),
                    RandomForestClassifier(n_estimators = 100, max_depth = 20),
                    RandomForestClassifier(n_estimators = 1000, max_depth = 20),
                    GradientBoostingClassifier(criterion='friedman_mse', n_estimators=100),
                    GradientBoostingClassifier(criterion='friedman_mse', n_estimators=200),
                AdaBoostClassifier(),
                LogisticRegression(penalty = "l1",max_iter=10000, C = 0.01, solver='liblinear'),
                LogisticRegression(penalty = "l2",max_iter=10000, C = 0.01)]
model_list_names = ["dt_shallow", "dt_deep", "random_forest_10020", "random_forest_100020",
                    "gb_shallow", "gb_deep", "ada", "logit_l1_lowerpen",
                    "logit_l2_lowerpen"]

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
id_cols = ['jobs_group_id', "merge_index", "index", "jobs_row_id", "level_0"]
common_cols = set(whd_train.columns).intersection(set(whd_test.columns)).difference(id_cols)

## then, subset to each, separate out outcome var, 
## and work on code inside
outcomes_WHD = [col for col in whd_train if "outcome" in col]
X_train = whd_train[[col for col in whd_train.columns if col not in outcomes_WHD and col in common_cols]].copy()
X_test = whd_test[[col for col in whd_test.columns if col not in outcomes_WHD and col in common_cols]].copy()
y_train = whd_train[[focal_outcome]].copy().iloc[:, 0].to_numpy()
y_test = whd_test[[focal_outcome]].copy().iloc[:, 0].to_numpy()


evals, confus, pred = estimate_models(model_list,
                                     model_list_names,
                                     X_train, y_train, X_test, y_test)

## save results
evals.to_csv(MODEL_OUTPUT_PATH + "evals_df_" + focal_outcome + ".csv", index = False)
confus.to_csv(MODEL_OUTPUT_PATH + "confus_df_" + focal_outcome + ".csv", index = False)
pred.to_csv(MODEL_OUTPUT_PATH + "pred_df_" + focal_outcome + ".csv", index = False)




