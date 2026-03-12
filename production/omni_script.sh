#!/bin/bash
set -e

sid=$1
#ses=$2
data_dir="/home/${USER}/backup/ROSMAP_proc/raw"
omni_sif="/home/${USER}/backup/backup_files/omni_2023.2.1.sif"

# script run after copying the raw data into working directory

# ------ Run Omni pipeline

unset PYTHONPATH
export APPTAINERENV_FSLOUTPUTTYPE=NIFTI_GZ

echo "Processing participant: $sid"

singularity exec --cleanenv \
    --env FSLOUTPUTTYPE=NIFTI_GZ \
    -B "/home/${USER}:/home" \
    -B "/home/${USER}/Desktop/omni_proc/omni_tmp/raw:/data" \
    "$omni_sif" \
    omni_pipeline /data/ /home/Desktop/omni_proc/omni_tmp/derivatives \
    --resample_resolution 2 \
    --participant_label "$sid" \
    --skip_validation \
    --number_of_threads 16 \
    --log_file "/home/${USER}/Desktop/omni_proc/omni_logs/omni_${sid}.log"

echo "Omni processing is completed for participant: $sid"

rm -rf "/home/${USER}/Desktop/omni_proc/omni_tmp/raw/sub-${sid}"
echo "Temporary $sid folder for preprocessing is deleted"

# ---------------------------------------------------

module load GCC/12.3.0 OpenMPI/4.1.5 R/4.4.1 AFNI/24.0.02

omni_dir="/home/${USER}/Desktop/omni_proc/omni_tmp"
omni_der="/home/${USER}/Desktop/omni_proc/derivatives"

for ses in $(find "${omni_dir}/derivatives/sub-${sid}" -name "ses-*" -type d | sed 's/.*ses-//'); do
    sub_dir=$(find "${omni_dir}/derivatives/sub-${sid}/ses-${ses}" -name "*task-rest*_bold" -type d | head -1)
    [ ! -d "$sub_dir" ] && continue

# ------ Apply unwarping + undo motion correction
    
    echo "Apply unwarping + undo motion correction for $sid $ses"
    
    warp_file="${sub_dir}/epi_proc_1_distortion_correction/final_epi_to_synth_warp.nii.gz"
    deobliqued_epi=(${sub_dir}/func_proc_0_deoblique_func/sub-${sid}_ses-${ses}_task-rest*_bold_deobliqued.nii.gz)
    epi_name=$(basename "$deobliqued_epi" | cut -d '.' -f 1)
    echo "epi name: $epi_name"
    epi_dir=$(dirname "$deobliqued_epi")
    
    mkdir -p "${sub_dir}/final_manual_warp_unmoco"
    
    transform_mat="${sub_dir}/func_proc_1_create_reference_and_moco/rigid_body.params"
    mat_inv="${sub_dir}/final_manual_warp_unmoco/inverted_rigid_body.params"

    Rscript -e "
    invert_affine <- function(row){
      mat4x4 <- matrix(c(row[1:4], row[5:8], row[9:12], 0, 0, 0, 1), nrow=4, byrow=TRUE)
      inv_mat <- solve(mat4x4)
      return(as.vector(t(inv_mat[1:3, ])))
    }
    transform_mat <- read.table('$transform_mat', skip=1)
    rigid_body_inv <- t(apply(transform_mat, 1, invert_affine))
    write.table(rigid_body_inv, file='$mat_inv', row.names=FALSE, col.names=FALSE, quote=FALSE)
    "
    
    rsync -aP $deobliqued_epi "${sub_dir}/final_manual_warp_unmoco/${epi_name}.nii.gz"
        
    3dNwarpApply -warp "$warp_file" -source "${sub_dir}/func_proc_1_create_reference_and_moco/${epi_name}_moco.nii.gz" -prefix "${sub_dir}/final_manual_warp_unmoco/${epi_name}_moco_unwarp.nii.gz"
    
    
    3dAllineate -prefix "${sub_dir}/final_manual_warp_unmoco/${epi_name}_moco_unwarp_unmoco.nii.gz" -base "$deobliqued_epi" \
        -source "${sub_dir}/final_manual_warp_unmoco/${epi_name}_moco_unwarp.nii.gz" -1Dmatrix_apply "$mat_inv"
     
    echo "unwarping + moco $sid $ses is done"
       
# # ------ Remove unnecessary files   

	echo "Removing unnecessary $sid $ses omni files and keep important in omni derivative dir"
	 
	epi_unwarp=(${sub_dir}/final_manual_warp_unmoco/sub-${sid}_ses-${ses}_task-rest*_bold_deobliqued_moco_unwarp.nii.gz)
	epi_final=(${sub_dir}/final_manual_warp_unmoco/sub-${sid}_ses-${ses}_task-rest*_bold_deobliqued_moco_unwarp_unmoco.nii.gz)
	warp1="${sub_dir}/epi_proc_1_distortion_correction/final_epi_to_synth_warp.nii.gz"
	warp2="${sub_dir}/epi_proc_1_distortion_correction/final_synth_to_epi_warp.nii.gz"

	mkdir -p "${omni_der}/sub-${sid}/ses-${ses}"
	outpath="${omni_der}/sub-${sid}/ses-${ses}"
	
	rsync -aP $mat_inv "${outpath}/sub-${sid}_ses-${ses}_inverted_rigid_body.params"
	rsync -aP $deobliqued_epi "${outpath}/sub-${sid}_ses-${ses}_task-rest_bold_deobliqued.nii.gz"
	rsync -aP $epi_unwarp "${outpath}/sub-${sid}_ses-${ses}_task-rest_bold_deobliqued_moco_unwarp.nii.gz"
	rsync -aP $epi_final "${outpath}/sub-${sid}_ses-${ses}_task-rest_bold_deobliqued_moco_unwarp_unmoco.nii.gz"
	rsync -aP $warp1 "${outpath}/sub-${sid}_ses-${ses}_final_epi_to_synth_warp.nii.gz"
	rsync -aP $warp2 "${outpath}/sub-${sid}_ses-${ses}_final_synth_to_epi_warp.nii.gz"	   
 
 	[ -n "$ses" ] && rm -rf "${omni_dir}/sub-${sid}/ses-${ses}"
 	
	echo "Omni cleaning $sid $ses is done"
done
