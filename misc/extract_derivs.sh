#!/bin/bash

cd /home/gabridele/backup/ROSMAP_proc/BABS_proj_exemplar_fmri/output_ria/786/9998e-5f58-405c-a4dd-cc87e1d80404/annex/objects
partial_der='/home/gabridele/backup/ROSMAP_proc/exemplar_der1'
for output in */*/*; do
cd $output
pwd

#find . -mindepth 1 -maxdepth 1 ! -name "*.zip" -exec rm -rf {} \;
unzip -q *.zip -d unzipped

# Find the folder starting with "sub-" and containing "ses-"
sub=$(find 'unzipped' -maxdepth 1 -type d -name "sub-*")
ses=$(find $sub -maxdepth 1 -type d -name "ses-*")
echo $dir
echo $ses
# Extract sub-# and ses-# parts
sub_id=$(echo "$sub" | grep -o "sub-[^_/]*")
ses_id=$(echo "$ses" | grep -o "ses-[^_/]*")

# Build the new name
new_name="${sub_id}_${ses_id}"
echo $new_name
# Rename the folder
cp -r unzipped $partial_der/$new_name

echo "Renamed unzipped to $partial_der/$new_name"
rm -r unzipped
cd ../../..

done
