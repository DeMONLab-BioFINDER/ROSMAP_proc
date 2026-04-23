library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(tidyverse)
library(readxl)


rosmap_demos <- read_excel("/Users/ga0034de/Documents/R_projs/rosmap_analyses_feb26/ROSMAP_demos2026.xlsx")

rosmap_demos <- rosmap_demos %>%
  select(c("projid", "study", "msex", "educ", "age_bl", "dcfdx_bl"))
# filter only ROS and MAP studies

# 0 pad to 8 digits projid
rosmap_demos <- rosmap_demos %>%
  mutate(projid = str_pad(projid, width = 8, side = "left", pad = "0"))

df_2 <- read_csv("/Users/ga0034de/Documents/R_projs/rosmap_analyses_feb26/mean_within_conn_demos.csv")
# count duplicates in first column
df_2 <- df_2 %>%
  group_by(sub) %>%
  mutate(ses_count = n()) %>%
  ungroup()

# new df with unique sub column
df_2_unique <- df_2 %>%
  group_by(sub) %>%
  slice(1) %>%
  ungroup() %>%
  select(c("sub", "ses_count"))

#plot
ggplot(df_2_unique, aes(x = ses_count)) +
  geom_histogram(binwidth = 1, fill = "lightblue", color = "black") +
  labs(title = "Distribution of Session Counts per Subject",
       x = "Number of Sessions",
       y = "Frequency") +
  theme_minimal()
# make table
ses_count_table <- df_2_unique %>%
  group_by(ses_count) %>%
  summarise(count = n())
print(ses_count_table)

# add sub- to projid in rosmap_demos
rosmap_demos <- rosmap_demos %>%
  mutate(projid = paste0("sub-", projid))
# left merge rosmap_demos and df_2_unique by projid and sub
merged_df <- left_join(df_2, rosmap_demos, by = c("sub" = "projid"))

# merge df_2_unique and rosmap_demos by sub and projid
sexcount_df <- left_join(df_2_unique, rosmap_demos, by = c("sub" = "projid"))
# get count of study column
study_count <- sexcount_df %>%
  group_by(study) %>%
  summarise(count = n())
print(study_count)
