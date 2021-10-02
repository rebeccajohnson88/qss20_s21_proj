# Repo for DOL Summer Data Challenge

Repo for DOL Summer Equity Project.

## Current scripts (`code`)

- [00_scraping_DOLh2a.ipynb](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/00_scraping_DOLh2a.ipynb)
  - Takes in: none
  - What it does: scrapes DOL h2a employee data from 2014 to 2021
  - Output: excel data (one file per year)

- [01_disclosure_diff_fields.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/01_disclosure_diff_fields.py)
  - Takes in: DOL h2a job data 2014-2021
  - What it does: looks at common and different column names based on year
  - Output: none

- [02_RenameCol_Rowbind.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/02_RenameCol_Rowbind.py)
  - Takes in: DOL h2a job data 2014-2021
  - What it does: rename and reconcile the column names and row bind the data
  - Output: 
      - 1) combined 2014-21 h2a data based on shared columns in csv; 
      - 2) csv jobs data just 2020 and 2021; 
      - 3) jobs data all years/all columns

- [03_fuzzy_matching.R](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/03_fuzzy_matching.R)
  - Takes in: combined DOL h2a data and WHD investigation data
  - What it does: fuzzy matches between the two data based on name and city
  - Output: fuzzy matched data in RDS

- [04_acs_demographics.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/04_acs_demographics.py) [04_acs_pulls.sh](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/04_acs_pulls.sh)
  - Takes in: csv acs predictors data
  - What it does: loads ACS variables at tract level and pull census data for a certain year; 
  - A bash script that runs 04_acs_demographics.py multiple times by iterating over years is also included
  - Output:
  
- [04_acs_demographics_percentage.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/04_acs_demographics_percentage.py)
  - Takes in: csv predictors, pickle acs tract demographics data, pickle H2A jobs tract data
  - What it does: identify which predictors to calculate percentage, calculate percentage, and clean and combine percentage and nonpercentage variables' data  
  - Output: .pkl of calculated tract-level percentage data and remaining predictors data

- [04_acs_percentage_pulls.sh](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/04_acs_percentage_pulls.sh)
  - A bash script that pulls percentage (runs the script 04_acs_demographics_percentage.py on data) from year 2014 to 2019

- [05_geocode_jobs.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/06_geocode_jobs.py)
  - Takes in: pkl combined DOL h2a data
  - What it does: using api, geocode each data entry's location with latitude and longitude
  - Output: .pkl and csv of the geocoded data

- [06_h2a_tract_intersections.ipynb](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/06_h2a_tract_intersections.ipynb)
  - Takes in: tract shapefiles url and geocoded dol h2a data
  - What it does: joins dol data with geoid (as a unique identifier) and tract shape; plots case number on US map
  - Output: .pkl dol h2a data merged with geoId and corresponding tract shape; graph of case number on US map

- [07_merging_acs_geocodedjobs.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/07_merging_acs_geocodedjobs.py)
  - Takes in: acs data with percentage calculation from year 2014-2019, h2a job data with tract information
  - What it does: merge all the datasets
  - Output: one .csv data file of 2014-2019 acs data merged with geocode/tract information (referred as h2a combined data form now on)

- [08_clean_TRLA_intake.Rmd](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/08_clean_TRLA_intake.Rmd)
  - Takes in: TRLA report data in .xlsx/.xls
  - What it does: cleans the data, consolidate opponent columns, deals with and flags missing values
  - Output: one .csv and .RDS for cleaned TRLA data

- [09_fuzzy_matching_TRLA.R](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/09_fuzzy_matching_TRLA.R)
  - Takes in: h2a combined data, cleaned TRLA data
  - What it does: fuzzy matches between H2A applications data and the TRLA data
  - Output: .RDS and .csv of matched data of trla and h2a job

- [10_construct_outcomes.R](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/10_construct_outcomes.R)
  - Takes in: matched data (between h2a application and WHD data) with de-duped datasets, TRLA cleaned data, ACS data
  - What it does: dedupes the data based on unique identifier; constructs outcome variables (based on findings start/end date and job star/end date) on the matched data, then merge ACS onto datasets
  - Output: WHD data 1) with outcome variable columns and merged with ACS, 2) of TRLA states with outcome variables and merged with ACS

- [10a_construct_jobs_address.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/10a_construct_jobs_address.py)
  - Takes in: h2a and WHD matched data
  - What it does: creates unique job address column on dataset
  - Output: h2a and WHD matched data with employer full address column

- [12_mlmodeling_preprocessing.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/12_mlmodeling_preprocessing.py)
  - Takes in: TRLA state's whd data, general whd data, h2a 2014-2021 combined data (for feature columns extracction)
  - What it does: preprocesses the TRLA and full whd data for later modeling; preprocess include: extract feature columns, generate dummy values for trivial row values, impute missing values, train and test split based on uniqie identifier `jobs_group_id`
  - Output: .pkl files of split train and test for TRLA and full whd data.

- [13_descriptives_and_visualizations.R](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/13_descriptives_and_visualizations.R)
  - Takes in: TRLA state's whd data, general whd data
  - What it does: creates descriptives and visualizations based on merged WHD/TRLA data

- [14_mlmodeling_eval.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/14_mlmodeling_eval.py)
  - Takes in: train and test split of WHD data
  - What it does: run several machine learning models and evaluate the performance of trained models on prediction, including confusion matrices
  - Output: .csv of evalutation results, confusion matrices, predictions on test data of different models

- [15_viz_modelingoutputs.R](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/15_viz_modelingoutputs.R)
  - Takes in: all .csv from script 14_mlmodeling_eval.py
  - What it does: creates visualizations of outputs from the predicative models on WHD data

- [16_mlmodeling_featureimportances.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/16_mlmodeling_featureimportances.py)
  - Takes in: train and test split of WHD data
  - What it does: run specifically two models, shallow GradientBossting() and logistic regression and evaluate the performance of trained models on prediction, including confusion matrices
  - Output: none

- [17_mlmodeling_eval_trla.py](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/17_mlmodeling_eval_trla.py)
  - Takes in: train and test split of TRLA-WHD data
  - What it does: run machine learning models, focussing on whether the outcome variable is intersect of TRLA/WHD, or one of them, or none; and evaluate the performance of trained models on prediction, including confusion matrices
  - Output: .csv of evalutation results, confusion matrices, predictions on test data of the models

- [18_viz_modelingoutputs_trla.R](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/18_viz_modelingoutputs_trla.R)
  - Takes in: all .csv from script 17_mlmodeling_eval_trla.py
  - What it does: visualizes outputs from models and predictions on TRLA on WHD vilation data

- [19_visualize_investigations.ipynb](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/19_visualize_investigations.ipynb)
  - Takes in: trac shape files and investigation data from TRLA on WHD violations
  - What it does: visualizes shaded maps with investigation locations

- [20_textanalysis_addendums.Rmd](https://github.com/rebeccajohnson88/qss20_s21_proj/blob/main/code/20_textanalysis_addendums.Rmd)
  - Takes in: job disclosure data and investigation data of TRLA on WHD violations
  - What it does: text analysis and topic matching on the disclosure data
  - Output: html_document of analysis result

## Directory structure

- [background_reading](https://github.com/rebeccajohnson88/qss20_s21_proj/tree/main/background_reading): contains background readings on (1) the H-2 program, (2) legal rights visa holders have, (3) evidence of violations of those rights

## Links to external data sources

- DOL Wages and Hour Division (WHD) compliance data: https://enforcedata.dol.gov/views/data_summary.php 

  - Data download link: https://enfxfr.dol.gov/data_catalog/WHD/whd_whisard_20210127.csv.zip
  - Rough summary: contains ~309681 compliance-related actions (not limited to H2 program) beginning in FY2005
  - Documentation in `data/documentation/whd_data_dictionary.csv`

- OPM staffing data (potentially useful for WHD staffing patterns)- https://www.fedscope.opm.gov/ 

## Details on data

### TRLA's Merged Dataset: Quarterly Disclosure & Scraped Data

Relevant links:

- Static data can be found in [this folder](https://github.com/rebeccajohnson88/qss20_s21_proj/tree/main/data).
- Data dictionary for DOL-only fields is [here](https://www.dol.gov/sites/dolgov/files/ETA/oflc/pdfs/H-2A_Record_Layout_FY2021_Q1.pdf).
- Data dictionary for scraper-only fields is [here](https://www.dol.gov/sites/dolgov/files/ETA/oflc/pdfs/H-2A_Record_Layout_FY2021_Q1.pdf).

Background: 

- job_central parts 1 and 2 contain data for every clearance order submitted to DOL, for both the H-2A and H-2B visa programs. Each clearance order is for a primary job, but can contain multiple worksites and multiple housing locations (see below).
  
  - Disclosure data: Data on job postings released every quarter of a fiscal year.
  - Scraped data: In the interim between these data releases, we scrape the DOL site to see who is requesting H-2A or H-2B certification in real time.

- additional_housing contains all the data for the additional housing locations associated with a single clearance order.
- additioanl_worksite contains all data for additional work locations associated with a single clearance order.
- both ^ can be linked together with the Case Number.

### DOL WHD data

|  table_name   |  column_name              |  attribute_name                  |  definition |
|---|---|---|---|
|  whd_whisard  |  h2b_violtn_cnt           |  H2B Violation Count             |  Violations found under H2B (Work Visa - Temporary Non-Agricultural Work)
|  whd_whisard  |  h2b_bw_atp_amt           |  H2B BW ATP Amount               |  BW Agreed to under H2B (Work Visa - Temporary Non-Agricultural Work)
|  whd_whisard  |  h2b_ee_atp_cnt           |  H2B EE ATP Count                |  EE's Agreed to under H2B (Work Visa - Temporary Non-Agricultural Work)
|  whd_whisard  |  sraw_violtn_cnt          |  SRAW Violation Count            |  Violations found under SRAW (Spec. Agri. Workers/Replenishment Agri. Workers)
|  whd_whisard  |  sraw_bw_atp_amt          |  SRAW BW ATP Amount              |  BW Agreed to under SRAW (Spec. Agri. Workers/Replenishment Agri. Workers)
|  whd_whisard  |  sraw_ee_atp_cnt          |  SRAW EE ATP Count               |  EE's Agreed to under SRAW (Spec. Agri. Workers/Replenishment Agri. Workers)
|  whd_whisard  |  ld_dt                    |  Load Date Timestamp             |  Load Date Timestamp
|  whd_whisard  |  findings_start_date      |  Findings Start Date             |  The date where WHD determined that findings first occurred. Findings are defined as either a Violation or No Violation found. <br> <b>NOTE:</b> Findings Start Date is not equal to Case Open Date which is not included in the dataset.
|  whd_whisard  |  findings_end_date        |  Findings End Date               |  The date where WHD determined that findings last occurred. Findings are defined as either a Violation or No Violation found. <br> <b>NOTE:</b> Findings End Date is not equal to Case Close Date which is not included in the dataset.
|  whd_whisard  |  case_id                  |  Case ID                         |  Unique Case Identifier
|  whd_whisard  |  trade_nm                 |  Trade Name                      |  Employer Name
|  whd_whisard  |  legal_name               |  Legal Name                      |  Employer Legal Name.
|  whd_whisard  |  street_addr_1_txt        |  Employer Street Address         |  The street address
|  whd_whisard  |  cty_nm                   |  City Name                       |  Employer City
|  whd_whisard  |  st_cd                    |  State Code                      |  Employer State
|  whd_whisard  |  zip_cd                   |  Zip Code                        |  Employer Zip Code
|  whd_whisard  |  naic_cd                  |  NAICS Code                      |  Industry Code
|  whd_whisard  |  naics_code_description   |  NAICS Code Description.         |  Industry Code Description.
|  whd_whisard  |  case_violtn_cnt          |  Case Violation Count            |  Total Case Violations
|  whd_whisard  |  cmp_assd_cnt             |  Total CMP Assessments           |  Total CMP (Civil Monetary Penalties) assessments
|  whd_whisard  |  ee_violtd_cnt            |  EE's in Violation               |  Total EE's employed in Violation
|  whd_whisard  |  bw_atp_amt               |  BW ATP Amount                   |  Total Backwages Agreed To Pay
|  whd_whisard  |  ee_atp_cnt               |  EE ATP Amount                   |  Total Employees Agreed to
|  whd_whisard  |  flsa_violtn_cnt          |  FLSA Violation Count            |  Violations found under FLSA (Fair Labor Standards Act)
|  whd_whisard  |  flsa_repeat_violator     |  FLSA Repeat Violator            |  FLSA Repeat/Willful violator. R=Repeat; W=Willful; RW=Repeat and Willful.
|  whd_whisard  |  flsa_bw_atp_amt          |  FLSA BW ATP Amount              |  BW Agreed to under FLSA (Fair Labor Standards Act)
|  whd_whisard  |  flsa_ee_atp_cnt          |  FLSA EE ATP Count               |  EE's Agreed to under FLSA (Fair Labor Standards Act)
|  whd_whisard  |  flsa_mw_bw_atp_amt       |  FLSA MW BW ATP Amount           |  BW Agreed to under FLSA (Fair Labor Standards Act) Minimum Wages
   |  whd_whisard  |  flsa_ot_bw_atp_amt       |  FLSA OT BW ATP Amount           |  BW Agreed to under FLSA (Fair Labor Standards Act) Overtime
   |  whd_whisard  |  flsa_15a3_bw_atp_amt     |  FLSA 15a3 BW ATP Amount         |  BW Agreed under FLSA (Fair Labor Standards Act) 15 (a)(3)
   |  whd_whisard  |  flsa_cmp_assd_amt        |  FLSA CMP Assessed Amount        |  CMP's assessed under FLSA (Fair Labor Standards Act)
   |  whd_whisard  |  sca_violtn_cnt           |  SCA Violation Count             |  Violations found under  SCA (Service Contract Act)
   |  whd_whisard  |  sca_bw_atp_amt           |  SCA BW ATP Amount               |  BW Agreed to under SCA (Service Contract Act)
   |  whd_whisard  |  sca_ee_atp_cnt           |  SCA EE ATP Count                |  EE's Agreed to under  SCA (Service Contract Act)
   |  whd_whisard  |  mspa_violtn_cnt          |  MSPA Violation Count            |  Violations found under MSPA (Migrant and Seasonal Agricultural Worker Protection Act)
   |  whd_whisard  |  mspa_bw_atp_amt          |  MSPA BW ATP Amount              |  BW Agreed to under MSPA (Migrant and Seasonal Agricultural Worker Protection Act)
   |  whd_whisard  |  mspa_ee_atp_cnt          |  MSPA EE ATP Count               |  EE's Agreed to under MSPA (Migrant and Seasonal Agricultural Worker Protection Act)
   |  whd_whisard  |  mspa_cmp_assd_amt        |  MSPA CMP Assessed Amount        |  CMP's assessed under MSPA (Migrant and Seasonal Agricultural Worker Protection Act)
   |  whd_whisard  |  h1b_violtn_cnt           |  H1B Violation Count             |  Violations found under H1B (Work Visa - Speciality Occupations)
   |  whd_whisard  |  h1b_bw_atp_amt           |  H1B BW ATP Amount               |  BW Agreed to under H1B (Work Visa - Speciality Occupations)
   |  whd_whisard  |  h1b_ee_atp_cnt           |  H1B EE ATP Count                |  EE's Agreed to under H1B (Work Visa - Speciality Occupations)
   |  whd_whisard  |  h1b_cmp_assd_amt         |  H1B CMP Assessed Amount         |  CMP's assessed under H1B (Work Visa - Speciality Occupations)
   |  whd_whisard  |  fmla_violtn_cnt          |  FMLA Violation Count            |  Violations found under FMLA (Family and Medical Leave Act)
   |  whd_whisard  |  fmla_bw_atp_amt          |  FMLA BW ATP Amount              |  BW Agreed to under FMLA (Family and Medical Leave Act)
   |  whd_whisard  |  fmla_ee_atp_cnt          |  FMLA EE ATP Count               |  EE's Agreed to under FMLA (Family and Medical Leave Act)
   |  whd_whisard  |  fmla_cmp_assd_amt        |  FMLA CMP Assessed Amount        |  CMP's assessed under FMLA (Family and Medical Leave Act)
   |  whd_whisard  |  flsa_cl_violtn_cnt       |  FLSA CL Violation Count         |  Violations found under FLSA - CL (Fair Labor Standards Act - Child Labor)
   |  whd_whisard  |  flsa_cl_minor_cnt        |  FLSA CL Minor Count             |  Minors found employed in violation of FLSA - CL (Fair Labor Standards Act - Child Labor)
   |  whd_whisard  |  flsa_cl_cmp_assd_amt     |  FLSA CL CMP Assessed Amount     |  CMP's assessed under FLSA - CL (Fair Labor Standards Act - Child Labor)
   |  whd_whisard  |  dbra_cl_violtn_cnt       |  DBRA Violation Count            |  Violations found under DBRA (Davis-Bacon and Related Act)
   |  whd_whisard  |  dbra_bw_atp_amt          |  DBRA BW ATP Amount              |  BW Agreed to under DBRA (Davis-Bacon and Related Act)
   |  whd_whisard  |  dbra_ee_atp_cnt          |  DBRA EE ATP Count               |  EE's Agreed to under DBRA (Davis-Bacon and Related Act)
   |  whd_whisard  |  h2a_violtn_cnt           |  H2A Violation Count             |  Violations found under H2A (Work Visa - Seasonal Agricultural Workers)
|  whd_whisard  |  h2a_bw_atp_amt           |  H2A BW ATP Amount               |  BW Agreed to under H2A (Work Visa - Seasonal Agricultural Workers)
|  whd_whisard  |  h2a_ee_atp_cnt           |  H2A EE ATP Count                |  EE's Agreed to under H2A (Work Visa - Seasonal Agricultural Workers)
|  whd_whisard  |  h2a_cmp_assd_amt         |  H2A CMP Assessed Amount         |  CMP's assessed under H2A (Work Visa - Seasonal Agricultural Workers)
|  whd_whisard  |  flsa_smw14_violtn_cnt    |  FLSA SMW14 Violation Count      |  Violations found under FLSA - SMW14 (Fair Labor Standards Act - Special Minimum Wages under Section 14(c))
   |  whd_whisard  |  flsa_smw14_bw_amt        |  FLSA SMW14 BW ATP Amount        |  BW Agreed to under FLSA - SMW14 (Fair Labor Standards Act - Special Minimum Wages under Section 14(c))
   |  whd_whisard  |  flsa_smw14_ee_atp_cnt    |  FLSA SMW14 EE ATP Count         |  EE's Agreed to under FLSA - SMW14 (Fair Labor Standards Act - Special Minimum Wages under Section 14(c))
   |  whd_whisard  |  cwhssa_violtn_cnt        |  CWHSSA Violation Count          |  Violations found under CWHSSA (Contract Work Hours and Safety Standards Act)
   |  whd_whisard  |  cwhssa_bw_amt            |  CWHSSA BW ATP Amount            |  BW Agreed to under CWHSSA (Contract Work Hours and Safety Standards Act)
   |  whd_whisard  |  cwhssa_ee_cnt            |  CWHSSA EE ATP Count             |  EE's Agreed to under CWHSSA (Contract Work Hours and Safety Standards Act)
   |  whd_whisard  |  osha_violtn_cnt          |  OSHA Violation Count            |  Violations found under OSHA (Occupational Safety and Health Standards)
   |  whd_whisard  |  osha_bw_atp_amt          |  OSHA BW ATP Amount              |  BW Agreed to under OSHA (Occupational Safety and Health Standards)
   |  whd_whisard  |  osha_ee_atp_cnt          |  OSHA EE ATP Count               |  EE's Agreed to under OSHA (Occupational Safety and Health Standards)
   |  whd_whisard  |  osha_cmp_assd_amt        |  OSHA CMP Assessed Amount        |  CMP's assessed under OSHA (Occupational Safety and Health Standards)
   |  whd_whisard  |  eppa_violtn_cnt          |  EPPA Violation Count            |  Violations found under EPPA (Employee Polygraph Protection Act)
   |  whd_whisard  |  eppa_bw_atp_amt          |  EPPA BW ATP Amount              |  BW Agreed to under EPPA (Employee Polygraph Protection Act)
   |  whd_whisard  |  eppa_ee_cnt              |  EPPA EE ATP Count               |  EE's Agreed to under EPPA (Employee Polygraph Protection Act)
   |  whd_whisard  |  eppa_cmp_assd_amt        |  EPPA CMP Assessed Amount        |  CMP's assessed under EPPA (Employee Polygraph Protection Act)
   |  whd_whisard  |  h1a_violtn_cnt           |  H1A Violation Count             |  Violations found under H1A (Work Visa - Registered nurses for temporary employment)
   |  whd_whisard  |  h1a_bw_atp_amt           |  H1A BW ATP Amount               |  BW Agreed to under H1A (Work Visa - Registered nurses for temporary employment)
   |  whd_whisard  |  h1a_ee_atp_cnt           |  H1A EE ATP Count                |  EE's Agreed to under H1A (Work Visa - Registered nurses for temporary employment)
   |  whd_whisard  |  h1a_cmp_assd_amt         |  H1A CMP Assessed Amount         |  CMP's assessed under H1A (Work Visa - Registered nurses for temporary employment)
|  whd_whisard  |  crew_violtn_cnt          |  CREW Violation Count            |  Violations found under CREW (Longshoremen (D1))
|  whd_whisard  |  crew_bw_atp_amt          |  CREW BW ATP Amount              |  BW Agreed to under CREW (Longshoremen (D1))
|  whd_whisard  |  crew_ee_atp_cnt          |  CREW EE ATP Count               |  EE's Agreed to under CREW (Longshoremen (D1))
|  whd_whisard  |  crew_cmp_assd_amt        |  CREW CMP Assessed               |  CMP's assessed under CREW (Longshoremen (D1))
|  whd_whisard  |  ccpa_violtn_cnt          |  CCPA Violation Count            |  Violations found under CCPA (Consumer Credit Protection Act - Wage Garnishment)
|  whd_whisard  |  ccpa_bw_atp_amt          |  CCPA BW ATP Amount              |  BW Agreed to under CCPA (Consumer Credit Protection Act - Wage Garnishment)
|  whd_whisard  |  ccpa_ee_atp_cnt          |  CCPA EE ATP Count               |  EE's Agreed to under CCPA (Consumer Credit Protection Act - Wage Garnishment)
|  whd_whisard  |  flsa_smwpw_violtn_cnt    |  FLSA SMWPW Violation Count      |  Violations found under  FLSA - SMWPW (Fair Labor Standards Act - Special Minimum Wages - Patient worker)
|  whd_whisard  |  flsa_smwpw_bw_atp_amt    |  FLSA SMWPW BW ATP Amount        |  BW Agreed to under FLSA - SMWPW (Fair Labor Standards Act - Special Minimum Wages - Patient worker)
|  whd_whisard  |  flsa_smwpw_ee_atp_cnt    |  FLSA SMWPW EE ATP Count         |  EE's Agreed to under  FLSA - SMWPW (Fair Labor Standards Act - Special Minimum Wages - Patient worker)
|  whd_whisard  |  flsa_hmwkr_violtn_cnt    |  FLSA HMWKR Violation Count      |  Violations found under FLSA - HMWKR (Fair Labor Standards Act - industrial homework)
|  whd_whisard  |  flsa_hmwkr_bw_atp_amt    |  FLSA HMWKR BW ATP Amount        |  BW Agreed to under FLSA - HMWKR (Fair Labor Standards Act - industrial homework)
|  whd_whisard  |  flsa_hmwkr_ee_atp_cnt    |  FLSA HMWKR EE ATP Count         |  EE's Agreed to under FLSA - HMWKR (Fair Labor Standards Act - industrial homework)
|  whd_whisard  |  flsa_hmwkr_cmp_assd_amt  |  FLSA HMWKR CMP Assessed Amount  |  CMP's assessed under FLSA - HMWKR (Fair Labor Standards Act - industrial homework)
|  whd_whisard  |  ca_violtn_cnt            |  CA Violation Count              |  Violations found under CA (Copeland Anti-kickbact Act)
|  whd_whisard  |  ca_bw_atp_amt            |  CA BW ATP Amount                |  Back Wages Agreed to under CA (Copeland Anti-kickbact Act)
|  whd_whisard  |  ca_ee_atp_cnt            |  CA EE ATP Count                 |  EE's Agreed to under CA (Copeland Anti-kickbact Act)
|  whd_whisard  |  pca_violtn_cnt           |  PCA Violation Count             |  Violations found under PCA (Public Contracts Act)
|  whd_whisard  |  pca_bw_atp_amt           |  PCA BW ATP Amount               |  BW Agreed to under PCA (Public Contracts Act)
|  whd_whisard  |  pca_ee_atp_cnt           |  PCA EE ATP Count                |  EE's Agreed to under PCA (Public Contracts Act)
|  whd_whisard  |  flsa_smwap_violtn_cnt    |  FLSA SMWAP Violation Count      |  Violations found under  FLSA - SMWAP (Fair Labor Standards Act - Special Minimum Wages - Apprentices)
|  whd_whisard  |  flsa_smwap_bw_atp_amt    |  FLSA SMWAP BW ATP Amount        |  BW Agreed to under FLSA - SMWAP (Fair Labor Standards Act - Special Minimum Wages - Apprentices)
|  whd_whisard  |  flsa_smwap_ee_atp_cnt    |  FLSA SMWAP EE ATP Count         |  EE's Agreed to under  FLSA - SMWAP (Fair Labor Standards Act - Special Minimum Wages - Apprentices)
|  whd_whisard  |  flsa_smwft_violtn_cnt    |  FLSA SMWFT Violation Count      |  Violations found under  FLSA - SMWFT (Fair Labor Standards Act - Special Minimum Wages - Full Time)
|  whd_whisard  |  flsa_smwft_bw_atp_amt    |  FLSA SMWFT BW ATP Amount        |  BW Agreed to under FLSA - SMWFT (Fair Labor Standards Act - Special Minimum Wages - Full Time)
|  whd_whisard  |  flsa_smwft_ee_atp_cnt    |  FLSA SMWFT EE ATP Count         |  EE's Agreed to under  FLSA - SMWFT (Fair Labor Standards Act - Special Minimum Wages - Full Time)
|  whd_whisard  |  flsa_smwl_violtn_cnt     |  FLSA SMWL Violation Count       |  Violations found under  FLSA - SMWL (Fair Labor Standards Act - Special Minimum Wages - Learners)
|  whd_whisard  |  flsa_smwl_bw_atp_amt     |  FLSA SMWL BW ATP Amount         |  BW Agreed to under FLSA - SMWL (Fair Labor Standards Act - Special Minimum Wages - Learners)
|  whd_whisard  |  flsa_smwl_ee_atp_cnt     |  FLSA SMWL EE ATP Count          |  EE's Agreed to under  FLSA - SMWL (Fair Labor Standards Act - Special Minimum Wages - Learners)
|  whd_whisard  |  flsa_smwmg_violtn_cnt    |  FLSA SMWMG Violation Count      |  Violations found under  FLSA - SMWMG (Fair Labor Standards Act - Special Minimum Wages - Messengers)
|  whd_whisard  |  flsa_smwmg_bw_atp_amt    |  FLSA SMWMG BW ATP Amount        |  BW Agreed to under FLSA - SMWMG (Fair Labor Standards Act - Special Minimum Wages - Messengers)
|  whd_whisard  |  flsa_smwmg_ee_atp_cnt    |  FLSA SMWMG EE ATP Count         |  EE's Agreed to under  FLSA - SMWMG (Fair Labor Standards Act - Special Minimum Wages - Messengers)
|  whd_whisard  |  flsa_smwsl_violtn_cnt    |  FLSA SMWSL Violation Count      |  Violations found under  FLSA - SMWSL (Fair Labor Standards Act - Special Minimum Wages - Student Learners)
|  whd_whisard  |  flsa_smwsl_bw_atp_amt    |  FLSA SMWSL BW ATP Amount        |  BW Agreed to under FLSA - SMWSL (Fair Labor Standards Act - Special Minimum Wages - Student Learners)
|  whd_whisard  |  flsa_smwsl_ee_atp_cnt    |  FLSA SMWSL EE ATP Count         |  EE's Agreed to under FLSA - SMWSL (Fair Labor Standards Act - Special Minimum Wages - Student Learners)
|  whd_whisard  |  eev_violtn_cnt           |  EEV Violation Count             |  Violations found under EEV (ESA 91)




