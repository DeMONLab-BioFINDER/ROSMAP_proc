library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)

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
predictors <- c("mean_FD", "msex", "site")

# ensure categorical variables are factors
rosmap_df$msex <- factor(rosmap_df$msex)
rosmap_df$site <- factor(rosmap_df$site)

# container for results
results <- list()

# Loop over each network column (e.g., Vis, SomMot, etc.)
for (col in target_cols) {
  
  # # --- SAFETY CHECK ---
  # # Skip this network if:
  # # 1) all values are NA, OR
  # # 2) there is no variance (sd = 0 → constant values → regression would fail)
  # if (all(is.na(rosmap_df[[col]])) ||
  #     sd(rosmap_df[[col]], na.rm = TRUE) == 0) {
  #   next  # skip to next network
  # }
  
  # --- FIT LINEAR MODEL ---
  # Dynamically builds a formula like:
  #   Vis ~ mean_FD + msex + site
  #   SomMot ~ mean_FD + msex + site
  # depending on `col`
  model <- lm(
    reformulate(predictors, response = col),
    data = rosmap_df
  )
  
  # --- EXTRACT EFFECT OF INTEREST ---
  # Get the regression coefficient (beta) for mean_FD
  beta <- coef(model)["mean_FD"]
  
  # Get the p-value associated with mean_FD
  pval <- summary(model)$coefficients["mean_FD", "Pr(>|t|)"]
  
  # --- STORE RESULTS ---
  # Save results for this network as a small data frame
  results[[col]] <- data.frame(
    network = col,     # network name
    beta_FD = beta,    # effect size of mean_FD
    p_FD    = pval     # p-value of mean_FD
  )
}

# --- COMBINE ALL NETWORK RESULTS ---
# Convert list of data frames into one big data frame
results_df <- do.call(rbind, results)

# --- MULTIPLE COMPARISON CORRECTION ---
# Adjust p-values across networks using FDR (Benjamini-Hochberg)
results_df$q_FD <- p.adjust(results_df$p_FD, method = "fdr")

# --- ADD SIGNIFICANCE LABELS ---
# Convert q-values into stars for plotting/interpretation:
# ***  q < 0.001
# **   q < 0.01
# *    q < 0.05
# ""   not significant
results_df$q_FD_star <- cut(
  results_df$q_FD,
  breaks = c(-Inf, 0.001, 0.01, 0.05, Inf),
  labels = c("***", "**", "*", "")
)

print(results_df)
print(model)
# exclude those rows that have mean_FD > 0.3
rosmap_df_filtered <- rosmap_df %>%
  filter(mean_FD <= 0.25)

results_filtered <- list()

for (col in target_cols) {
  
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

results_df$network <- factor(results_df$network, levels = target_cols)
results_filtered_df$network <- factor(results_filtered_df$network, levels = target_cols)

# plot 1: all subjects
p1 <- ggplot(results_df, aes(x = network, y = beta_FD)) +
  geom_col(width = 0.7) +
  geom_text(
    aes(label = round(beta_FD, 3)),
    vjust = ifelse(results_df$beta_FD >= 0, -0.4, 1.2),
    size = 4
  ) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  theme_minimal(base_size = 13) +
  labs(
    title = "Beta estimates for mean_FD (all subjects)",
    x = "Network",
    y = "Beta for mean_FD"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

print(p1)

p2 <- ggplot(results_filtered_df, aes(x = network, y = beta_FD)) +
  geom_col(width = 0.7) +
  geom_text(
    aes(label = round(beta_FD, 3)),
    vjust = ifelse(results_filtered_df$beta_FD >= 0, -0.4, 1.2),
    size = 4
  ) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  theme_minimal(base_size = 13) +
  labs(
    title = "Beta estimates for mean_FD (mean_FD <= 0.25)",
    x = "Network",
    y = "Beta for mean_FD"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

print(p2)
