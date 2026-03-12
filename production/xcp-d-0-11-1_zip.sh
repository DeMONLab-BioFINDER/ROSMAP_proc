#!/bin/bash
set -e -u -x

subid="$1"
sesid="$2"
FMRIPREP_ZIP="$3"


wd=${PWD}
cd inputs/data/fmriprep
7z x `basename ${FMRIPREP_ZIP}`
cd $wd

mkdir -p ${PWD}/.git/tmp/wkdir
singularity run --cleanenv \
	-B ${PWD} \
	-B /home/gabridele/backup/templateflow:/SGLR/TEMPLATEFLOW_HOME \
	-B /home/gabridele/license.txt:/SGLR/FREESURFER_HOME/license.txt \
	--env TEMPLATEFLOW_HOME=/SGLR/TEMPLATEFLOW_HOME \
	containers/.datalad/environments/xcp-d-0-11-1/image \
	inputs/data/fmriprep/fmriprep \
	outputs \
	participant \
	-w ${PWD}/.git/tmp/wkdir \
	--mode none \
	--nthreads 24 \
	--omp-nthreads 8 \
	--input-type fmriprep \
	--file-format nifti \
	--smoothing 0 \
	--motion-filter-type none \
	--nuisance-regressors 36P \
	--min_coverage 0.5 \
	--abcc-qc n \
	--output-type interpolated \
	-f 0 \
	--despike y \
	--lower-bpf 0.01 \
	--upper-bpf 0.08 \
	--linc-qc y \
	--combine-runs n \
	--stop-on-first-crash \
	--warp-surfaces-native2std n \
	--fs-license-file /SGLR/FREESURFER_HOME/license.txt \
	--resource-monitor \
	-vvv \
	--notrack \
	--participant-label "${subid}"

cd outputs

rsync -a --progress ./* xcp_d_nifti/

cd ..

singularity run --cleanenv \
	-B ${PWD} \
	-B /home/gabridele/backup/templateflow:/SGLR/TEMPLATEFLOW_HOME \
	-B /home/gabridele/license.txt:/SGLR/FREESURFER_HOME/license.txt \
	--env TEMPLATEFLOW_HOME=/SGLR/TEMPLATEFLOW_HOME \
	containers/.datalad/environments/xcp-d-0-11-1/image \
	inputs/data/fmriprep/fmriprep \
	outputs \
	participant \
	-w ${PWD}/.git/tmp/wkdir \
	--mode none \
	--nthreads 16 \
	--omp-nthreads 4 \
	--input-type fmriprep \
	--file-format cifti \
	--smoothing 0 \
	--motion-filter-type none \
	--nuisance-regressors 36P \
	--min_coverage 0.5 \
	--abcc-qc n \
	--output-type interpolated \
	-f 0 \
	--despike y \
	--lower-bpf 0.01 \
	--upper-bpf 0.08 \
	--linc-qc y \
	--combine-runs n \
	--stop-on-first-crash \
	--warp-surfaces-native2std n \
	--fs-license-file /SGLR/FREESURFER_HOME/license.txt \
	-vvv \
	--notrack \
	--participant-label "${subid}"

cd outputs

rsync -a --progress --exclude='xcp_d_nifti' ./* xcp_d_cifti/

7z a ../${subid}_${sesid}_xcp_d-0-11-1.zip xcp_d_nifti xcp_d_cifti
cd ..
rm -rf outputs .git/tmp/wkdir

