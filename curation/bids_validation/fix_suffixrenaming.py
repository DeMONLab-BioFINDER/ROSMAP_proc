import os
from concurrent.futures import ThreadPoolExecutor
import glob
import datalad.api as dl
from pathlib import Path


def rename_anat_file(file):
    base = Path(file).name.split('.')[0]

    new_base = base.replace('_T1w', '_T2starw')

    new_nifti = os.path.join(Path(file).parent, new_base + '.nii.gz')
    new_json = os.path.join(Path(file).parent, new_base + '.json')

    os.rename(file, new_nifti)
    os.rename(os.path.join(Path(file).parent, base + '.json'), new_json)


def main():
    files = sorted(glob.glob(os.path.join(os.getcwd(), 'sub*', 'ses-*', 'anat', '*RIRC*Sag3DMEGRE*_T1w.nii.gz')))

    for ii, file in enumerate(files):
        dl.unlock(file)

    with ThreadPoolExecutor(max_workers=48) as executor:
        executor.map(rename_anat_file, files)

if __name__ == "__main__":
    main()