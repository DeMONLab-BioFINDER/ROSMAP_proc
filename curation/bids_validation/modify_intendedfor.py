import os
import pandas as pd
import json
import datalad.api as dl
import glob
from pathlib import Path

# Function to modify 'INTENDED_FOR' entries
def modify_intended_for(input_file):
    """
    Modify the 'INTENDED_FOR' entry in the JSON file, in order to point to the right bold acq.
    Args:
        input_file (str): Path to the NIfTI file.
    """

    # Load the JSON file
    # Skip processing if 'BNK' is in the input file name
    json_path = str(input_file).replace(".nii.gz", ".json")
    try:
        with open(json_path, 'r') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"File not found: {json_path}")
        return
    except json.JSONDecodeError:
        print(f"Error decoding JSON in file: {json_path}")
        return
     
    # Modify the 'INTENDED_FOR' entry with correct func scan
    dl.unlock(json_path)
    if 'BNK' in json_path:
        data.pop("IntendedFor", None)
        print(f"Skipping file {json_path} as BNK scans do not need fmap correction")
        return
    try:
        input_dir = os.path.relpath(os.path.dirname(json_path), start=os.getcwd())
        func_dir = os.path.abspath(os.path.join(input_dir, "../func/"))
        data["IntendedFor"] = [
            os.path.relpath(os.path.join(func_dir, file), start=os.path.join(os.getcwd(), input_dir.split("ses-")[0]))

            for file in os.listdir(func_dir) if file.endswith("_bold.nii.gz")
        ]
        print(f"Modified 'IntendedFor' entry in {json_path}")
        print(data["IntendedFor"])
    except FileNotFoundError:
        print("Directory '../func' not found.")
        return

    #Save the modified JSON file
    try:
        with open(json_path, 'w') as f:
            json.dump(data, f, indent=4)
    except Exception as e:
        print(f"Error writing to file {json_path}: {e}")

def main():
    df = pd.read_csv('code/CuBIDS/v2_validation.tsv', sep='\t')

    intended_for = df[df.iloc[:, 1] == 'INTENDED_FOR'].copy()

    for file in intended_for.iloc[:, 0]:
        file = file.lstrip('/')
        modify_intended_for(file)

if __name__ == "__main__":
    main()
