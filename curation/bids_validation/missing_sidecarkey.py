import nibabel as nb
import json
import os
import numpy as np
import datalad.api as dl
import sys
from pathlib import Path
import pandas as pd

def set_echotime(file):

    json_path = str(file).replace(".nii.gz", ".json")
    dl.unlock(path=str(json_path))
    try:
        with open(json_path, 'r') as json_file:
            data = json.load(json_file)
        if 'echo-1' in json_path:
            data['EchoTime'] = 0.02 
            print(f"Setting EchoTime for {json_path} to {data['EchoTime']}")
        elif 'echo-2' in json_path:
            data['EchoTime'] = 0.04
            print(f"Setting EchoTime for {json_path} to {data['EchoTime']}")
        with open(json_path, 'w') as json_file:
            json.dump(data, json_file, indent=4)
        print(f"Set EchoTime for {json_path}")
    except FileNotFoundError:
        print(f"JSON file not found: {json_path}")
    except json.JSONDecodeError:
        print(f"Error decoding JSON file: {json_path}")

def set_taskname(file):

    json_path = str(file).replace(".nii.gz", ".json")
    dl.unlock(path=str(json_path))
    try:
        with open(json_path, 'r') as json_file:
            data = json.load(json_file)
            data['TaskName'] = 'rest'
            print(f"Setting TaskName for {file} to {data['TaskName']}")
        with open(json_path, 'w') as json_file:
            json.dump(data, json_file, indent=4)
        print(f"Set TaskName for {file}")
    except FileNotFoundError:
        print(f"JSON file not found: {json_path}")
    except json.JSONDecodeError:
        print(f"Error decoding JSON file: {json_path}")

def main():

    df = pd.read_csv('code/CuBIDS/v1_validation.tsv', sep='\t')

    required_keys = df[df.iloc[:, 1] == 'SIDECAR_KEY_REQUIRED'].copy()
    
    # Sequentially handle datalad operations (git can't handle parallelization)
    for _, row in required_keys.iterrows():
        file = row.iloc[0].lstrip('/')
        subset = file.split('/')[0]
        
        key = row.iloc[3]
        print(f"Processing file: {file} in dataset: {subset} for key: {key}")
        try:
            if key == 'EchoTime':
                set_echotime(file)
            elif key == 'TaskName':
                print('!!!!')
                set_taskname(file)
            else:
                print(f"Skipping unsupported key: {key} in file: {file}")
        except Exception as e:
            with open('code/curation/validation/sidecarkey_error_files.txt', 'a') as log:
                log.write(f"{file} - Error: {str(e)}\n")
if __name__ == "__main__":
    main()
