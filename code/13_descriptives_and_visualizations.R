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

# fuzzy matched data with whd and trla outcomes
merged_data <- readRDS("intermediate/whd_violations_wTRLA_catchmentonly.RDS")

###################
# Visualizations
###################

# custom theme
base_size = 24

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
merged_data <- merged_data %>%
  mutate(REQUESTED_START_DATE_OF_NEED = ymd_hms(REQUESTED_START_DATE_OF_NEED))

# extract the year for plotting
merged_data <- merged_data %>%
  mutate(year_for_plotting = as.factor(year(REQUESTED_START_DATE_OF_NEED)))

# get the summary statistics desired
plot_1_data <- merged_data %>%
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
  labs(x = "Year", y = "Number of Empoyers", fill = "Type of Employer", title = "Employer Type over Time") +
  scale_fill_manual(values = our_colors, labels = c("Unique Employers with Jobs", "Unique Employers with WHD Investigations", "Unique Employers with Violations"))

# not sure where we're getting NA from! especially b/c year_for_plotting has no NAs.. comes in during group_by/summarize stage


# plot 2: By year or by month-year, plotting the # of unique employers with jobs, # of unique employers with TRLA investigations
plot_2_data <- merged_data %>%
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
  labs(x = "Year", y = "Number of Empoyers", fill = "Type of Employer", title = "Employer Type over Time (TRLA)") +
  scale_fill_manual(values = c(our_colors[1], our_colors[2]), labels = c("Unique Employers with Jobs", "Unique Employers with TRLA Investigations"))


# plot 3: Something with overlap of those two
plot_3_data <- merged_data %>%
  group_by(year_for_plotting) %>%
  summarize(unique_employers = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "Neither WHD nor TRLA"]),
            unique_employers_with_whd_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "WHD; not TRLA"]),
            unique_employers_with_trla_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "TRLA; not WHD"]),
            unique_employers_with_both_investigations = n_distinct(jobs_row_id[outcome_compare_TRLA_WHD == "Both TRLA and WHD"]))

# convert to tall format so we can plot all 4
plot_3_data_tall <- melt(plot_3_data, id.vars = "year_for_plotting")

brewer.pal(8, "Dark2")
display.brewer.pal(8, "Dark2")


# shading post covid?

