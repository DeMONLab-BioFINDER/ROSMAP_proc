library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(lme4)
library(lmerTest)
library(emmeans)


df_3 <- read_csv("/Volumes/GabrieleSSD/backup/Desktop/R_qc_metrics/derivatives_list_with_age.csv")

rosmap_df <- read.csv("mean_within_conn_demos.csv")
rosmap_df <- rosmap_df %>%
  left_join(df_3 %>% select(sub_id, ses_id, age_scandate), by = c("sub" = "sub_id", "ses" = "ses_id"))

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

########
# filter for FD 

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



library(lme4)
library(lmerTest)   # gives p-values for lmer
library(emmeans)
library(ggplot2)
library(dplyr)
library(forcats)
library(scales)

# Single-dataset analyzer ---------------------------------------------------
analyze_fd_effects <- function(df,
                               target_cols = c("Vis","SomMot","DorsAttn","SalVentAttn","Limbic","Cont","Default"),
                               fd_var = "mean_FD",
                               id_var = "sub_ses",
                               age_var = "age_scandate",
                               sex_var = "msex",
                               site_var = "site",
                               label = "dataset") {
  # Check required columns
  required <- c(target_cols, fd_var, id_var, age_var, sex_var, site_var)
  miss <- setdiff(required, names(df))
  if (length(miss) > 0) stop("Missing columns in df: ", paste(miss, collapse = ", "))
  
  # make long
  long <- df %>%
    tidyr::pivot_longer(cols = all_of(target_cols),
                        names_to = "network",
                        values_to = "within_conn") %>%
    mutate(
      !!sym(sex_var) := factor(.data[[sex_var]]),
      !!sym(site_var) := factor(.data[[site_var]]),
      network = factor(network)
    )
  
  # fit model (using lmerTest to get p-values)
  form <- as.formula(paste0("within_conn ~ ", fd_var, " * network + ",
                            age_var, " + ", sex_var, " + ", site_var, " + (1 | ", id_var, ")"))
  model <- lmer(form, data = long)
  
  # emtrends for motion effect per network
  fd_effects <- tryCatch(
    emtrends(model, ~ network, var = fd_var),
    error = function(e) stop("emtrends failed: ", e$message)
  )
  results_df <- as.data.frame(summary(fd_effects, infer = TRUE))
  # ensure consistent names
  # expected cols: network, mean_FD.trend (or var.trend), SE, df, asymp.LCL, asymp.UCL, z.ratio, p.value
  # rename trend column to mean_FD.trend if not already
  trend_col <- grep("\\.trend$", names(results_df), value = TRUE)
  if (length(trend_col) == 1 && trend_col != "mean_FD.trend") {
    names(results_df)[names(results_df) == trend_col] <- "mean_FD.trend"
  }
  
  # adjust / add q and stars
  results_df <- results_df %>%
    mutate(
      p.value = as.numeric(p.value),
      q_FD = p.adjust(p.value, method = "fdr"),
      q_FD_star = cut(q_FD, breaks = c(-Inf, 0.001, 0.01, 0.05, Inf),
                      labels = c("***", "**", "*", "")),
      dataset = label
    )
  
  # scatter facet plot (QC-FC by network)
  scatter <- ggplot(long, aes(x = fd_var, y = "within_conn")) +
    geom_point(alpha = 0.35, size = 0.7) +
    geom_smooth(method = "lm", color = "black", se = FALSE) +
    facet_wrap(~ network) +
    theme_bw(base_size = 12) +
    labs(title = paste0("QC-FC by network — ", label),
         x = "Mean Framewise Displacement",
         y = "Within-network connectivity")
  
  # slope plot with CIs and stars
  plot_df <- results_df %>%
    mutate(
      network = factor(network),
      network_ordered = fct_reorder(network, mean_FD.trend),
      p_adj_for_sig = q_FD
    )
  
  slope_plot <- ggplot(plot_df, aes(x = network_ordered, y = mean_FD.trend)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
    geom_errorbar(aes(ymin = asymp.LCL, ymax = asymp.UCL), width = 0.2, size = 0.6) +
    geom_point(aes(fill = mean_FD.trend), shape = 21, color = "black", size = 4, show.legend = FALSE) +
    geom_text(aes(label = q_FD_star), nudge_y = sign(plot_df$mean_FD.trend) * 0.02 + 0.01, size = 5, fontface = "bold") +
    coord_flip() +
    scale_y_continuous(name = paste0("Slope: d(within_conn) / d(", fd_var, ")"),
                       labels = number_format(accuracy = 0.001)) +
    scale_x_discrete(name = "") +
    theme_classic(base_size = 13) +
    ggtitle(paste0("Motion slopes per network (with 95% CI) — ", label)) +
    labs(caption = "Significance: * q<0.05, ** q<0.01, *** q<0.001 (FDR)")
  
  return(list(
    long = long,
    model = model,
    emtrends = fd_effects,
    results = results_df,
    scatter_plot = scatter,
    slope_plot = slope_plot
  ))
}

# Comparison wrapper -------------------------------------------------------
compare_fd <- function(df_before, df_after, label_before = "before", label_after = "after", ...) {
  out_before <- analyze_fd_effects(df_before, label = label_before, ...)
  out_after  <- analyze_fd_effects(df_after,  label = label_after,  ...)
  return(list(before = out_before, after = out_after))
}

rosmap_df_filtered <- rosmap_df %>%
  filter(mean_FD <= 0.25)

res <- compare_fd(rosmap_df, rosmap_df_filtered,
                                    target_cols = c("Vis","SomMot","DorsAttn","SalVentAttn","Limbic","Cont","Default"),
                                    fd_var = "mean_FD", id_var = "sub_ses",
                                    age_var = "age_scandate", sex_var = "msex", site_var = "site",
                                    label_before = "pre-exclusion", label_after = "post-exclusion")

# # View tables:
res$before$results
res$after$results


# # Print plots:
print(res$before$slope_plot)
print(res$after$slope_plot)
print(res$before$scatter_plot)  # facet plot of FD vs within_conn
