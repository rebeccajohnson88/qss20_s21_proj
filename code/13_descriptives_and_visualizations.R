##########################
# This code creates descriptives and visualizations based on merged WHD/TRLA data
# Author: Cam Guage
# Written: 8/26/2021
##########################
# Packages, Imports, and Working Directory
##########################

library(ggplot2)
library(dplyr)
library(lubridate)
library(reshape2)
library(RColorBrewer)

RUN_FROM_CONSOLE = FALSE
if(RUN_FROM_CONSOLE){
  args <- commandArgs(TRUE)
  DATA_DIR = args[1]
} else{
  DATA_DIR = "~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
}


setwd(DATA_DIR)

#####################
# Loading in Data
#####################

# trla_file
trla_data <- readRDS("clean/whd_violations_wTRLA_catchmentonly.RDS")

# general file
general_data <- readRDS("clean/whd_violations.RDS")

###################
# Visualizations
###################

# custom theme
theme_DOL <- function(base_size = 24){
  theme_bw(base_size = base_size) %+replace%
    theme(
      panel.grid.major = element_blank(),  
      panel.grid.minor = element_blank(),
      panel.border = element_blank(),
      panel.background = element_blank(),
      strip.background = element_rect(fill = NA),
      axis.text.x = element_text(color = "black"),
      axis.text.y = element_text(color = "black"),
      axis.ticks.x = element_blank(),
      axis.line = element_line(colour = "black",
                               size = 0.5),
      legend.title = element_text(size= base_size,
                                  face = "italic"),
      legend.text = element_text(size = 12),
      legend.background = element_blank()
    )
}

# custom palette
our_colors = c("#1B9E77", "#E6AB02", "#7570B3")

# visualization 1: By year or by month-year, plotting the # of unique employers with jobs, # of unique employers with WHD investigations, # of unique employers with violations (using the overlap version of the outcome)

# put the relevant date column in a cleaner date format
general_data <- general_data %>%
  mutate(REQUESTED_START_DATE_OF_NEED = ymd_hms(REQUESTED_START_DATE_OF_NEED))

# extract the year for plotting
general_data <- general_data %>%
  mutate(year_for_plotting = as.factor(year(REQUESTED_START_DATE_OF_NEED)))

# check and make sure the years look correct
table(general_data$year_for_plotting) # no NA's here

# get the summary statistics desired
plot_1_data <- general_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers = n_distinct(jobs_row_id),
            unique_employers_with_investigations = n_distinct(jobs_row_id[is_matched_investigations == TRUE]),
            unique_employers_with_violations = n_distinct(jobs_row_id[outcome_is_investigation_overlapsd == TRUE]))

plot_1_data # where is this NA row coming from!

# convert to tall format so we can plot all 3
plot_1_data_tall <- melt(plot_1_data, id.vars = "year_for_plotting")

# now the plot
plot_1_data_tall %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge") +
  theme_DOL() +
  labs(x = "Year", y = "Number of Empoyers", fill = "Type of Employer", title = "Employer Type over Time") +
  scale_fill_manual(values = our_colors, labels = c("Unique Employers with Jobs", "Unique Employers with WHD Investigations", "Unique Employers with Violations"))

# not sure where we're getting NA from! especially b/c year_for_plotting has no NAs.. comes in during group_by/summarize stage


# plot 2: By year or by month-year, plotting the # of unique employers with jobs, # of unique employers with TRLA investigations

# put the relevant date column in a cleaner date format
trla_data <- trla_data %>%
  mutate(REQUESTED_START_DATE_OF_NEED = ymd_hms(REQUESTED_START_DATE_OF_NEED))

# extract the year for plotting
trla_data <- trla_data %>%
  mutate(year_for_plotting = as.factor(year(REQUESTED_START_DATE_OF_NEED)))

table(trla_data$year_for_plotting)

plot_2_data <- trla_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers = n_distinct(jobs_row_id),
            unique_employers_with_trla_investigations = n_distinct(jobs_row_id[outcome_is_investigation_overlapsd_trla == TRUE]))

plot_2_data # NA row again!!! 


# trla_data %>%
  # group_by(year_for_plotting) %>%
  # summarize(n = n()) other numbers line up so this is sus


# convert to tall format so we can plot both
plot_2_data_tall <- melt(plot_2_data, id.vars = "year_for_plotting")

# now the plot
plot_2_data_tall %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge") +
  theme_DOL() +
  labs(x = "Year", y = "Number of Empoyers", fill = "Type of Employer", title = "Employer Type over Time (TRLA)") +
  scale_fill_manual(values = c(our_colors[1], our_colors[2]), labels = c("Unique Employers with Jobs", "Unique Employers with TRLA Investigations"))


# plot 3: Something with overlap of those two
plot_3_data <- trla_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers_without_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "Neither WHD nor TRLA"]),
            unique_employers_with_whd_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "WHD; not TRLA"]),
            unique_employers_with_trla_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "TRLA; not WHD"]),
            unique_employers_with_both_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "Both TRLA and WHD"]))

# convert to tall format so we can plot all 4
plot_3_data_tall <- melt(plot_3_data, id.vars = "year_for_plotting")

brewer.pal(8, "Dark2")
display.brewer.pal(8, "Dark2")

# now the plot
plot_3_data_tall %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge") +
  theme_DOL() +
  labs(x = "Year", y = "Number of Empoyers", fill = "Type of Employer", title = "Employer Type Each Year (TRLA States)") +
  scale_fill_manual(values = c("#D95F02", "#66A61E", "#E6AB02", "#A6761D"), labels = c("Unique Employers with No Investigations", "Unique Employers with WHD Investigations", "Unique Employers with TRLA Investigations", "Unique Employers with both WHD and TRLA Investigations"))

# plot 3.5 for proportions instead of counts
plot_3_and_a_half_data <- trla_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers = n_distinct(jobs_row_id),
            unique_employers_without_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "Neither WHD nor TRLA"]),
            unique_employers_with_whd_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "WHD; not TRLA"]),
            unique_employers_with_trla_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "TRLA; not WHD"]),
            unique_employers_with_both_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "Both TRLA and WHD"]))

plot_3_and_a_half_data <- plot_3_and_a_half_data %>%
  mutate(unique_employers_without_investigations = unique_employers_without_investigations / unique_employers,
         unique_employers_with_whd_investigations = unique_employers_with_whd_investigations / unique_employers,
         unique_employers_with_trla_investigations = unique_employers_with_trla_investigations / unique_employers,
         unique_employers_with_both_investigations = unique_employers_with_both_investigations / unique_employers)


plot_3_and_a_half_data = subset(plot_3_and_a_half_data, select = -unique_employers)


plot_3_and_a_half_data_tall<- melt(plot_3_and_a_half_data, id.vars = "year_for_plotting")

# now the plot
plot_3_and_a_half_data_tall %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge") +
  theme_DOL() +
  labs(x = "Year", y = "Proportion of Empoyers", fill = "Type of Employer", title = "Employer Type Each Year (TRLA States)") +
  scale_fill_manual(values = c("#D95F02", "#66A61E", "#E6AB02", "#A6761D"), labels = c("Unique Employers with No Investigations", "Unique Employers with WHD Investigations", "Unique Employers with TRLA Investigations", "Unique Employers with both WHD and TRLA Investigations"))


# plot 4: Overrepresentation of certain attorney agents in entities investigated or with violations

# function to clean the EMPLOYER_NAME in approved_only (h2a apps) and legal_name in violations (WHD data)
clean_names <- function(one){
  
  string_version = toString(one) # convert to string
  no_white_space = trimws(string_version) # remove leading and trailing whitespace
  upper_only <- toupper(no_white_space) # convert to uppercase
  res <- gsub("\\s+", " ", upper_only)
  return(res)
  
}

# make new "name" columns for the cleaned versions of the names
aan = unlist(lapply(general_data$ATTORNEY_AGENT_NAME, clean_names))
general_data$ATTORNEY_AGENT_NAME_CLEANED <- aan

# in entities investigated
general_data <- general_data %>%
  mutate(ATTORNEY_AGENT_NAME_CLEANED = ifelse(ATTORNEY_AGENT_NAME_CLEANED == "", "missing", ATTORNEY_AGENT_NAME_CLEANED)) # %>%
  # filter(is_matched_investigations == TRUE)

############################
# ADJUST THIS FOR PLOT 4

num_unique_employers <- length(unique(general_data$jobs_row_id))

plot_4_data <- plot_4_data %>%
  group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
  summarize(distinct_jobs_prop = n_distinct(jobs_row_id) / num_unique_employers)

plot_4_data_filtered <- general_data %>%
  filter(is_matched_investigations == TRUE)

num_unique_employers_with_investigations <- length(unique(plot_4_data_filtered$jobs_row_id))

plot_4_data_more <- plot_4_data_filtered %>%
  group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
  summarize(distinct_investigations_prop = n_distinct(jobs_row_id) / num_unique_employers_with_investigations)

plot_4_data_final <- merge(plot_4_data, plot_4_data_more, by = "ATTORNEY_AGENT_NAME_CLEANED", all.x = TRUE)

plot_4_data_final <- plot_4_data_final %>%
  mutate(plotting_ratio = distinct_jobs_prop / distinct_investigations_prop) %>%
  filter(ATTORNEY_AGENT_NAME_CLEANED != "missing")

# now the plot (investigations)
plot_4_data_final %>%
  ggplot(aes(x = plotting_ratio)) +
  geom_histogram() +
  theme_DOL() +
  labs(x = "Plotting Ratio", y = "Number of SOC Codes", title = "Representation of SOC Codes for Investigated Entities")

# do we need to do this for violations as well?

# plot 5: Overrepresentation of certain SOC codes

num_unique_employers <- length(unique(general_data$jobs_row_id))

plot_5_data <- general_data %>%
  group_by(SOC_CODE) %>%
  summarize(distinct_jobs_prop = n_distinct(jobs_row_id) / num_unique_employers)

plot_5_data_filtered <- general_data %>%
  filter(is_matched_investigations == TRUE)

num_unique_employers_with_investigations <- length(unique(plot_5_data_filtered$jobs_row_id))

plot_5_data_more <- plot_5_data_filtered %>%
  group_by(SOC_CODE) %>%
  summarize(distinct_investigations_prop = n_distinct(jobs_row_id) / num_unique_employers_with_investigations)

plot_5_data_final <- merge(plot_5_data, plot_5_data_more, by = "SOC_CODE", all.x = TRUE)

plot_5_data_final <- plot_5_data_final %>%
  mutate(plotting_ratio = distinct_jobs_prop / distinct_investigations_prop) %>%
  filter(SOC_CODE != "")
  
# now the plot (investigations)
plot_5_data_final %>%
  ggplot(aes(x = plotting_ratio)) +
  geom_histogram() +
  theme_DOL() +
  labs(x = "Plotting Ratio", y = "Number of SOC Codes", title = "Representation of SOC Codes for Investigated Entities")

# plot 6: Overrepresentation of certain naics codes

num_unique_employers <- length(unique(general_data$jobs_row_id))

plot_6_data <- general_data %>%
  group_by(naic_cd) %>%
  summarize(distinct_jobs_prop = n_distinct(jobs_row_id) / num_unique_employers)

plot_6_data_filtered <- general_data %>%
  filter(is_matched_investigations == TRUE)

num_unique_employers_with_investigations <- length(unique(plot_6_data_filtered$jobs_row_id))

plot_6_data_more <- plot_6_data_filtered %>%
  group_by(naic_cd) %>%
  summarize(distinct_investigations_prop = n_distinct(jobs_row_id) / num_unique_employers_with_investigations)

plot_6_data_final <- merge(plot_6_data, plot_6_data_more, by = "naic_cd", all.x = TRUE)

plot_6_data_final <- plot_6_data_final %>%
  mutate(plotting_ratio = distinct_jobs_prop / distinct_investigations_prop) # %>%
  # filter out NA?

# now the plot (investigations)
plot_5_data_final %>%
  ggplot(aes(x = plotting_ratio)) +
  geom_histogram() +
  theme_DOL() +
  labs(x = "Plotting Ratio", y = "Number of SOC Codes", title = "Representation of SOC Codes for Investigated Entities")


# NA to filter out- when should I do this?

# shading post covid?
