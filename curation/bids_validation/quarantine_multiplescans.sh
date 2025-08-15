#!/bin/bash

SRC_DIR="."  # You can change this to your base directory
DEST_DIR="../../quarantine_ROSMAP/"  # Set your desired rsync destination
PATTERNS="echoesa|echoesb|echoesc|Opena|e2a|e3a|e4a|e5a|e6a|e7a|e8a|BNK20090211_phase1"

find "$SRC_DIR" -type l -name "*.nii.gz" | grep -E "$PATTERNS" | while read -r nii_file; do

    json_file="${nii_file%.nii.gz}.json"

    rsync -avR "$nii_file" "$DEST_DIR"
    rsync -avR "$json_file" "$DEST_DIR"
    datalad remove "$nii_file"
    datalad remove "$json_file"
    echo "Quarantined: $nii_file and $json_file"
done