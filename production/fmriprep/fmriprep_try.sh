usesyn=""
anat_dir="/home/gabridele/Desktop/test2/inputs/data/ROSMAP_exemplar/sub-15938020/ses-1/anat"

if ! find "$anat_dir" -type l | grep -q "BNK"; then
  usesyn="--use-syn-sdc"
fi

singularity run --cleanenv \
        --writable-tmpfs \
	-B ${PWD} \
	-B /home/gabridele:/SGLR/home \
	-B /home/gabridele/backup/templateflow:/SGLR/TEMPLATEFLOW_HOME \
	-B /home/gabridele/license.txt:/SGLR/FREESURFER_HOME/license.txt \
	--env TEMPLATEFLOW_HOME=/SGLR/TEMPLATEFLOW_HOME \
	../../backup/fmriprep_v25.1.1.sif \
	inputs/data/ROSMAP_exemplar \
	outputs/fmriprep \
	participant \
	-w ${PWD} \
	--n_cpus 16 \
	--omp-nthreads 4 \
	--stop-on-first-crash \
	--fs-license-file /SGLR/FREESURFER_HOME/license.txt \
	--skip-bids-validation \
	--output-spaces MNI152NLin6Asym:res-2 \
	--force bbr \
	--cifti-output 91k \
	$usesyn \
	--notrack \
	--resource-monitor \
	-v -v \
	--participant-label "sub-15938020"
