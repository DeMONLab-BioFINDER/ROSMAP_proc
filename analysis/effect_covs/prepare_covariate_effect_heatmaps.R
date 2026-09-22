# Prepare longitudinal covariate-effect results for heatmap plotting.
#
# This is the ONLY stage that applies multiple-comparison correction to the
# categorical-covariate results. For each covariate, all unique connectivity
# cells (7 within + 21 between = 28) are combined across all pairwise level
# contrasts and corrected together with Benjamini-Hochberg FDR.
#
# Examples:
#   binary covariate: 28 x 1 = 28 tests
#   diagnosis (3 levels): 28 x 3 contrasts = 84 tests
#   site (4 levels): 28 x 6 contrasts = 168 tests

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

within_file <- require_file(
  output("covariates", "all_pairwise_results_withinconn_covs_long.csv"),
  "raw longitudinal within-network covariate results"
)
between_file <- require_file(
  output("covariates", "all_pairwise_results_betweenconn_covs_long.csv"),
  "raw longitudinal between-network covariate results"
)

out_dir <- output_dir("covariate_heatmaps")
network_order <- target_cols

within_raw <- readr::read_csv(within_file, show_col_types = FALSE)
between_raw <- readr::read_csv(between_file, show_col_types = FALSE)

required_common <- c(
  "covariate", "contrast", "estimate", "se", "df", "statistic", "p_raw"
)
if (!all(c("network", required_common) %in% names(within_raw))) {
  stop("Within-network raw results are missing required columns.")
}
if (!all(c("network_combo", required_common) %in% names(between_raw))) {
  stop("Between-network raw results are missing required columns.")
}

within_cells <- within_raw %>%
  mutate(
    network = stringr::str_replace(as.character(network), "Network$", "")
  ) %>%
  transmute(
    connection_type = "within",
    measure = network,
    row_net = network,
    col_net = network,
    covariate = as.character(covariate),
    contrast = as.character(contrast),
    estimate = as.numeric(estimate),
    se = as.numeric(se),
    df = as.numeric(df),
    statistic = as.numeric(statistic),
    p_raw = as.numeric(p_raw)
  )

between_cells <- between_raw %>%
  mutate(network_combo = as.character(network_combo)) %>%
  tidyr::separate(
    network_combo,
    into = c("network1", "network2"),
    sep = "_to_",
    remove = FALSE,
    fill = "right"
  ) %>%
  mutate(
    network1 = stringr::str_replace(network1, "Network$", ""),
    network2 = stringr::str_replace(network2, "Network$", ""),
    index1 = match(network1, network_order),
    index2 = match(network2, network_order)
  )

if (any(is.na(between_cells$index1) | is.na(between_cells$index2))) {
  stop("Unknown network name found in between-network results.")
}

between_cells <- between_cells %>%
  transmute(
    connection_type = "between",
    measure = network_combo,
    row_net = ifelse(index1 > index2, network1, network2),
    col_net = ifelse(index1 > index2, network2, network1),
    covariate = as.character(covariate),
    contrast = as.character(contrast),
    estimate = as.numeric(estimate),
    se = as.numeric(se),
    df = as.numeric(df),
    statistic = as.numeric(statistic),
    p_raw = as.numeric(p_raw)
  )

all_cells <- bind_rows(within_cells, between_cells)

if (any(is.na(all_cells$p_raw))) {
  stop("Raw p-values contain NA; refusing to construct an incomplete FDR family.")
}

cell_counts <- all_cells %>%
  count(covariate, contrast, name = "n_cells")

bad_counts <- cell_counts %>% filter(n_cells != 28L)
if (nrow(bad_counts) > 0) {
  print(bad_counts, n = Inf)
  stop("Every covariate contrast must contain exactly 28 unique connectivity tests.")
}

duplicate_cells <- all_cells %>%
  count(covariate, contrast, row_net, col_net, name = "n") %>%
  filter(n != 1L)
if (nrow(duplicate_cells) > 0) {
  print(duplicate_cells, n = Inf)
  stop("Duplicate connectivity cells found within a covariate contrast.")
}

corrected <- all_cells %>%
  group_by(covariate) %>%
  mutate(
    n_contrasts = n_distinct(contrast),
    fdr_family_n = n(),
    q_fdr = stats::p.adjust(p_raw, method = "BH"),
    sig_fdr = ec_sig_from_p(q_fdr)
  ) %>%
  ungroup()

family_summary <- corrected %>%
  group_by(covariate) %>%
  summarise(
    n_contrasts = first(n_contrasts),
    n_connectivity_cells_per_contrast = 28L,
    n_tests = first(fdr_family_n),
    expected_n_tests = 28L * first(n_contrasts),
    .groups = "drop"
  )

expected_contrast_counts <- c(
  msex = 1L,
  eyes = 1L,
  syn_bin = 1L,
  dcfdx = 3L,
  site = 6L
)

family_summary <- family_summary %>%
  mutate(
    expected_n_contrasts = unname(expected_contrast_counts[covariate]),
    expected_design_n_tests = 28L * expected_n_contrasts
  )

if (any(is.na(family_summary$expected_n_contrasts))) {
  print(family_summary, n = Inf)
  stop("Unexpected covariate found while defining FDR families.")
}

if (any(
  family_summary$n_tests != family_summary$expected_n_tests |
    family_summary$n_contrasts != family_summary$expected_n_contrasts |
    family_summary$n_tests != family_summary$expected_design_n_tests
)) {
  print(family_summary, n = Inf)
  stop(
    "FDR family does not match the prespecified design: 28 cells per contrast; ",
    "binary covariates = 28, diagnosis = 84, site = 168 tests."
  )
}

print(family_summary, n = Inf)

readr::write_csv(
  corrected,
  file.path(out_dir, "covariate_effects_longitudinal_fdr_unique.csv")
)
readr::write_csv(
  family_summary,
  file.path(out_dir, "covariate_fdr_family_summary.csv")
)
