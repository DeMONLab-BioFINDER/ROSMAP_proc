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
        if 'EstimatedPhaseEncodingDirection'

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
        
        print(f"Processed: {new_json_path}")

def main():
    print("Starting processing of JSON files...")
    files = sorted(glob.glob(os.path.join(os.getcwd(), 'sub*', 'ses-*', 'func', '*UC*.json')))
    
    for ii, file in enumerate(files):
        dl.unlock(file)

    print(f"Found {len(files)} files to process.")
    with ThreadPoolExecutor(max_workers=48) as executor:
        executor.map(process_file, files)

if __name__ == "__main__":
    main()
