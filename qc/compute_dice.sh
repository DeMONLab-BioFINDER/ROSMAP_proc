#!/usr/bin/env bash
set -euo pipefail

# should get a list of boldref files with 'find', this will be used in this loop below

# ===============================
# Dice (FSL)
# ===============================

usage() {
    echo "Usage: $0 <fmriprep_jobs_root> <coreg_boldref_file_list.txt> <output.csv> [tmp_dir]" >&2
}

if (( $# < 3 || $# > 4 )); then
    usage
    exit 2
fi

path_fmriprep="$1"
input_list="$2"
dice_results="$3"
tmp_dir="${4:-$(dirname "$dice_results")/tmp_dice}"

mkdir -p "$(dirname "$dice_results")" "$tmp_dir"
printf '%s\n' 'sub_id,ses_id,dice_val' > "$dice_results"

find_first_file() {
    local base_dir="$1"
    local pattern="$2"
    local exclude_pattern="${3:-}"
    if [[ -n "$exclude_pattern" ]]; then
        find "$base_dir" -type f -name "$pattern" ! -name "$exclude_pattern" -print -quit 2>/dev/null || true
    else
        find "$base_dir" -type f -name "$pattern" -print -quit 2>/dev/null || true
    fi
}

compute_dice() {
    local sub_id="$1"
    local ses_id="$2"
    local anat_mask="$3"
    local mask_func="$4"
    local intersection="${tmp_dir}/${sub_id}_${ses_id}_mask_intersection.nii.gz"
    local anat func intersection_n dice_val

    anat=$(fslstats "$anat_mask" -V | awk '{print $1}')
    func=$(fslstats "$mask_func" -V | awk '{print $1}')
    fslmaths "$anat_mask" -mul "$mask_func" "$intersection"
    intersection_n=$(fslstats "$intersection" -V | awk '{print $1}')

    dice_val=$(python3 - "$intersection_n" "$anat" "$func" <<'PY'
import sys
intersection, anat, func = map(float, sys.argv[1:])
denominator = anat + func
if denominator == 0:
    raise SystemExit("Cannot compute Dice: both masks have zero volume")
print(f"{2 * intersection / denominator:.3f}")
PY
)
    printf '%s,%s,%s\n' "$sub_id" "$ses_id" "$dice_val" >> "$dice_results"
    rm -f "$intersection"
}

while IFS= read -r boldref_file; do
    [[ -z "$boldref_file" ]] && continue
    sub_id=$(grep -oE 'sub-[0-9]+' <<< "$boldref_file" | head -1 || true)
    ses_id=$(grep -oE 'ses-[0-9]+' <<< "$boldref_file" | head -1 || true)
    if [[ -z "$sub_id" || -z "$ses_id" ]]; then
        echo "WARNING: could not parse subject/session from: $boldref_file" >&2
        continue
    fi

    anat_mask=$(find_first_file "$path_fmriprep" "${sub_id}_${ses_id}*space-MNI*desc-brain_mask.nii.gz" "*task-rest*")
    mask_func=$(find_first_file "$path_fmriprep" "${sub_id}_${ses_id}_task-rest*space-MNI*desc-brain_mask.nii.gz")

    if [[ -z "$anat_mask" || -z "$mask_func" ]]; then
        echo "WARNING: missing anat or func mask for $sub_id $ses_id" >&2
        continue
    fi

    echo "Computing Dice for $sub_id $ses_id"
    compute_dice "$sub_id" "$ses_id" "$anat_mask" "$mask_func"
done < "$input_list"
