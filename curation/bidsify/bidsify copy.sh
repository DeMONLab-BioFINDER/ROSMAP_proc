#!/bin/bash

set -e -u -x
module load GCC/12.2.0
module load Anaconda3/2022.05
module load parallel/20230722
source /sw/easybuild_milan/software/Anaconda3/2022.05/bin/activate ~/.conda/envs/babs_28_11

source config.sh || {
    echo "Error: Failed to source config file"
    exit 1
}

echo "Working on dataset: $dataset"

# Logging function
function log_message {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

subid="$1"
strippedid=$(echo "$subid" | sed 's/^sub-//')
sesid="$2"

# if sesid = none
if [[ -z "$sesid" ]]; then

    echo "Processing subject $subid with no sessions"    
    singularity run -e -containall \
        -B $input_dir:/$input_bound \
        -B $root_dir:/$output_bound \
        bidsify-container/.datalad/environments/dcm2bids-latest/image \
        --auto_extract_entities --bids_validate -o /$output_bound \
        -d /"$input_bound"/$subid \
        -c /"$input_bound"/config.json \
        -p $strippedid || echo "Error processing $subid"


else

    echo "Processing subject $subid, $sesid"

    singularity run -e -containall \
        -B $input_dir:/$input_bound \
        -B $root_dir:/$output_bound \
        bidsify-container/.datalad/environments/dcm2bids-latest/image \
        --auto_extract_entities --bids_validate -o /$output_bound \
        -d /"$input_bound"/$subid/$sesid \
        -c /"$input_bound"/config.json \
        -s $sesid \
        -p $strippedid || echo "Error processing $subid $sesid"

fi


# datalad run \
# 	-i code/fmriprep-24-1-1_zip.sh \
# 	-i inputs/data/BIDS/${subid}/${sesid} \
# 	-i 'inputs/data/BIDS/*json' \
# 	-i containers/.datalad/environments/fmriprep-24-1-1/image \
# 	--expand inputs \
# 	--explicit \
# 	-o ${subid}_${sesid}_fmriprep-24-1-1.zip \
# 	-m "fmriprep-24-1-1 ${subid} ${sesid}" \
# 	"bash ./code/fmriprep-24-1-1_zip.sh ${subid} ${sesid}"

# ##### must do it over
# ## func accepting two args, subid and sesid
# ## should account for possiboility of not having sesid\

# # wrap datalad run in a for loop that itwerates all the subjects found in sourcedata - so find function first

# for subid in $(find sourcedata -mindepth 1 -maxdepth 1 -type d -name 'sub-*' | sed -E 's|.*/sub-([0-9]+)$|\1|' | sort -n); do
#     for sesid in $(find sourcedata/sub-${subid} -mindepth 1 -maxdepth 1 -type d -name 'ses-*' | sed -E 's|.*/ses-([0-9]+)$|\1|' | sort -n); do
#         echo "Processing sub-${subid} ses-${sesid}"
#        datalad run \
# 	        -i code/bidsify.sh \
# 	        -i "$input_dir"/config.json \
# 	        -i "$input_dir"/${subid}/${sesid} \
# 	        -i containers/.datalad/environments/dcm2bids-latest/image \
# 	        --expand inputs \
# 	        --explicit \
# 	        # -o ${subid}_${sesid}_fmriprep-24-1-1.zip \
# 	        -m "dcm2bids ${subid} ${sesid}" \
# 	        "bash ./code/bidsify.sh ${subid} ${sesid}"
#     done
# done