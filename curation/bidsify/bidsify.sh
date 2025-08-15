#!/bin/bash
#SBATCH -t 00:20:00
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH -J dcm2niixTest2

module load GCC/12.2.0
module load Anaconda3/2022.05
source /sw/easybuild_milan/software/Anaconda3/2022.05/bin/activate ~/.conda/envs/babs_28_11
    
source /home/gabridele/backup/config.sh || {
    echo "Error: Failed to source config file"
    exit 1
}

echo "Working on dataset: $dataset"

# first create a scaffold (optional tho) according to bids structure
function bids_scaffold {
 singularity exec \
 -e --containall \
 -B "$input_dir":/"$input_bound":ro \
 -B "$output_dir":/"$output_bound" \
 /home/gabridele/backup/backup_files/dcm2bids_latest.sif dcm2bids_scaffold -o $output_bound/$dataset --force

}

# Logging function
function log_message {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

function bidsify { 
    # Input validation
    [[ ! -d "$input_dir" ]] && { log_message "Error: input_dir not found"; exit 1; }
    [[ ! -d "$output_dir" ]] && { log_message "Error: output_dir not found"; exit 1; }

    for ((i=1; i<=n_sub; i++)); do

        subject_dir="${input_dir}/sub-0${i}"
        session_count=$(find "$subject_dir" -mindepth 1 -maxdepth 1 -type d -name 'session*' | \
                        sed -E 's|.*/session([0-9]+)$|\1|' | \
                        sort -rn | \
                        head -n1 || echo "0")

        SINGULARITY_OPTS="-e -containall -B $input_dir:/$input_bound:ro -B $output_dir:/$output_bound"
        COMMON_ARGS="--auto_extract_entities --bids_validate -o /$output_bound"

        if [[ -z "$session_count" || "$session_count" -eq 0 ]]; then
            log_message "No sessions found for subject sub-0${i}. Running without session option."
            singularity run $SINGULARITY_OPTS /home/gabridele/backup/backup_files/dcm2bids_latest.sif \
                $COMMON_ARGS \
                -d /"$input_bound"/sub-0${i} \
                -c /"$input_bound"/config.json \
                -p 0${i} || log_message "Error processing sub-0${i}"
        else
            log_message "Processing subject sub-0${i} with $session_count sessions"
            for ((ii=1; ii<=session_count; ii++)); do
                session_dir="/$input_bound/sub-0${i}/session${ii}/*/*"
                file_count=$(find "$session_dir" -type f | wc -l)
                
                if [[ "$file_count" -ne "$num_scans" ]]; then
                    log_message "Warning: Expected $num_scans files in $session_dir, but found $file_count. Skipping session."
                    actual_path_dicom=$(eval echo $gen_path_dicom)
                    echo "$actual_path_dicom" >> "$output_dir/$dataset/code/skipped_bidsify_sess.txt"
                    continue
                fi

                singularity run $SINGULARITY_OPTS /home/gabridele/backup/backup_files/dcm2bids_latest.sif \
                    $COMMON_ARGS \
                    -d /"$input_bound"/sub-0${i}/session${ii} \
                    -c /"$input_bound"/config.json \
                    -s ${ii} \
                    -p 0${i}
                log_message "Skipped sessions are logged in $output_dir/$dataset/code/skipped_bidsify_sess.txt"
            done
        fi
    done
}

# create scaffold
bids_scaffold
pwd

# cd to dataset and make it datalad dataset
cd $output_dir/$dataset
if [[ "$(pwd)" == "$output_dir/$dataset" ]]; then
    datalad create -c text2git -f
else
    echo "Error: Not in the correct directory to create dataset"
    exit 1
fi
datalad status
pwd

# save scaffold
datalad save -d . -m 'created bids scaffold'

# paste dataset into sourcedata
cp -r "$input_dir"/* "$output_dir/$dataset/sourcedata"

# save changes
datalad save -d . -m 'copied dataset into sourcedata dir'

cd ~/backup

# bidsify dicoms
bidsify

# save changes
datalad save -m 'bidsified dataset'



