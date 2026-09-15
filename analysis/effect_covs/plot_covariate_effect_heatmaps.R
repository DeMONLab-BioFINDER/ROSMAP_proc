# Summarize longitudinal covariate effects as network heatmaps.
#
# Main heatmaps:
#   ALL covariates plotted as t-values.
#
# Additional heatmaps:
#   dcfdx also plotted separately as beta estimates.
#
# Pre/post FD-filtering plots use the same colour scale
# within each covariate and statistic type.


# ============================================================
# 0. Paths and packages
# ============================================================

.script_arg <- grep(
  "^--file=",
  commandArgs(trailingOnly = FALSE),
  value = TRUE
)

.script_dir <- if (length(.script_arg)) {
  dirname(
    normalizePath(
      sub("^--file=", "", .script_arg[[1]]),
      mustWork = FALSE
    )
  )
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

.paths_file <- .paths_candidates[
  file.exists(.paths_candidates)
][1]

if (is.na(.paths_file)) {
  stop("Could not locate analysis/paths.R")
}

source(.paths_file)

rm(
  .script_arg,
  .script_dir,
  .paths_candidates,
  .paths_file
)


library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)


# ============================================================
# 1. Load longitudinal covariate-result tables
# ============================================================

csvs_long <- list.files(
  path = OUTPUT_DIR,
  pattern = "^all_pairwise_results_(within|between)conn_covs_long\\.csv$",
  full.names = TRUE,
  recursive = TRUE
)

if (length(csvs_long) == 0) {
  stop(
    "No longitudinal covariate-result tables found under: ",
    OUTPUT_DIR
  )
}


covs_long_list <- lapply(
  csvs_long,
  read_csv,
  show_col_types = FALSE
)

names(covs_long_list) <- basename(csvs_long) %>%
  str_remove("^all_pairwise_results_") %>%
  str_remove("conn_covs_long\\.csv$")


covs_long_df <- bind_rows(
  covs_long_list,
  .id = "comparison"
)


# Checks
print(unique(covs_long_df$comparison))
print(colnames(covs_long_df))
print(unique(covs_long_df$contrast))


# ============================================================
# 2. Shared colour-scale helpers
# ============================================================


# ------------------------------------------------------------
# Shared t-value limits
# ------------------------------------------------------------

get_shared_t_limits <- function(
    df,
    covariate_to_plot,
    filter_statuses = c("pre", "post"),
    padding = 0
) {

  tvals <- df %>%
    filter(
      covariate == covariate_to_plot,
      filter_status %in% filter_statuses
    ) %>%
    pull(statistic) %>%
    as.numeric()

  tvals <- tvals[
    is.finite(tvals)
  ]

  if (length(tvals) == 0) {
    stop(
      paste0(
        "No finite t-values found for covariate = '",
        covariate_to_plot,
        "'."
      )
    )
  }

  max_abs <- max(
    abs(tvals)
  )

  if (max_abs == 0) {
    max_abs <- 1
  }

  max_abs <- max_abs * (1 + padding)

  c(
    -max_abs,
    max_abs
  )
}


# ------------------------------------------------------------
# Shared beta limits
# Needed for additional dcfdx beta plots
# ------------------------------------------------------------

get_shared_beta_limits <- function(
    df,
    covariate_to_plot,
    filter_statuses = c("pre", "post"),
    padding = 0
) {

  betas <- df %>%
    filter(
      covariate == covariate_to_plot,
      filter_status %in% filter_statuses
    ) %>%
    pull(beta) %>%
    as.numeric()

  betas <- betas[
    is.finite(betas)
  ]

  if (length(betas) == 0) {
    stop(
      paste0(
        "No finite beta values found for covariate = '",
        covariate_to_plot,
        "'."
      )
    )
  }

  max_abs <- max(
    abs(betas)
  )

  if (max_abs == 0) {
    max_abs <- 1
  }

  max_abs <- max_abs * (1 + padding)

  c(
    -max_abs,
    max_abs
  )
}


# ============================================================
# 3. Prepare data
# ============================================================

stats_df <- covs_long_df %>%

  mutate(

    comparison = case_when(
      str_detect(
        comparison,
        regex("within", ignore_case = TRUE)
      ) ~ "within",

      str_detect(
        comparison,
        regex("between", ignore_case = TRUE)
      ) ~ "between",

      TRUE ~ as.character(comparison)
    ),

    covariate = as.character(covariate),

    contrast = as.character(contrast),

    sig_tukey = ifelse(
      is.na(sig_tukey),
      "",
      sig_tukey
    ),

    beta = as.numeric(estimate),

    statistic = as.numeric(statistic)
  ) %>%

  separate(
    contrast,
    into = c(
      "contrast1",
      "contrast2"
    ),
    sep = " - ",
    remove = FALSE,
    fill = "right",
    extra = "merge"
  ) %>%

  separate(
    network_combo,
    into = c(
      "network1_from_combo",
      "network2_from_combo"
    ),
    sep = "_to_",
    remove = FALSE,
    fill = "right",
    extra = "merge"
  ) %>%

  mutate(

    network1 = case_when(
      comparison == "between" ~ network1_from_combo,
      comparison == "within" ~ as.character(network),
      TRUE ~ NA_character_
    ),

    network2 = case_when(
      comparison == "between" ~ network2_from_combo,
      comparison == "within" ~ as.character(network),
      TRUE ~ NA_character_
    ),

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
  ) %>%

  select(
    -network1_from_combo,
    -network2_from_combo
  ) %>%

  filter(
    !is.na(covariate),
    !is.na(contrast),
    !is.na(network1),
    !is.na(network2)
  )


# ============================================================
# 4. Network order
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
# 5. Multi-level covariate heatmap grid
#
# Used for:
#   site
#   dcfdx
#
# value_type:
#   "t"    -> statistic
#   "beta" -> estimate
# ============================================================

make_covariate_heatmap_grid_lower <- function(
    effects_df,
    covariate_to_plot,
    filter_status_to_plot,
    contrast_levels,
    fill_limits = NULL,
    text_size = 6,
    value_type = c("t", "beta"),
    blank_nonsig = FALSE
) {

  value_type <- match.arg(value_type)


  # ==========================================================
  # 1. Filter requested covariate / FD status
  # ==========================================================

  plot_df <- effects_df %>%
    filter(
      covariate == covariate_to_plot,
      filter_status == filter_status_to_plot
    ) %>%
    mutate(
      beta = as.numeric(beta),
      statistic = as.numeric(statistic),

      sig_tukey = ifelse(
        is.na(sig_tukey),
        "",
        sig_tukey
      ),

      network1 = as.character(network1),
      network2 = as.character(network2),

      contrast1 = as.character(contrast1),
      contrast2 = as.character(contrast2)
    )


  # Select the ENTIRE column.
  # Important: use if(), NOT ifelse(), here.
  plot_df <- plot_df %>%
    mutate(
      raw_plot_value = if (value_type == "t") {
        statistic
      } else {
        beta
      }
    ) %>%
    filter(
      is.finite(raw_plot_value)
    )


  if (nrow(plot_df) == 0) {
    stop(
      paste0(
        "No usable rows found for covariate = '",
        covariate_to_plot,
        "', filter_status = '",
        filter_status_to_plot,
        "', value_type = '",
        value_type,
        "'."
      )
    )
  }


  # ==========================================================
  # 2. Set contrast order
  # ==========================================================

  plot_df <- plot_df %>%
    mutate(
      contrast1 = factor(
        contrast1,
        levels = contrast_levels
      ),

      contrast2 = factor(
        contrast2,
        levels = contrast_levels
      ),

      contrast1_id = as.integer(contrast1),
      contrast2_id = as.integer(contrast2)
    ) %>%

    # Drops contrasts involving a level intentionally excluded
    # from contrast_levels, e.g. "other"
    filter(
      !is.na(contrast1_id),
      !is.na(contrast2_id)
    )


  # ==========================================================
  # 3. Put contrasts into lower-triangle orientation
  # ==========================================================

  plot_df <- plot_df %>%
    mutate(

      flip_contrast =
        contrast1_id < contrast2_id,


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


      panel_row_id = pmax(
        contrast1_id,
        contrast2_id
      ),


      panel_col_id = pmin(
        contrast1_id,
        contrast2_id
      ),


      # raw_plot_value originally represents:
      #
      # contrast1 - contrast2
      #
      # If we reverse the contrast for the lower-triangle
      # arrangement, reverse its sign as well.
      plot_value = ifelse(
        flip_contrast,
        -raw_plot_value,
        raw_plot_value
      ),


      sig_plot = sig_tukey
    ) %>%

    filter(
      panel_row_id > panel_col_id
    ) %>%

    mutate(
      panel_row = factor(
        panel_row,
        levels = contrast_levels
      ),

      panel_col = factor(
        panel_col,
        levels = contrast_levels
      )
    )


  # ==========================================================
  # 4. Construct network x network matrices
  # ==========================================================

  heatmap_df <- bind_rows(

    # Original network orientation
    plot_df %>%
      transmute(
        panel_row,
        panel_col,

        row_net = network1,
        col_net = network2,

        plot_value,
        sig = sig_plot
      ),


    # Mirror between-network values across diagonal
    plot_df %>%
      filter(
        network1 != network2
      ) %>%
      transmute(
        panel_row,
        panel_col,

        row_net = network2,
        col_net = network1,

        plot_value,
        sig = sig_plot
      )

  ) %>%

    group_by(
      panel_row,
      panel_col,
      row_net,
      col_net
    ) %>%

    summarise(
      plot_value = first(plot_value),
      sig = first(sig),
      .groups = "drop"
    ) %>%

    mutate(

      # For blank_nonsig = TRUE:
      # nonsignificant cells show nothing at all
      cell_label = if (blank_nonsig) {

        ifelse(
          sig == "",
          "",
          paste0(
            sprintf("%.2f", plot_value),
            sig
          )
        )

      } else {

        ifelse(
          is.na(plot_value),
          "",
          paste0(
            sprintf("%.2f", plot_value),
            sig
          )
        )
      },


      # For blank_nonsig = TRUE:
      # nonsignificant cells have no colour fill
      fill_value = if (blank_nonsig) {

        ifelse(
          sig == "",
          NA_real_,
          plot_value
        )

      } else {

        plot_value
      },


      row_net = factor(
        row_net,
        levels = rev(network_order)
      ),

      col_net = factor(
        col_net,
        levels = network_order
      )
    )

  # ==========================================================
  # 5. Full 7 x 7 matrix for each contrast
  # ==========================================================

  panel_grid <- plot_df %>%
    distinct(
      panel_row,
      panel_col
    )


  heatmap_full <- panel_grid %>%
    crossing(

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
      heatmap_df,
      by = c(
        "panel_row",
        "panel_col",
        "row_net",
        "col_net"
      )
    )


  # ==========================================================
  # 6. Remove impossible first row / last column
  # ==========================================================

  first_level <- contrast_levels[1]

  last_level <- contrast_levels[
    length(contrast_levels)
  ]


  heatmap_full <- heatmap_full %>%
    filter(
      panel_row != first_level,
      panel_col != last_level
    ) %>%

    mutate(
      panel_row = factor(
        panel_row,
        levels = contrast_levels[
          contrast_levels != first_level
        ]
      ),

      panel_col = factor(
        panel_col,
        levels = contrast_levels[
          contrast_levels != last_level
        ]
      )
    )


  # ==========================================================
  # 7. Plot labels
  # ==========================================================

  legend_name <- if (value_type == "t") {
    "t-value"
  } else {
    expression(beta)
  }


  na_fill <- if (blank_nonsig) {
    "white"
  } else {
    "grey90"
  }


  # ==========================================================
  # 8. Plot
  # ==========================================================

  p <- ggplot(
    heatmap_full,
    aes(
      x = col_net,
      y = row_net,
      fill = fill_value
    )
  ) +

    geom_tile(
      color = "grey80",
      linewidth = 0.3
    ) +

    geom_text(
      aes(
        label = cell_label
      ),
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

    theme_minimal(
      base_size = 15
    ) +

    theme(
      panel.grid = element_blank(),

      axis.title = element_blank(),

      axis.text.x = element_text(
        angle = 45,
        hjust = 1,
        size = 18
      ),

      axis.text.y = element_text(
        size = 18
      ),

      strip.text = element_text(
        face = "bold",
        size = 16
      ),

      legend.position = "right",

      plot.title = element_text(
        face = "bold",
        hjust = 0.5
      ),

      plot.subtitle = element_text(
        hjust = 0.5
      )
    ) +

    labs(
      title = paste0(
        covariate_to_plot,
        " effect heatmap grid"
      ),

      subtitle = paste0(
        "Row level - column level | ",
        ifelse(
          value_type == "t",
          "t-values",
          "beta estimates"
        )
      )
    )


  return(p)
}

# ============================================================
# 6. Binary-covariate heatmaps
#
# Main use = t-values
# ============================================================

make_covariate_heatmaps <- function(
    df,
    covariate_to_plot,
    filter_status_to_plot = "pre",
    network_order = c(
      "Vis",
      "SomMot",
      "DorsAttn",
      "SalVentAttn",
      "Limbic",
      "Cont",
      "Default"
    ),
    text_size = 4,
    fill_limits = NULL,
    save_plots = FALSE,
    save_dir = output_dir("heatmaps"),
    value_type = c("t", "beta")
) {

  value_type <- match.arg(
    value_type
  )


  # ----------------------------------------------------------
  # Filter and clean
  # ----------------------------------------------------------

  effects_df <- df %>%

    filter(
      covariate == covariate_to_plot,
      filter_status == filter_status_to_plot
    ) %>%

    mutate(

      beta = as.numeric(beta),

      statistic = as.numeric(statistic),

      sig_tukey = ifelse(
        is.na(sig_tukey),
        "",
        sig_tukey
      ),

      network1 = as.character(network1),

      network2 = as.character(network2),

      contrast = as.character(contrast),

      contrast1 = as.character(contrast1),

      contrast2 = as.character(contrast2),

      plot_value = if (value_type == "t") {
        statistic
      } else {
        beta
      }
    ) %>%

    filter(
      is.finite(plot_value)
    )


  if (nrow(effects_df) == 0) {
    stop(
      paste0(
        "No rows found for covariate = '",
        covariate_to_plot,
        "' and filter_status = '",
        filter_status_to_plot,
        "'."
      )
    )
  }


  contrast_combinations <-
    unique(
      effects_df$contrast
    )


  heatmaps <- list()


  # ----------------------------------------------------------
  # One heatmap per contrast
  # ----------------------------------------------------------

  for (
    this_contrast in contrast_combinations
  ) {


    contrast_df <- effects_df %>%

      filter(
        contrast == this_contrast
      )


    contrast1_name <-
      unique(
        contrast_df$contrast1
      )[1]


    contrast2_name <-
      unique(
        contrast_df$contrast2
      )[1]


    # --------------------------------------------------------
    # Symmetric network matrix
    # --------------------------------------------------------

    heatmap_df <- bind_rows(

      contrast_df %>%

        transmute(
          row_net = network1,
          col_net = network2,
          plot_value,
          sig = sig_tukey
        ),


      contrast_df %>%

        filter(
          network1 != network2
        ) %>%

        transmute(
          row_net = network2,
          col_net = network1,
          plot_value,
          sig = sig_tukey
        )

    ) %>%

      group_by(
        row_net,
        col_net
      ) %>%

      summarise(

        plot_value = first(
          plot_value
        ),

        sig = first(
          sig
        ),

        .groups = "drop"
      ) %>%

      mutate(

        cell_label = ifelse(
          is.na(plot_value),
          "",
          paste0(
            sprintf(
              "%.2f",
              plot_value
            ),
            sig
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


    # --------------------------------------------------------
    # Full network matrix
    # --------------------------------------------------------

    heatmap_full <- expand_grid(

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
        heatmap_df,
        by = c(
          "row_net",
          "col_net"
        )
      )


    legend_name <- if (
      value_type == "t"
    ) {
      "t-value"
    } else {
      "beta"
    }


    # --------------------------------------------------------
    # Plot
    # --------------------------------------------------------

    p <- ggplot(
      heatmap_full,
      aes(
        x = col_net,
        y = row_net,
        fill = plot_value
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
        na.value = "grey90",
        name = paste0(
          contrast1_name,
          " - ",
          contrast2_name,
          "\n",
          legend_name
        )
      ) +

      coord_fixed() +

      theme_minimal(
        base_size = 13
      ) +

      theme(

        panel.grid =
          element_blank(),

        axis.title =
          element_blank(),

        axis.text.x =
          element_text(
            angle = 45,
            hjust = 1,
            face = "bold"
          ),

        axis.text.y =
          element_text(
            face = "bold"
          ),

        plot.title =
          element_text(
            face = "bold",
            hjust = 0.5
          ),

        plot.subtitle =
          element_text(
            hjust = 0.5
          ),

        legend.position =
          "right"
      ) +

      labs(

        title = paste0(
          covariate_to_plot,
          " effect heatmap, ",
          filter_status_to_plot,
          " FD filtering"
        ),

        subtitle = paste0(
          "Contrast: ",
          contrast1_name,
          " - ",
          contrast2_name
        )
      )


    print(p)


    heatmaps[[this_contrast]] <- p


    # --------------------------------------------------------
    # Save
    # --------------------------------------------------------

    if (save_plots) {


      safe_covariate <- str_replace_all(
        covariate_to_plot,
        "[^A-Za-z0-9]+",
        "_"
      )

      safe_contrast <- str_replace_all(
        this_contrast,
        "[^A-Za-z0-9]+",
        "_"
      )

      safe_filter <- str_replace_all(
        filter_status_to_plot,
        "[^A-Za-z0-9]+",
        "_"
      )


      ggsave(
        filename = file.path(
          save_dir,
          paste0(
            "heatmap_",
            safe_covariate,
            "_",
            safe_contrast,
            "_",
            safe_filter,
            "_",
            value_type,
            ".png"
          )
        ),
        plot = p,
        width = 20,
        height = 20,
        dpi = 300
      )
    }
  }


  return(
    heatmaps
  )
}


# ============================================================
# 7. Binary covariates
#
# ALL MAIN PLOTS = t-values
# ============================================================


# ------------------------------------------------------------
# Sex
# ------------------------------------------------------------

msex_t_limits <- get_shared_t_limits(
  stats_df,
  "msex"
)

msex_heatmaps_pre <- make_covariate_heatmaps(
  df = stats_df,
  covariate_to_plot = "msex",
  filter_status_to_plot = "pre",
  fill_limits = msex_t_limits,
  save_plots = TRUE,
  value_type = "t"
)

msex_heatmaps_post <- make_covariate_heatmaps(
  df = stats_df,
  covariate_to_plot = "msex",
  filter_status_to_plot = "post",
  fill_limits = msex_t_limits,
  save_plots = TRUE,
  value_type = "t"
)


# ------------------------------------------------------------
# Eyes
# ------------------------------------------------------------

eyes_t_limits <- get_shared_t_limits(
  stats_df,
  "eyes"
)

eyes_heatmaps_pre <- make_covariate_heatmaps(
  df = stats_df,
  covariate_to_plot = "eyes",
  filter_status_to_plot = "pre",
  fill_limits = eyes_t_limits,
  save_plots = TRUE,
  value_type = "t"
)

eyes_heatmaps_post <- make_covariate_heatmaps(
  df = stats_df,
  covariate_to_plot = "eyes",
  filter_status_to_plot = "post",
  fill_limits = eyes_t_limits,
  save_plots = TRUE,
  value_type = "t"
)


# ------------------------------------------------------------
# Synesthesia
# ------------------------------------------------------------

syn_t_limits <- get_shared_t_limits(
  stats_df,
  "syn_bin"
)

syn_heatmaps_pre <- make_covariate_heatmaps(
  df = stats_df,
  covariate_to_plot = "syn_bin",
  filter_status_to_plot = "pre",
  fill_limits = syn_t_limits,
  save_plots = TRUE,
  value_type = "t"
)

syn_heatmaps_post <- make_covariate_heatmaps(
  df = stats_df,
  covariate_to_plot = "syn_bin",
  filter_status_to_plot = "post",
  fill_limits = syn_t_limits,
  save_plots = TRUE,
  value_type = "t"
)


# ============================================================
# 8. Multi-level covariates
#
# ALL MAIN PLOTS = t-values
# ============================================================


# ------------------------------------------------------------
# Site: t-values
# ------------------------------------------------------------

site_t_limits <- get_shared_t_limits(
  stats_df,
  "site"
)

p_site_pre_grid <- make_covariate_heatmap_grid_lower(
  effects_df = stats_df,
  covariate_to_plot = "site",
  filter_status_to_plot = "pre",
  contrast_levels = EC_SITE_LEVELS,
  fill_limits = site_t_limits,
  value_type = "t"
)

p_site_post_grid <- make_covariate_heatmap_grid_lower(
  effects_df = stats_df,
  covariate_to_plot = "site",
  filter_status_to_plot = "post",
  contrast_levels = EC_SITE_LEVELS,
  fill_limits = site_t_limits,
  value_type = "t"
)


# ------------------------------------------------------------
# Diagnosis: t-values
# ------------------------------------------------------------

dx_levels <- EC_DX_LEVELS[
  EC_DX_LEVELS != "other"
]

dcfdx_t_limits <- get_shared_t_limits(
  stats_df,
  "dcfdx"
)

p_dx_pre_grid <- make_covariate_heatmap_grid_lower(
  effects_df = stats_df,
  covariate_to_plot = "dcfdx",
  filter_status_to_plot = "pre",
  contrast_levels = dx_levels,
  fill_limits = dcfdx_t_limits,
  value_type = "t"
)

p_dx_post_grid <- make_covariate_heatmap_grid_lower(
  effects_df = stats_df,
  covariate_to_plot = "dcfdx",
  filter_status_to_plot = "post",
  contrast_levels = dx_levels,
  fill_limits = dcfdx_t_limits,
  value_type = "t"
)


print(p_site_pre_grid)
print(p_site_post_grid)

print(p_dx_pre_grid)
print(p_dx_post_grid)


# ============================================================
# 9. ADDITIONAL site BETA plots
# ============================================================

site_beta_limits <- get_shared_beta_limits(
  stats_df,
  "site"
)

p_site_beta_pre_grid <- make_covariate_heatmap_grid_lower(
  effects_df = stats_df,
  covariate_to_plot = "site",
  filter_status_to_plot = "pre",
  contrast_levels = EC_SITE_LEVELS,
  fill_limits = site_beta_limits,
  value_type = "beta",
  blank_nonsig = TRUE
)

p_site_beta_post_grid <- make_covariate_heatmap_grid_lower(
  effects_df = stats_df,
  covariate_to_plot = "site",
  filter_status_to_plot = "post",
  contrast_levels = EC_SITE_LEVELS,
  fill_limits = site_beta_limits,
  value_type = "beta",
  blank_nonsig = TRUE
)

print(p_site_beta_pre_grid)
print(p_site_beta_post_grid)


# ============================================================
# 10. Save grid plots
# ============================================================

grid_plots <- list(

  # Main t-value plots
  sex_pre_t =
    msex_heatmaps_pre,
  sex_post_t =
    msex_heatmaps_post,
  eyes_pre_t =
    eyes_heatmaps_pre,
  eyes_post_t =
    eyes_heatmaps_post,
  syn_pre_t =
    syn_heatmaps_pre,
  syn_post_t =
    syn_heatmaps_post,
  
  site_pre_t =
    p_site_pre_grid,

  site_post_t =
    p_site_post_grid,

  diagnosis_pre_t =
    p_dx_pre_grid,

  diagnosis_post_t =
    p_dx_post_grid,


  # Additional site beta plots
  site_pre_beta =
    p_site_beta_pre_grid,

  site_post_beta =
    p_site_beta_post_grid
)


for (
  plot_name in names(grid_plots)
) {

  ggsave(
    filename = output(
      "heatmaps",
      paste0(
        "heatmap_grid_",
        plot_name,
        ".pdf"
      )
    ),
    plot = grid_plots[[plot_name]],
    width = 15,
    height = 15,
    units = "in",
    limitsize = FALSE
  )
}