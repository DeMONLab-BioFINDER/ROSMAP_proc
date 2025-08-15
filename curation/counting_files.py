import os
import pandas as pd

csv_path = 'code/bids_sessions_summary_with_exemplar.csv'
bids_root = '.' 

# Load the CSV
df = pd.read_csv(csv_path)

def session_has(sub_id, ses_id, keyword):
    anat_path = os.path.join(bids_root, sub_id, ses_id, 'anat')
    if not os.path.isdir(anat_path):
        return 'no'
    return 'yes' if any(keyword.lower() in f.lower() for f in os.listdir(anat_path)) else 'no'

# Apply function per row
df['t2starw'] = df.apply(lambda row: session_has(row['sub_id'], row['ses_id'], 'T2starw'), axis=1)
df['t2w'] = df.apply(lambda row: session_has(row['sub_id'], row['ses_id'], 'T2w'), axis=1)

# Save updated CSV
output_path = 'bids_sessions_summary_with_exemplar_and_t2flags.csv'
df.to_csv(output_path, index=False)

print(f"Updated CSV saved to: {output_path}")
