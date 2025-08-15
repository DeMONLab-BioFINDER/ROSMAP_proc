import nibabel as nib
import numpy as np
import pandas as pd
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor

df = pd.read_csv('code/CuBIDS/v2_1_validation.tsv', sep='\t')

bnk_fmaps = df[df.iloc[:, 1] == 'NOT_INCLUDED'].copy()

for file in bnk_fmaps.iloc[:, 0]:
    file = file.lstrip('/')
    if 'BNK' in file:
        try:
            result = subprocess.run(["rsync", "-avR", "--copy-links", file, "../../quarantine_ROSMAP/"], check=True, capture_output=True)
            
            if result.returncode == 0:
                subprocess.run(["datalad", "remove", file], check=True)
            else:
                raise subprocess.CalledProcessError(result.returncode, result.args, output=result.stdout, stderr=result.stderr)
        except subprocess.CalledProcessError as e:
            print(f"Error processing {file}: {e}")

fmaps = df[df.iloc[:, 1] == 'FIELDMAP_WITHOUT_MAGNITUDE_FILE'].copy()

for file in fmaps.iloc[:, 0]:
    file = file.lstrip('/')
    if 'fmap' in file:
        try:
            result = subprocess.run(["rsync", "-avR", "--copy-links", file, "../../quarantine_ROSMAP/"], check=True, capture_output=True)
            
            if result.returncode == 0:
                subprocess.run(["datalad", "remove", file], check=True)
            else:
                raise subprocess.CalledProcessError(result.returncode, result.args, output=result.stdout, stderr=result.stderr)
        except subprocess.CalledProcessError as e:
            print(f"Error processing {file}: {e}")