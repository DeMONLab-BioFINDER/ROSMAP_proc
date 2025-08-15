## some acqs in MG have the wrong suffix for their dwi files. most likely they wont be used, but renamed for consistency
import os
import json
import datalad.api as dl
import glob
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

def rename_dwi_file(file):
    base = Path(file).name.split('.')[0]
    if 'FA' not in base:
        return
    
    if 'ColFA' in base:
        new_base = base.replace('ColFA', '')
        new_base = new_base.replace('_dwi', '_ColFA')
        new_nifti = os.path.join(Path(file).parent, new_base + '.nii.gz')
        new_json = os.path.join(Path(file).parent, new_base + '.json')
        # print(new_nifti)
        # print(new_json)
        os.rename(file, new_nifti)
        os.rename(os.path.join(Path(file).parent, base + '.json'), new_json)

    if 'FA' in base and 'Col' not in base:
        new_base = base.replace('FA', '')
        new_base = new_base.replace('_dwi', '_FA')
        new_nifti = os.path.join(Path(file).parent, new_base + '.nii.gz')
        new_json = os.path.join(Path(file).parent, new_base + '.json')
        # print(new_nifti)
        # print(new_json)
        os.rename(file, new_nifti)
        os.rename(os.path.join(Path(file).parent, base + '.json'), new_json)

def main():
    files = sorted(glob.glob(os.path.join(os.getcwd(), 'sub*', 'ses-*', 'dwi', '*MG*DTI*.nii.gz')))

    for ii, file in enumerate(files):
        base, _ = os.path.splitext(file)
        
        if 'FA' not in base:
            continue
        dl.unlock(file)

    with ThreadPoolExecutor(max_workers=48) as executor:
        executor.map(rename_dwi_file, files)
    
if __name__ == "__main__":
    main()
