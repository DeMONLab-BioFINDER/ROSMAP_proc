# Plot longitudinal categorical-covariate connectivity heatmaps from already
# FDR-corrected results produced by prepare_covariate_effect_heatmaps.R.
#
# No multiple-comparison correction is performed in this script.
#
# Representation:
#   - binary covariates: one symmetric 7 x 7 network heatmap
#   - site / diagnosis: preserve the original lower-triangular grid of
#     pairwise level comparisons, where every populated panel is a symmetric
#     7 x 7 network heatmap.

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

in_file <- require_file(
  file.path(
    output_dir("covariate_heatmaps"),
    "covariate_effects_longitudinal_fdr_unique.csv"
  ),
  "FDR-corrected covariate heatmap results"
)
out_dir <- output_dir("heatmaps")
network_order <- target_cols

corrected <- readr::read_csv(in_file, show_col_types = FALSE)

required <- c(
  "row_net", "col_net", "covariate", "contrast",
  "estimate", "statistic", "p_raw", "q_fdr", "sig_fdr"
)
if (!all(required %in% names(corrected))) {
  stop("Corrected covariate table is missing required columns.")
}

# ============================================================
# Shared helpers
# ============================================================

mirror_complete <- function(df) {
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
      row_net = factor(row_net, levels = rev(network_order)),
      col_net = factor(col_net, levels = network_order)
    )
}

get_fill_limits <- function(df, value_col) {
  values <- as.numeric(df[[value_col]])
  values <- values[is.finite(values)]
  if (!length(values)) stop("No finite values available for plotting.")

  max_abs <- max(abs(values))
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  c(-max_abs, max_abs)
}

# ============================================================
# Binary covariates
# ============================================================

plot_one_binary_covariate <- function(covariate_name, value_col = "statistic") {
  cov_df <- corrected %>% filter(covariate == covariate_name)
  if (nrow(cov_df) == 0) stop("No corrected rows for covariate: ", covariate_name)

  contrasts <- unique(cov_df$contrast)
  if (length(contrasts) != 1L) {
    stop("Binary plotting helper expected exactly one contrast for ", covariate_name)
  }

  fill_limits <- get_fill_limits(cov_df, value_col)

  matrix_df <- mirror_complete(cov_df) %>%
    mutate(
      plot_value = as.numeric(.data[[value_col]]),
      cell_label = ifelse(
        is.na(plot_value),
        "",
        paste0(
          sprintf("%.2f", plot_value),
          ifelse(is.na(sig_fdr), "", sig_fdr)
        )
      )
    )

  legend_name <- if (value_col == "statistic") "t-value" else expression(beta)

  ggplot(matrix_df, aes(x = col_net, y = row_net, fill = plot_value)) +
    geom_tile(color = "grey80", linewidth = 0.3) +
    geom_text(aes(label = cell_label), size = 4, color = "black", na.rm = TRUE) +
    scale_fill_gradient2(
      low = "#2166AC",
      mid = "white",
      high = "#B2182B",
      midpoint = 0,
      limits = fill_limits,
      na.value = "grey90",
      name = legend_name
    ) +
    coord_fixed() +
    theme_minimal(base_size = 15) +
    theme(
      panel.grid = element_blank(),
      axis.title = element_blank(),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 18),
      axis.text.y = element_text(size = 18),
      legend.position = "right",
      plot.title = element_text(face = "bold", hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5)
    ) +
    labs(
      title = paste0(covariate_name, " effect heatmap"),
      subtitle = contrasts[[1]]
    )
}

# ============================================================
# Multi-level covariates: original representation
#
# This intentionally reproduces the old site / diagnosis display:
#   * level comparisons are arranged as a lower-triangular facet grid
#   * each populated facet contains a full mirrored 7 x 7 network matrix
#   * facet value is always row level - column level
#
# The only inferential change is that labels now use sig_fdr, which was
# computed beforehand over the complete 28 x number-of-contrasts family.
# ============================================================

make_covariate_heatmap_grid_lower <- function(
    effects_df,
    covariate_to_plot,
    contrast_levels,
    fill_limits = NULL,
    text_size = 6,
    value_type = c("t", "beta"),
    blank_nonsig = FALSE
) {
  value_type <- match.arg(value_type)

  plot_df <- effects_df %>%
    filter(covariate == covariate_to_plot) %>%
    tidyr::separate(
      contrast,
      into = c("contrast1", "contrast2"),
      sep = " - ",
      remove = FALSE,
      fill = "right",
      extra = "merge"
    ) %>%
    mutate(
      estimate = as.numeric(estimate),
      statistic = as.numeric(statistic),
      sig_fdr = ifelse(is.na(sig_fdr), "", sig_fdr),
      row_net = as.character(row_net),
      col_net = as.character(col_net),
      contrast1 = as.character(contrast1),
      contrast2 = as.character(contrast2),
      raw_plot_value = if (value_type == "t") statistic else estimate
    ) %>%
    filter(is.finite(raw_plot_value))

  if (nrow(plot_df) == 0) {
    stop(
      "No usable rows found for covariate = '",
      covariate_to_plot,
      "', value_type = '",
      value_type,
      "'."
    )
  }

  plot_df <- plot_df %>%
    mutate(
      contrast1 = factor(contrast1, levels = contrast_levels),
      contrast2 = factor(contrast2, levels = contrast_levels),
      contrast1_id = as.integer(contrast1),
      contrast2_id = as.integer(contrast2)
    ) %>%
    filter(!is.na(contrast1_id), !is.na(contrast2_id)) %>%
    mutate(
      flip_contrast = contrast1_id < contrast2_id,
      panel_row = ifelse(
        flip_contrast,
        as.character(contrast2),
        as.character(contrast1)
      ),
      panel_col = ifelse(
        flip_contrast,
        as.character(contrast1),
        as.character(contrast2)
      ),
      panel_row_id = pmax(contrast1_id, contrast2_id),
      panel_col_id = pmin(contrast1_id, contrast2_id),
      # The old figure displayed row-level minus column-level. If emmeans
      # supplied the reverse orientation, reverse the sign for plotting only.
      plot_value = ifelse(flip_contrast, -raw_plot_value, raw_plot_value),
      sig_plot = sig_fdr
    ) %>%
    filter(panel_row_id > panel_col_id) %>%
    mutate(
      panel_row = factor(panel_row, levels = contrast_levels),
      panel_col = factor(panel_col, levels = contrast_levels)
    )

  if (nrow(plot_df) == 0) {
    stop("No pairwise contrasts remained after applying level order for ", covariate_to_plot)
  }

  # Each corrected row is one of the 28 unique network cells. Mirror only for
  # display; the mirrored cell is never included in the FDR family a second time.
  heatmap_df <- bind_rows(
    plot_df %>%
      transmute(
        panel_row,
        panel_col,
        row_net,
        col_net,
        plot_value,
        sig = sig_plot
      ),
    plot_df %>%
      filter(row_net != col_net) %>%
      mutate(
        original_row_net = row_net,
        original_col_net = col_net
      ) %>%
      transmute(
        panel_row,
        panel_col,
        row_net = original_col_net,
        col_net = original_row_net,
        plot_value,
        sig = sig_plot
      )
  ) %>%
    group_by(panel_row, panel_col, row_net, col_net) %>%
    summarise(
      plot_value = first(plot_value),
      sig = first(sig),
      .groups = "drop"
    ) %>%
    mutate(
      cell_label = if (blank_nonsig) {
        ifelse(sig == "", "", paste0(sprintf("%.2f", plot_value), sig))
      } else {
        ifelse(
          is.na(plot_value),
          "",
          paste0(sprintf("%.2f", plot_value), sig)
        )
      },
      fill_value = if (blank_nonsig) {
        ifelse(sig == "", NA_real_, plot_value)
      } else {
        plot_value
      },
      row_net = factor(row_net, levels = rev(network_order)),
      col_net = factor(col_net, levels = network_order)
    )

  # Construct the full 7 x 7 matrix inside every lower-triangle level panel.
  panel_grid <- plot_df %>% distinct(panel_row, panel_col)

  heatmap_full <- panel_grid %>%
    tidyr::crossing(
      row_net = factor(rev(network_order), levels = rev(network_order)),
      col_net = factor(network_order, levels = network_order)
    ) %>%
    left_join(
      heatmap_df,
      by = c("panel_row", "panel_col", "row_net", "col_net")
    )

  # Same facet geometry as the original script: impossible first row and last
  # column are omitted, leaving only the lower-triangular comparison layout.
  first_level <- contrast_levels[1]
  last_level <- contrast_levels[length(contrast_levels)]

  heatmap_full <- heatmap_full %>%
    filter(panel_row != first_level, panel_col != last_level) %>%
    mutate(
      panel_row = factor(
        panel_row,
        levels = contrast_levels[contrast_levels != first_level]
      ),
      panel_col = factor(
        panel_col,
        levels = contrast_levels[contrast_levels != last_level]
      )
    )

  if (is.null(fill_limits)) {
    finite_values <- heatmap_full$plot_value[is.finite(heatmap_full$plot_value)]
    max_abs <- max(abs(finite_values))
    if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
    fill_limits <- c(-max_abs, max_abs)
  }

  legend_name <- if (value_type == "t") "t-value" else expression(beta)
  na_fill <- if (blank_nonsig) "white" else "grey90"

  ggplot(
    heatmap_full,
    aes(x = col_net, y = row_net, fill = fill_value)
  ) +
    geom_tile(color = "grey80", linewidth = 0.3) +
    geom_text(
      aes(label = cell_label),
      size = text_size,
      color = "black",
      na.rm = TRUE
    ) +
    scale_fill_gradient2(
      low = "#2166AC",
      mid = "white",
      high = "#B2182B",
      midpoint = 0,
      limits = fill_limits,
      na.value = na_fill,
      name = legend_name
    ) +
    facet_grid(
      rows = vars(panel_row),
      cols = vars(panel_col),
      drop = FALSE
    ) +
    coord_fixed() +
    theme_minimal(base_size = 15) +
    theme(
      panel.grid = element_blank(),
      axis.title = element_blank(),
      axis.text.x = element_text(angle = 45, hjust = 1, size = 18),
      axis.text.y = element_text(size = 18),
      strip.text = element_text(face = "bold", size = 16),
      legend.position = "right",
      plot.title = element_text(face = "bold", hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5)
    ) +
    labs(
      title = paste0(covariate_to_plot, " effect heatmap grid"),
      subtitle = paste0(
        "Row level - column level | ",
        ifelse(value_type == "t", "t-values", "beta estimates")
      )
    )
}

# ============================================================
# Plot binary covariates
# ============================================================

binary_covariates <- intersect(c("msex", "eyes", "syn_bin"), unique(corrected$covariate))

for (covariate_name in binary_covariates) {
  p <- plot_one_binary_covariate(covariate_name, value_col = "statistic")
  print(p)

  ggsave(
    filename = file.path(out_dir, paste0("heatmap_grid_", covariate_name, "_t.pdf")),
    plot = p,
    width = 9,
    height = 8,
    units = "in",
    limitsize = FALSE
  )
}

# ============================================================
# Site: original lower-triangular level-comparison grid
# ============================================================

if ("site" %in% corrected$covariate) {
  site_df <- corrected %>% filter(covariate == "site")
  site_t_limits <- get_fill_limits(site_df, "statistic")

  p_site_t <- make_covariate_heatmap_grid_lower(
    effects_df = corrected,
    covariate_to_plot = "site",
    contrast_levels = EC_SITE_LEVELS,
    fill_limits = site_t_limits,
    value_type = "t"
  )

  print(p_site_t)
  ggsave(
    filename = file.path(out_dir, "heatmap_grid_site_t.pdf"),
    plot = p_site_t,
    width = 15,
    height = 15,
    units = "in",
    limitsize = FALSE
  )

  # Preserve the old additional site beta view: same lower-triangular layout,
  # with nonsignificant cells blanked using the final FDR significance.
  site_beta_limits <- get_fill_limits(site_df, "estimate")

  p_site_beta <- make_covariate_heatmap_grid_lower(
    effects_df = corrected,
    covariate_to_plot = "site",
    contrast_levels = EC_SITE_LEVELS,
    fill_limits = site_beta_limits,
    value_type = "beta",
    blank_nonsig = TRUE
  )

  print(p_site_beta)
  ggsave(
    filename = file.path(out_dir, "heatmap_grid_site_estimate.pdf"),
    plot = p_site_beta,
    width = 15,
    height = 15,
    units = "in",
    limitsize = FALSE
  )

  ggsave(
    filename = file.path(out_dir, "heatmap_grid_site_estimate.svg"),
    plot = p_site_beta,
    width = 20,
    height = 20,
    dpi = 300
  )
}

# ============================================================
# Diagnosis: original lower-triangular level-comparison grid
# ============================================================

if ("dcfdx" %in% corrected$covariate) {
  # "other" was intentionally excluded from the old diagnosis heatmap and is
  # still excluded here. The model/FDR design is expected to contain the three
  # displayed levels and their three pairwise contrasts.
  dx_levels <- EC_DX_LEVELS[EC_DX_LEVELS != "other"]
  dx_df <- corrected %>% filter(covariate == "dcfdx")
  dx_t_limits <- get_fill_limits(dx_df, "statistic")

  p_dx_t <- make_covariate_heatmap_grid_lower(
    effects_df = corrected,
    covariate_to_plot = "dcfdx",
    contrast_levels = dx_levels,
    fill_limits = dx_t_limits,
    value_type = "t"
  )

  print(p_dx_t)
  ggsave(
    filename = file.path(out_dir, "heatmap_grid_diagnosis_t.pdf"),
    plot = p_dx_t,
    width = 15,
    height = 15,
    units = "in",
    limitsize = FALSE
  )
}
