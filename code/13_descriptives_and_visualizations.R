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
library(stringr)

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

##########################
# Clean year and attorney agent for WHD data
##########################

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

##########################
# Over-time plots
##########################

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

##########################
# Over-time plots TRLA
##########################


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


##########################
# To add: zoom in on 2020 pre and post covid
##########################


##########################
# Over-rep in those investigated: attorney agents
##########################

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

## first plot dist of n employers
sum(attorney_rep$n_employers >= 10, na.rm = TRUE)

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
  labs(x = "Attorney/agent on application", y = "Percent of employers they represent\nwith investigation\n(TRLA catchment states only)") +
  coord_flip() +
  scale_fill_manual(values = c(as.character(color_guide["WHD investigations"]), 
                              color_guide["TRLA intake"]),
                    labels = c("WHD investigation",
                               "TRLA intake")) +
  theme(axis.text.x = element_text(size = 12, angle = 90),
        legend.position = c(0.8, 0.2)) +
  labs(fill = "Investigator") 

ggsave(here("output/figs", "attorney_highriskWHD_trlastates.pdf"), width = 12, height = 8)

# Look at employers with high rates of violations conditional on an investigation
# but only within TRLA states
attorney_highrate_viol = trla_data %>%
  filter(outcome_is_investigation_overlapsd) %>%
  group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
  summarise(n_investigated = n_distinct(jobs_group_id)) %>%
  ungroup() %>%
  left_join(trla_data %>%
              filter(outcome_is_viol_overlapsd) %>%
              group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
              summarise(n_violations = n_distinct(jobs_group_id)) %>%
              ungroup()) %>% 
  left_join(trla_data %>% 
              filter(outcome_is_investigation_overlapsd_trla) %>%
              group_by(ATTORNEY_AGENT_NAME_CLEANED) %>%
              summarise(n_investigated_trla = n_distinct(jobs_group_id)) %>%
              ungroup()) %>%
  mutate(perc_investigations_viol = ifelse(is.na(n_violations), 0,
                                           n_violations/n_investigated),
         trla_intake_call = ifelse(is.na(n_investigated_trla), FALSE,
                                   TRUE)) %>%
  arrange(desc(perc_investigations_viol))
  
attorney_highrate_viol %>%
  filter(n_investigated >= 2 & ATTORNEY_AGENT_NAME_CLEANED != "Missing") %>%
  ggplot(aes(x = reorder(ATTORNEY_AGENT_NAME_CLEANED,
                         perc_investigations_viol), y = perc_investigations_viol*100, 
             fill = trla_intake_call)) +
  geom_col(position = "dodge", color = "black") +
  theme_DOL() +
  labs(x = "Attorney/agent on application", y = "Of employers investigated,\n% with 1+ WHD-found violation") +
  coord_flip() +
  scale_fill_manual(values = c("wheat4", 
                               color_guide["TRLA intake"]),
                    labels = c("None",
                               "1+")) +
  theme(axis.text.y = element_text(size = 12),
        legend.position = c(0.9, 0.1)) +
  labs(fill = "TRLA intakes?")  

ggsave(here("output/figs", "attorney_highviol_TRLAstates.pdf"), width = 12, height = 8)



##########################
# Over-representation in investigations: soc titles/naics codes
##########################

## create new 6 digit soc code
trla_data = trla_data %>%
        mutate(soc_code_6dig = gsub("\\..*", "", SOC_CODE)) 

## summarized titles
trla_data_wtitle = trla_data %>%
        group_by(soc_code_6dig, SOC_TITLE) %>%
        summarise(count_titles = n()) %>%
        filter(count_titles == max(count_titles)) %>%
        rename(soc_title_consolidated = SOC_TITLE) %>%
        right_join(trla_data, by = "soc_code_6dig")

## code consolidated
trla_v_WHD_soc = trla_data_wtitle %>%
        mutate(soc_summarized = ifelse(soc_code_6dig %in% c("45-2091", 
                                                            "45-2092",
                                                            "45-2093"), soc_title_consolidated, 
                                       "Other")) %>%
        group_by(soc_summarized, outcome_compare_TRLA_WHD) %>%
        summarise(soc_num = n_distinct(jobs_row_id)) %>%
        ungroup() %>%
        left_join(trla_data %>%
                    mutate(soc_summarized = ifelse(SOC_TITLE %in% soc_titles_ranked, SOC_TITLE, 
                                                   "Other")) %>%
                    group_by(outcome_compare_TRLA_WHD) %>%
                    summarise(soc_denom = n_distinct(jobs_row_id)) %>%
                    ungroup()) %>%
        mutate(soc_prop = soc_num/soc_denom,
               soc_wrapped = str_wrap(soc_summarized, width = 15)) 

#
ggplot(trla_v_WHD_soc %>%
      filter(outcome_compare_TRLA_WHD %in% c("TRLA; not WHD", 
                                             "WHD; not TRLA")),
      aes(x = soc_wrapped, y = soc_prop, fill = outcome_compare_TRLA_WHD)) +
  geom_bar(stat = "identity", position = "dodge", 
           color = "black") +
  coord_flip() +
  theme_DOL() +
  labs(fill = "") +
  theme(legend.position = c(0.8, 0.8)) +
  xlab("") +
  ylab("Proportion of employers in that investigation category") +
  scale_fill_manual(values = c("TRLA; not WHD" = as.character(color_guide["TRLA intake"]),
                               "WHD; not TRLA" = as.character(color_guide["WHD investigations"])))


ggsave(here("output/figs", "soc_code_compare.pdf"), width = 12, height = 8)
