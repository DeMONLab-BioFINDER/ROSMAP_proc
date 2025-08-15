import pandas as pd
import os
import subprocess

df = pd.read_csv('code/CuBIDS/v3_validation.tsv', sep='\t')

json_fmaps = df[df.iloc[:, 1] == 'SIDECAR_WITHOUT_DATAFILE'].copy()

for file in json_fmaps.iloc[:, 0]:
    file = file.lstrip('/')
    try:
        result = subprocess.run(["rsync", "-avR", "--copy-links", file, "../../quarantine_ROSMAP/"], check=True, capture_output=True)
        
        if result.returncode == 0:
            subprocess.run(["datalad", "remove", file], check=True)
        else:
            raise subprocess.CalledProcessError(result.returncode, result.args, output=result.stdout, stderr=result.stderr)
    except subprocess.CalledProcessError as e:
        print(f"Error processing {file}: {e}")

# Remove empty folders inside ./sub-*/ses-*/ only if they are empty
for sub in [d for d in os.listdir(".") if d.startswith("sub-") and os.path.isdir(d)]:
    sub_path = os.path.join(".", sub)
    for ses in [d for d in os.listdir(sub_path) if d.startswith("ses-") and os.path.isdir(os.path.join(sub_path, d))]:
        ses_path = os.path.join(sub_path, ses)
    for folder in [f for f in os.listdir(ses_path) if os.path.isdir(os.path.join(ses_path, f))]:
        folder_path = os.path.join(ses_path, folder)
        if not os.listdir(folder_path):
            try:
                os.rmdir(folder_path)
                print(f"Removed empty folder: {folder_path}")
            except OSError as e:
                print(f"Error removing {folder_path}: {e}")