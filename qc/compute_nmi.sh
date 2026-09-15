#!/usr/bin/env bash
set -euo pipefail

# https://github.com/ANTsX/ANTs/discussions/1706

usage() {
    echo "Usage: $0 <fmriprep_jobs_root> <id_list.csv> <output.tsv> <mni_t1.nii.gz> <mni_mask.nii.gz> [work_dir]" >&2
    echo "Optional env: FMRIPREP_VERSION (default: 25-1-1)" >&2
}

if (( $# < 5 || $# > 6 )); then
    usage
    exit 2
fi

path_fmriprep="$1"
list_sid="$2"
output_file="$3"
mni="$4"
mni_mask="$5"
wdir="${6:-$(dirname "$output_file")/work_registration_qc}"
log_file="${output_file%.*}.errors.log"
fmriprep_version="${FMRIPREP_VERSION:-25-1-1}"

mkdir -p "$(dirname "$output_file")" "$wdir"
: > "$log_file"
printf 'sid\tsession\tmattes_t1_bold\tmattes_wt1_mni\tmattes_wbold_mni\tentropy_t1\tentropy_bold\tentropy_wt1\tentropy_wbold\tentropy_mni\n' > "$output_file"

find_first_file() {
    local base_dir="$1"
    local include_pattern="$2"
    local exclude_pattern="${3:-}"
    if [[ -n "$exclude_pattern" ]]; then
        find "$base_dir" -type f -name "$include_pattern" ! -name "$exclude_pattern" -print -quit 2>/dev/null || true
    else
        find "$base_dir" -type f -name "$include_pattern" -print -quit 2>/dev/null || true
    fi
}

entropy_mni=$(ImageIntensityStatistics 3 "$mni" "$mni_mask" | awk 'NR==2 {print $6}')

while IFS=',' read -r sid session _; do
    session="${session%$'\r'}"
    [[ "$sid" == "sub_id" || -z "$sid" ]] && continue

    echo "Processing $sid $session"
    job_dir="${path_fmriprep}/${sid}_${session}_fmriprep-${fmriprep_version}"
    fmriprep_dir="${job_dir}/fmriprep/${sid}/${session}"
    [[ -d "$fmriprep_dir" ]] || fmriprep_dir="${job_dir}/${sid}/${session}"

    if [[ ! -d "$fmriprep_dir" ]]; then
        echo "$(date) - WARNING: fMRIPrep directory not found for $sid $session" | tee -a "$log_file"
        continue
    fi

    boldref_mni=$(find_first_file "${fmriprep_dir}/func" "*space-MNI152NLin6Asym_res-2_boldref.nii.gz")
    t1=$(find_first_file "${fmriprep_dir}/anat" "*_desc-preproc_T1w.nii.gz" "*space-MNI152NLin6Asym_res-2*")
    t1_mask=$(find_first_file "${fmriprep_dir}/anat" "*_desc-brain_mask.nii.gz" "*space-MNI152NLin6Asym_res-2*")
    boldref=$(find_first_file "${fmriprep_dir}/func" "*desc-coreg_boldref.nii.gz" "*space-MNI152NLin6Asym_res-2*")
    wt1=$(find_first_file "${fmriprep_dir}/anat" "*space-MNI152NLin6Asym_res-2_desc-preproc_T1w.nii.gz")

    missing=0
    for name in boldref_mni t1 t1_mask boldref wt1; do
        if [[ -z "${!name:-}" ]]; then
            echo "$(date) - ERROR: required file '$name' missing for $sid $session" | tee -a "$log_file"
            missing=1
        fi
    done
    (( missing )) && continue

    t1_mask_bold_space="${wdir}/mask_${sid}_${session}_bold_space.nii.gz"
    t1_resampled="${wdir}/t1_${sid}_${session}_bold_space.nii.gz"

    # need masks to be in the same resolution for calculating entropy + then resample t1 to make it homogeneous
    antsApplyTransforms -d 3 -i "$t1_mask" -r "$boldref" -o "$t1_mask_bold_space" -n NearestNeighbor
    antsApplyTransforms -d 3 -i "$t1" -r "$boldref" -o "$t1_resampled" -n BSpline

    # Mattes similarity metrics
    mattes_t1_bold=$(MeasureImageSimilarity -d 3 -m "Mattes[$t1_resampled,$boldref,1,64]" -x "$t1_mask_bold_space")
    mattes_wt1_mni=$(MeasureImageSimilarity -d 3 -m "Mattes[$wt1,$mni,1,64]" -x "$mni_mask")
    mattes_wbold_mni=$(MeasureImageSimilarity -d 3 -m "Mattes[$boldref_mni,$mni,1,64]" -x "$mni_mask")

    # Entropies
    entropy_t1=$(ImageIntensityStatistics 3 "$t1_resampled" "$t1_mask_bold_space" | awk 'NR==2 {print $6}')
    entropy_bold=$(ImageIntensityStatistics 3 "$boldref" "$t1_mask_bold_space" | awk 'NR==2 {print $6}')
    entropy_wt1=$(ImageIntensityStatistics 3 "$wt1" "$mni_mask" | awk 'NR==2 {print $6}')
    entropy_wbold=$(ImageIntensityStatistics 3 "$boldref_mni" "$mni_mask" | awk 'NR==2 {print $6}')

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$sid" "$session" "$mattes_t1_bold" "$mattes_wt1_mni" "$mattes_wbold_mni" \
        "$entropy_t1" "$entropy_bold" "$entropy_wt1" "$entropy_wbold" "$entropy_mni" >> "$output_file"
done < "$list_sid"
