

##########################
# This code visualizes outputs from
# the predictive models
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
library(xtable)

RUN_FROM_CONSOLE = FALSE
if(RUN_FROM_CONSOLE){
  args <- commandArgs(TRUE)
  DATA_DIR = args[1]
} else{
  #DATA_DIR = "~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
  DATA_DIR = "~/Dropbox/qss20_finalproj_rawdata/summerwork"
}

##########################
# Read in model results: any WHD investigation
##########################

preds = read.csv("output/model_outputs/pred_df_outcome_is_investigation_overlapsd.csv")
confus = read.csv("output/model_outputs/confus_df_outcome_is_investigation_overlapsd.csv")
evals = read.csv("output/model_outputs/evals_df_outcome_is_investigation_overlapsd.csv")

## code to top 5% of predictions

### next- maybe use better threshold
total_in_test = confus %>% group_by(model) %>%
            summarise(total = sum(value)) %>%
            select(total) %>% distinct() %>% pull(total)
confus = confus %>%
      mutate(actual_bin = ifelse(actual == "False", FALSE, TRUE),
             predicted_bin = ifelse(predicted == "False", FALSE, TRUE),
             category = case_when(predicted_bin & actual_bin ~ "TP",
                                  predicted_bin& !actual_bin ~ "FP",
                                  !predicted_bin & actual_bin ~ "FN",
                                  !predicted_bin & !actual_bin ~ "TN"),
             perc =(value/total_in_test)*100,
             meta_cat = case_when(grepl("P", category) ~ "Positive cases:\ninvestigation",
                                  TRUE ~ "Negative cases:\nno investigation"))

ggplot(confus, aes(x = model, y  = perc, fill = category)) +
  geom_bar(stat = "identity", position = "dodge", color = "black") +
  scale_fill_manual(values = c("TN" = "darkgreen",
                               "FN" = "firebrick",
                               "TP" = "gold3",
                               "FP" = "darkorange1")) +
  theme_DOL() +
  facet_wrap(~meta_cat, scales = "free") +
  theme(legend.position = "bottom") +
  ylab("% of test set cases") +
  geom_label(aes(x = model, y = perc, label = round(perc, 2), 
                 group = category),
             fill = "white", position = position_dodge(width = 1),
             size = 6) +
  guides(fill = guide_legend(ncol = 2)) +
  labs(fill = "") 

ggsave(here("output/figs", 
            "errorcats_anyinvestigation.pdf"), width = 12, height = 8)

ggplot(preds %>%
      filter(model == "dt_shallow"), aes(x = predicted_cont_true, fill = actual)) +
  geom_density(alpha = 0.05)  


test = preds %>% filter(model == "dt_shallow")
