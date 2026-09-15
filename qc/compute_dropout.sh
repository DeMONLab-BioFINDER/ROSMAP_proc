#!/usr/bin/env bash
set -euo pipefail

# uncomment if running on cluster with modules:
# module load c3d/1.4.4
# module load fsl/6.0
# source ${FSLDIR}/etc/fslconf/fsl.sh

usage() {
    echo "Usage: $0 <fmriprep_jobs_root> <id_list.csv> <output.csv> [work_dir]" >&2
}

if (( $# < 3 || $# > 4 )); then
    usage
    exit 2
fi

pathroot="$1"
list_sid="$2"
output_file="$3"
wdir="${4:-$(dirname "$output_file")/work_dropout}"
log_file="${output_file%.*}.errors.log"

mkdir -p "$(dirname "$output_file")" "$wdir"
printf '%s\n' 'sid,session,volume_gm,nvox_gm,intensity_gm,volume_dropout,nvox_dropout,intensity_dropout' > "$output_file"
: > "$log_file"

find_first_file() {
    local base_dir="$1"
    local pattern="$2"
    find "$base_dir" -type f -name "$pattern" -print -quit 2>/dev/null || true
}

while IFS=',' read -r sid session _; do
    session="${session%$'\r'}"
    [[ "$sid" == "sub_id" || -z "$sid" ]] && continue

    echo "Processing $sid $session"

    matches=("${pathroot}/${sid}_${session}_fmriprep-"*)

    if (( ${#matches[@]} != 1 )) || [[ ! -d "${matches[0]}" ]]; then
        echo "Expected exactly one fMRIPrep folder for $sid $session"
        continue
    fi

    job_dir="${matches[0]}"
    fmriprep_dir="${job_dir}/fmriprep/${sid}/${session}"
    [[ -d "$fmriprep_dir" ]] || fmriprep_dir="${job_dir}/${sid}/${session}"

    if [[ ! -d "$fmriprep_dir" ]]; then
        echo "$(date) - WARNING: fMRIPrep directory not found for $sid $session" | tee -a "$log_file"
        printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$sid" "$session" "NA" "NA" "NA" "NA" "NA" "NA" >> "$output_file"
        continue
    fi

    mask_func=$(find_first_file "${fmriprep_dir}/func" "*space-MNI152NLin6Asym_res-2_desc-brain_mask.nii.gz")
    mask_anat=$(find_first_file "${fmriprep_dir}/anat" "*space-MNI152NLin6Asym_res-2_desc-brain_mask.nii.gz")
    boldref=$(find_first_file "${fmriprep_dir}/func" "*space-MNI152NLin6Asym_res-2_boldref.nii.gz")
    gm_seg=$(find_first_file "${fmriprep_dir}/anat" "*space-MNI152NLin6Asym_res-2_label-GM_probseg.nii.gz")

    missing=0
    for name in mask_func mask_anat boldref gm_seg; do
        if [[ -z "${!name:-}" ]]; then
            echo "$(date) - ERROR: required file '$name' missing for $sid $session" | tee -a "$log_file"
            missing=1
        fi
    done
    if (( missing )); then
        printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$sid" "$session" "NA" "NA" "NA" "NA" "NA" "NA" >> "$output_file"
        continue
    fi

    subject_wdir="${wdir}/${sid}_${session}"
    mkdir -p "${subject_wdir}/func" "${subject_wdir}/anat"

    boldref_masked="${subject_wdir}/func/boldref_masked.nii.gz"
    mask_gm_thr="${subject_wdir}/anat/gm_thr03.nii.gz"
    new_mask_func="${subject_wdir}/func/boldref_p10_mask.nii.gz"
    mask_dropout="${subject_wdir}/func/dropout_mask.nii.gz"
    mask_gm_thr_clean="${subject_wdir}/anat/gm_without_dropout.nii.gz"
    mask_merged="${subject_wdir}/func/anat_func_union.nii.gz"

    echo "Creating GM binary mask (thr=0.3) at: $mask_gm_thr"
    fslmaths "$gm_seg" -thr 0.3 -bin "$mask_gm_thr"
    # merge anat+func masks (c3d add, replace) — use both masks
    c3d "$mask_anat" "$mask_func" -add -replace 2 1 -o "$mask_merged"
    # mask the boldref with the merged mask
    fslmaths "$boldref" -mul "$mask_merged" "$boldref_masked"

    # compute threshold from masked boldref and create new mask
    thresh=$(fslstats "$boldref_masked" -l 0.001 -P 10 2>/dev/null | awk '{print $1}')
    if [[ -z "$thresh" ]]; then
        echo "$(date) - ERROR: could not compute P10 threshold for $sid $session" | tee -a "$log_file"
        printf '%s,%s,%s\n' "$sid" "$session" "threshold_failed" >> "$output_file"
        continue
    fi
    fslmaths "$boldref_masked" -thr "$thresh" -bin "$new_mask_func"

    # compute dropout: GM mask minus new func mask (inverting new_mask_func before add by -scale -1)
    c3d "$mask_gm_thr" "$new_mask_func" -scale -1 -add -o "$mask_dropout"
    # convert >1 values -> 0 and 1 stays 1
    c3d "$mask_dropout" -replace 1 1 0 0 -1 0 -o "$mask_dropout"

    vol_dropout=$(c3d "$mask_dropout" -dup -lstat | awk 'NR==3 {print $7}')
    nvox_dropout=$(c3d "$mask_dropout" -dup -lstat | awk 'NR==3 {print $6}')
    vol_gm=$(c3d "$mask_gm_thr" -dup -lstat | awk 'NR==3 {print $7}')
    nvox_gm=$(c3d "$mask_gm_thr" -dup -lstat | awk 'NR==3 {print $6}')

    fslmaths "$mask_gm_thr" -sub "$mask_dropout" "$mask_gm_thr_clean"
    intensity_gm=$(fslstats "$boldref" -k "$mask_gm_thr_clean" -M)
    intensity_dropout=$(fslstats "$boldref" -k "$mask_dropout" -M)

    echo "$sid $session | GM: $vol_gm $intensity_gm | dropouts: $vol_dropout $intensity_dropout"

    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$sid" "$session" "$vol_gm" "$nvox_gm" "$intensity_gm" \
        "$vol_dropout" "$nvox_dropout" "$intensity_dropout" >> "$output_file"

    # cleanup temp files (don't fail if missing)
    rm -f "$mask_gm_thr_clean" "$mask_merged" "$boldref_masked"
    
done < "$list_sid"
