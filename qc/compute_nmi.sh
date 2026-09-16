#!/usr/bin/env bash
set -euo pipefail

# https://github.com/ANTsX/ANTs/discussions/1706

usage() {
    echo "Usage: $0 <fmriprep_jobs_root> <id_list.csv> <output.tsv> <mni_t1.nii.gz> <mni_mask.nii.gz> [work_dir]" >&2
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

mkdir -p "$(dirname "$output_file")" "$wdir"

: > "$log_file"

printf 'sid\tsession\tmattes_t1_bold\tmattes_wt1_mni\tentropy_t1\tentropy_bold\tentropy_wt1\tentropy_mni\n' \
    > "$output_file"


# ============================================================
# SETTINGS / LOGGING
# ============================================================

mattes_bins=64

nmi_dir="${wdir}/nmi"
mkdir -p "$nmi_dir"


log_message() {
    local level="$1"
    shift

    printf '%s - %s: %s\n' \
        "$(date '+%F %T')" \
        "$level" \
        "$*" |
        tee -a "$log_file" >&2
}


log_step() {
    log_message "STEP" "$@"
}


log_info() {
    log_message "INFO" "$@"
}


log_ok() {
    log_message "OK" "$@"
}


log_error() {
    log_message "ERROR" "$@"
}


log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        log_message "DEBUG" "$@"
    fi
}


find_first_file() {
    local base_dir="$1"
    local include_pattern="$2"
    local exclude_pattern="${3:-}"

    if [[ -n "$exclude_pattern" ]]; then
        find "$base_dir" \
            -type f \
            -name "$include_pattern" \
            ! -name "$exclude_pattern" \
            -print -quit 2>/dev/null || true
    else
        find "$base_dir" \
            -type f \
            -name "$include_pattern" \
            -print -quit 2>/dev/null || true
    fi
}


# ============================================================
# TEMPLATE ENTROPY
# ============================================================

entropy_mni=$(
    ImageIntensityStatistics \
        3 "$mni" "$mni_mask" |
        awk 'NR == 2 {print $6}'
)


# ============================================================
# METRIC 3: MATTES / ENTROPY
# ============================================================

transform_bold_t1space() {
    local id_key="$1"
    local t1="$2"
    local matrix="$3"
    local refbold_file="$4"
    local existing_t1w_boldref="${5:-}"

    local bold_t1space

    # Prefer an already available BOLD reference in T1w space.
    if [[ -n "$existing_t1w_boldref" && -f "$existing_t1w_boldref" ]]; then
        log_step "Registration: using existing BOLD reference in T1w space"
        log_debug "Existing T1w-space BOLD reference: $existing_t1w_boldref"

        printf '%s\n' "$existing_t1w_boldref"
        return 0
    fi

    # The provided reference may itself already be in T1w space.
    if [[ -f "$refbold_file" && "$(basename "$refbold_file")" == *_space-T1w_* ]]; then
        log_step "Registration: BOLD reference is already in T1w space"
        log_debug "T1w-space BOLD reference: $refbold_file"

        printf '%s\n' "$refbold_file"
        return 0
    fi

    bold_t1space="${id_tmp_dir}/${id_key}_space-T1w_desc-coreg_boldref.nii.gz"

    # Reuse a previously generated transform output.
    if [[ -f "$bold_t1space" ]]; then
        log_step "Registration: reusing transformed BOLD reference in T1w space"
        log_debug "Transformed BOLD reference: $bold_t1space"

        printf '%s\n' "$bold_t1space"
        return 0
    fi

    log_step "Registration: transforming BOLD reference into T1w space"
    log_debug "Transform input BOLD: $refbold_file"
    log_debug "Transform reference T1: $t1"
    log_debug "Transform matrix: $matrix"

    antsApplyTransforms \
        -d 3 \
        -i "$refbold_file" \
        -r "$t1" \
        -o "$bold_t1space" \
        -t "$matrix" \
        --interpolation LanczosWindowedSinc \
        >&2

    log_ok "BOLD-to-T1 transform complete"
    log_debug "Transformed BOLD reference: $bold_t1space"

    printf '%s\n' "$bold_t1space"
}


extract_nmi_metric() {
    local id_key="$1"
    local t1="$2"
    local t1_mask="$3"
    local refbold_t1space="$4"
    local wt1="$5"
    local mni_template="$6"
    local entropy_mni="$7"
    local mni_mask="$8"
    local space="${9:-}"
    local task="${10:-}"
    local acq="${11:-}"

    local metric_file
    local t1_mask_boldres
    local t1_boldres

    local mattes_t1_bold
    local mattes_wt1_mni

    local entropy_t1
    local entropy_bold
    local entropy_wt1

    metric_file="$nmi_dir/${id_key}_nmi.csv"
    t1_mask_boldres="${id_tmp_dir}/${id_key}_space-bold_desc-brain_T1wmask.nii.gz"
    t1_boldres="${id_tmp_dir}/${id_key}_space-bold_T1w.nii.gz"

    log_step "NMI: validating inputs and computing entropy terms"
    log_debug "NMI T1: $t1"
    log_debug "NMI T1 mask: $t1_mask"
    log_debug "NMI BOLD reference in T1 space: $refbold_t1space"
    log_debug "NMI warped T1: $wt1"
    log_debug "NMI template T1: $mni_template"
    log_debug "NMI template mask: $mni_mask"

    for required_file in \
        "$t1" \
        "$t1_mask" \
        "$refbold_t1space" \
        "$wt1" \
        "$mni_template" \
        "$mni_mask"
    do
        if [[ ! -f "$required_file" ]]; then
            log_error "Missing NMI input file: $required_file"
            return 1
        fi
    done

    log_info "NMI: resampling T1 mask and T1 image into the BOLD-reference grid"

    antsApplyTransforms \
        -d 3 \
        -i "$t1_mask" \
        -r "$refbold_t1space" \
        -o "$t1_mask_boldres" \
        -n NearestNeighbor \
        >&2

    antsApplyTransforms \
        -d 3 \
        -i "$t1" \
        -r "$refbold_t1space" \
        -o "$t1_boldres" \
        -n BSpline \
        >&2

    log_info "NMI: measuring T1/BOLD and warped-T1/template similarity"

    mattes_t1_bold=$(
        MeasureImageSimilarity \
            -d 3 \
            -m "Mattes[${t1_boldres},${refbold_t1space},1,${mattes_bins}]" \
            -x "$t1_mask_boldres"
    )

    log_info "NMI: calculating image entropy values"

    entropy_t1=$(
        ImageIntensityStatistics \
            3 "$t1_boldres" "$t1_mask_boldres" |
            awk 'NR == 2 {print $6}'
    )

    entropy_bold=$(
        ImageIntensityStatistics \
            3 "$refbold_t1space" "$t1_mask_boldres" |
            awk 'NR == 2 {print $6}'
    )

    # do this only if space contains mni
    if [[ "$space" == *"MNI"* ]]; then

        entropy_wt1=$(
            ImageIntensityStatistics \
                3 "$wt1" "$mni_mask" |
                awk 'NR == 2 {print $6}'
        )

        mattes_wt1_mni=$(
            MeasureImageSimilarity \
                -d 3 \
                -m "Mattes[${wt1},${mni_template},1,${mattes_bins}]" \
                -x "$mni_mask"
        )

    else

        entropy_wt1="NA"
        mattes_wt1_mni="NA"

    fi


    if [[ -z "$mattes_t1_bold" || -z "$mattes_wt1_mni" ]]; then
        log_error "Empty Mattes result"
        return 1
    fi

    if [[ -z "$entropy_t1" || -z "$entropy_bold" || -z "$entropy_wt1" || -z "$entropy_mni" ]]; then
        log_error "Empty entropy result"
        return 1
    fi

    {
        echo "id_key,space,task,acq,mattes_t1_bold,mattes_wt1_mni,entropy_t1,entropy_bold,entropy_wt1,entropy_mni"
        echo "$id_key,$space,$task,$acq,$mattes_t1_bold,$mattes_wt1_mni,$entropy_t1,$entropy_bold,$entropy_wt1,$entropy_mni"
    } > "$metric_file"

    log_info "NMI terms: T1/BOLD=$mattes_t1_bold, warped-T1/template=$mattes_wt1_mni"
    log_ok "NMI inputs complete"
    log_debug "NMI CSV: $metric_file"

    rm -f \
        "$t1_mask_boldres" \
        "$t1_boldres"
}


# ============================================================
# SUBJECT LOOP
# ============================================================

while IFS=',' read -r sid session _; do

    session="${session%$'\r'}"

    [[ "$sid" == "sub_id" || -z "$sid" ]] && continue

    echo "Processing $sid $session"


    # --------------------------------------------------------
    # Find fMRIPrep job directory
    # --------------------------------------------------------

    matches=("${path_fmriprep}/${sid}_${session}_fmriprep-"*)

    if (( ${#matches[@]} != 1 )) || [[ ! -d "${matches[0]}" ]]; then
        echo "Expected exactly one fMRIPrep folder for $sid $session" |
            tee -a "$log_file" >&2
        continue
    fi

    job_dir="${matches[0]}"

    fmriprep_dir="${job_dir}/fmriprep/${sid}/${session}"

    [[ -d "$fmriprep_dir" ]] ||
        fmriprep_dir="${job_dir}/${sid}/${session}"

    if [[ ! -d "$fmriprep_dir" ]]; then
        echo "$(date) - WARNING: fMRIPrep directory not found for $sid $session" |
            tee -a "$log_file" >&2
        continue
    fi


    # --------------------------------------------------------
    # Locate required fMRIPrep derivatives
    # --------------------------------------------------------

    # Native T1w-space anatomical image
    t1=$(
        find_first_file \
            "${fmriprep_dir}/anat" \
            "*_desc-preproc_T1w.nii.gz" \
            "*_space-*"
    )

    # Native T1w-space brain mask
    t1_mask=$(
        find_first_file \
            "${fmriprep_dir}/anat" \
            "*_desc-brain_mask.nii.gz" \
            "*_space-*"
    )

    # BOLD reference used for BOLD -> T1w coregistration
    boldref=$(
        find_first_file \
            "${fmriprep_dir}/func" \
            "*desc-coreg_boldref.nii.gz"
    )

    # T1w transformed to MNI
    wt1=$(
        find_first_file \
            "${fmriprep_dir}/anat" \
            "*space-MNI152NLin6Asym_res-2_desc-preproc_T1w.nii.gz"
    )


    missing=0

    for name in t1 t1_mask boldref wt1; do

        if [[ -z "${!name:-}" ]]; then
            log_error "Required file '$name' missing for $sid $session"
            missing=1
        fi

    done

    (( missing )) && continue


    # --------------------------------------------------------
    # Match the BOLD -> T1w transform to this BOLD reference
    # --------------------------------------------------------

    boldref_name=$(basename "$boldref")

    func_prefix_name="${boldref_name%_desc-coreg_boldref.nii.gz}"

    matrix="${fmriprep_dir}/func/${func_prefix_name}_from-boldref_to-T1w_mode-image_desc-coreg_xfm.txt"


    # If fMRIPrep already produced a BOLD reference in T1w space,
    # transform_bold_t1space() will prefer it.
    existing_t1w_boldref=$(
        find_first_file \
            "${fmriprep_dir}/func" \
            "${func_prefix_name}_space-T1w*_boldref.nii.gz"
    )


    if [[ ! -f "$matrix" ]]; then
        log_error "BOLD-to-T1w transform missing for $sid $session: $matrix"
        continue
    fi


    # --------------------------------------------------------
    # Extract BIDS entities for metric metadata
    # --------------------------------------------------------

    space=$(
        basename "$wt1" |
            sed -n 's/.*_space-\([^_]*\).*/\1/p'
    )

    task=$(
        printf '%s\n' "$boldref_name" |
            sed -n 's/.*_task-\([^_]*\).*/\1/p'
    )

    acq=$(
        printf '%s\n' "$boldref_name" |
            sed -n 's/.*_acq-\([^_]*\).*/\1/p'
    )


    # --------------------------------------------------------
    # Per-subject working directory
    # --------------------------------------------------------

    id_key="${sid}_${session}"

    id_tmp_dir="${wdir}/${id_key}"

    mkdir -p "$id_tmp_dir"


    # --------------------------------------------------------
    # Transform BOLD reference into T1w space
    # --------------------------------------------------------

    if ! refbold_t1space=$(
        transform_bold_t1space \
            "$id_key" \
            "$t1" \
            "$matrix" \
            "$boldref" \
            "$existing_t1w_boldref"
    ); then

        log_error "Could not prepare BOLD reference in T1w space for $sid $session"
        continue

    fi


    # --------------------------------------------------------
    # Compute Mattes / entropy metrics
    # --------------------------------------------------------

    if ! extract_nmi_metric \
        "$id_key" \
        "$t1" \
        "$t1_mask" \
        "$refbold_t1space" \
        "$wt1" \
        "$mni" \
        "$entropy_mni" \
        "$mni_mask" \
        "$space" \
        "$task" \
        "$acq"
    then

        log_error "NMI metric extraction failed for $sid $session"
        continue

    fi


    # --------------------------------------------------------
    # Add metric result to master TSV
    # --------------------------------------------------------

    metric_file="${nmi_dir}/${id_key}_nmi.csv"

    IFS=',' read -r \
        _metric_id \
        _metric_space \
        _metric_task \
        _metric_acq \
        mattes_t1_bold \
        mattes_wt1_mni \
        entropy_t1 \
        entropy_bold \
        entropy_wt1 \
        metric_entropy_mni \
        < <(tail -n 1 "$metric_file")


    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$sid" \
        "$session" \
        "$mattes_t1_bold" \
        "$mattes_wt1_mni" \
        "$entropy_t1" \
        "$entropy_bold" \
        "$entropy_wt1" \
        "$metric_entropy_mni" \
        >> "$output_file"

done < "$list_sid"