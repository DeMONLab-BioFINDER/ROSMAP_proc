#!/bin/bash
set -e -u -x

subid="$1"
sesid="$2"
sesdir="inputs/data/raw/${subid}/${sesid}"
# Create a filter file that only allows this session
filterfile=${PWD}/${sesid}_filter.json
echo "{" > ${filterfile}
echo "'fmap': {'datatype': 'fmap', 'session': '$sesid'}," >> ${filterfile}
echo "'bold': {'datatype': 'func', 'session': '$sesid', 'suffix': 'bold'}," >> ${filterfile}
echo "'sbref': {'datatype': 'func', 'session': '$sesid', 'suffix': 'sbref'}," >> ${filterfile}
echo "'flair': {'datatype': 'anat', 'session': '$sesid', 'suffix': 'FLAIR'}," >> ${filterfile}
echo "'t2w': {'datatype': 'anat', 'session': '$sesid', 'suffix': 'T2w'}," >> ${filterfile}
echo "'t1w': {'datatype': 'anat', 'session': '$sesid', 'suffix': 'T1w'}," >> ${filterfile}
echo "'roi': {'datatype': 'anat', 'session': '$sesid', 'suffix': 'roi'}" >> ${filterfile}
echo "}" >> ${filterfile}

# remove ses and get valid json
sed -i "s/'/\"/g" ${filterfile}
sed -i "s/ses-//g" ${filterfile}

# Check if fmap directory exists and is non-empty. the fmap line in the filter file was causing an error
if [ ! -d "$sesdir/fmap" ]; then
    echo "No fmap data found. Removing 'fmap' filter from $filterfile"

    # Remove fmap entry from the JSON
    tmpfile=$(mktemp)
    jq 'del(.fmap)' "$filterfile" > "$tmpfile" && mv "$tmpfile" "$filterfile"
else
    echo "fmap data found. Keeping filter."
fi

## BNK scans don't need fmap correction, according to those who acquired them

usesyn=""
anat_dir="inputs/data/raw/${subid}/${sesid}/anat"
fmap="inputs/data/raw/${subid}/${sesid}/fmap"
if ! find "$anat_dir" -type l | grep -q "BNK"; then
  usesyn="--use-syn-sdc"
fi
echo $anat_dir

if find "$fmap" -type l | grep -q 'MG2012'; then
    # Second IF: count them and compare
    count=$(find "$fmap" -type l | grep 'MG2012' | wc -l)
    if (( count <= 4 )); then
        tmpfile=$(mktemp)
        jq 'del(.fmap)' "$filterfile" > "$tmpfile" && mv "$tmpfile" "$filterfile"
        echo 'removed fmap filter from bids_filter_json, missing key files'
    fi
fi

mkdir -p ${PWD}/.git/tmp/wkdir
singularity run --cleanenv \
	-B ${PWD} \
	-B /home/gabridele/backup/templateflow:/SGLR/TEMPLATEFLOW_HOME \
	-B /home/gabridele/license.txt:/SGLR/FREESURFER_HOME/license.txt \
	--env TEMPLATEFLOW_HOME=/SGLR/TEMPLATEFLOW_HOME \
	containers/.datalad/environments/fmriprep-25-1-1/image \
	inputs/data/raw \
	outputs/fmriprep \
	participant \
	-w ${PWD}/.git/tmp/wkdir \
	--n_cpus 16 \
	--omp-nthreads 4 \
	--stop-on-first-crash \
	--fs-license-file /SGLR/FREESURFER_HOME/license.txt \
	--skip-bids-validation \
	--output-spaces MNI152NLin6Asym:res-2 \
	$usesyn \
	--force bbr \
	--cifti-output 91k \
	--notrack \
	--resource-monitor \
	-v -v \
	--debug fieldmaps \
	--bids-filter-file "${filterfile}" \
	--participant-label "${subid}"
# use fmapless distortion correction if fmaps are not avail
cd outputs
7z a ../${subid}_${sesid}_fmriprep-25-1-1.zip fmriprep
cd ..
rm -rf outputs .git/tmp/wkdir

rm ${filterfile} 

