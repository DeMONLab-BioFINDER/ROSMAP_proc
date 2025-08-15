#!/bin/bash

SOURCES=(
    "sub-47923038/ses-1/func"
    "sub-47923038/ses-1/fmap"
    "sub-59497970/ses-0/dwi"
    "sub-10479506/ses-1/dwi"
    )
DESTINATION="../../quarantine_ROSMAP/"

for SOURCE in "${SOURCES[@]}"; do
    if [ -d "$SOURCE" ]; then
        echo "Copying $SOURCE to $DESTINATION"
        rsync -avr --copy-links "$SOURCE" "$DESTINATION"
    else
        echo "Source directory $SOURCE does not exist."
    fi
done

for SOURCE in "${SOURCES[@]}"; do
    if [ -d "$SOURCE" ]; then
        datalad remove "$SOURCE" --reckless kill
    fi
done
