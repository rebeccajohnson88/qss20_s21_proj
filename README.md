# Repo for QSS20 final project
Repo for SIP final project for QSS20 focused on protecting legal rights of H-2 workers

## Directory structure

- [background_reading](https://github.com/rebeccajohnson88/qss20_s21_proj/tree/main/background_reading): contains background readings on (1) the H-2 program, (2) legal rights visa holders have, (3) evidence of violations of those rights

## Links to data sources

- DOL Wages and Hour Division (WHD) compliance data: https://enforcedata.dol.gov/views/data_summary.php 

  - Data download link: https://enfxfr.dol.gov/data_catalog/WHD/whd_whisard_20210127.csv.zip
  - Rough summary: contains ~309681 compliance-related actions (not limited to H2 program) beginning in FY2005
  - Documentation in `data/documentation/whd_data_dictionary.csv`

## Details on data

### DOL Quarterly Disclosure & Scraped Data

- job_central parts 1 and 2 contain data for every clearance order submitted to DOL, for both the H-2A and H-2B visa programs. Each clearance order is for a primary job, but can contain multiple worksites and multiple housing locations (see below)
  
  - Disclosure data: Data on job postings released every quarter of a fiscal year
  - Scraped data: In the interim between these data releases, we scrape the DOL site to see who is requesting H-2A or H-2B certification in real time.

- additional_housing contains all the data for the additional housing locations associated with a single clearance order
- additioanl_worksite contains all data for additional work locations associated with a single clearance order
- both ^ can be linked together with the Case Number

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




