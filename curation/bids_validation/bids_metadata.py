import os
import re
import pandas as pd

# Initialize list to collect data
data = []

# Walk from current working directory
cwd = os.getcwd()

# Loop through sub-* folders
for sub in os.listdir(cwd):
    sub_path = os.path.join(cwd, sub)
    if os.path.isdir(sub_path) and sub.startswith('sub-'):
        sub_id = sub

        # Check for ses-* folders inside sub-*
        for ses in os.listdir(sub_path):
            ses_path = os.path.join(sub_path, ses)
            if os.path.isdir(ses_path) and ses.startswith('ses-'):
                ses_id = ses

                # Traverse further inside session folders
                for root, dirs, files in os.walk(ses_path):
                    for file in files:
                        # Check for 'acq-' in filename
                        match = re.search(r'acq-([^_]+)', file)
                        if match:
                            protocol = match.group(1)
                            location = os.path.relpath(os.path.join(root, file), cwd)

                            # Append record
                            data.append({
                                'location': location,
                                'sub-ID': sub_id,
                                'ses': ses_id,
                                'protocol': protocol
                            })

# Create DataFrame
df = pd.DataFrame(data)

# --- Add modality column
df['modality'] = df['location'].apply(lambda x: x.split(os.sep)[2] if len(x.split(os.sep)) > 2 else None)

# --- Extract acq raw string (e.g. 'BNK2009') from protocol
df['acq_raw'] = df['protocol']

# Extract full 8-digit date from protocol
df['acq_date'] = df['acq_raw'].str.extract(r'(\d{8})')

# Extract site prefix (anything before the date)
df['acq_site'] = df['acq_raw'].str.extract(r'([A-Z]+)(?=\d{8})', flags=re.IGNORECASE)

def infer_site(row):
    if pd.notnull(row['acq_site']):
        return row['acq_site']

    date = row['acq_date']
    if pd.isnull(date):
        return None

    if date.startswith('2009'):
        return 'BNK'
    elif date in ['20150706', '20151120', '20160125', '20120221', '20140922']:
        return 'UC'
    elif date in ['20120501', '20150715', '20160621', '20160627']:
        return 'MG'
    else:
        return None

df['acq_site'] = df.apply(infer_site, axis=1)

# Show or save
print(df.head())
df.to_csv('~/backup/bids_metadata.csv', index=False)

site_counts = df.groupby(['sub-ID', 'modality'])['acq_site'].nunique().reset_index()
diff_sites = site_counts[site_counts['acq_site'] > 1]

# Save to new DataFrame
df_diff_sites = df[df['sub-ID'].isin(diff_sites['sub-ID'])]

# Optional: drop duplicates to make it clearer
#df_diff_sites = df_diff_sites[['sub-ID', 'modality', 'acq_site']].drop_duplicates()

date_counts = df.groupby(['sub-ID', 'ses'])['acq_date'].nunique().reset_index()
diff_dates = date_counts[date_counts['acq_date'] > 1]

# Save to new DataFrame
df_diff_dates = df[df[['sub-ID', 'ses']].apply(tuple, axis=1).isin(diff_dates[['sub-ID', 'ses']].apply(tuple, axis=1))]

# Optional: simplify
#f_diff_dates = df_diff_dates[['sub-ID', 'ses', 'modality', 'acq_date']].drop_duplicates()
n_diff_sites = df_diff_sites['sub-ID'].nunique()
n_diff_dates = df_diff_dates['sub-ID'].nunique()

print(f"🔹 Subjects with different sites in the same modality: {n_diff_sites}")
print(f"🔹 Subjects with different acquisition dates across modalities in a session: {n_diff_dates}")

df_diff_sites.to_csv('subjects_with_different_sites_per_modality.csv', index=False)
df_diff_dates.to_csv('subjects_with_different_dates_per_session.csv', index=False)
