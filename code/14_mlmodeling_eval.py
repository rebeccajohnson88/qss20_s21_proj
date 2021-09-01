# code to run model/eval
# CG
# 9/1/21

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

## functions
def get_metrics(y_test, y_predicted):
    '''generate evaluation scores accroding predicted y'''
    accuracy = accuracy_score(y_test, y_predicted)
    precision = precision_score(y_test, y_predicted, average='binary')
    recall = recall_score(y_test, y_predicted, average='binary')
    f1 = f1_score(y_test, y_predicted, average='binary')
    return accuracy, precision, recall, f1

def estimate_models(model_list, X_train, y_train, X_test, y_test):
    '''takes in a list of models, fit and test each one, generates a df with evaluation parameters of all models ran'''
    evals_array = []
    for i in range(0, len(model_list)):
        ## pull out model
        one_model = model_list[i]

        print("fitting model: " + str(one_model))
        ## fit the model and evaluate
        one_model.fit(X_train, y_train)
        y_pred = one_model.predict(X_test)

        print("Confusion matrix \n")
        print(pd.crosstab(pd.Series(y_test, name='Actual'), pd.Series(y_pred, name='Predicted')))

        accuracy, precision, recall, f1 = get_metrics(y_test, y_pred)
        print("accuracy = %.3f \nprecision = %.3f \nrecall = %.3f \nf1 = %.3f" % (accuracy, precision, recall, f1))

        evals_array.append(pd.DataFrame({'Model': [model_list[i]],
                                     'Accuracy': [accuracy], 'Precision': [precision], 'Recall':[recall], 'f1-score':[f1]
                                      }))

    evals_df = pd.concat(evals_array)
    return evals_df

## create a list of model objects
model_list1 = [DecisionTreeClassifier(random_state=0, max_depth = 5),
                    DecisionTreeClassifier(random_state=0, max_depth = 50)]
model_list = [DecisionTreeClassifier(random_state=0, max_depth = 5),
                    DecisionTreeClassifier(random_state=0, max_depth = 50),
                    RandomForestClassifier(n_estimators = 100, max_depth = 20),
                    RandomForestClassifier(n_estimators = 1000, max_depth = 20),
                    GradientBoostingClassifier(criterion='friedman_mse', n_estimators=100),
                    GradientBoostingClassifier(criterion='friedman_mse', n_estimators=1000),
                AdaBoostClassifier(),
                LogisticRegression(max_iter=10000),
                LogisticRegressionCV(max_iter=10000),
                LogisticRegression(penalty = "l1",max_iter=10000),
                LogisticRegressionCV(solver = "liblinear",
                                 penalty = "l1", max_iter=10000)]
print("Length of classifier list is:" + str(len(model_list)))

evals_df = estimate_models(model_list, X_train, y_train, X_test, y_test)
evals_df.to_csv("model_evaluation.csv", encoding='utf-8', index=False)
print(evals_df)
