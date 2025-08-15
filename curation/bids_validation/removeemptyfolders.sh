#!/bin/bash

# Iterate through all directories named 'fmap' in the current directory and subdirectories
find ./sub-*/ses-*/ -type d -name "fmap" | while read -r dir; do
    # Check if the directory is empty
    if [ -z "$(ls -A "$dir")" ]; then
        echo "Deleting empty folder: $dir"
        rmdir "$dir"
    fi
done
