# Longitudinal covariate-effects analysis for within-network connectivity.
# Fits participant-level mixed models once on the unfiltered analysis sample and exports
# unadjusted emmeans pairwise contrasts only. No post-hoc correction and no
# plotting are performed in this model script.

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
  ec_prepare_model_variables(longitudinal = TRUE) %>%
  filter(dcfdx != "other") %>%
  droplevels()

print(colSums(is.na(demos_conn)))

model_formula <- within_conn ~ mean_FD + msex + site + age_scandate +
  eyes + dcfdx + syn_bin + (1 | sub_id)

# ============================================================
# 2. Long-format data and models
# ============================================================

data_long <- ec_make_long(
  data = demos_conn,
  measure_cols = target_cols,
  measure_name = "network",
  value_name = "within_conn",
  required_vars = c(
    "sub_id", "mean_FD", "msex", "site", "age_scandate",
    "eyes", "dcfdx", "syn_bin"
  )
)

models <- ec_fit_models_by_measure(
  data_long = data_long,
  measure_levels = target_cols,
  measure_col = "network",
  model_formula = model_formula,
  mixed = TRUE
)

# ============================================================
# 3. Raw pairwise contrasts
# ============================================================

all_pairwise_results <- purrr::map_dfr(
  covariates_to_run,
  function(covariate) {
    ec_pairwise_from_models(
      models = models,
      covariate = covariate,
      measure_col = "network",
      measure_levels = target_cols
    )
  }
)

ec_print_pairwise_table(
  all_pairwise_results,
  "Raw model-based pairwise contrasts"
)

# Preserve full precision. FDR correction is applied only after within- and
# between-network rows are combined into complete 28-cell heatmap families.
write_csv(
  all_pairwise_results,
  output(
    "covariates",
    "all_pairwise_results_withinconn_covs_long.csv"
  )
)
