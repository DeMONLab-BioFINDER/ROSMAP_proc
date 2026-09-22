# Covariate and motion-effect analyses

This directory contains the statistical analyses used to assess demographic,
acquisition, diagnosis, and motion effects on within- and between-network
functional connectivity.

## Statistical workflow

The workflow is deliberately split into three stages:

1. **Fit models and export raw statistics only.**
2. **Combine within- and between-network results into complete connectivity
   families and apply BH-FDR once.**
3. **Plot only from the corrected result tables.**

There is no Tukey adjustment, BH-FDR adjustment, significance-star generation,
or plotting inside the model-fitting scripts.

## Shared configuration

All entry-point scripts source:

1. `analysis/paths.R` for input/output paths and `FD_THRESHOLD <- 0.25`.
2. `analysis/effect_covs/covs_utils.R` for network definitions, factor levels,
   data preparation, model loops, raw emmeans contrasts, and raw FD coefficient
   extraction.

The seven networks are:

`Vis`, `SomMot`, `DorsAttn`, `SalVentAttn`, `Limbic`, `Cont`, and `Default`.

They define 28 unique connectivity cells per matrix:

- 7 within-network diagonal cells.
- 21 unique between-network cells in one triangle.

The opposite triangle is a visual mirror only and is never counted as an
additional statistical test.

## Covariate model scripts

| Script | Analysis |
|---|---|
| `effect_covariates_within_network_baseline.R` | Baseline within-network covariate models |
| `effect_covariates_between_network_baseline.R` | Baseline between-network covariate models |
| `effect_covariates_within_network_longitudinal.R` | Longitudinal within-network covariate models |
| `effect_covariates_between_network_longitudinal.R` | Longitudinal between-network covariate models |

Covariate scripts fit one unfiltered analysis dataset only. They do **not** fit
a second post-FD dataset. Mean FD remains an adjustment covariate in the model.

Baseline model:

```r
connectivity ~ mean_FD + msex + site + age_scandate +
  eyes + dcfdx + syn_bin
```

Longitudinal model:

```r
connectivity ~ mean_FD + msex + site + age_scandate +
  eyes + dcfdx + syn_bin + (1 | sub_id)
```

For categorical covariates, `emmeans` pairwise contrasts are requested with
`adjust = "none"`. The exported tables therefore contain raw quantities only,
including `estimate`, `se`, `df`, `statistic`, and `p_raw`.

## Covariate FDR families

Run `prepare_covariate_effect_heatmaps.R` after the two longitudinal covariate
model scripts. It combines the 7 within-network and 21 between-network rows
before any correction is applied.

BH-FDR is applied **once per covariate across all of that covariate's pairwise
level contrasts**. The prespecified family sizes are:

| Covariate | Pairwise contrasts | Tests in FDR family |
|---|---:|---:|
| `msex` | 1 | 28 |
| `eyes` | 1 | 28 |
| `syn_bin` | 1 | 28 |
| `dcfdx` | 3 | 84 |
| `site` | 6 | 168 |

The correction script validates these family sizes and writes:

- `covariate_heatmaps/covariate_effects_longitudinal_fdr_unique.csv`
- `covariate_heatmaps/covariate_fdr_family_summary.csv`

The corrected table adds `q_fdr` and `sig_fdr`.

`plot_covariate_effect_heatmaps.R` reads only the corrected table, mirrors the
21 between-network cells for display, and creates the heatmaps. It performs no
additional multiple-comparison correction.

## FD model scripts

| Script | Analysis |
|---|---|
| `effect_fd_within_network_baseline.R` | Baseline within-network FD models |
| `effect_fd_between_network_baseline.R` | Baseline between-network FD models |
| `effect_fd_within_network_longitudinal.R` | Longitudinal within-network FD models |
| `effect_fd_between_network_longitudinal.R` | Longitudinal between-network FD models |

Unlike the categorical-covariate analyses, the FD analyses retain two model
families:

- pre-FD filtering / all observations;
- post-FD filtering, retaining `mean_FD < 0.25`.

The model scripts export only `beta_fd`, `t_val_fd`, and raw `p_fd`; they do not
compute FDR values and they do not plot.

## FD FDR families and heatmaps

`heatmap_fd.R` is now the FD correction/preparation stage. It combines the 7
within-network and 21 unique between-network tests and applies BH-FDR separately
to:

- the 28 pre-FD tests;
- the 28 post-FD tests.

It writes:

- `fd_heatmaps/fd_effects_longitudinal_fdr_unique.csv`
- `fd_heatmaps/fd_fdr_family_summary.csv`

`plot_fd_heatmaps.R` is the heatmap-only plotting stage. It reads the corrected
FD table, mirrors the lower-triangle between-network cells for display, and
plots pre- and post-FD heatmaps with a shared beta scale. It performs no
correction.

The longitudinal `effect_fd_*` scripts also save their fitted model objects and
analysis data as RDS files. `plot_fd_effects_corrected.R` uses those saved
objects together with the final `q_fdr` values to create fitted-value and
partial-residual FD figures. This keeps all inferential annotations downstream
of the final correction and avoids refitting the models.

## Suggested run order

For the longitudinal covariate heatmaps:

```text
effect_covariates_within_network_longitudinal.R
effect_covariates_between_network_longitudinal.R
prepare_covariate_effect_heatmaps.R
plot_covariate_effect_heatmaps.R
```

For the longitudinal FD heatmaps:

```text
effect_fd_within_network_longitudinal.R
effect_fd_between_network_longitudinal.R
heatmap_fd.R
plot_fd_heatmaps.R
plot_fd_effects_corrected.R
```

Baseline model scripts can be run independently when raw baseline results are
needed. They do not perform multiple-comparison correction or plotting.
