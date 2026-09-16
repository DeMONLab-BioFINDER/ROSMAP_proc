#!/bin/bash

set -eux

sub_ses=$1
subid=$(echo $sub_ses | cut -d'_' -f1)
sesid=$(echo $sub_ses | cut -d'_' -f2)

# this is for BNKs only, no fmap correction neeeded

# copy singularity run here
	
workdir="workdir/${subid}_${sesid}"

singularity run --cleanenv \
	-B ${PWD} \
	-B /scale/gr05/home/gabridele/backup/templateflow:/SGLR/TEMPLATEFLOW_HOME \
	-B /scale/gr05/home/gabridele/license.txt:/SGLR/FREESURFER_HOME/license.txt \
	-B /scale/gr05/home/gabridele/Documents/BNK_v1-3:/SGLR/BNK_v1-3 \
	--env TEMPLATEFLOW_HOME=/SGLR/TEMPLATEFLOW_HOME \
	/scale/gr05/home/gabridele/Documents/BNK_v1-3/xcp_d-0.11.1.sif \
	tot_ders/outputs_${subid}_${sesid}/fmriprep \
	xcpd_outputs_${subid}_${sesid}/xcp_d_nifti \
	participant \
	-w $workdir \
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
	--participant-label "${subid}" \
	--session-id "${sesid}"

echo "finished with nifti"
#cd outputs

#rsync -a --progress ./* xcp_d_nifti/

#cd ..

singularity run --cleanenv \
	-B ${PWD} \
	-B /scale/gr05/home/gabridele/backup/templateflow:/SGLR/TEMPLATEFLOW_HOME \
	-B /scale/gr05/home/gabridele/license.txt:/SGLR/FREESURFER_HOME/license.txt \
	-B /scale/gr05/home/gabridele/Documents/BNK_v1-3:/SGLR/BNK_v1-3 \
	--env TEMPLATEFLOW_HOME=/SGLR/TEMPLATEFLOW_HOME \
	/scale/gr05/home/gabridele/Documents/BNK_v1-3/xcp_d-0.11.1.sif \
	tot_ders/outputs_${subid}_${sesid}/fmriprep \
	xcpd_outputs_${subid}_${sesid}/xcp_d_cifti \
	participant \
	-w $workdir \
	--mode none \
	--nthreads 24 \
	--omp-nthreads 8 \
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
	--participant-label "${subid}" \
	--session-id "${sesid}"

cd xcpd_outputs_${subid}_${sesid}

#rsync -a --progress --exclude='xcp_d_nifti' ./* xcp_d_cifti/

7z a ../${subid}_${sesid}_xcpd-0-11-1.zip xcp_d_nifti xcp_d_cifti
cd ..
rm -rf $workdir
echo "$workdir removed"
echo "SUCCESS"
