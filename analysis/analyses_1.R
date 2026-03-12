library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(lme4)
library(lmerTest)
library(emmeans)

# mat_folder <- "/Users/ga0034de/Documents/rosmap_analyses_feb26/456parcels_fc"
# 
# 
# 
# names(conn_mats) <- sub("\\.csv$", "", basename(mat_files))
# # initialize list
# timeseries_list <- list()
# 
# for (f in ts_files) {
#   # extract subject ID if needed
#   sub_id <- sub(".*/(.*)456_timeseries\\.tsv$", "\\1", f)
#   print(paste("Processing subject:", sub_id))
#   ts <- read.delim(f)
#   timeseries_list[[sub_id]] <- as.matrix(ts)
# }

rosmap_df <- read.csv("mean_within_conn_demos.csv")
rosmap_df <- rosmap_df %>%
  left_join(df_3 %>% select(sub_id, ses_id, age_scandate), by = c("sub" = "sub_id", "ses" = "ses_id"))

colnames(rosmap_df)
# filter columns that are networks
networks_df <- rosmap_df %>%
  select(8:14)

# target network columns
target_cols <- c(
  "Vis", "SomMot", "DorsAttn",
  "SalVentAttn", "Limbic", "Cont", "Default"
)

# predictors
predictors <- c("mean_FD", "msex", "age_scandate", "site")

# ensure categorical variables are factors
rosmap_df$msex <- factor(rosmap_df$msex)
rosmap_df$site <- factor(rosmap_df$site)

# container for results
results <- list()

for (col in target_cols) {
  
  # defensive: skip degenerate targets
  if (all(is.na(rosmap_df[[col]])) ||
      sd(rosmap_df[[col]], na.rm = TRUE) == 0) {
    next
  }
  
  model <- lm(
    reformulate(predictors, response = col),
    data = rosmap_df
  )
  
  beta <- coef(model)["mean_FD"]
  pval <- summary(model)$coefficients["mean_FD", "Pr(>|t|)"]
  
  results[[col]] <- data.frame(
    network = col,
    beta_FD = beta,
    p_FD    = pval
  )
}

results_df <- do.call(rbind, results)

results_df$q_FD <- p.adjust(results_df$p_FD, method = "fdr")
results_df$q_FD_star <- cut(
  results_df$q_FD,
  breaks = c(-Inf, 0.001, 0.01, 0.05, Inf),
  labels = c("***", "**", "*", "")
)

print(results_df)

ggplot(results_df, aes(x = network, y = beta_FD)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  geom_text(aes(label = round(beta_FD, 2)), vjust = -0.5) +          # beta values
  geom_text(aes(label = q_FD_star), vjust = -0.3, size = 6) + # stars
  theme_minimal() +
  labs(
    title = "Beta values for mean_FD across networks",
    x = "Network",
    y = "Beta (mean_FD)"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


# exclude those rows that have mean_FD > 0.3
rosmap_df_filtered <- rosmap_df %>%
  filter(mean_FD <= 0.25)

results_filtered <- list()

for (col in target_cols) {
  
  # defensive: skip degenerate targets
  if (all(is.na(rosmap_df_filtered[[col]])) ||
      sd(rosmap_df_filtered[[col]], na.rm = TRUE) == 0) {
    next
  }
  
  model <- lm(
    reformulate(predictors, response = col),
    data = rosmap_df_filtered
  )
  
  beta <- coef(model)["mean_FD"]
  pval <- summary(model)$coefficients["mean_FD", "Pr(>|t|)"]
  
  results_filtered[[col]] <- data.frame(
    network = col,
    beta_FD = beta,
    p_FD    = pval
  )
}

results_filtered_df <- do.call(rbind, results_filtered)
print(results_filtered_df)

results_filtered_df$q_FD <- p.adjust(results_filtered_df$p_FD, method = "fdr")
results_filtered_df$q_FD_star <- cut(
  results_filtered_df$q_FD,
  breaks = c(-Inf, 0.001, 0.01, 0.05, Inf),
  labels = c("***", "**", "*", "")
)
print(results_filtered_df)

ggplot(results_filtered_df, aes(x = network, y = beta_FD)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  geom_text(aes(label = round(beta_FD, 2)), vjust = -0.5) +          # beta values
  geom_text(aes(label = q_FD_star), vjust = -0.3, size = 6) + # stars
  theme_minimal() +
  labs(
    title = "Beta values for mean_FD across networks",
    x = "Network",
    y = "Beta (mean_FD)"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

#plot mean FD
ggplot(rosmap_df, aes(x = mean_FD)) +
  geom_histogram(binwidth = 0.01, fill = "lightblue") +
  theme_minimal() +
  labs(title = "Distribution of Mean FD", x = "Mean FD", y = "Count")

#summary of stats of mean fd
mean_fd_summary <- rosmap_df %>%
  summarise(
    n = sum(!is.na(mean_FD)),
    mean = mean(mean_FD, na.rm = TRUE),
    sd = sd(mean_FD, na.rm = TRUE),
    min = min(mean_FD, na.rm = TRUE),
    first_quart = quantile(mean_FD, 0.25, na.rm = TRUE),
    median = median(mean_FD, na.rm = TRUE),
    second_quart = quantile(mean_FD, 0.75, na.rm = TRUE),
    max = max(mean_FD, na.rm = TRUE)
  )
print(mean_fd_summary)

# plot mean fd <0.25
ggplot(rosmap_df_filtered, aes(x = mean_FD)) +
  geom_histogram(binwidth = 0.01, fill = "lightblue", color = "black") +
  theme_minimal() +
  labs(title = "Distribution of Mean FD (Filtered)", x = "Mean FD", y = "Count")

#summary of stats of mean fd
filtered_fd_summary <- rosmap_df_filtered %>%
  summarise(
    n = sum(!is.na(mean_FD)),
    mean = mean(mean_FD, na.rm = TRUE),
    sd = sd(mean_FD, na.rm = TRUE),
    min = min(mean_FD, na.rm = TRUE),
    first_quart = quantile(mean_FD, 0.25, na.rm = TRUE),
    median = median(mean_FD, na.rm = TRUE),
    second_quart = quantile(mean_FD, 0.75, na.rm = TRUE),
    max = max(mean_FD, na.rm = TRUE)
  )
print(filtered_fd_summary)


#------- 

df_3 <- read_csv("/Volumes/GabrieleSSD/backup/Desktop/R_qc_metrics/derivatives_list_with_age.csv")


# trying mixed models with interacitons

target_cols <- c(
  "Vis", "SomMot", "DorsAttn",
  "SalVentAttn", "Limbic", "Cont", "Default"
)

rosmap_long <- rosmap_df %>%
  pivot_longer(
    cols = all_of(target_cols),
    names_to = "network",
    values_to = "within_conn"
  )
rosmap_long$msex <- factor(rosmap_long$msex)
rosmap_long$site <- factor(rosmap_long$site)
rosmap_long$network <- factor(rosmap_long$network)

model <- lmer(
  within_conn ~ mean_FD * network + age_scandate + msex + site + (1 | sub_ses),
  data = rosmap_long
)
levels(rosmap_long$network)
summary(model)
anova(model)

fd_effects <- emtrends(
  model,
  ~ network,
  var = "mean_FD"
)

results_df <- as.data.frame(
  summary(fd_effects, infer = TRUE)
)
colnames(results_df)
results_df$q_FD <- p.adjust(results_df$p.value, method = "fdr")

results_df$q_FD_star <- cut(
  results_df$q_FD,
  breaks = c(-Inf, 0.001, 0.01, 0.05, Inf),
  labels = c("***", "**", "*", "")
)
print(results_df)

ggplot(rosmap_long, aes(x = mean_FD, y = within_conn)) +
  geom_point(alpha = 0.4) +
  geom_smooth(method = "lm", color = "black", se = FALSE) +
  facet_wrap(~ network) +
  theme_bw() +
  labs(
    x = "Mean Framewise Displacement",
    y = "Within-network Connectivity",
    title = "QC–FC Relationship by Network"
  )

ggplot(results_df, aes(x = network, y = mean_FD.trend)) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  theme_bw() +
  labs(
    x = "Network",
    y = "FD Effect on Connectivity (beta)",
    title = "Effect of Motion on Within-network Connectivity"
  )

ggplot(results_df, aes(x = network, y = mean_FD.trend)) +
  geom_col(fill = "steelblue") +
  # beta values
  geom_text(aes(label = round(mean_FD.trend, 2)), vjust = -1.5, size = 4) +
  # FDR significance stars
  geom_text(aes(label = q_FD_star), vjust = 0.3, size = 6, fontface = "bold") +
  theme_minimal() +
  labs(
    title = "Effect of mean_FD on Within-network Connectivity",
    x = "Network",
    y = "Beta (mean_FD)"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# filtger for FD 

rosmap_long_filtered <- rosmap_long %>%
  filter(mean_FD <= 0.25)

rosmap_long_filtered$msex <- factor(rosmap_long_filtered$msex)
rosmap_long_filtered$site <- factor(rosmap_long_filtered$site)
rosmap_long_filtered$network <- factor(rosmap_long_filtered$network)

model <- lmer(
  within_conn ~ mean_FD * network + age_scandate + msex + site + (1 | sub_ses),
  data = rosmap_long_filtered
)

summary(model)
anova(model)

fd_effects <- emtrends(
  model,
  ~ network,
  var = "mean_FD"
)

results_df <- as.data.frame(
  summary(fd_effects, infer = TRUE)
)
colnames(results_df)
results_df$q_FD <- p.adjust(results_df$p.value, method = "fdr")

results_df$q_FD_star <- cut(
  results_df$q_FD,
  breaks = c(-Inf, 0.001, 0.01, 0.05, Inf),
  labels = c("***", "**", "*", "")
)
print(results_df)

ggplot(rosmap_long_filtered, aes(x = mean_FD, y = within_conn)) +
  geom_point(alpha = 0.4) +
  geom_smooth(method = "lm", color = "black", se = FALSE) +
  facet_wrap(~ network) +
  theme_bw() +
  labs(
    x = "Mean Framewise Displacement",
    y = "Within-network Connectivity",
    title = "QC–FC Relationship by Network"
  )

ggplot(results_df, aes(x = network, y = mean_FD.trend)) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  theme_bw() +
  labs(
    x = "Network",
    y = "FD Effect on Connectivity (beta)",
    title = "Effect of Motion on Within-network Connectivity"
  )

ggplot(results_df, aes(x = network, y = mean_FD.trend)) +
  geom_col(fill = "steelblue") +
  # beta values
  geom_text(aes(label = round(mean_FD.trend, 2)), vjust = -1.5, size = 4) +
  # FDR significance stars
  geom_text(aes(label = q_FD_star), vjust = 0.3, size = 6, fontface = "bold") +
  theme_minimal() +
  labs(
    title = "Effect of mean_FD on Within-network Connectivity",
    x = "Network",
    y = "Beta (mean_FD)"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))



#---
# packages (install if needed)
if (!requireNamespace("ggplot2", quietly=TRUE)) install.packages("ggplot2")
if (!requireNamespace("dplyr", quietly=TRUE)) install.packages("dplyr")
if (!requireNamespace("forcats", quietly=TRUE)) install.packages("forcats")
if (!requireNamespace("scales", quietly=TRUE)) install.packages("scales")

library(ggplot2)
library(dplyr)
library(forcats)
library(scales)

# assume results_df is already in your environment (the emtrends() output)
# ensure column names match: network, mean_FD.trend, SE, asymp.LCL, asymp.UCL, p.value, q_FD
# If p-value or q-value column names differ, adapt below.

plot_df <- results_df %>%
  mutate(
    # use q_FD if available for multiple comparisons; fallback to p.value
    p_adj = if ("q_FD" %in% names(.)) { as.numeric(q_FD) } else { as.numeric(p.value) },
    sig = case_when(
      is.na(p_adj) ~ "",
      p_adj < 0.001 ~ "***",
      p_adj < 0.01  ~ "**",
      p_adj < 0.05  ~ "*",
      TRUE ~ ""
    ),
    # nice network ordering: put Control (Cont) first or order by slope magnitude
    network = factor(network),
    network_ordered = fct_reorder(network, mean_FD.trend)   # reorder by slope (ascending)
  )

# Basic slope plot with 95% CI and significance labels
p <- ggplot(plot_df, aes(x = network_ordered, y = mean_FD.trend)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  geom_errorbar(aes(ymin = asymp.LCL, ymax = asymp.UCL), width = 0.2, size = 0.6) +
  geom_point(aes(fill = mean_FD.trend), shape = 21, color = "black", size = 4, show.legend = FALSE) +
  geom_text(aes(label = sig), nudge_y = sign(plot_df$mean_FD.trend) * 0.02 + 0.01, size = 5, fontface = "bold") +
  coord_flip() +
  scale_y_continuous(name = "Slope: d(within_conn) / d(mean_FD)", labels = scales::number_format(accuracy = 0.001)) +
  scale_x_discrete(name = "") +
  theme_classic(base_size = 14) +
  theme(
    axis.text = element_text(colour = "black"),
    axis.title.x = element_text(margin = margin(t = 10)),
    plot.title = element_text(face = "bold", size = 16),
    panel.grid.major.y = element_blank()
  ) +
  ggtitle("Motion slopes per network (with 95% CI)") +
  labs(caption = "Significance: * q<0.05, ** q<0.01, *** q<0.001 (FDR if q_FD present)")

# Print plot
print(p)

# Save high-res files (adjust filename and size as needed)
ggsave("motion_slopes_by_network.png", plot = p, width = 8, height = 5, dpi = 300)
ggsave("motion_slopes_by_network.pdf", plot = p, width = 8, height = 5)