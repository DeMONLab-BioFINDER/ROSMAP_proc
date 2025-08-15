import os
import json
import datalad.api as dl
import glob
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess

def add_dirAP(file_path):

    base = Path(file_path).name.split('.')[0]
    if 'dir-' in base:
        return
    if 'Open_bold' not in base:
        return

    new_base = base.replace('_bold', '_dir-AP_bold')
    new_nifti = os.path.join(Path(file_path).parent, new_base + '.nii.gz')
    new_json = os.path.join(Path(file_path).parent, new_base + '.json')
    
    os.rename(os.path.join(Path(file_path).parent, base + '.nii.gz'), new_nifti)
    os.rename(os.path.join(Path(file_path).parent, base + '.json'), new_json)


def dump_entry():
    # fixing REPETITION_TIME_AND_ACQUISITION_DURATION_MUTUALLY_EXCLUSIVE error by removing AcquisitionDuration from the JSON file, not needed

    json_file = 'sub-57707979/ses-4/func/sub-57707979_ses-4_task-rest_acq-RIRC20230726AxMBrsfMRIEyesOpen_dir-AP_bold.json'
    if not os.path.exists(json_file):
        print(f"JSON file {json_file} not found.")
        return

    with open(json_file, 'r') as f:
        data = json.load(f)
    dl.unlock(json_file)
    key_remove = "AcquisitionDuration"
    if key_remove in data:
        data.pop(key_remove)
    
    with open(json_file, 'w') as f:
        json.dump(data, f, indent=4)
    print(f"Removed 'Acquisition duration' from {json_file}")

def run_rsync(source, destination):
    try:
        subprocess.run(['rsync', '-avr', '--copy-links', source, destination], check=True)
        print(f"Successfully synced {source} to {destination}")
    except subprocess.CalledProcessError as e:
        print(f"Error during rsync: {e}")

def add_taskname(file_path):
    with open(file_path, 'r') as f:
        data = json.load(f)

        if 'TaskName' not in data:
            data['TaskName'] = 'rest'

        with open(file_path, 'w') as f:
            json.dump(data, f, indent=4)

def edit_suffix(file_path):
    base = Path(file_path).name.split('.')[0]
    if 'echo-1' in base:

        new_base = base.replace('_echo-1_fieldmap', '_phase1')
        new_nifti = os.path.join(Path(file_path).parent, new_base + '.nii.gz')
        new_json = os.path.join(Path(file_path).parent, new_base + '.json')
    if 'echo-2' in base:
        new_base = base.replace('_echo-2_fieldmap', '_phase2')
        new_nifti = os.path.join(Path(file_path).parent, new_base + '.nii.gz')
        new_json = os.path.join(Path(file_path).parent, new_base + '.json')

    os.rename(file_path, new_nifti)
    os.rename(os.path.join(Path(file_path).parent, base + '.json'), new_json)
    
def main():
    print("Starting processing of JSON files...")
    files = sorted(glob.glob(os.path.join(os.getcwd(), 'sub*', 'ses-*', 'func', '*RIRC2023*')))
    
    for ii, file in enumerate(files):
        dl.unlock(file)

    print(f"Found {len(files)} files to process.")
    with ThreadPoolExecutor(max_workers=48) as executor:
        executor.map(add_dirAP, files)

    # dumping entry to fix REPETITION_TIME_AND_ACQUISITION_DURATION_MUTUALLY_EXCLUSIVE error
    dump_entry()
    
    ## commenting outr next lines because used another script to move to quarantine
    # moving subs to quarantine. fmap too because they intended for these funcs
    # source = "/sub-41635233/ses-1/"
    # source2 = '/sub-06798423/ses-0/func'
    # source3 = '/sub-06798423/ses-0/fmap'
    # source4 = '/sub-06172311/ses-0/func'
    # source5 = '/sub-06172311/ses-0/fmap'
    # destination = "../../quarantine_ROSMAP/"
    # run_rsync(source, destination)
    # run_rsync(source2, destination)
    # run_rsync(source3, destination)
    # run_rsync(source4, destination)
    # run_rsync(source5, destination)

    uc22 = sorted(glob.glob(os.path.join(os.getcwd(), 'sub*', 'ses-*', 'func', '*UC2022*.json')))
    mg12 = sorted(glob.glob(os.path.join(os.getcwd(), 'sub*', 'ses-*', 'func', '*MG2012*.json')))
    
    for ii, file in enumerate(uc22 + mg12):
        dl.unlock(file)
    
    with ThreadPoolExecutor(max_workers=48) as executor:
        executor.map(add_taskname, files)

    with ThreadPoolExecutor(max_workers=48) as executor:
        executor.map(add_taskname, uc22)

    with ThreadPoolExecutor(max_workers=48) as executor:
        executor.map(add_taskname, mg12)
    
    fmaps_mg = sorted(glob.glob(os.path.join(os.getcwd(), 'sub*', 'ses-*', 'fmap', '*MG2012*echo-*_fieldmap*.nii.gz')))

    for ii, file in enumerate(fmaps_mg):
        dl.unlock(file)

    with ThreadPoolExecutor(max_workers=48) as executor:
        executor.map(edit_suffix, fmaps_mg)

if __name__ == "__main__":
    main()
