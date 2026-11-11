# Curation utilities

This directory contains project-specific tools for staging imaging files,
converting selected scans, maintaining BIDS metadata, and recording curation
checks. The scripts are independent utilities rather than a single
automated workflow. Many use the current working directory, local CSV/TSV
files, DataLad, or paths configured directly in the script.

## Main entry points

| File or folder | Purpose and assumptions |
| --- | --- |
| `0a_copytoraw.py` | Copies files listed in `code/dates_scraping/9_logfile.csv` from `relative_path` to `new_path` using `rsync --copy-links`. Run from the directory where those paths resolve. |
| `0b_subdataset_checking_in.sh` | Loops over `sub-*` folders in the current directory, creates a DataLad subdataset for each, and saves it. Run from the intended parent DataLad dataset. |
| `1_rosmap_fix_BNKfMRI_fromscratch.py` | Converts BNK zipped Analyze-format fMRI files under `sub-*/ses-*/func/` to NIfTI, reorients the image, updates its header, and writes a JSON sidecar. It removes the source ZIP after a successful conversion; keep a backup first. |
| `2_modify_intendedfor.py` | Scans `sub-*/ses-*/fmap/*.json` from the current directory and rebuilds `IntendedFor` for non-BNK scans from sibling functional BOLD files. |
| `3_scan_date.py` | Adds `ScanDate` to sidecars using a curation CSV. The BIDS root and CSV paths are currently set in the script and must be changed for another environment. |
| `4_nifti_info_custom.py` | Adds NIfTI dimensions, voxel sizes, orientation, and volume count to sidecars under `raw/`, then saves changed subject subdatasets with DataLad. The script runs this operation when executed. |
| `bidsify/` | SLURM/Singularity wrappers around `dcm2bids` for source DICOM conversion or validation. They expect an external `config.sh`, a dcm2bids container, and project configuration that are not included here. |
| `bids_validation/` | Individual sidecar, phase-encoding, suffix, and quarantine helpers. Several consume CuBIDS validation TSVs; check the expected report and working directory in each script. |
| `logfile/` | Numbered utilities for building and updating scan, date, and BIDS metadata logs. These rely on project-specific tables and schemas. |
| `_old/` | Historical scripts retained for reference; they may contain obsolete paths and assumptions. |

Other one-off tools include `checklogs.py`, `counting_files.py`, and
`move_quarantined_sub.sh`. Their input and output paths are specific to the
original project environment; edit and review them before use.

## Working-directory inputs

Several scripts discover files relative to the directory from which they are
started. Common expected layouts include:

- `sub-*/ses-*/func/*.zip` for the BNK fMRI converter.
- `sub-*/ses-*/fmap/*.json` and sibling `func/*_bold.nii.gz` files for the
  `IntendedFor` helper.
- A `raw/` directory containing BIDS subject/session trees for the NIfTI
  metadata helper.
- Project-generated curation CSV/TSV files under `code/` for the log and
  validation utilities.

For example, run a current-directory helper from the BIDS root it should edit,
while passing the script by its full path:

```bash
cd /path/to/bids-root
python /path/to/ROSMAP_proc/curation/2_modify_intendedfor.py
```

This example does not supply the data or validation reports; those must already
exist in the expected locations.

## Dependencies

Requirements vary by script. Python utilities use combinations of `pandas`,
`numpy`, `nibabel`, and DataLad API. Shell and BIDS conversion
utilities may require `rsync`, `dcm2bids`, Singularity or Apptainer, SLURM, and
DataLad.

## Before running

These utilities may rewrite JSON sidecars, rename or remove files, create
DataLad commits, copy files into quarantine, or delete input archives. Make a
backup, confirm the dataset root and all configured paths, and review the
script's exact changes before running it on valuable data. Some helpers also
contain site-specific scan conventions; they should not be applied to a new
dataset without checking those assumptions.
