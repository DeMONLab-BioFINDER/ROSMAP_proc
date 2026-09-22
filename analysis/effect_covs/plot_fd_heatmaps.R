# Plot longitudinal FD-effect connectivity heatmaps from already FDR-corrected
# results produced by heatmap_fd.R.
#
# No multiple-comparison correction is performed in this script.

.script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
.script_dir <- if (length(.script_arg)) {
  dirname(normalizePath(sub("^--file=", "", .script_arg[[1]]), mustWork = FALSE))
} else {
  getwd()
}
.paths_candidates <- unique(c(
  file.path("analysis", "paths.R"),
  file.path(.script_dir, "paths.R"),
  file.path(.script_dir, "..", "paths.R"),
  "paths.R",
  file.path("..", "paths.R")
))
.paths_file <- .paths_candidates[file.exists(.paths_candidates)][1]
if (is.na(.paths_file)) stop("Could not locate analysis/paths.R")
source(.paths_file)
source(file.path(ANALYSIS_DIR, "effect_covs", "covs_utils.R"))
rm(.script_arg, .script_dir, .paths_candidates, .paths_file)

library(patchwork)

out_dir <- output_dir("fd_heatmaps")
in_file <- require_file(
  file.path(out_dir, "fd_effects_longitudinal_fdr_unique.csv"),
  "FDR-corrected FD heatmap results"
)
network_order <- target_cols

fd_unique <- readr::read_csv(in_file, show_col_types = FALSE)
required <- c(
  "filter_status", "row_net", "col_net", "beta_fd", "t_val_fd",
  "p_fd", "q_fdr", "sig_fdr"
)
if (!all(required %in% names(fd_unique))) {
  stop("Corrected FD table is missing required columns.")
}

make_matrix <- function(status) {
  df <- fd_unique %>% filter(filter_status == status)
  if (nrow(df) != 28L) stop("Expected 28 unique FD cells for status: ", status)

  mirrored <- df %>%
    filter(row_net != col_net) %>%
    mutate(
      row_net_original = row_net,
      col_net_original = col_net,
      row_net = col_net_original,
      col_net = row_net_original
    ) %>%
    select(-row_net_original, -col_net_original)

  bind_rows(df, mirrored) %>%
    distinct(row_net, col_net, .keep_all = TRUE) %>%
    tidyr::complete(
      row_net = network_order,
      col_net = network_order
    ) %>%
    mutate(
      cell_label = ifelse(
        is.na(beta_fd),
        "",
        paste0(sprintf("%.3f", beta_fd), ifelse(is.na(sig_fdr), "", sig_fdr))
      ),
      row_net = factor(row_net, levels = rev(network_order)),
      col_net = factor(col_net, levels = network_order)
    )
}

matrix_pre <- make_matrix("pre")
matrix_post <- make_matrix("post")

all_betas <- c(matrix_pre$beta_fd, matrix_post$beta_fd)
all_betas <- all_betas[is.finite(all_betas)]
max_abs <- max(abs(all_betas))
if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
fill_limits <- c(-max_abs, max_abs)

plot_fd_matrix <- function(matrix_df, title) {
  ggplot(matrix_df, aes(x = col_net, y = row_net, fill = beta_fd)) +
    geom_tile(color = "white", linewidth = 0.7) +
    geom_text(aes(label = cell_label), size = 5, na.rm = TRUE) +
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
      subtitle = "Diagonal = within-network | Off-diagonal = between-network | stars = BH-FDR",
      x = NULL,
      y = NULL
    ) +
    theme_minimal(base_size = 15) +
    theme(
      panel.grid = element_blank(),
      axis.text.x = element_text(angle = 45, hjust = 1, face = "bold", size = 12),
      axis.text.y = element_text(face = "bold", size = 12),
      plot.title = element_text(face = "bold", hjust = 0.5, size = 18),
      plot.subtitle = element_text(hjust = 0.5, size = 10),
      legend.position = "right"
    )
}

p_pre <- plot_fd_matrix(matrix_pre, "Pre-FD filtering")
p_post <- plot_fd_matrix(
  matrix_post,
  paste0("Post-FD filtering (mean FD < ", FD_THRESHOLD, ")")
)
p_combined <- p_pre + p_post + plot_layout(ncol = 2, guides = "collect") &
  theme(legend.position = "right")

print(p_pre)
print(p_post)
print(p_combined)

ggsave(file.path(out_dir, "fd_heatmap_pre.pdf"), p_pre, width = 9, height = 8, units = "in")
ggsave(file.path(out_dir, "fd_heatmap_post.pdf"), p_post, width = 9, height = 8, units = "in")
ggsave(
  file.path(out_dir, "fd_heatmaps_pre_vs_post.pdf"),
  p_combined,
  width = 47,
  height = 25,
  units = "cm"
)
