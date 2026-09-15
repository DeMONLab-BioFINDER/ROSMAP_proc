# Longitudinal motion-sensitivity analysis for between-network connectivity.
# Fits mixed-effects models before and after FD exclusion and generates the
# model tables and diagnostic figures used to assess motion bias.

# Shared input/output path configuration. See analysis/README.md.
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

if (is.na(.paths_file)) {
  stop("Could not locate analysis/paths.R")
}

source(.paths_file)

source(file.path(ANALYSIS_DIR, "effect_covs", "covs_utils.R"))

rm(
  .script_arg,
  .script_dir,
  .paths_candidates,
  .paths_file
)

library(patchwork)


# ============================================================
# 1. Load and prepare data
# ============================================================

demos_betweenconn <- read.csv(
  require_file(demos("demos_conn.csv"))
)

demos_betweenconn <- demos_betweenconn %>%
  ec_add_session_number() %>%
  ec_prepare_model_variables(
    longitudinal = TRUE
  )

# FD exclusion threshold
fd_threshold <- FD_THRESHOLD

# Keep plotting colours aligned with canonical network-pair order
between_network_colors <- between_network_colors[
  target_combos
]


# ============================================================
# 2. Convert network-pair data to long format
# ============================================================

make_long <- function(data) {

  ec_make_long(
    data = data,
    measure_cols = target_combos,
    measure_name = "network_combo",
    value_name = "between_conn",
    required_vars = c(
      "sub_id",
      "ses_num",
      "mean_FD",
      "msex",
      "site",
      "age_scandate",
      "eyes",
      "syn_bin",
      "dcfdx"
    )
  )
}


# ============================================================
# 3. Create ALL and FD-FILTERED datasets
# ============================================================

data_long_all <- make_long(
  demos_betweenconn
)

# Keep observations with mean FD < threshold
data_long_fd_filtered <- data_long_all %>%
  ec_apply_fd_filter(
    threshold = fd_threshold
  )


# ============================================================
# 4. Print sample-size information
# ============================================================

cat(
  "\n============================================================\n",
  "SAMPLE SIZE BEFORE AND AFTER FD FILTERING\n",
  "============================================================\n",
  sep = ""
)

# Because data are in long format, count unique subject-session
# combinations rather than network-pair rows.

sample_summary <- bind_rows(

  data_long_all %>%
    distinct(
      sub_id,
      ses_num
    ) %>%
    summarise(
      dataset = "All observations",
      n_subjects = n_distinct(sub_id),
      n_scans = n()
    ),

  data_long_fd_filtered %>%
    distinct(
      sub_id,
      ses_num
    ) %>%
    summarise(
      dataset = paste0(
        "FD < ",
        fd_threshold
      ),
      n_subjects = n_distinct(sub_id),
      n_scans = n()
    )
)

print(sample_summary)


# Number of unique scans excluded
n_scans_all <- data_long_all %>%
  distinct(
    sub_id,
    ses_num
  ) %>%
  nrow()

n_scans_filtered <- data_long_fd_filtered %>%
  distinct(
    sub_id,
    ses_num
  ) %>%
  nrow()

cat(
  "\nScans excluded by FD threshold:",
  n_scans_all - n_scans_filtered,
  "\n"
)


# ============================================================
# 5. Global plotting / output settings
# ============================================================

out_dir <- output_dir(
  "fd_between_longitudinal"
)

# Same model is fitted in both datasets.
#
# ALL:
#   Uses the full available FD range.
#
# FD FILTERED:
#   Uses only observations with mean_FD < 0.25.
#
# mean_FD remains the predictor in both models.

fd_formula <- between_conn ~
  mean_FD +
  msex +
  site +
  age_scandate +
  eyes +
  syn_bin +
  dcfdx +
  (1 | sub_id)


# Common y-axis for direct comparison between ALL and FD-filtered
#
# Use the range of the full dataset rather than hard-coding the
# within-network limits, because between-network connectivity
# may have a different scale.

between_range <- range(
  data_long_all$between_conn,
  na.rm = TRUE
)

between_padding <- diff(between_range) * 0.05

fixed_y_limits <- c(
  between_range[1] - between_padding,
  between_range[2] + between_padding
)

fixed_y_breaks <- pretty(
  fixed_y_limits,
  n = 5
)


# ============================================================
# 6. Fit network-pair models + extract statistics
# ============================================================

fit_fd_models <- function(data_long) {

  models <- ec_fit_models_by_measure(
    data_long = data_long,
    measure_levels = target_combos,
    measure_col = "network_combo",
    model_formula = fd_formula,
    mixed = TRUE,
    optimizer = "bobyqa"
  )

  list(
    models = models,

    results = ec_fd_results_from_models(
      models = models,
      measure_col = "network_combo",
      measure_levels = target_combos
    )
  )
}


# ============================================================
# 7. Fixed-effect predictions
# ============================================================

get_adjusted_predictions <- function(models) {

  ec_fd_predictions_from_models(
    models = models,
    measure_col = "network_combo",
    measure_levels = target_combos,
    fixed_only = TRUE
  )
}


# ============================================================
# 8. Common figure theme
# ============================================================

network_plot_theme <- function() {

  theme_minimal(
    base_size = 15
  ) +

    theme(

      legend.position = "none",

      strip.text = element_text(
        size = 14,
        face = "bold"
      ),

      plot.title = element_text(
        size = 20,
        face = "bold",
        margin = margin(
          b = 10
        )
      ),

      axis.title.x = element_text(
        size = 18,
        face = "bold",
        margin = margin(
          t = 8
        )
      ),

      axis.title.y = element_text(
        size = 18,
        face = "bold",
        margin = margin(
          r = 8
        )
      ),

      axis.text.x = element_text(
        size = 12,
        angle = 45,
        hjust = 1
      ),

      axis.text.y = element_text(
        size = 12
      ),

      panel.grid.minor = element_blank()
    )
}


# ============================================================
# 9. Fitted-value plot
# ============================================================

plot_fd_effects <- function(
    data_long,
    predictions,
    model_results,
    title,
    y_limits = fixed_y_limits,
    y_breaks = fixed_y_breaks
) {

  labels <- model_results %>%
    mutate(
      x = Inf,
      y = Inf
    )

  ggplot(
    data_long,
    aes(
      x = mean_FD,
      y = between_conn,
      color = network_combo
    )
  ) +

    # Raw observations
    geom_point(
      alpha = 0.3,
      size = 1
    ) +

    # Confidence interval
    geom_ribbon(
      data = predictions,
      aes(
        x = x,
        ymin = conf.low,
        ymax = conf.high,
        fill = network_combo
      ),
      inherit.aes = FALSE,
      alpha = 0.25
    ) +

    # Adjusted fixed-effect line
    geom_line(
      data = predictions,
      aes(
        x = x,
        y = predicted,
        color = network_combo
      ),
      inherit.aes = FALSE,
      linewidth = 1.2
    ) +

    # Model statistics
    geom_label(
      data = labels,
      aes(
        x = x,
        y = y,
        label = label
      ),
      inherit.aes = FALSE,
      hjust = 1.05,
      vjust = 1.1,
      size = 3.5,
      color = "black",
      fill = "white",
      alpha = 0.8,
      linewidth = 0
    ) +

    facet_wrap(
      ~ network_combo,
      ncol = 3,
      scales = "fixed",
      axes = "all",
      axis.labels = "all"
    ) +

    scale_color_manual(
      values = between_network_colors
    ) +

    scale_fill_manual(
      values = between_network_colors
    ) +

    scale_y_continuous(
      breaks = y_breaks
    ) +

    coord_cartesian(
      ylim = y_limits
    ) +

    network_plot_theme() +

    labs(
      title = title,
      x = "Mean FD",
      y = "Between-network connectivity"
    )
}


# ============================================================
# 10. Get visreg partial residual data
# ============================================================

get_partial_residual_data <- function(
    models,
    predictor = "mean_FD"
) {

  # Run visreg only once per model
  visreg_objects <- imap(
    models,
    function(model, combo) {

      visreg(
        model,
        predictor,
        plot = FALSE,
        predict = list(
          re.form = NA
        )
      )
    }
  )


  # ----------------------------------------------------------
  # Partial residual points
  # ----------------------------------------------------------

  points <- imap_dfr(
    visreg_objects,
    function(v, combo) {

      residual_col <- intersect(
        c(
          "visreg_res",
          "visregRes"
        ),
        names(v$res)
      )

      if (length(residual_col) == 0) {

        stop(
          paste(
            "Could not identify visreg residual column for",
            combo
          )
        )
      }

      tibble(
        x = v$res[[predictor]],

        partial_residual =
          v$res[[residual_col[1]]],

        network_combo = combo
      )
    }
  )


  # ----------------------------------------------------------
  # Fitted fixed-effect lines
  # ----------------------------------------------------------

  lines <- imap_dfr(
    visreg_objects,
    function(v, combo) {

      fit_col <- intersect(
        c(
          "visreg_fit",
          "visregFit"
        ),
        names(v$fit)
      )

      if (length(fit_col) == 0) {

        stop(
          paste(
            "Could not identify visreg fitted column for",
            combo
          )
        )
      }

      tibble(
        x = v$fit[[predictor]],
        fitted = v$fit[[fit_col[1]]],
        network_combo = combo
      )
    }
  )


  list(

    points = points %>%
      mutate(
        network_combo = factor(
          network_combo,
          levels = target_combos
        )
      ),

    lines = lines %>%
      mutate(
        network_combo = factor(
          network_combo,
          levels = target_combos
        )
      )
  )
}


# ============================================================
# 11. Partial residual plot
# ============================================================

plot_fd_partial_residuals <- function(
    models,
    model_results,
    predictor = "mean_FD",
    title,
    y_limits = fixed_y_limits,
    y_breaks = fixed_y_breaks
) {

  vr <- get_partial_residual_data(
    models,
    predictor
  )

  labels <- model_results %>%
    mutate(
      x = Inf,
      y = Inf
    )

  ggplot(
    vr$points,
    aes(
      x = x,
      y = partial_residual,
      color = network_combo
    )
  ) +

    # Partial residual observations
    geom_point(
      alpha = 0.3,
      size = 1
    ) +

    # Adjusted fitted line
    geom_line(
      data = vr$lines,
      aes(
        x = x,
        y = fitted,
        color = network_combo
      ),
      inherit.aes = FALSE,
      linewidth = 1.2
    ) +

    # Model statistics
    geom_label(
      data = labels,
      aes(
        x = x,
        y = y,
        label = label
      ),
      inherit.aes = FALSE,
      hjust = 1.05,
      vjust = 1.1,
      size = 3.5,
      color = "black",
      fill = "white",
      alpha = 0.8,
      linewidth = 0
    ) +

    facet_wrap(
      ~ network_combo,
      ncol = 3,
      scales = "fixed",
      axes = "all",
      axis.labels = "all"
    ) +

    scale_color_manual(
      values = between_network_colors
    ) +

    scale_y_continuous(
      breaks = y_breaks
    ) +

    coord_cartesian(
      ylim = y_limits
    ) +

    network_plot_theme() +

    labs(
      title = title,
      x = "Mean framewise displacement",
      y = "Between-network connectivity (partial residual)"
    )
}


# ============================================================
# 12. Save figure as PDF + editable SVG
# ============================================================

save_figure <- function(
    plot,
    filename,
    width = 13,
    height = 10
) {

  ec_save_pdf_svg(
    plot = plot,
    out_dir = out_dir,
    filename = filename,
    width = width,
    height = height,
    cairo = TRUE
  )
}


# ============================================================
# 13. Print model table
# ============================================================

print_model_table <- function(
    model_results,
    title
) {

  ec_print_fd_model_table(
    model_results,
    title
  )
}


# ============================================================
# 14. Run one complete FD analysis
# ============================================================

run_fd_analysis <- function(
    data_long,
    analysis_label,
    file_suffix
) {

  cat(
    "\n\n############################################################\n",
    analysis_label,
    "\n############################################################\n",
    sep = ""
  )


  # ----------------------------------------------------------
  # Models
  # ----------------------------------------------------------

  fit <- fit_fd_models(
    data_long
  )

  models <- fit$models

  results <- fit$results


  # ----------------------------------------------------------
  # Predictions
  # ----------------------------------------------------------

  predictions <- get_adjusted_predictions(
    models
  )


  # ----------------------------------------------------------
  # Print model results
  # ----------------------------------------------------------

  print_model_table(
    results,
    paste0(
      analysis_label,
      " adjusted FD model results"
    )
  )


  # ----------------------------------------------------------
  # Save model results CSV
  # ----------------------------------------------------------

  write_csv(
    results,
    file.path(
      out_dir,
      paste0(
        "fd_effects_betweenconn_",
        file_suffix,
        "_modelresults.csv"
      )
    )
  )


  # ----------------------------------------------------------
  # Fitted-value plot
  # ----------------------------------------------------------

  p_fitted <- plot_fd_effects(
    data_long = data_long,
    predictions = predictions,
    model_results = results,
    title = paste0(
      analysis_label,
      ": adjusted FD effect by network pair"
    )
  )


  # ----------------------------------------------------------
  # Partial-residual plot
  # ----------------------------------------------------------

  p_partial <- plot_fd_partial_residuals(
    models = models,
    model_results = results,
    predictor = "mean_FD",
    title = paste0(
      analysis_label,
      ": partial residual FD effect by network pair"
    )
  )


  # ----------------------------------------------------------
  # Print plots
  # ----------------------------------------------------------

  print(
    p_fitted
  )

  print(
    p_partial
  )


  # ----------------------------------------------------------
  # Save PDF + SVG
  # ----------------------------------------------------------

  save_figure(
    p_fitted,
    paste0(
      "fd_effects_betweenconn_",
      file_suffix,
      "_fitted"
    )
  )

  save_figure(
    p_partial,
    paste0(
      "fd_effects_betweenconn_",
      file_suffix,
      "_partial_residuals"
    )
  )


  # ----------------------------------------------------------
  # Return everything
  # ----------------------------------------------------------

  list(
    models = models,
    results = results,
    predictions = predictions,
    fitted_plot = p_fitted,
    partial_plot = p_partial
  )
}


# ============================================================
# 15. RUN MODEL 1:
#     ALL OBSERVATIONS — NO FD THRESHOLD EXCLUSION
# ============================================================

results_all <- run_fd_analysis(

  data_long = data_long_all,

  analysis_label =
    "All observations",

  file_suffix =
    "all"
)


# ============================================================
# 16. RUN MODEL 2:
#     FD-FILTERED OBSERVATIONS
#     Keep mean FD < 0.25
# ============================================================

results_fd_filtered <- run_fd_analysis(

  data_long = data_long_fd_filtered,

  analysis_label = paste0(
    "FD filtered (mean FD < ",
    fd_threshold,
    ")"
  ),

  file_suffix =
    "fd_filtered"
)


# ============================================================
# 17. Direct comparison of model coefficients
# ============================================================

comparison_results <- results_all$results %>%

  select(
    network_combo,
    beta_all = beta_fd,
    t_all = t_val_fd,
    p_all = p_fd,
    q_all = q_fd
  ) %>%

  left_join(

    results_fd_filtered$results %>%

      select(
        network_combo,
        beta_fd_filtered = beta_fd,
        t_fd_filtered = t_val_fd,
        p_fd_filtered = p_fd,
        q_fd_filtered = q_fd
      ),

    by = "network_combo"
  )


cat(
  "\n============================================================\n",
  "COMPARISON: ALL vs FD-FILTERED MODELS\n",
  "============================================================\n",
  sep = ""
)

print(
  comparison_results,
  n = Inf
)


# Save comparison table
write_csv(
  comparison_results,
  file.path(
    out_dir,
    "fd_effects_betweenconn_all_vs_fd_filtered.csv"
  )
)


# ============================================================
# 18. SELECTED NETWORK-PAIR COMPARISON FIGURE
#
# Choose the network pairs you want to highlight in the main
# figure here.
#
# By default, use the first three pairs in canonical order.
# Replace these with named pairs if particular combinations
# are scientifically relevant.
# ============================================================

selected_network_combos <- target_combos[
  seq_len(
    min(
      3,
      length(target_combos)
    )
  )
]

# Remaining pairs can be used in a supplementary figure
selected_network_combos_suppl <- setdiff(
  target_combos,
  selected_network_combos
)


# ------------------------------------------------------------
# Extract partial residual data for selected network pairs
# ------------------------------------------------------------

get_selected_residuals <- function(
    models,
    selected_network_combos,
    model_results,
    condition_label
) {

  vr <- get_partial_residual_data(
    models[selected_network_combos],
    predictor = "mean_FD"
  )

  points <- vr$points %>%
    filter(
      network_combo %in% selected_network_combos
    ) %>%
    mutate(
      network_combo = factor(
        network_combo,
        levels = selected_network_combos
      ),
      condition = condition_label
    )

  lines <- vr$lines %>%
    filter(
      network_combo %in% selected_network_combos
    ) %>%
    mutate(
      network_combo = factor(
        network_combo,
        levels = selected_network_combos
      ),
      condition = condition_label
    )

  labels <- model_results %>%
    filter(
      network_combo %in% selected_network_combos
    ) %>%
    mutate(
      network_combo = factor(
        network_combo,
        levels = selected_network_combos
      ),
      condition = condition_label,
      x = Inf,
      y = Inf,
      plot_label = sprintf(
        "beta = %.3f %s\nq = %.3g",
        beta_fd,
        sig_fd,
        q_fd
      )
    )

  list(
    points = points,
    lines = lines,
    labels = labels
  )
}


# ------------------------------------------------------------
# ALL observations
# ------------------------------------------------------------

pres_all <- get_selected_residuals(
  models = results_all$models,
  selected_network_combos = selected_network_combos,
  model_results = results_all$results,
  condition_label = "Before FD exclusion"
)


# ------------------------------------------------------------
# AFTER FD filtering
# ------------------------------------------------------------

pres_filtered <- get_selected_residuals(
  models = results_fd_filtered$models,
  selected_network_combos = selected_network_combos,
  model_results = results_fd_filtered$results,
  condition_label = "After FD exclusion"
)


# ============================================================
# 19. Selected network-pair residual figure
# ============================================================

make_selected_residual_panel <- function(
    residuals,
    selected_combos,
    title = NULL,
    ncol = 3
) {

  ggplot(
    residuals$points,
    aes(
      x = x,
      y = partial_residual,
      color = network_combo
    )
  ) +

    geom_point(
      alpha = 0.35,
      size = 1.5
    ) +

    geom_line(
      data = residuals$lines,
      aes(
        x = x,
        y = fitted,
        color = network_combo
      ),
      inherit.aes = FALSE,
      linewidth = 1.2
    ) +

    geom_label(
      data = residuals$labels,
      aes(
        x = x,
        y = y,
        label = plot_label
      ),
      inherit.aes = FALSE,
      hjust = 1.05,
      vjust = 0.9,
      size = 4,
      color = "black",
      fill = "white",
      alpha = 0.75,
      linewidth = 0
    ) +

    facet_wrap(
      ~ network_combo,
      ncol = ncol,
      scales = "fixed"
    ) +

    scale_color_manual(
      values = between_network_colors
    ) +

    labs(
      title = title,
      x = "Mean framewise displacement",
      y = "Between-network connectivity\n(partial residual)"
    ) +

    theme_minimal(
      base_size = 10
    ) +

    theme(
      legend.position = "none",
      plot.title = element_text(
        size = 11,
        face = "bold"
      ),
      strip.text = element_text(
        size = 11,
        face = "bold"
      ),
      axis.title = element_text(
        size = 11,
        face = "bold"
      ),
      axis.text = element_text(
        size = 9
      ),
      panel.grid.minor = element_blank(),
      panel.spacing.x = grid::unit(
        0.35,
        "cm"
      ),
      text = element_text(
        family = "Helvetica"
      )
    )
}


p_before <- make_selected_residual_panel(
  residuals = pres_all,
  selected_combos = selected_network_combos
)

p_after <- make_selected_residual_panel(
  residuals = pres_filtered,
  selected_combos = selected_network_combos,
  title = paste0(
    "FD < ",
    fd_threshold
  )
)


# ============================================================
# Stack BEFORE and AFTER
# ============================================================

p_residuals_selected <-
  p_before /
  p_after


print(
  p_residuals_selected
)


# ============================================================
# Save selected-network-pair comparison
# ============================================================

ggsave(
  file.path(
    out_dir,
    "fd_partial_residuals_selected_network_pairs_before_after.pdf"
  ),
  p_residuals_selected,
  device = cairo_pdf,
  width = 50,
  height = 27,
  units = "cm"
)

ggsave(
  file.path(
    out_dir,
    "fd_partial_residuals_selected_network_pairs_before_after.png"
  ),
  p_residuals_selected,
  width = 18,
  height = 9,
  units = "cm",
  dpi = 300
)