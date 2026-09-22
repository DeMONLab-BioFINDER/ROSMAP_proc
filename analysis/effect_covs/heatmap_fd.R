# Prepare longitudinal FD-effect results for heatmap plotting.
#
# This is the ONLY stage that applies multiple-comparison correction to the FD
# results. The 7 within-network diagonal tests and 21 unique between-network
# tests are combined into one 28-test family. Pre-FD and post-FD analyses are
# corrected separately.

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

network_order <- target_cols
out_dir <- output_dir("fd_heatmaps")

files <- list(
  pre_within = require_file(
    file.path(output_dir("fd_within_longitudinal"), "fd_effects_withinconn_all_modelresults.csv")
  ),
  post_within = require_file(
    file.path(output_dir("fd_within_longitudinal"), "fd_effects_withinconn_fd_filtered_modelresults.csv")
  ),
  pre_between = require_file(
    file.path(output_dir("fd_between_longitudinal"), "fd_effects_betweenconn_all_modelresults.csv")
  ),
  post_between = require_file(
    file.path(output_dir("fd_between_longitudinal"), "fd_effects_betweenconn_fd_filtered_modelresults.csv")
  )
)

make_unique_fd_cells <- function(within_file, between_file, filter_status) {
  within <- readr::read_csv(within_file, show_col_types = FALSE)
  between <- readr::read_csv(between_file, show_col_types = FALSE)

  if (!all(c("network", "beta_fd", "t_val_fd", "p_fd") %in% names(within))) {
    stop("Within-network FD results are missing required raw columns.")
  }
  if (!all(c("network_combo", "beta_fd", "t_val_fd", "p_fd") %in% names(between))) {
    stop("Between-network FD results are missing required raw columns.")
  }

  diagonal <- within %>%
    mutate(network = stringr::str_replace(as.character(network), "Network$", "")) %>%
    transmute(
      filter_status = filter_status,
      connection_type = "within",
      measure = network,
      row_net = network,
      col_net = network,
      beta_fd = as.numeric(beta_fd),
      t_val_fd = as.numeric(t_val_fd),
      p_fd = as.numeric(p_fd)
    )

  off_diagonal <- between %>%
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

  if (any(is.na(off_diagonal$index1) | is.na(off_diagonal$index2))) {
    stop("Unknown network name found in between-network FD results.")
  }

  off_diagonal <- off_diagonal %>%
    transmute(
      filter_status = filter_status,
      connection_type = "between",
      measure = network_combo,
      row_net = ifelse(index1 > index2, network1, network2),
      col_net = ifelse(index1 > index2, network2, network1),
      beta_fd = as.numeric(beta_fd),
      t_val_fd = as.numeric(t_val_fd),
      p_fd = as.numeric(p_fd)
    )

  out <- bind_rows(diagonal, off_diagonal)

  if (nrow(out) != 28L) {
    stop("FD family '", filter_status, "' has ", nrow(out), " rows; expected 28.")
  }
  if (any(is.na(out$p_fd))) {
    stop("FD family '", filter_status, "' contains NA p-values.")
  }
  duplicates <- out %>% count(row_net, col_net, name = "n") %>% filter(n != 1L)
  if (nrow(duplicates) > 0) {
    print(duplicates, n = Inf)
    stop("Duplicate cells found in FD family '", filter_status, "'.")
  }

  out
}

fd_unique <- bind_rows(
  make_unique_fd_cells(files$pre_within, files$pre_between, "pre"),
  make_unique_fd_cells(files$post_within, files$post_between, "post")
) %>%
  group_by(filter_status) %>%
  mutate(
    fdr_family_n = n(),
    q_fdr = stats::p.adjust(p_fd, method = "BH"),
    sig_fdr = ec_sig_from_p(q_fdr)
  ) %>%
  ungroup()

family_summary <- fd_unique %>%
  group_by(filter_status) %>%
  summarise(n_tests = n(), .groups = "drop")

if (any(family_summary$n_tests != 28L)) {
  print(family_summary, n = Inf)
  stop("Each FD filtering status must contain exactly 28 tests.")
}

print(family_summary, n = Inf)

readr::write_csv(
  fd_unique,
  file.path(out_dir, "fd_effects_longitudinal_fdr_unique.csv")
)
readr::write_csv(
  family_summary,
  file.path(out_dir, "fd_fdr_family_summary.csv")
)
