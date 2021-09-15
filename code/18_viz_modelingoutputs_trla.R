

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
library(data.table)
library(janitor)

RUN_FROM_CONSOLE = FALSE
if(RUN_FROM_CONSOLE){
  args <- commandArgs(TRUE)
  DATA_DIR = args[1]
} else{
  #DATA_DIR = "~/Dropbox (Dartmouth College)/qss20_finalproj_rawdata/summerwork"
  DATA_DIR = "~/Dropbox/qss20_finalproj_rawdata/summerwork"
}

## define theme

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

color_guide = c("jobs" = "#1B9E77", 
                "WHD investigations" = "#D95F02", 
                "WHD violations" = "#7570B3",
                "TRLA intake" = "#E6AB02",
                "Both WHD TRLA" = "#A6761D")

##########################
# Read in datasets 
##########################

trla_training = fread(sprintf("%s/clean/trla_training.csv", DATA_DIR))
trla_testing = fread(sprintf("%s/clean/trla_testing.csv", DATA_DIR))

## rowbind
common_cols = intersect(colnames(trla_training), colnames(trla_testing))
trla_both = rbind.data.frame(trla_training %>% select(all_of(common_cols)),
                             trla_testing %>% select(all_of(common_cols))) %>%
          mutate(outcome_is_whd_investigation = ifelse(`WHD; not TRLA` == 1, 1, 0)) 

## choose top features from pooled model
coef_selected = read.csv("output/model_outputs/fi_results_outcome_is_investigation_overlapsd.csv") %>%
        filter(model == "lasso" & value != 0) %>%
        pull(coef_name) 

coef_intersect = intersect(colnames(trla_both), coef_selected)
coef_intersect_clean = janitor::make_clean_names(coef_intersect)
trla_formod = clean_names(trla_both)

final_vars = setdiff(coef_intersect_clean, c("job_end_date", "job_start_date", "requested_start_date_of_need"))


## logit
trla_pred = glm(formula(sprintf("outcome_is_trla_investigation ~ %s", 
                                   paste(final_vars, collapse = "+"))),
                   data = trla_formod,
                   family = "binomial")

whd_pred = glm(formula(sprintf("outcome_is_whd_investigation ~ %s", 
                               paste(final_vars, collapse = "+"))),
               data = trla_formod,
               family = "binomial")

## bind together coefficients and compare signs
compare_coefs_long = data.frame(trla_coef = summary(trla_pred)$coefficients[, "Estimate"],
                           names_coef = rownames(summary(trla_pred)$coefficients)) %>%
            left_join(data.frame(whd_coef = summary(whd_pred)$coefficients[, "Estimate"],
                                 names_coef = rownames(summary(whd_pred)$coefficients)),
                      on = "names_coef") %>%
            filter(!grepl("Intercept", names_coef)) %>%
            reshape2::melt(, id.vars = "names_coef") %>%
            group_by(variable) %>%
            mutate(ingroup_rank = rank(desc(value), ties.method = "first")) %>%
            ungroup() %>%
          mutate(is_acs = ifelse(grepl("^acs", names_coef), TRUE, FALSE))

compare_coefs_wide_rank = reshape2::dcast(compare_coefs_long, 
                                     names_coef ~ variable, value.var = "ingroup_rank")

ggplot(compare_coefs_wide_rank, aes(x = trla_coef, y = whd_coef)) +
  geom_point(size = 2, alpha = 0.5) +
  theme_DOL() +
  geom_smooth(se = FALSE) +
  xlab("Rank in predicting TRLA intake call\n(lower = higher risk)") +
  ylab("Rank in predicting WHD investigation\n(lower = higher risk)") 

ggsave(here("output/figs", 
            "trla_v_whd_rankcor.pdf"), width = 12, height = 8)

## compare by feature type
compare_coefs_wcat = reshape2::dcast(compare_coefs_long, 
                  names_coef ~ variable, value.var = "value") %>%
            mutate(coef_category = case_when(abs(trla_coef) < 0.1 &
                                              abs(whd_coef) < 0.1 ~ "Small both",
                                    trla_coef > 0 & whd_coef > 0 ~
                                    "Higher risk both",
                                    trla_coef < 0 & whd_coef < 0 ~ "Lower risk both",
                                    trla_coef > 0 & whd_coef < 0 ~ "Higher risk TRLA",
                                    trla_coef < 0 & whd_coef > 0 ~ "Higher risk WHD")) %>%
            select(names_coef, coef_category) %>%
            right_join(compare_coefs_long, by = "names_coef") %>%
            mutate(names_coef_wrap = str_wrap(gsub("\\_", " ", 
                                                  gsub("acs\\_", "", 
                                                       names_coef)), 40))


ggplot(compare_coefs_wcat %>%
      filter(is_acs & coef_category == "Higher risk both"),
    aes(x = names_coef_wrap, y = value, group = variable,
                               fill = variable)) +
  geom_bar(stat = "identity",
           position = "dodge", color = "black") +
  coord_flip() +
  ylab("Coefficient\n(positive = higher risk)") +
  scale_fill_manual(values = c("trla_coef" = as.character(color_guide["TRLA intake"]),
                               "whd_coef" = as.character(color_guide["WHD investigations"])),
                    labels = c("trla_coef" = "TRLA intake",
                               "whd_coef" = "WHD investigation")) +
  theme_DOL()  +
  xlab("Tract-level characteristic") +
  theme(legend.position = c(0.8, 0.2),
        axis.text.y = element_text(size = 10)) +
  labs(fill = "")

ggsave(here("output/figs", 
            "both_high_acs_trlawhd.pdf"), width = 12, height = 8)

ggplot(compare_coefs_wcat %>%
         filter(is_acs & coef_category == "Lower risk both"),
       aes(x = names_coef_wrap, y = value, group = variable,
           fill = variable)) +
  geom_bar(stat = "identity",
           position = "dodge", color = "black") +
  coord_flip() +
  ylab("Coefficient\n(negative = lower risk)") +
  scale_fill_manual(values = c("trla_coef" = as.character(color_guide["TRLA intake"]),
                               "whd_coef" = as.character(color_guide["WHD investigations"])),
                    labels = c("trla_coef" = "TRLA intake",
                               "whd_coef" = "WHD investigation")) +
  theme_DOL()  +
  xlab("Tract-level characteristic") +
  theme(legend.position = c(0.2, 0.5),
        axis.text.y = element_text(size = 10)) +
  labs(fill = "")

ggsave(here("output/figs", 
            "both_low_acs_trlawhd.pdf"), width = 12, height = 8)

ggplot(compare_coefs_wcat %>%
         filter(is_acs & coef_category 
                %in% c("Higher risk TRLA", "Higher risk WHD")),
       aes(x = names_coef_wrap, y = value, group = variable,
           fill = variable)) +
  geom_bar(stat = "identity",
           position = "dodge", color = "black") +
  coord_flip() +
  ylab("Coefficient\n(positive = higher risk)") +
  scale_fill_manual(values = c("trla_coef" = as.character(color_guide["TRLA intake"]),
                               "whd_coef" = as.character(color_guide["WHD investigations"])),
                    labels = c("trla_coef" = "TRLA intake",
                               "whd_coef" = "WHD investigation")) +
  theme_DOL()  +
  xlab("Tract-level characteristic") +
  theme(legend.position = c(0.8, 0.8),
        axis.text.y = element_text(size = 10)) +
  labs(fill = "") 

ggsave(here("output/figs", 
            "oppsigns_acs_trlawhd.pdf"), width = 12, height = 8)

preds = read.csv("output/model_outputs/pred_df_outcome_is_TRLA_investigation.csv")
confus = read.csv("output/model_outputs/confus_df_outcome_is_TRLA_investigation.csv")
evals = read.csv("output/model_outputs/evals_df_outcome_is_TRLA_investigation.csv")



## flag for degen model (all coef 0)
fi_flag_degen = fi %>% group_by(model) %>%
        filter(sum(value == 0) == n()) %>%
        ungroup() %>% select(model) %>% distinct() 

models_keep = setdiff(unique(fi$model), fi_flag_degen$model)

## get one test set
one_test = preds %>% filter(model == "dt_shallow")
obs_rate = sum(one_test$actual == 1)/nrow(one_test)

## use top 5%
rank_top5 = round(0.05 * nrow(one_test))

## within each model type, rank from highest predicted true to lowest
## and code top 5% to true
preds_coded = preds %>%
        filter(model %in% models_keep) %>%
        group_by(model) %>%
        arrange(desc(predicted_cont_true)) %>%
        mutate(rank_pred_true = rank(desc(predicted_cont_true), ties.method = "first")) %>%
        ungroup() %>%
        mutate(top_perc = ifelse(rank_pred_true <= rank_top5, TRUE, FALSE),
               pred_final = ifelse(top_perc, TRUE, FALSE),
               actual_final = ifelse(actual == 1, TRUE, FALSE),
               category = case_when(pred_final & actual_final ~ "TP",
                                    pred_final & !actual_final ~ "FP",
                                    !pred_final & actual_final ~ "FN",
                                    !pred_final & !actual_final ~ "TN"),
               meta_cat = case_when(grepl("P", category) ~ "Positive cases:\ninvestigation",
                                    TRUE ~ "Negative cases:\nno investigation"),
               model_descriptive = 
              case_when(grepl("random_forest_1000", model) ~ "RF: deep",
                        grepl("random_forest_100", model) ~ "RF: shallow",
                        grepl("l2", model) ~ "Ridge",
                        grepl("l1", model) ~ "Lasso",
                        grepl("ada", model) ~ "Adaboost",
                        grepl("gb_shallow", model) ~ "GB: shallow",
                        grepl("gb", model) ~ "GB: deep",
                        grepl("dt_shallow", model) ~ "DT: shallow",
                        TRUE ~ "DT: deep"))  


## create summaries
confus = preds_coded %>%
        group_by(model_descriptive, category) %>%
        summarise(count = n(),
                  perc = count/nrow(one_test)*100,
                  meta_cat = unique(meta_cat)) %>%
        ungroup() 


ggplot(confus, aes(x = model_descriptive, y  = perc, fill = category)) +
  geom_bar(stat = "identity", position = "dodge", color = "black") +
  scale_fill_manual(values = c("TN" = "darkgreen",
                               "FN" = "firebrick",
                               "TP" = "gold3",
                               "FP" = "darkorange1")) +
  theme_DOL() +
  facet_wrap(~category, scales = "free") +
  theme(legend.position = "bottom") +
  ylab("% of test set cases") +
  geom_label(aes(x = model_descriptive, y = perc, label = round(perc, 2), 
                 group = category),
             fill = "white", position = position_dodge(width = 1),
             size = 4,
             hjust = 1) +
  guides(fill = FALSE) +
  labs(fill = "") +
  coord_flip() +
  xlab("") 

ggsave(here("output/figs", 
            "errorcats_anyinvestigation_trla.pdf"), width = 12, height = 8)

## read in fi



## Visualize separation- after post-mod viz
ggplot(preds_coded %>%
      filter(model == "gb_deep"), aes(x = predicted_cont_true, fill = actual_final)) +
  geom_density(alpha = 0.5)  +
  theme_DOL() +
  xlab("Predicted probability from model") +
  ylab("Density of test set cases") +
  theme(legend.position = c(0.4, 0.8),
        legend.text = element_text(size = 16)) +
  scale_fill_manual(values = c("FALSE" = "#1B9E77",
                               "TRUE" = "#D95F02"),
                    labels = c("FALSE" = "Not Investigated",
                               "TRUE" = "Investigated")) +
  labs(fill = "") +
  scale_x_continuous(breaks = pretty_breaks(n = 10))

ggsave(here("output/figs", 
            "sep_anyinvestigation_gbshallow.pdf"), width = 12, height = 8)

ggplot(preds_coded %>%
         filter(model_descriptive == "Lasso"), 
       aes(x = predicted_cont_true, fill = actual_final)) +
  geom_density(alpha = 0.5)  +
  theme_DOL() +
  xlab("Predicted probability from model") +
  ylab("Density of test set cases") +
  theme(legend.position = c(0.4, 0.8),
        legend.text = element_text(size = 16)) +
  scale_fill_manual(values = c("FALSE" = "#1B9E77",
                               "TRUE" = "#D95F02"),
                    labels = c("FALSE" = "Not Investigated",
                               "TRUE" = "Investigated")) +
  labs(fill = "") +
  scale_x_continuous(breaks = pretty_breaks(n = 10))
   
ggsave(here("output/figs", 
            "sep_anyinvestigation_lasso.pdf"), width = 12, height = 8)


## read in fi
fi_res =read.csv("output/model_outputs/fi_results_outcome_is_investigation_overlapsd.csv")

## plot of nonzero coefficients
fi_res_lasso= fi_res %>% filter(model == "lasso") %>% arrange(desc(value)) %>%
        mutate(coef_name_upper = toupper(coef_name)) %>%
        group_by(coef_name_upper) %>%
        summarise(value = mean(value)) %>%
        ungroup() %>%
        mutate(is_acs = ifelse(grepl("ACS", coef_name_upper), TRUE, FALSE))

options(scipen = 999)
fi_res_lasso_pos = fi_res_lasso %>% filter(value > 0 & !is_acs) %>%
  arrange(desc(value)) %>% slice(1:20) %>% select(-is_acs)

print(xtable(fi_res_lasso_pos), include.rownames = FALSE)


fi_res_lasso_pos_acs = fi_res_lasso %>% filter(value > 0 & is_acs) %>%
      arrange(desc(value)) %>% slice(1:10) %>% select(-is_acs) %>%
      mutate(coef_name_clean = gsub("ACS.*\\!\\!", "", coef_name_upper)) %>%
      select(coef_name_clean, value)

print(xtable(fi_res_lasso_pos_acs), include.rownames = FALSE) 
