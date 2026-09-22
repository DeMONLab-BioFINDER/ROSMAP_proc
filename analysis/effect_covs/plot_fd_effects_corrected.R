# Plot longitudinal FD effects after the final 28-test BH-FDR correction.
#
# The effect_fd_* model scripts save raw result CSVs plus the fitted model/data
# objects. heatmap_fd.R then combines within + between results and computes the
# final FDR values. This script reuses the saved models and corrected values to
# make fitted-value and partial-residual figures without refitting models and
# without performing any additional correction.

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

corrected_file <- require_file(
  file.path(
    output_dir("fd_heatmaps"),
    "fd_effects_longitudinal_fdr_unique.csv"
  ),
  "FDR-corrected longitudinal FD results"
)
corrected <- readr::read_csv(corrected_file, show_col_types = FALSE)

required_corrected <- c(
  "filter_status", "connection_type", "measure",
  "beta_fd", "t_val_fd", "p_fd", "q_fdr", "sig_fdr"
)
if (!all(required_corrected %in% names(corrected))) {
  stop("Corrected FD result table is missing required columns.")
}

read_rds_required <- function(path, label) {
  readRDS(require_file(path, label))
}

within_dir <- output_dir("fd_within_longitudinal")
between_dir <- output_dir("fd_between_longitudinal")

fd_objects <- list(
  within_pre = list(
    models = read_rds_required(
      file.path(within_dir, "fd_models_withinconn_all.rds"),
      "within-network pre-FD models"
    ),
    data = read_rds_required(
      file.path(within_dir, "fd_data_withinconn_all.rds"),
      "within-network pre-FD data"
    )
  ),
  within_post = list(
    models = read_rds_required(
      file.path(within_dir, "fd_models_withinconn_fd_filtered.rds"),
      "within-network post-FD models"
    ),
    data = read_rds_required(
      file.path(within_dir, "fd_data_withinconn_fd_filtered.rds"),
      "within-network post-FD data"
    )
  ),
  between_pre = list(
    models = read_rds_required(
      file.path(between_dir, "fd_models_betweenconn_all.rds"),
      "between-network pre-FD models"
    ),
    data = read_rds_required(
      file.path(between_dir, "fd_data_betweenconn_all.rds"),
      "between-network pre-FD data"
    )
  ),
  between_post = list(
    models = read_rds_required(
      file.path(between_dir, "fd_models_betweenconn_fd_filtered.rds"),
      "between-network post-FD models"
    ),
    data = read_rds_required(
      file.path(between_dir, "fd_data_betweenconn_fd_filtered.rds"),
      "between-network post-FD data"
    )
  )
)

corrected_for_plot <- function(connection_type_value, status, measure_col) {
  out <- corrected %>%
    filter(
      .data$connection_type == connection_type_value,
      .data$filter_status == status
    ) %>%
    transmute(
      measure = as.character(.data$measure),
      beta_fd = as.numeric(.data$beta_fd),
      t_val_fd = as.numeric(.data$t_val_fd),
      p_fd = as.numeric(.data$p_fd),
      q_fdr = as.numeric(.data$q_fdr),
      sig_fdr = ifelse(is.na(.data$sig_fdr), "", .data$sig_fdr),
      label = sprintf(
        "beta = %.3f %s\nq = %.3g",
        beta_fd,
        sig_fdr,
        q_fdr
      )
    )

  names(out)[names(out) == "measure"] <- measure_col
  out
}

get_partial_residual_data <- function(models, predictor, measure_col, measure_levels) {
  visreg_objects <- purrr::imap(
    models,
    function(model, measure) {
      visreg::visreg(
        model,
        predictor,
        plot = FALSE,
        predict = list(re.form = NA)
      )
    }
  )

  points <- purrr::imap_dfr(
    visreg_objects,
    function(v, measure) {
      residual_col <- intersect(c("visreg_res", "visregRes"), names(v$res))[1]
      if (is.na(residual_col)) {
        stop("Could not identify visreg residual column for ", measure)
      }
      tibble::tibble(
        x = v$res[[predictor]],
        partial_residual = v$res[[residual_col]],
        measure = measure
      )
    }
  )

  lines <- purrr::imap_dfr(
    visreg_objects,
    function(v, measure) {
      fit_col <- intersect(c("visreg_fit", "visregFit"), names(v$fit))[1]
      if (is.na(fit_col)) {
        stop("Could not identify visreg fitted column for ", measure)
      }
      tibble::tibble(
        x = v$fit[[predictor]],
        fitted = v$fit[[fit_col]],
        measure = measure
      )
    }
  )

  names(points)[names(points) == "measure"] <- measure_col
  names(lines)[names(lines) == "measure"] <- measure_col
  points[[measure_col]] <- factor(points[[measure_col]], levels = measure_levels)
  lines[[measure_col]] <- factor(lines[[measure_col]], levels = measure_levels)

  list(points = points, lines = lines)
}

plot_partial_residuals <- function(
    models,
    model_results,
    measure_col,
    measure_levels,
    palette,
    title,
    y_label,
    ncol
) {
  vr <- get_partial_residual_data(
    models = models,
    predictor = "mean_FD",
    measure_col = measure_col,
    measure_levels = measure_levels
  )

  labels <- model_results %>% mutate(x = Inf, y = Inf)
  facet_formula <- stats::as.formula(paste("~", measure_col))

  ggplot(vr$points, aes(x = x, y = partial_residual, color = .data[[measure_col]])) +
    geom_point(alpha = 0.3, size = 1) +
    geom_line(
      data = vr$lines,
      aes(x = x, y = fitted, color = .data[[measure_col]]),
      inherit.aes = FALSE,
      linewidth = 1
    ) +
    geom_label(
      data = labels,
      aes(x = x, y = y, label = label),
      inherit.aes = FALSE,
      hjust = 1.05,
      vjust = 1.1,
      size = if (length(measure_levels) > 10L) 2.2 else 3.2,
      color = "black",
      fill = "white",
      alpha = 0.8,
      linewidth = 0
    ) +
    facet_wrap(facet_formula, ncol = ncol, scales = "fixed") +
    scale_color_manual(values = palette) +
    theme_minimal(base_size = 13) +
    theme(
      legend.position = "none",
      strip.text = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    ) +
    labs(
      title = title,
      subtitle = "Significance labels use final 28-test BH-FDR correction",
      x = "Mean framewise displacement",
      y = y_label
    )
}

save_plot_pair <- function(plot, out_dir, stem, width, height) {
  ggsave(
    file.path(out_dir, paste0(stem, ".pdf")),
    plot = plot,
    width = width,
    height = height,
    units = "in",
    limitsize = FALSE
  )
  ggsave(
    file.path(out_dir, paste0(stem, ".png")),
    plot = plot,
    width = width,
    height = height,
    units = "in",
    dpi = 300,
    limitsize = FALSE
  )
}

plot_one_family <- function(
    object,
    connection_type_value,
    status,
    measure_col,
    measure_levels,
    value_col,
    palette,
    out_dir,
    stem,
    title,
    y_label,
    ncol,
    width,
    height
) {
  model_results <- corrected_for_plot(
    connection_type_value = connection_type_value,
    status = status,
    measure_col = measure_col
  )

  if (nrow(model_results) != length(measure_levels)) {
    stop(
      "Corrected result count for ", connection_type_value, "/", status,
      " is ", nrow(model_results), "; expected ", length(measure_levels), "."
    )
  }

  predictions <- ec_fd_predictions_from_models(
    models = object$models,
    measure_col = measure_col,
    measure_levels = measure_levels,
    fixed_only = TRUE
  )

  fitted_plot <- ec_plot_fd_effects(
    data_long = object$data,
    predictions = predictions,
    model_results = model_results,
    title = title,
    measure_col = measure_col,
    value_col = value_col,
    palette = palette,
    y_label = y_label,
    label_box = TRUE,
    label_size = if (length(measure_levels) > 10L) 2.0 else 3.0,
    strip_size = if (length(measure_levels) > 10L) 8 else 11,
    rotate_x = FALSE
  ) +
    labs(subtitle = "Significance labels use final 28-test BH-FDR correction")

  partial_plot <- plot_partial_residuals(
    models = object$models,
    model_results = model_results,
    measure_col = measure_col,
    measure_levels = measure_levels,
    palette = palette,
    title = paste0(title, ": partial residuals"),
    y_label = paste0(y_label, " (partial residual)"),
    ncol = ncol
  )

  print(fitted_plot)
  print(partial_plot)

  save_plot_pair(fitted_plot, out_dir, paste0(stem, "_fitted_corrected"), width, height)
  save_plot_pair(partial_plot, out_dir, paste0(stem, "_partial_residuals_corrected"), width, height)
}

plot_one_family(
  object = fd_objects$within_pre,
  connection_type_value = "within",
  status = "pre",
  measure_col = "network",
  measure_levels = target_cols,
  value_col = "within_conn",
  palette = network_colors,
  out_dir = within_dir,
  stem = "fd_effects_withinconn_all",
  title = "All observations: adjusted FD effect by network",
  y_label = "Within-network connectivity",
  ncol = 3,
  width = 13,
  height = 8
)

plot_one_family(
  object = fd_objects$within_post,
  connection_type_value = "within",
  status = "post",
  measure_col = "network",
  measure_levels = target_cols,
  value_col = "within_conn",
  palette = network_colors,
  out_dir = within_dir,
  stem = "fd_effects_withinconn_fd_filtered",
  title = paste0("FD filtered (mean FD < ", FD_THRESHOLD, "): adjusted FD effect by network"),
  y_label = "Within-network connectivity",
  ncol = 3,
  width = 13,
  height = 8
)

plot_one_family(
  object = fd_objects$between_pre,
  connection_type_value = "between",
  status = "pre",
  measure_col = "network_combo",
  measure_levels = target_combos,
  value_col = "between_conn",
  palette = between_network_colors[target_combos],
  out_dir = between_dir,
  stem = "fd_effects_betweenconn_all",
  title = "All observations: adjusted FD effect by network pair",
  y_label = "Between-network connectivity",
  ncol = 4,
  width = 18,
  height = 14
)

plot_one_family(
  object = fd_objects$between_post,
  connection_type_value = "between",
  status = "post",
  measure_col = "network_combo",
  measure_levels = target_combos,
  value_col = "between_conn",
  palette = between_network_colors[target_combos],
  out_dir = between_dir,
  stem = "fd_effects_betweenconn_fd_filtered",
  title = paste0("FD filtered (mean FD < ", FD_THRESHOLD, "): adjusted FD effect by network pair"),
  y_label = "Between-network connectivity",
  ncol = 4,
  width = 18,
  height = 14
)
