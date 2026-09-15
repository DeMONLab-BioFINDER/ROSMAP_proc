# ============================================================
# FD-effect connectivity heatmaps
#
# Two 7 x 7 matrices:
#
#   1. All observations
#   2. FD filtered
#
# Diagonal:
#   within-network FD beta
#
# Off-diagonal:
#   between-network FD beta
#
# Fill:
#   beta_fd
#
# Labels:
#   beta + FDR significance
# ============================================================


library(ggplot2)
library(dplyr)
library(readr)
library(tidyr)
library(stringr)
library(patchwork)


# ============================================================
# 1. Input / output
# ============================================================

within_all_file <- file.path(
  output_dir("fd_within_longitudinal"),
  "fd_effects_withinconn_all_modelresults.csv"
)

within_filtered_file <- file.path(
  output_dir("fd_within_longitudinal"),
  "fd_effects_withinconn_fd_filtered_modelresults.csv"
)

between_all_file <- file.path(
  output_dir("fd_between_longitudinal"),
  "fd_effects_betweenconn_all_modelresults.csv"
)

between_filtered_file <- file.path(
  output_dir("fd_between_longitudinal"),
  "fd_effects_betweenconn_fd_filtered_modelresults.csv"
)


out_dir <- output_dir(
  "fd_heatmaps"
)


# ============================================================
# 2. Network order
# ============================================================

network_order <- c(
  "Vis",
  "SomMot",
  "DorsAttn",
  "SalVentAttn",
  "Limbic",
  "Cont",
  "Default"
)


# ============================================================
# 3. Read results
# ============================================================

within_all <- read_csv(
  within_all_file,
  show_col_types = FALSE
)

within_filtered <- read_csv(
  within_filtered_file,
  show_col_types = FALSE
)

between_all <- read_csv(
  between_all_file,
  show_col_types = FALSE
)

between_filtered <- read_csv(
  between_filtered_file,
  show_col_types = FALSE
)


# ============================================================
# 4. Build one complete 7 x 7 FD matrix
# ============================================================

make_fd_matrix <- function(
    within_results,
    between_results
) {

  # ----------------------------------------------------------
  # Diagonal: WITHIN-network effects
  # ----------------------------------------------------------

  diagonal <- within_results %>%

    mutate(
      network = as.character(network),

      network = str_replace(
        network,
        "Network",
        ""
      ),

      beta_fd = as.numeric(beta_fd),

      q_fd = as.numeric(q_fd),

      sig_fd = ifelse(
        is.na(sig_fd),
        "",
        sig_fd
      )
    ) %>%

    transmute(
      row_net = network,
      col_net = network,
      beta_fd = beta_fd,
      q_fd = q_fd,
      sig_fd = sig_fd,
      connection_type = "Within"
    )


  # ----------------------------------------------------------
  # Off-diagonal: BETWEEN-network effects
  # ----------------------------------------------------------

  between_clean <- between_results %>%

    mutate(
      network_combo = as.character(
        network_combo
      ),

      beta_fd = as.numeric(beta_fd),

      q_fd = as.numeric(q_fd),

      sig_fd = ifelse(
        is.na(sig_fd),
        "",
        sig_fd
      )
    ) %>%

    separate(
      network_combo,
      into = c(
        "network1",
        "network2"
      ),
      sep = "_to_",
      remove = FALSE,
      fill = "right"
    ) %>%

    mutate(
      network1 = str_replace(
        network1,
        "Network",
        ""
      ),

      network2 = str_replace(
        network2,
        "Network",
        ""
      )
    )


  # Original orientation
  between_1 <- between_clean %>%

    transmute(
      row_net = network1,
      col_net = network2,
      beta_fd = beta_fd,
      q_fd = q_fd,
      sig_fd = sig_fd,
      connection_type = "Between"
    )


  # Mirror across diagonal
  between_2 <- between_clean %>%

    transmute(
      row_net = network2,
      col_net = network1,
      beta_fd = beta_fd,
      q_fd = q_fd,
      sig_fd = sig_fd,
      connection_type = "Between"
    )


  # ----------------------------------------------------------
  # Combine within + between
  # ----------------------------------------------------------

  matrix_df <- bind_rows(
    diagonal,
    between_1,
    between_2
  ) %>%

    distinct(
      row_net,
      col_net,
      .keep_all = TRUE
    ) %>%

    mutate(

      cell_label = ifelse(
        is.na(beta_fd),
        "",
        paste0(
          sprintf(
            "%.3f",
            beta_fd
          ),
          sig_fd
        )
      ),

      row_net = factor(
        row_net,
        levels = rev(network_order)
      ),

      col_net = factor(
        col_net,
        levels = network_order
      )
    )


  # ----------------------------------------------------------
  # Force complete 7 x 7 matrix
  # ----------------------------------------------------------

  matrix_full <- expand_grid(

    row_net = factor(
      rev(network_order),
      levels = rev(network_order)
    ),

    col_net = factor(
      network_order,
      levels = network_order
    )

  ) %>%

    left_join(
      matrix_df,
      by = c(
        "row_net",
        "col_net"
      )
    )


  matrix_full
}


# ============================================================
# 5. Create ALL and FD-filtered matrices
# ============================================================

matrix_all <- make_fd_matrix(
  within_results = within_all,
  between_results = between_all
)


matrix_filtered <- make_fd_matrix(
  within_results = within_filtered,
  between_results = between_filtered
)


# ============================================================
# 6. Shared beta limits
# ============================================================
# Important: same colour represents same beta in both plots.

all_betas <- c(
  matrix_all$beta_fd,
  matrix_filtered$beta_fd
)

all_betas <- all_betas[
  is.finite(all_betas)
]

max_abs_beta <- max(
  abs(all_betas)
)

if (max_abs_beta == 0) {
  max_abs_beta <- 1
}

fill_limits <- c(
  -max_abs_beta,
  max_abs_beta
)


# ============================================================
# 7. Heatmap function
# ============================================================

plot_fd_matrix <- function(
    matrix_df,
    title,
    fill_limits
) {

  ggplot(
    matrix_df,
    aes(
      x = col_net,
      y = row_net,
      fill = beta_fd
    )
  ) +

    geom_tile(
      color = "white",
      linewidth = 0.7
    ) +

    geom_text(
      aes(
        label = cell_label
      ),
      size = 6,
      color = "black",
      na.rm = TRUE
    ) +

    scale_fill_gradient2(
      low = "#2166AC",
      mid = "white",
      high = "#B2182B",
      midpoint = 0,
      limits = fill_limits,
      na.value = "grey90",
      name = expression(beta[FD])
    ) +

    coord_fixed() +

    labs(
      title = title,
      subtitle =
        "Diagonal = within-network | Off-diagonal = between-network",
      x = NULL,
      y = NULL
    ) +

    theme_minimal(
      base_size = 15
    ) +

    theme(

      panel.grid = element_blank(),

      axis.text.x = element_text(
        angle = 45,
        hjust = 1,
        face = "bold",
        size = 12
      ),

      axis.text.y = element_text(
        face = "bold",
        size = 12
      ),

      plot.title = element_text(
        face = "bold",
        hjust = 0.5,
        size = 18
      ),

      plot.subtitle = element_text(
        hjust = 0.5,
        size = 11
      ),

      legend.position = "right"
    )
}


# ============================================================
# 8. Plot
# ============================================================

p_all <- plot_fd_matrix(
  matrix_df = matrix_all,
  title = "All observations",
  fill_limits = fill_limits
)


p_filtered <- plot_fd_matrix(
  matrix_df = matrix_filtered,
  title = paste0(
    "FD filtered (mean FD < ",
    FD_THRESHOLD,
    ")"
  ),
  fill_limits = fill_limits
)


print(p_all)

print(p_filtered)


# ============================================================
# 9. Combined figure
# ============================================================

p_combined <-
  p_all +
  p_filtered +
  plot_layout(
    ncol = 2,
    guides = "collect"
  ) &
  theme(
    legend.position = "right"
  )


print(
  p_combined
)


# ============================================================
# 10. Save
# ============================================================

ggsave(
  file.path(
    out_dir,
    "fd_heatmap_all.pdf"
  ),
  plot = p_all,
  width = 9,
  height = 8,
  units = "in"
)


ggsave(
  file.path(
    out_dir,
    "fd_heatmap_fd_filtered.pdf"
  ),
  plot = p_filtered,
  width = 9,
  height = 8,
  units = "in"
)


ggsave(
  file.path(
    out_dir,
    "fd_heatmaps_all_vs_fd_filtered.pdf"
  ),
  plot = p_combined,
  width = 47,
  height = 25,
  units = "cm"
)


ggsave(
  file.path(
    out_dir,
    "fd_heatmaps_all_vs_fd_filtered.svg"
  ),
  plot = p_combined,
  width = 50,
  height = 50,
  units = "cm"
)

