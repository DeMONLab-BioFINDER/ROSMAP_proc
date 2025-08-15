#!/bin/bash
#SBATCH -t 00:20:00
#SBATCH -J dcm2niixTest
#SBATCH --mail-user=gabriele.de_leonardis@med.lu.se
#SBATCH --mail-type=END

source config.sh
echo 'hello world'
# this function only bids validated, skips conversion to nifti
function bidsify { 

    for ((i=1; i<=n_sub; i++)); do

        subject_dir="${input_dir}/sub-0${i}"

        session_count=$(find "$subject_dir" -mindepth 1 -maxdepth 1 -type d -name 'session*' | \
                        sed -E 's|.*/session([0-9]+)$|\1|' | \
                        sort -n | \
                        tail -1)
        
        if [[ -z "$session_count" ]]; then
            # No session folders found, run Singularity without -s option
            echo "No sessions found for subject sub-0${i}. Running without session option."

            singularity run -e -containall -B "$input_dir":/"$input_bound":ro -B "$output_dir":/"$output_bound" FileTransfer/dcm2bids.sif \
                --auto_extract_entities \
                --bids_validate \
                --skip_dcm2niix \
                -d /"$output_bound" \
                -c /"$input_bound"/config.json \
                -p 0${i}
        else
            # Sessions found, process each session with -s option
            echo "Processing subject sub-0${i} with $session_count sessions"

            for ((ii=1; ii<=session_count; ii++)); do
                singularity run -e -containall -B "$input_dir":/"$input_bound":ro -B "$output_dir":/"$output_bound" FileTransfer/dcm2bids.sif \
                    --auto_extract_entities \
                    --bids_validate \
                    --skip_dcm2niix \
                    -d /"$output_bound" \
                    -c /"$input_bound"/config.json \
                    -s ${ii} \
                    -p 0${i}
            done
        fi
    done
}

bidsify
