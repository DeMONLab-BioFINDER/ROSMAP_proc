# ROSMAP_proc

Research code for preparing and processing ROSMAP neuroimaging data, quality
control, and downstream functional-connectivity analyses. The repository
contains BIDS curation utilities, project-specific fMRIPrep/XCP-D launchers,
quality-control scripts, and analysis code for parcelwise connectivity and
longitudinal outcomes.

This is a collection of project workflows, not a single end-to-end command.
The scripts depend on local data, container images, software environments, and
in some cases a particular SLURM/HPC setup.

## Repository overview

| Folder | Contents |
| --- | --- |
| [`curation/`](curation/) | BIDS staging, metadata updates, validation helpers, and obsolete curation utilities. |
| [`production/`](production/) | SLURM and Singularity wrappers for MRI pre- and post-processing, including fMRIPrep and XCP-D workflows. |
| [`qc/`](qc/) | Quality control steps: coverage, dropout, mask-overlap, and image-similarity summaries. See [`qc/README.md`](qc/README.md). |
| [`analysis/`](analysis/) | Extracting functional connectivity, statistical analyses, and visualizations. See [`analysis/README.md`](analysis/README.md). |
| [`misc/`](misc/) | Utilities for atlas handling, derivative extraction, and other misc scripts. |

## Typical workflow

1. **Prepare the inputs.** Organize and check imaging files in the expected
   BIDS layout with the relevant scripts in `curation/`.
2. **Run preprocessing.** Adapt a suitable launcher in `production/` to your
   compute environment, input dataset, container image, and resource limits.
3. **Review quality.** Run the appropriate utilities in `qc/` and inspect the
   resulting reports and tables.
4. **Calculate connectivity.** Use `analysis/0_compute_fc_meanconn.py` on
   XCP-D parcel time series to compute functional connectivity matrices.
5. **Assemble and analyze the study table.** Configure the inputs,
   then run `analysis/1_prepare_analysis_table.R` and the other analysis scripts

The stages are intentionally separate: they use different inputs and answer
different preprocessing, QC, and statistical questions. See the folder guides
and each script's arguments before running a stage.

## Analysis setup

The analysis scripts use Python and R. Install the listed Python dependencies
with:

```bash
python -m pip install -r analysis/requirements-python.txt
```

The R package names are in `analysis/requirements-r.txt`. They can be installed
from an R session with:

```r
packages <- readLines("analysis/requirements-r.txt")
packages <- packages[nzchar(packages) & !startsWith(packages, "#")]
install.packages(packages)
```

Some QC and preprocessing scripts also require external neuroimaging software
such as FSL, ANTs, c3d, FreeSurfer, Singularity, or Apptainer. See the relevant
script and [`qc/README.md`](qc/README.md) for the tools it calls.

Set the analysis input and output locations before running R analyses:

```bash
export ROSMAP_DATA=/path/to/authorized/private-inputs
export ROSMAP_OUTPUT=/path/to/analysis-outputs
```

`ROSMAP_DATA` defaults to `analysis/sheets`; `ROSMAP_OUTPUT` defaults to
`analysis/outputs`. Optional overrides include `ROSMAP_DEMOS_CSV`,
`ROSMAP_PREPARED_CSV`, and `ROSMAP_ANALYSIS_DIR`. The shared path logic and
other analysis settings are in [`analysis/paths.R`](analysis/paths.R).

To calculate connectivity from XCP-D parcel time series:

```bash
python analysis/0_compute_fc_meanconn.py \
  --atlas-tsv analysis/fc_related/atlas-4S456Parcels/atlas-4S456Parcels_dseg.tsv \
  --timeseries-dir /path/to/xcpd/timeseries \
  --output-csv "$ROSMAP_OUTPUT/atlas_mean_connectivity456.csv"
```

The script expects 456 parcel columns per time series. By default, it computes
Pearson correlations, averages correlations in Fisher-z space, writes one
matrix per scan plus an average matrix, and summarizes within- and
between-network connectivity. The atlas and time-series parcel order must
match.

After providing the metadata and connectivity inputs expected by the
script, prepare the analysis table with:

```bash
Rscript analysis/1_prepare_analysis_table.R
```

The detailed analysis guide documents the output locations, motion-exclusion
rule (`mean_FD < 0.25`), and downstream workflows.

## Data, portability, and reuse

Participant-level ROSMAP data and restricted demographic or diagnosis tables
are not included, as being sensitive data. The curation scripts can modify, move, or remove files;
check their configured paths and side effects before running them on a dataset.

Many `production/` scripts contain machine-specific paths, module names,
container locations, and SLURM resource settings. Adapt and review them for
your environment. The analysis code also assumes project-specific file names, atlas ordering, site labels, and model
specifications.
