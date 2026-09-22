# Baseline FD-effects analysis for within-network connectivity.
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
  ec_select_baseline() %>%
  ec_prepare_model_variables()

print(colSums(is.na(demos_conn)))

fd_threshold <- FD_THRESHOLD
out_dir <- output_dir("motion")

fd_formula <- within_conn ~ mean_FD + msex + site + age_scandate +
  eyes + dcfdx + syn_bin

# ============================================================
# 2. Long-format data
# ============================================================

data_long_pre <- ec_make_long(
  data = demos_conn,
  measure_cols = target_cols,
  measure_name = "network",
  value_name = "within_conn",
  required_vars = c(
    "mean_FD", "msex", "site", "age_scandate",
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
    measure_levels = target_cols,
    measure_col = "network",
    model_formula = fd_formula,
    mixed = FALSE,
    optimizer = "bobyqa"
  )

  ec_fd_results_from_models(
    models = models,
    measure_col = "network",
    measure_levels = target_cols
  )
}

results_pre <- fit_fd_family(data_long_pre)
results_post <- fit_fd_family(data_long_post)

ec_print_fd_model_table(results_pre, "Pre-FD-filtering: raw FD model results")
ec_print_fd_model_table(
  results_post,
  paste0("Post-FD-filtering: raw FD model results (mean_FD < ", fd_threshold, ")")
)

# ============================================================
# 4. Save raw results only
# ============================================================

write_csv(results_pre, file.path(out_dir, "fd_effects_withinconn_bl_preFDfilter_modelresults.csv"))
write_csv(results_post, file.path(out_dir, "fd_effects_withinconn_bl_postFDfilter_modelresults.csv"))
