library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)

demos_withinconn <- read.csv("demos_withinconn.csv")
colnames(demos_withinconn)[3] <- "sub_ses"
# filter columns that are networks

# target network columns
target_cols <- c(
  "Vis", "SomMot", "DorsAttn",
  "SalVentAttn", "Limbic", "Cont", "Default"
)

# predictors
predictors <- c("mean_FD", "msex", "site", "age_scandate", "distortion_correction", "eyes")

# ensure categorical variables are factors
demos_withinconn$msex <- factor(demos_withinconn$msex)
demos_withinconn$site <- factor(demos_withinconn$site)
demos_withinconn$scanner <- factor(demos_withinconn$scanner)
demos_withinconn$distortion_correction <- factor(demos_withinconn$distortion_correction)
demos_withinconn$eyes <- factor(demos_withinconn$eyes)

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
    data = demos_withinconn
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
demos_withinconn_filtered <- demos_withinconn %>%
  filter(mean_FD <= 0.25)

results_filtered <- list()

for (col in target_cols) {
  
  model <- lm(
    reformulate(predictors, response = col),
    data = demos_withinconn_filtered
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

summary(model)
alias(model)
