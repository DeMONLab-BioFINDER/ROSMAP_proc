#!/bin/bash

SRC_DIR="."
DEST_DIR="../../quarantine_ROSMAP/"
PATTERNS="_ADC|mpragerms|_T2starw"

find "$SRC_DIR" -type l -name "*.nii.gz" | grep -E "$PATTERNS" | while read -r nii_file; do

    json_file="${nii_file%.nii.gz}.json"

    if [[ ! -f "$json_file" ]]; then
        echo "No JSON found for: $nii_file. Quarantining..."
        rsync -avR "$nii_file" "$DEST_DIR"
        datalad remove "$nii_file"
    fi
done
