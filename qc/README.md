# QC utilities

Small utilities for post-fMRIPrep/XCP-D quality-control summaries. Active scripts are kept at the top level; historical experiments live in `archive/` and are not maintained.

## Active scripts

- `coverage_metrics.py`: summarize XCP-D coverage TSVs. Reports mean coverage and the number of entries below a configurable threshold.
- `compute_dropout.sh`: estimate gray-matter dropout from fMRIPrep outputs using FSL and c3d.
- `compute_dice.sh`: compute Dice overlap between anatomical and functional brain masks using FSL.
- `compute_nmi.sh`: compute Mattes similarity and entropy measures for T1w/BOLD and MNI-space images using ANTs.

## Dependencies

- Python 3 + pandas (`coverage_metrics.py`)
- FSL (`fslmaths`, `fslstats`)
- c3d (`compute_dropout.sh`)
- ANTs (`antsApplyTransforms`, `MeasureImageSimilarity`, `ImageIntensityStatistics`)

## Examples

```bash
python qc/coverage_metrics.py \
  '/path/to/covg_bbr/*seg-4S456Parcels_stat-coverage_bold.tsv' \
  outputs/bbr_coverage.tsv


qc/compute_dropout.sh /path/to/fmriprep_jobs ID_list.csv outputs/dropout.csv

qc/compute_dice.sh \
  /path/to/fmriprep_jobs \
  coreg_boldref_files.txt \
  outputs/dice.csv
  
qc/compute_nmi.sh \
  /path/to/fmriprep_jobs ID_list.csv outputs/nmi.tsv \
  /path/to/tpl-MNI152NLin6Asym_res-02_desc-brain_T1w.nii.gz \
  /path/to/tpl-MNI152NLin6Asym_res-02_desc-brain_mask.nii.gz
```

## Notes

The archived scripts are retained only for provenance. They contain older versions and hard-coded paths.
