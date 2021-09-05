##########################
# This code creates descriptives and visualizations based on merged WHD/TRLA data
# Author: Cam Guage and Rebecca Johnson
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
library(scales)

RUN_FROM_CONSOLE = FALSE
if(RUN_FROM_CONSOLE){
 args <- commandArgs(TRUE)
  DATA_DIR = args[1]
} else{
  #DATA_DIR = "~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
  DATA_DIR = "~/Dropbox/qss20_finalproj_rawdata/summerwork"
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
color_guide = c("jobs" = "#1B9E77", 
               "WHD investigations" = "#D95F02", 
               "WHD violations" = "#7570B3",
               "TRLA intake" = "#E6AB02",
               "Both WHD TRLA" = "#A6761D")

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
n_by_year <- general_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers = n_distinct(jobs_group_id),
            unique_employers_with_investigations = n_distinct(jobs_group_id[is_matched_investigations == TRUE]),
            unique_employers_with_violations = n_distinct(jobs_group_id[outcome_is_investigation_overlapsd == TRUE]),
            unique_jobs = n_distinct(jobs_row_id),
            unique_jobs_with_investigations = n_distinct(jobs_row_id[is_matched_investigations == TRUE]),
            unique_jobs_with_violations = n_distinct(jobs_row_id[outcome_is_investigation_overlapsd == TRUE]))

# convert to tall format so we can plot all 3
n_by_year_long <- melt(n_by_year, id.vars = "year_for_plotting")

# now the plot
n_by_year_long %>%
  filter(grepl("employers", variable)) %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge", color = "black") +
  theme_DOL() +
  labs(x = "Calendar Year", y = "Number of Employers", fill = "") +
  theme(legend.position = "bottom") +
  scale_fill_manual(values = c(as.character(color_guide["jobs"]),
                               color_guide["WHD investigations"],
                               color_guide["WHD violations"]),
                    labels = c("Unique Employers with Jobs", "Unique Employers with WHD Investigation", 
                                                    "Unique Employers with Violation")) +
  guides(fill = guide_legend(nrow = 2))


ggsave(here("output/figs", "barplot_unique_emp_by_year.pdf"), 
       plot = last_plot(), 
       device = "pdf",
       width = 12, height = 8)

## repeat but at level of jobs rather than employers
n_by_year_long %>%
  filter(grepl("jobs", variable)) %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge", color = "black") +
  theme_DOL() +
  labs(x = "Calendar Year", y = "Number of Employers", fill = "") +
  theme(legend.position = "bottom") +
  scale_fill_manual(values = c(as.character(color_guide["jobs"]),
                               color_guide["WHD investigations"],
                               color_guide["WHD violations"]), labels = c("Job Applications (repeated across employers)", "Job Applications with WHD Investigations", 
                                                    "Job Applications with Violation")) +
  guides(fill = guide_legend(nrow = 2))


ggsave(here("output/figs", "barplot_unique_jobs_by_year.pdf"), 
       plot = last_plot(), 
       device = "pdf",
       width = 12, height = 8)

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

n_by_year_trla <- trla_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers = n_distinct(jobs_group_id),
            unique_employers_with_trla_investigations = n_distinct(jobs_group_id[outcome_is_investigation_overlapsd_trla == TRUE]),
            unique_jobs = n_distinct(jobs_row_id),
            unique_jobs_with_trla_investigations = n_distinct(jobs_row_id[outcome_is_investigation_overlapsd_trla == TRUE]))

# convert to tall format so we can plot both
n_by_year_trla_long <- melt(n_by_year_trla, id.vars = "year_for_plotting")

# now the plot
n_by_year_trla_long %>%
  filter(grepl("employers", variable)) %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge", color = "black") +
  theme_DOL() +
  labs(x = "Year", y = "Number of Employers\n(restricted to 7 TRLA\ncatchment states)", fill = "") +
  scale_fill_manual(values = c(as.character(color_guide["jobs"]),
                               color_guide["TRLA intake"]), labels = c("Unique Employers", 
                                        "Unique Employers with TRLA intake call")) +
  theme(legend.position = "bottom") +
  scale_y_continuous(breaks = pretty_breaks(n = 10)) 

ggsave(here("output/figs", "barplot_unique_emp_by_year_trla.pdf"), width = 12, height = 8)

# plot 3: Something with overlap of those two
trla_v_WHD <- trla_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers_without_investigations = n_distinct(jobs_group_id[outcome_compare_TRLA_WHD == "Neither WHD nor TRLA"]),
            unique_employers_with_whd_investigations = n_distinct(jobs_group_id[outcome_compare_TRLA_WHD == "WHD; not TRLA"]),
            unique_employers_with_trla_investigations = n_distinct(jobs_group_id[outcome_compare_TRLA_WHD == "TRLA; not WHD"]),
            unique_employers_with_both_investigations = n_distinct(jobs_group_id[outcome_compare_TRLA_WHD == "Both TRLA and WHD"]))

# convert to tall format so we can plot all 4
trla_v_WHD_long <- melt(trla_v_WHD, id.vars = "year_for_plotting")

# now the plot
trla_v_WHD_long %>%
  ggplot(aes(x = year_for_plotting, y = value, fill = variable)) +
  geom_col(position = "dodge") +
  theme_DOL() +
  labs(x = "Year", y = "Number of Employers\n(restricted to 7 TRLA\ncatchment states)",
       fill = "") +
  scale_fill_manual(values = c("#66A61E", "#D95F02","#E6AB02", "#A6761D"), 
                    labels = c("Unique Employers with No Investigation", 
                               "Unique Employers with WHD Investigation", 
                               "Unique Employers with TRLA Investigation", 
                               "Unique Employers with both WHD and TRLA Investigation")) +
  theme(legend.position = "bottom") +
  guides(fill = guide_legend(ncol = 2)) 

ggsave(here("output/figs", "trla_v_whd_counts.pdf"), width = 12, height = 8)

# plot 3.5 for proportions instead of counts
trla_v_WHD_plot <- trla_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers = n_distinct(jobs_group_id),
            unique_employers_without_investigations = n_distinct(jobs_group_id[outcome_compare_TRLA_WHD == "Neither WHD nor TRLA"])/unique_employers,
            unique_employers_with_whd_investigations = n_distinct(jobs_group_id[outcome_compare_TRLA_WHD == "WHD; not TRLA"])/unique_employers,
            unique_employers_with_trla_investigations = n_distinct(jobs_group_id[outcome_compare_TRLA_WHD == "TRLA; not WHD"])/unique_employers,
            unique_employers_with_both_investigations = n_distinct(jobs_group_id[outcome_compare_TRLA_WHD == "Both TRLA and WHD"])/unique_employers)

trla_v_WHD_plot_long <- melt(trla_v_WHD_plot, id.vars = "year_for_plotting")

# now the plot
trla_v_WHD_plot_long %>%
  filter(variable != "unique_employers" &
        variable != "unique_employers_without_investigations") %>%
  ggplot(aes(x = year_for_plotting, y = value*100, fill = variable)) +
  geom_col(position = "dodge", color = "black") +
  theme_DOL() +
  labs(x = "Year", y = "Percent of Unique Employers\n(restricted to 7 TRLA\ncatchment states)", fill = "") +
  scale_fill_manual(values = c(as.character(color_guide["WHD investigations"]),
                               color_guide["TRLA intake"],
                               color_guide["Both WHD TRLA"]), 
                    labels = c("Unique Employers with WHD Investigations", 
                               "Unique Employers with TRLA Intake Call", 
                               "Unique Employers with both WHD and TRLA Intake")) +
  theme(legend.position = "bottom") +
  guides(fill = guide_legend(ncol = 2))

ggsave(here("output/figs", "trla_v_whd_prop.pdf"), width = 12, height = 8)


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
  mutate(ATTORNEY_AGENT_NAME_CLEANED = ifelse(ATTORNEY_AGENT_NAME_CLEANED == "", "Missing", ATTORNEY_AGENT_NAME_CLEANED))

# group by unique employers and whether investigation
attorney_rep = general_data %>%
                group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
                summarise(n_employers = n_distinct(jobs_group_id)) %>%
               ungroup() %>%
            left_join(general_data %>%
                    filter(outcome_is_investigation_overlapsd) %>%
                    group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
                        summarise(n_investigated = n_distinct(jobs_group_id)) %>%
                        ungroup()) %>% 
        mutate(investigated_prop_employers = ifelse(is.na(n_investigated), 0,
                                                    n_investigated/n_employers)) %>%
        arrange(desc(investigated_prop_employers))

#to plot: for those with at least 5 employers, ratio
attorney_rep_top = attorney_rep %>% filter(n_employers >= 10) %>% arrange(desc(investigated_prop_employers)) %>%
        slice(1:15) 

# new articles: https://account.miamiherald.com/paywall/subscriber-only?resume=238404323&intcid=ab_archive

# now the plot (investigations)
attorney_rep_top %>%
  ggplot(aes(x = reorder(ATTORNEY_AGENT_NAME_CLEANED,
                      investigated_prop_employers), y = investigated_prop_employers*100, 
             fill = investigated_prop_employers)) +
  geom_col(position = "dodge", color = "black") +
  theme_DOL() +
  labs(x = "Attorney/agent on application", y = "Percent of their employers\nwith WHD investigation") +
  scale_fill_gradient(low = "darkorange1", high = "firebrick") +
  guides(fill = FALSE) +
  theme(axis.text.x = element_text(size = 12, angle = 90)) +
  geom_label(aes(x = reorder(ATTORNEY_AGENT_NAME_CLEANED,
                  investigated_prop_employers), y = investigated_prop_employers*100,
                 label = round(n_employers)),
             fill = "white") 

ggsave(here("output/figs", "attorney_highriskWHD.pdf"), width = 12, height = 8)

## repeat for TRLA states
## clean attorney name and find high risk 
aan = unlist(lapply(trla_data$ATTORNEY_AGENT_NAME, clean_names))
trla_data$ATTORNEY_AGENT_NAME_CLEANED <- aan

# recode missing values
trla_data <- trla_data %>%
  mutate(ATTORNEY_AGENT_NAME_CLEANED = ifelse(ATTORNEY_AGENT_NAME_CLEANED == "", "Missing", ATTORNEY_AGENT_NAME_CLEANED))

attorney_rep_trla = trla_data %>%
  group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
  summarise(n_employers = n_distinct(jobs_group_id)) %>%
  ungroup() %>%
  left_join(trla_data %>%
              filter(outcome_is_investigation_overlapsd) %>%
              group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
              summarise(n_investigated = n_distinct(jobs_group_id)) %>%
              ungroup()) %>% 
  left_join(trla_data %>% 
              filter(outcome_is_investigation_overlapsd_trla) %>%
              group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
              summarise(n_investigated_trla = n_distinct(jobs_group_id)) %>%
              ungroup()) %>%
  mutate(investigated_prop_employers = ifelse(is.na(n_investigated), 0,
                                              n_investigated/n_employers),
         investigated_prop_employers_trla = ifelse(is.na(n_investigated_trla), 0,
                                              n_investigated_trla/n_employers),
         some_investigations_both = ifelse(investigated_prop_employers > 0 &
                                          investigated_prop_employers_trla > 0, 
                                          TRUE, FALSE)) %>%
  arrange(desc(investigated_prop_employers))

attorney_rep_top_trla = attorney_rep_trla %>% filter(some_investigations_both & n_employers >= 10 &
                                                investigated_prop_employers >= 0.05) %>%
                    select(ATTORNEY_AGENT_NAME_CLEANED, investigated_prop_employers,
                           investigated_prop_employers_trla) %>%
                    reshape2::melt(, id.vars = c("ATTORNEY_AGENT_NAME_CLEANED")) %>%
                    mutate(which_rate = ifelse(grepl("prop_employers_trla", variable),
                                               "TRLA",
                                               "WHD")) 
          

# new articles: https://account.miamiherald.com/paywall/subscriber-only?resume=238404323&intcid=ab_archive

# now the plot (investigations)
attorney_rep_top_trla %>%
  ggplot(aes(x = reorder(ATTORNEY_AGENT_NAME_CLEANED,
                         value), y = value*100, 
             fill = which_rate)) +
  geom_col(position = "dodge", color = "black") +
  theme_DOL() +
  labs(x = "Attorney/agent on application", y = "Percent of their employers\nwith investigation\n(TRLA catchment states only)") +
  coord_flip() +
  scale_fill_manual(values = c(as.character(color_guide["WHD investigations"]), 
                              color_guide["TRLA intake"]),
                    labels = c("WHD investigation",
                               "TRLA intake")) +
  theme(axis.text.x = element_text(size = 12, angle = 90),
        legend.position = c(0.8, 0.2)) +
  labs(fill = "Investigator") 

ggsave(here("output/figs", "attorney_highriskWHD_trlastates.pdf"), width = 12, height = 8)

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
