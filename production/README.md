# Preprocessing launchers

This directory holds project-specific launchers for fMRIPrep, XCP-D, and Omni workflow. They wrap externally installed SLURM modules and
Singularity containers; they are not portable pipeline definitions. Update
paths, container locations, bind mounts, licenses, module names, input lists,
and resource requests for the target system before submitting jobs.

BNK_* scripts are site-specific scripts, ran on a second iteration of processing, to fix issues with coregistration. 

## Choose a workflow

| Scripts | Use |
| --- | --- |
| `fmriprep-25-1-1_zip.sh` → `xcp-d-0-11-1_zip.sh` | A zip-based workflow for a BIDS/DataLad-style project layout. The first script runs fMRIPrep for a selected subject/session; the second unpacks the fMRIPrep archive and creates XCP-D NIfTI and CIFTI outputs. |
| `omni_script.sh` | OMNI workflow for synthetic fieldmap correction, specific to some protocols within the UC site. |
| `BNK_sbatch.sh` → `BNK_fmripreprun.sh` | BNK-specific fMRIPrep jobs. The SLURM wrapper selects a row from a project CSV and calls the single-run wrapper. The latter uses an fMRIPrep 25.2.5 image, ignores any fieldmaps, and zips the resulting derivatives. |
| `BNK_sbatch_xcpd.sh` → `BNK_xcpd.sh` | BNK-specific XCP-D jobs. The wrapper runs XCP-D 0.11.1 separately for NIfTI and CIFTI outputs and zips them both. |

## BNK-specific SLURM wrappers

`BNK_sbatch.sh` and `BNK_sbatch_xcpd.sh` read a subject/session identifier from
a CSV row selected by `SLURM_ARRAY_TASK_ID`. The CSV paths are set inside the
scripts. Their current array directives select single indices (`584` and
`648`); change these to the intended job range and make sure the row numbering
matches the CSV, including whether it has a header. The wrappers call
`BNK_fmripreprun.sh` and `BNK_xcpd.sh` by relative path, so submit them from a
working directory where those calls resolve or update the calls first.

## Zip-based workflow

The zip-based scripts are bootstrapped using babs, within a datalad environment. Please see https://pennlinc-babs.readthedocs.io/en/stable/ for more info and how to run them. They expect the project directory tree used in their shell
commands, including `inputs/data/raw`, `inputs/data/fmriprep`, container images,
and a FreeSurfer license. `fmriprep-25-1-1_zip.sh` accepts a subject ID and
session ID. `xcp-d-0-11-1_zip.sh` accepts a subject ID, session ID, and
fMRIPrep ZIP path. Both scripts build output zip archives and use temporary
working directories.
