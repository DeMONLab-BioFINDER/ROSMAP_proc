import os
import csv
import re
"""This script processes log files to find specific error patterns and outputs results to a CSV file.
Used to identify where I get errors caused by failed fmapless SDC"""


# --- CONFIG ---
log_folder = "."  # folder containing .log files
output_csv = "/home/gabridele/backup/errors_found2.csv"

results = []

for filename in os.listdir(log_folder):
    if ".e" in filename:  # only process files containing ".e"
        file_path = os.path.join(log_folder, filename)
        
        try:
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                # Read last 3 lines efficiently
                f.seek(0, os.SEEK_END)
                f_size = f.tell()

                lines_found = []
                buffer = ""
                newline_count = 0

                for pos in range(f_size - 1, -1, -1):
                    f.seek(pos)
                    char = f.read(1)

                    if char == "\n":
                        lines_found.append(buffer.strip())
                        buffer = ""
                        newline_count += 1
                        if newline_count == 3:  # we only need 3 lines
                            break
                    else:
                        buffer = char + buffer

                # If file has < 3 lines, append last partial buffer
                if buffer and newline_count < 3:
                    lines_found.append(buffer.strip())

                # We read backwards: lines_found[0] = last line, [1] = second last, [2] = third last
                if len(lines_found) >= 3:
                    last_line = lines_found[0]
                    second_last_line = lines_found[1]
                    third_last_line = lines_found[2]

                    if "[INFO]" in second_last_line and "ValueError" in third_last_line:
                        results.append([filename, third_last_line])

        except Exception as e:
            print(f"Could not process {filename}: {e}")
results.sort(key=lambda x: x[0].lower())
# --- SAVE TO CSV ---
with open(output_csv, "w", newline="", encoding="utf-8") as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(["Filename", "Error_Message"])
    writer.writerows(results)

print(f"Done! Found {len(results)} matching cases. Saved to {output_csv}.")


# --- CONFIG ---
input_csv = "/home/gabridele/backup/errors_found2.csv"
output_csv = "/home/gabridele/backup/fmriprep_errors_cleaned2.csv"
paths_txt = "/home/gabridele/backup/fmaplessfunc_paths2.txt"
# --- READ CSV ---
rows = []
with open(input_csv, "r", encoding="utf-8") as csvfile:
    reader = csv.reader(csvfile)
    header = next(reader)  # skip header
    for row in reader:
        filename = row[0]
        error_message = row[1]
        
        # Extract full fmr_sub / ses ID
        match = re.search(r"(fmr_sub-\d+_ses-\d+)", filename)
        if match:
            full_id = match.group(1)
            sub_match = re.search(r"(sub-\d+)", full_id)
            ses_match = re.search(r"(ses-\d+)", full_id)
            sub_id = sub_match.group(1) if sub_match else ""
            ses_id = ses_match.group(1) if ses_match else ""
        else:
            full_id = ""
            sub_id = ""
            ses_id = ""
        
        # Extract number after .e
        match_e = re.search(r"\.e(\d+)", filename)
        if match_e:
            e_number = int(match_e.group(1))
        else:
            e_number = -1
        
        rows.append([sub_id, ses_id, full_id, filename, error_message, e_number])

# --- DEDUPLICATE ---
best_rows = {}
for sub_id, ses_id, full_id, filename, error_message, e_number in rows:
    if full_id not in best_rows or e_number > best_rows[full_id][5]:
        best_rows[full_id] = [sub_id, ses_id, full_id, filename, error_message, e_number]

# --- SORT & WRITE OUTPUT CSV ---
final_rows = list(best_rows.values())
final_rows.sort(key=lambda x: (x[0], x[1]))

with open(output_csv, "w", newline="", encoding="utf-8") as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(["Sub_ID", "Ses_ID", "Subject_Session_ID", "Filename", "Error_Message", "E_Number"])
    writer.writerows(final_rows)

# --- CREATE PATH TXT FILE ---
paths = [f"--resubmit-job {sub} {ses} \\" for sub, ses, *_ in final_rows if sub and ses]
with open(paths_txt, "w", encoding="utf-8") as txtfile:
    txtfile.write("\n".join(paths))

print(f"Done! Cleaned CSV saved to {output_csv} and paths saved to {paths_txt}")
