#!/bin/bash

set -eux

sub_ses=$1
subid=$(echo $sub_ses | cut -d'_' -f1)
sesid=$(echo $sub_ses | cut -d'_' -f2)

# this is for BNKs only, no fmap correction neeeded

singularity run --cleanenv \
	-B ${PWD} \
	-B /home/gabridele/Documents/ROSMAP/raw:/SGLR/BNK_raw \
	-B /home/gabridele/backup/templateflow:/SGLR/TEMPLATEFLOW_HOME \
	-B /home/gabridele/license.txt:/SGLR/FREESURFER_HOME/license.txt \
	-B /home/gabridele/Documents/BNK_v1-3/fmriprep_bnk_ders0505_fs:/SGLR/freesurfer \
	--env TEMPLATEFLOW_HOME=/SGLR/TEMPLATEFLOW_HOME \
	/home/gabridele/backup/backup_files/bids_apps/fmriprep-25-2-5.sif \
	/SGLR/BNK_raw \
	outputs_${subid}_${sesid}/fmriprep \
	participant \
	-w workdir_3 \
	--n_cpus 24 \
	--omp-nthreads 8 \
	--stop-on-first-crash \
	--fs-license-file /SGLR/FREESURFER_HOME/license.txt \
	--skip-bids-validation \
	--fs-subjects-dir /SGLR/freesurfer \
	--output-spaces MNI152NLin6Asym:res-2 \
	--force no-bbr \
	--cifti-output 91k \
	--notrack \
	--resource-monitor \
	--fs-no-resume \
	--ignore fieldmaps \
	-v -v \
	--participant-label "${subid}" \
	--session-label "${sesid}"
	
cd outputs_${subid}_${sesid}
mkdir fmriprep/sourcedata
rsync -av /home/gabridele/Documents/BNK_v1-3/fmriprep_bnk_ders0505/${subid}_${sesid} fmriprep/sourcedata/
7z a ../${subid}_${sesid}_fmriprep-25-2-5.zip fmriprep
cd ..

