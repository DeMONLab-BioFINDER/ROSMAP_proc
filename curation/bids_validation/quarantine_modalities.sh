#!/bin/bash

# Strings to match
PATTERNS="real|imaginary|FLAIR|MEGRENDpha|MEGREpha"

# Find symlinks matching patterns
find . -type l | grep -E "$PATTERNS" | while read -r symlink; do
    target=$(readlink -f "$symlink")
    # Rsync the target
    rsync -avR --copy-links "$symlink" ../../quarantine_ROSMAP/
    # Remove the symlink with datalad
    datalad remove "$symlink"
done