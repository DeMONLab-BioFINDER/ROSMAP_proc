# Longitudinal FD-effects analysis for between-network connectivity.
# Fits the same adjusted model before and after the FD threshold and exports
# raw mean-FD coefficients/p-values only. No FDR correction and no plotting are
# performed here. Pre- and post-FD results are corrected later as separate
# 28-test connectivity families.

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
if (is.na(.paths_file)) stop("Could not locate analysis/paths.R")
source(.paths_file)
source(file.path(ANALYSIS_DIR, "effect_covs", "covs_utils.R"))
rm(.script_arg, .script_dir, .paths_candidates, .paths_file)

# ============================================================
# 1. Load and prepare data
# ============================================================

demos_conn <- read.csv(require_file(demos("demos_conn.csv")))

demos_conn <- demos_conn %>%
  ec_add_session_number() %>%
  ec_prepare_model_variables(longitudinal = TRUE)

print(colSums(is.na(demos_conn)))

fd_threshold <- FD_THRESHOLD
out_dir <- output_dir("fd_between_longitudinal")

fd_formula <- between_conn ~ mean_FD + msex + site + age_scandate +
  eyes + dcfdx + syn_bin + (1 | sub_id)

# ============================================================
# 2. Long-format data
# ============================================================

data_long_pre <- ec_make_long(
  data = demos_conn,
  measure_cols = target_combos,
  measure_name = "network_combo",
  value_name = "between_conn",
  required_vars = c(
    "sub_id", "ses_num", "mean_FD", "msex", "site", "age_scandate",
    "eyes", "dcfdx", "syn_bin"
  )
)

data_long_post <- data_long_pre %>%
  ec_apply_fd_filter(threshold = fd_threshold)

# ============================================================
# 3. Fit raw FD models
# ============================================================

fit_fd_family <- function(data_long) {
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

fit_pre <- fit_fd_family(data_long_pre)
fit_post <- fit_fd_family(data_long_post)
results_pre <- fit_pre$results
results_post <- fit_post$results

ec_print_fd_model_table(results_pre, "All observations: raw FD model results")
ec_print_fd_model_table(
  results_post,
  paste0("FD-filtered observations: raw FD model results (mean_FD < ", fd_threshold, ")")
)

# ============================================================
# 4. Save raw results and fitted model objects
# ============================================================

write_csv(results_pre, file.path(out_dir, "fd_effects_betweenconn_all_modelresults.csv"))
write_csv(results_post, file.path(out_dir, "fd_effects_betweenconn_fd_filtered_modelresults.csv"))

# Model/data RDS files contain no corrected statistics. They are retained only
# so post-correction plotting can reuse the exact fitted models without refitting.
saveRDS(fit_pre$models, file.path(out_dir, "fd_models_betweenconn_all.rds"))
saveRDS(fit_post$models, file.path(out_dir, "fd_models_betweenconn_fd_filtered.rds"))
saveRDS(data_long_pre, file.path(out_dir, "fd_data_betweenconn_all.rds"))
saveRDS(data_long_post, file.path(out_dir, "fd_data_betweenconn_fd_filtered.rds"))
