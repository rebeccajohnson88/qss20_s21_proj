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
library(here)

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
  mutate(JOB_START_DATE = ymd(JOB_START_DATE))

# extract the year for plotting
general_data <- general_data %>%
  mutate(year_for_plotting = year(JOB_START_DATE))

# filter to the relevant years
general_data <- general_data %>%
  filter(2014 <= year_for_plotting & year_for_plotting <= 2020)

general_data <- general_data %>%
  mutate(year_for_plotting = as.factor(year_for_plotting))

# get the summary statistics desired
plot_1_data <- general_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers = n_distinct(jobs_row_id),
            unique_employers_with_investigations = n_distinct(jobs_row_id[is_matched_investigations == TRUE]),
            unique_employers_with_violations = n_distinct(jobs_row_id[outcome_is_investigation_overlapsd == TRUE]))

# convert to tall format so we can plot all 3
plot_1_data_tall <- melt(plot_1_data, id.vars = "year_for_plotting")

# now the plot
plot_1_data_tall %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge") +
  theme_DOL() +
  labs(x = "Year", y = "Number of Empoyers", fill = "") +
  scale_fill_manual(values = our_colors, labels = c("Unique Employers with Jobs", "Unique Employers with WHD Investigations", "Unique Employers with Violations"))


ggsave(here("output/figs", "fig_1.pdf"), width = 12, height = 8)

# plot 2: By year or by month-year, plotting the # of unique employers with jobs, # of unique employers with TRLA investigations

# put the relevant date column in a cleaner date format
trla_data <- trla_data %>%
  mutate(JOB_START_DATE = ymd(JOB_START_DATE))

# extract the year for plotting
trla_data <- trla_data %>%
  mutate(year_for_plotting = year(JOB_START_DATE))

# filter to the relevant years
trla_data <- trla_data %>%
  filter(2014 <= year_for_plotting & year_for_plotting <= 2020)

trla_data <- trla_data %>%
  mutate(year_for_plotting = as.factor(year_for_plotting))

plot_2_data <- trla_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers = n_distinct(jobs_row_id),
            unique_employers_with_trla_investigations = n_distinct(jobs_row_id[outcome_is_investigation_overlapsd_trla == TRUE]))

# convert to tall format so we can plot both
plot_2_data_tall <- melt(plot_2_data, id.vars = "year_for_plotting")

# now the plot
plot_2_data_tall %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge") +
  theme_DOL() +
  labs(x = "Year", y = "Number of Empoyers", fill = "") +
  scale_fill_manual(values = c(our_colors[1], our_colors[2]), labels = c("Unique Employers with Jobs", "Unique Employers with TRLA Investigations"))

ggsave(here("output/figs", "fig_2.pdf"), width = 12, height = 8)

# plot 3: Something with overlap of those two
plot_3_data <- trla_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers_without_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "Neither WHD nor TRLA"]),
            unique_employers_with_whd_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "WHD; not TRLA"]),
            unique_employers_with_trla_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "TRLA; not WHD"]),
            unique_employers_with_both_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "Both TRLA and WHD"]))

# convert to tall format so we can plot all 4
plot_3_data_tall <- melt(plot_3_data, id.vars = "year_for_plotting")

# now the plot
plot_3_data_tall %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge") +
  theme_DOL() +
  labs(x = "Year", y = "Number of Empoyers", fill = "", title = "Employer Type Each Year (TRLA States)") +
  scale_fill_manual(values = c("#D95F02", "#66A61E", "#E6AB02", "#A6761D"), labels = c("Unique Employers with No Investigations", "Unique Employers with WHD Investigations", "Unique Employers with TRLA Investigations", "Unique Employers with both WHD and TRLA Investigations"))

ggsave(here("output/figs", "fig_3.pdf"), width = 12, height = 8)

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

ggsave(here("output/figs", "fig_4.pdf"), width = 12, height = 8)


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

# recode missing values
general_data <- general_data %>%
  mutate(ATTORNEY_AGENT_NAME_CLEANED = ifelse(ATTORNEY_AGENT_NAME_CLEANED == "", "missing", ATTORNEY_AGENT_NAME_CLEANED))

num_unique_employers <- length(unique(general_data$jobs_row_id))

plot_4_data <- general_data %>%
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
  mutate(plotting_ratio = distinct_investigations_prop / distinct_jobs_prop) %>%
  filter(ATTORNEY_AGENT_NAME_CLEANED != "missing")

# now the plot (investigations)
plot_4_data_final %>%
  ggplot(aes(x = plotting_ratio)) +
  geom_histogram() +
  theme_DOL() +
  labs(x = "Plotting Ratio", y = "Number of Attorney Agents", title = "Overrepresentation of Attorney Agents for Investigated Entities")

ggsave(here("output/figs", "fig_5.pdf"), width = 12, height = 8)

# For violations
plot_4_data_filtered_again <- general_data %>%
  filter(outcome_is_investigation_overlapsd == TRUE)

num_unique_employers_with_violations <- length(unique(plot_4_data_filtered_again$jobs_row_id))

plot_4_data_third <- plot_4_data_filtered_again %>%
  group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
  summarize(distinct_violations_prop = n_distinct(jobs_row_id) / num_unique_employers_with_violations)

plot_4_data_final_plot2 <- merge(plot_4_data_more, plot_4_data_third, by = "ATTORNEY_AGENT_NAME_CLEANED", all.x = TRUE)

plot_4_data_final_plot2 <- plot_4_data_final_plot2 %>%
  mutate(plotting_ratio_2 = distinct_violations_prop / distinct_investigations_prop) %>%
  filter(ATTORNEY_AGENT_NAME_CLEANED != "missing")

# now the plot (violations)
plot_4_data_final_plot2 %>%
  ggplot(aes(x = plotting_ratio_2)) +
  geom_histogram() +
  theme_DOL() +
  labs(x = "Plotting Ratio 2", y = "Number of Attorney Agents", title = "Overrepresentation of Attorney Agents for Entities with WHD Violations")

ggsave(here("output/figs", "fig_6.pdf"), width = 12, height = 8)

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
  mutate(plotting_ratio = distinct_investigations_prop / distinct_jobs_prop) %>%
  filter(SOC_CODE != "")

# now the plot (investigations)
plot_5_data_final %>%
  ggplot(aes(x = plotting_ratio)) +
  geom_histogram() +
  theme_DOL() +
  labs(x = "Plotting Ratio", y = "Number of SOC Codes", title = "Overrepresentation of SOC Codes for Investigated Entities")

ggsave(here("output/figs", "fig_7.pdf"), width = 12, height = 8)

# For violations
plot_5_data_filtered_again <- general_data %>%
  filter(outcome_is_investigation_overlapsd == TRUE)

num_unique_employers_with_violations <- length(unique(plot_5_data_filtered_again$jobs_row_id))

plot_5_data_third <- plot_5_data_filtered_again %>%
  group_by(SOC_CODE) %>%
  summarize(distinct_violations_prop = n_distinct(jobs_row_id) / num_unique_employers_with_violations)

plot_5_data_final_plot2 <- merge(plot_5_data_more, plot_5_data_third, by = "SOC_CODE", all.x = TRUE)

plot_5_data_final_plot2 <- plot_5_data_final_plot2 %>%
  mutate(plotting_ratio_2 = distinct_violations_prop / distinct_investigations_prop) %>%
  filter(SOC_CODE != "")

# now the plot (violations)
plot_5_data_final_plot2 %>%
  ggplot(aes(x = plotting_ratio_2)) +
  geom_histogram() +
  theme_DOL() +
  labs(x = "Plotting Ratio 2", y = "Number of SOC Codes", title = "Overrepresentation of SOC Codes for Entities with WHD Violations")

ggsave(here("output/figs", "fig_8.pdf"), width = 12, height = 8)

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
  mutate(plotting_ratio = distinct_investigations_prop / distinct_jobs_prop) # %>%

# now the plot (investigations)
plot_6_data_final %>%
  ggplot(aes(x = plotting_ratio)) +
  geom_histogram() +
  theme_DOL() +
  labs(x = "Plotting Ratio", y = "Number of NAICS Codes", title = "Overrepresentation of NAICS Codes for Investigated Entities")

# weird that these are all the same...

ggsave(here("output/figs", "fig_9.pdf"), width = 12, height = 8)

# For violations
plot_6_data_filtered_again <- general_data %>%
  filter(outcome_is_investigation_overlapsd == TRUE)

num_unique_employers_with_violations <- length(unique(plot_6_data_filtered_again$jobs_row_id))

plot_6_data_third <- plot_6_data_filtered_again %>%
  group_by(naic_cd) %>%
  summarize(distinct_violations_prop = n_distinct(jobs_row_id) / num_unique_employers_with_violations)

plot_6_data_final_plot2 <- merge(plot_6_data_more, plot_6_data_third, by = "naic_cd", all.x = TRUE)

plot_6_data_final_plot2 <- plot_6_data_final_plot2 %>%
  mutate(plotting_ratio_2 = distinct_violations_prop / distinct_investigations_prop)

# now the plot (violations)
plot_6_data_final_plot2 %>%
  ggplot(aes(x = plotting_ratio_2)) +
  geom_histogram() +
  theme_DOL() +
  labs(x = "Plotting Ratio 2", y = "Number of NAICS Codes", title = "Overrepresentation of NAICS Codes for Entities with WHD Violations")

ggsave(here("output/figs", "fig_10.pdf"), width = 12, height = 8)

# shading post covid?
