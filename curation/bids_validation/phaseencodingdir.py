import os
import json
import datalad.api as dl
import glob
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

def process_file(file_path):

    if file_path.endswith('.json'):
        print(f'Processing {file_path}')
    	# Load JSON
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        # Modify estimated keys if present. Otherwise you might have to pass a specific flag to fmriprep that tells it to look for 'estimated' keys instead
        if 'EstimatedTotalReadoutTime' in data:
            data['TotalReadoutTime'] = data['EstimatedTotalReadoutTime']
        if 'EstimatedEffectiveEchoSpacing' in data:
            data['EffectiveEchoSpacing'] = data['EstimatedEffectiveEchoSpacing']

        # Determine suffix and PhaseEncodingDirection
        base, _ = os.path.splitext(file_path)
        if 'EPIP' in base:
            suffix = '_dir-PA'
            data['PhaseEncodingDirection'] = 'j'
        elif 'EPIA' in base:
            suffix = '_dir-AP'
            data['PhaseEncodingDirection'] = 'j-'
        else:
            print(f"Skipping {file_path}: no EPIA or EPIP found.")
            return

        # Save JSON
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=4)
            
        print('performing renaming now')
        
        # Rename JSON file
        if '_dir' not in base:
            new_json_path = base.replace('_epi', f'{suffix}_epi') + '.json'
            print(new_json_path)
            os.rename(file_path, new_json_path)

            # Rename corresponding .nii.gz if exists
            nii_path = Path(base + '.nii.gz')
            if nii_path.exists():
                new_nii_path = new_json_path.replace('.json', '.nii.gz')
                print(new_nii_path)
                os.rename(nii_path, new_nii_path)
                print(f"Renamed NIfTI: {new_nii_path}")
            else:
                print(f"No NIfTI found for: {nii_path}")    
        print(f"Processed: {new_json_path}")

def main():
    print("Starting processing of JSON files...")
    files = sorted(glob.glob(os.path.join(os.getcwd(), 'sub*', 'ses-*', 'fmap', '*UC2022*SEEPI*')))
    
    for ii, file in enumerate(files):
        dl.unlock(file)

    print(f"Found {len(files)} files to process.")
    with ThreadPoolExecutor(max_workers=48) as executor:
        executor.map(process_file, files)

if __name__ == "__main__":
    main()
