import nibabel as nb
import json
import os
import numpy as np
import datalad.api as dl
import sys
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import pandas as pd

def get_json(path):
    """
    Get the repetition time from the JSON sidecar file.
    
    Args:
        path (str): Path to the NIfTI file.
    returns:
        repetition_time (float): Repetition time from the JSON file.
    """
    # get corresponding json file
    json_path = str(path).replace(".nii.gz", ".json")

    
    repetition_time = None
    
    try:
        # extract TR from json
        with open(json_path, 'r') as json_file:
            data = json.load(json_file)
            repetition_time = data.get('RepetitionTime')
            if repetition_time is not None:
                print(f"Repetition Time: {repetition_time}")
            else:
                print("Key 'repetitiontime' not found in JSON file.")
    except FileNotFoundError:
        print(f"JSON file not found: {json_path}")
    except json.JSONDecodeError:
        print(f"Error decoding JSON file: {json_path}")
    return repetition_time
# nake sure its passing right type

def strict_load(fname):
    """ Load an image that will write out the same as the input image.
    
    Args:
        fname (str): Path to the NIfTI file.
    Returns:
        strict_img (Nifti1Image): Loaded NIfTI image.
        zoom (float): Voxel size in the z-direction.
    """
    
    orig = nb.load(fname)
    # strict_img = orig.__class__(np.array(orig.dataobj.get_unscaled()), orig.affine, orig.header)
    # strict_img.header.set_slope_inter(orig.dataobj.slope, orig.dataobj.inter)
    header = orig.header
    # header = strict_img.header
    zooms = header.get_zooms()[:3]
    return orig, zooms[2]

def set_tr(img, tr):
    """
    This function modifies the TR in the NIfTI header to match the value
    provided in the JSON sidecar file, due to mismatch found during bids validation.
    The TR is set to the value in seconds.

    Args:
        img (Nifti1Image): NIfTI image.
        tr (float): Repetition time to set in the header.
    Returns:
        img (Nifti1Image): NIfTI image with updated TR.
    """

    # get header
    header = img.header
    # get the current zooms up to 3 dimensions (fourth entry is for TR). And append new TR to it
    zooms = header.get_zooms()[:3] + (tr,)
    print(zooms)
    # set the new zooms
    header.set_zooms(zooms)
    return img

def process_file(file_path):
    """ Process a single file while excluding datalad functions from parallelization 
    Args:
        file_path (str): Path to the NIfTI file.
    Returns:
        tuple: (path, subset, img, repetition_time) if processing is needed, else None.
    """
    # Remove leading slashes and whitespace
    # file_path = file_path.strip().lstrip('./\\')  # Remove leading slashes
    print(f"Processing: {file_path}")

    path = Path(file_path)
    subset = path.parts[0]  # Assuming subset is the first part of the path
    print(subset)

    # Get actual TR from json and load nifti image
    repetition_time = get_json(path)
    img, nifti_tr = strict_load(path)

    # if mismatch, return values for sequential datalad handling
    if repetition_time != nifti_tr:
        return (path, subset, img, repetition_time)
    return None
   
def main():

    df = pd.read_csv('code/CuBIDS/v1_validation.tsv', sep='\t')

    tr_df = df[df.iloc[:, 1] == 'REPETITION_TIME_MISMATCH'].copy()
    
    # with open(paths, "r") as file:
    #     file_paths = [line.strip() for line in file]

    # results = []
    # # Use ThreadPoolExecutor to process files in parallel
    # with ThreadPoolExecutor(max_workers=48) as executor:
    #     results = list(filter(None, executor.map(process_file, tr_df.iloc[:, 0].tolist())))

    # Sequentially handle datalad operations (git can't handle parallelization)
    for file in tr_df.iloc[:, 0]:
        file = file.lstrip('/')
        try:
            path, subset, img, repetition_time = process_file(file)
            print(f"Processing {path} with TR {repetition_time} and nifti_tr {img.header.get_zooms()[3]}")
            dl.unlock(dataset=subset, path=str(path))
            fixed_img = set_tr(img, repetition_time)
            fixed_img.to_filename(path)
            dl.save(path=path, dataset=subset, message=f'Changed TR in {path} header to match JSON sidecar')
        except Exception as e:
            with open('code/curation/validation/TRerror_files.txt', 'a') as log:
                log.write(f"{path} - Error: {str(e)}\n")
        

if __name__ == "__main__":
    main()