library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)

# from sourcedata list, get only the 27 subs that are total yes in rosmap qc
sourcedata_list <- read_csv("sourcedata_list.csv")
priority_list_qc <- read_csv("priority_list_withQC.csv")

# filter out for col v2525 only 'y'
priority_list_qc_yes <- priority_list_qc %>%
  filter(v2525 == "y")

# make sub_ses
priority_list_qc_yes <- priority_list_qc_yes %>%
  mutate(sub_ses = str_c(sub_id, ses_id, sep = "_")) %>%
  select(sub_ses)

write_csv(priority_list_qc_yes, "priority_list_IDs_yes.csv")

# inner join with rosmap_qc to get the QC metrics for the yes subs
rosmap_qc <- read_csv("Rosmap_QC_metrics.csv")
rosmap_qc_yes <- rosmap_qc %>%
  inner_join(priority_list_qc_yes, by = c("code" = "sub_ses"))
colnames(rosmap_qc_yes)

rosmap_qc_yes <- rosmap_qc_yes %>%
  select(site, code, subject, session, dice_masks, fd, surface_holes, nmi_t1_bold_masked, nmi_wt1_mni_masked, nmi_wbold_mni_masked, nmi_wt1_wbold)

# add mean dvars init, mni t1 bold

rosmap_qc_yes_new <- rosmap_qc_yes %>%
  select(code, subject, session, fd, surface_holes)

### construct nmis
# "~/Desktop/priority_v2525_nmi_norm.txt" for nmi wt1wbold

# nmi_2525 for rest of nmi

nmi_2525 <- read_csv("/Users/ga0034de/Documents/R_projs/priority_rosmap/nmi_2525.csv")

nmi_wt1wbold <- read_csv("/Users/ga0034de/Desktop/priority_v2525_nmi_norm.txt")

# separate first column by " "
nmi_wt1wbold <- nmi_wt1wbold %>%
  separate(col = 1, into = c("sid", "session", "mattes_wt1_wbold", "entropy_wt1", "entropy_wbold"), sep = " ")
# make all numeric
nmi_wt1wbold <- nmi_wt1wbold %>%
  mutate(mattes_wt1_wbold = as.numeric(mattes_wt1_wbold),
         entropy_wt1 = as.numeric(entropy_wt1),
         entropy_wbold = as.numeric(entropy_wbold))

nmi_wt1wbold <- nmi_wt1wbold %>%
  mutate(nmi_wt1wbold_ = (2 * mattes_wt1_wbold) / (entropy_wt1 + entropy_wbold))

nmi_wt1wbold <- nmi_wt1wbold %>%
  mutate(sub_ses = str_c(sid, session, sep = "_"))

# inner join with rosmap_qc_yes_new to get nmi wt1wbold
rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
  inner_join(nmi_wt1wbold %>% select(sub_ses, nmi_wt1wbold_), by = c("code" = "sub_ses"))
  
# inner join with nmi_2525 to get nmi wt1_mni and nmi wbold_mni
rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
  inner_join(nmi_2525 %>% select(sub_ses, mask_nmi_boldt1_v2525, mask_nmi_wt1mni_v2525, mask_nmi_wboldmni_v2525), by = c("code" = "sub_ses"))


# inner join with dice_v2525
rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
  inner_join(dice_v2525 %>% select(sub_ses, v2525_dice), by = c("code" = "sub_ses"))

old_qc_sheet <- read_csv("/Volumes/LU26D1023-DemonLab/DemonLab/ROSMAP/derivatives/metadata/qc_spreadsheet_beta.csv")
old_qc_sheet <- old_qc_sheet %>%
  mutate(sub_ses = str_c(sub_id, ses_id, sep = "_"))
# remove rows where sub_ses are duplicates
old_qc_sheeet <- old_qc_sheet %>%
  distinct(sub_ses, .keep_all = TRUE)
colnames(old_qc_sheet)
#inner join with old_qc_sheet
rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
  inner_join(old_qc_sheeet %>% select(sub_ses, protocol, mean_dvars_initial), by = c("code" = "sub_ses"))

rosmap_qc <- rosmap_qc %>%
  mutate(dropout_compo_perc10th= (1 - dropout_intensity_perc10th) + dropout_ratio_perc10th)

#rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
 # inner_join(rosmap_qc %>% select(code, dropout_compo_perc10th), by = c("code" = "code"))

dropout_composite <- read_csv("~/Desktop/dropout10_new_priority.txt", col_names = FALSE)
# remove first row
dropout_composite <- dropout_composite[-1, ]

#rename column
dropout_composite <- dropout_composite %>%
  separate(X1, into = c("sub_ses", "volume_gm", "nvox_gm", "intensity_gm", "nvm", "volume_dropout", "nvox_dropout", "intensity_dropout"), sep = " ") %>%
  select("sub_ses", "volume_gm", "nvox_gm", "intensity_gm", "volume_dropout", "nvox_dropout", "intensity_dropout")

#make all numeric
dropout_composite <- dropout_composite %>%
  mutate(volume_gm = as.numeric(volume_gm),
         nvox_gm = as.numeric(nvox_gm),
         intensity_gm = as.numeric(intensity_gm),
         volume_dropout = as.numeric(volume_dropout),
         nvox_dropout = as.numeric(nvox_dropout),
         intensity_dropout = as.numeric(intensity_dropout))

dropout_composite <- dropout_composite %>%
  mutate(dropout_intensity_perc10th=intensity_dropout/intensity_gm, dropout_ratio_perc10th=volume_dropout/volume_gm) %>%
  mutate(dropout_compo_perc10th = (1 - dropout_intensity_perc10th) + dropout_ratio_perc10th)

# inner join with rosmap_qc_yes_new
rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
  inner_join(dropout_composite %>% select(sub_ses, dropout_compo_perc10th), by = c("code" = "sub_ses"))

colnames(rosmap_qc_yes_new)
rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
  rename(sub_id = subject, ses_id = session, mean_FD = fd, surface_holes = surface_holes) %>%
  rename(nmi_normt1_normbold = nmi_wt1wbold_, nmi_boldt1 = mask_nmi_boldt1_v2525, nmi_mni_t1mni = mask_nmi_wt1mni_v2525, nmi_mni_boldmni = mask_nmi_wboldmni_v2525, dice = v2525_dice)

rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
  select(sub_id, ses_id, protocol, mean_FD, mean_dvars_initial, surface_holes, nmi_boldt1, nmi_mni_t1mni, nmi_mni_boldmni, nmi_normt1_normbold, dice, dropout_compo_perc10th)
# create mew empty cols
rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
  mutate(visual_qced = NA, qc_criterion = NA, qc_rating = NA, qc_comment = NA, date_qc = NA, suggested_exclusion = NA, reason_exclusion = NA)
rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
  mutate(sub_ses = str_c(sub_id, ses_id, sep = "_"))
  # filter out from old_qc_sheeet those sub_ses that are in rosmap new
old_qc_sheet <- old_qc_sheet %>%
  filter(!sub_ses %in% rosmap_qc_yes_new$sub_ses) %>%
  select(-ratio_dropout)

## add distortion
distortion <- read_csv("/Users/ga0034de/Desktop/v2525_distortion_results.txt")
distortion <- distortion %>%
  separate(col = 1, into = c("sub", "ses", "ratio_distortion"), sep = " ") %>%
  mutate(ratio_distortion = as.numeric(ratio_distortion))
# create sub_ses and merge into rosmap_qc_yes_new
distortion <- distortion %>%
  mutate(sub_ses = str_c(sub, ses, sep = "_")) %>%
  select(sub_ses, ratio_distortion)
rosmap_qc_yes_new <- rosmap_qc_yes_new %>%
  left_join(distortion, by = c("sub_ses" = "sub_ses"))


# add dropout_composite_perc10th to old_qc_sheet
old_qc_sheet <- old_qc_sheet %>%
  left_join(rosmap_qc %>% select(code, dropout_compo_perc10th), by = c("sub_ses" = "code"))
old_qc_sheet <- old_qc_sheet %>%
  inner_join(rosmap_qc %>% select(code, nmi_t1_bold_masked), by = c("sub_ses" = "code")) %>%
  rename(nmi_boldt1 = nmi_t1_bold_masked)
# do a merge
final_qc_sheet <- bind_rows(rosmap_qc_yes_new, old_qc_sheet)
# sort by sub_ses
final_qc_sheet <- final_qc_sheet %>%
  arrange(sub_ses)
#remove sub_ses
final_qc_sheet <- final_qc_sheet %>%
  select(-sub_ses)

# if mean_FD > 0.3, then suggested_exclusion = yes, reason_exclusion = high motion
final_qc_sheet <- final_qc_sheet %>%
  mutate(suggested_exclusion = ifelse(mean_FD > 0.3, "TRUE", suggested_exclusion)) %>%
  mutate(reason_exclusion = ifelse(mean_FD > 0.3, "mean FD greater than 0.3 threshold", reason_exclusion))

# remove row where sub-79692387	ses-1
final_qc_sheet <- final_qc_sheet %>%
  filter(!(sub_id == "sub-79692387" & ses_id == "ses-1"))
# reorder columns
final_qc_sheet <- final_qc_sheet %>%
  select(sub_id, ses_id, protocol, mean_FD, mean_dvars_initial, surface_holes, nmi_boldt1, nmi_mni_t1mni, nmi_mni_boldmni, nmi_normt1_normbold, dice, dropout_compo_perc10th, ratio_distortion, visual_qced, qc_criterion, qc_rating, qc_comment, date_qc, suggested_exclusion, reason_exclusion)
# CHECK FOR NANS
colSums(is.na(final_qc_sheet))

# where visual_qced is NA, write FALSE
final_qc_sheet <- final_qc_sheet %>%
  mutate(visual_qced = ifelse(is.na(visual_qced), "FALSE", visual_qced))
# where sub is sub-86420222 and ses-1, write 0.3 to mean_dvars initial
final_qc_sheet <- final_qc_sheet %>%
  mutate(
    mean_dvars_initial = case_when(
      sub_id == "sub-86420222" & ses_id == "ses-0" ~ 1.174843,
      sub_id == "sub-88495663" & ses_id == "ses-1" ~ 1.008935,
      sub_id == "sub-88961000" & ses_id == "ses-2" ~ 1.031901,
      sub_id == "sub-89292806" & ses_id == "ses-0" ~ 1.077945,
      sub_id == "sub-89835239" & ses_id == "ses-0" ~ 1.002631,
      TRUE ~ mean_dvars_initial
    )
  )

write_csv(final_qc_sheet, "qc_sheet_april2026.csv")

# issue a count of unique sub_ses in final_qc_sheet
length(unique(final_qc_sheet$sub_ses))
ID_yes <- dropout_composite %>%
  select(sub_ses)
# save without header
write_csv(ID_yes, "ID_yes.csv", col_names = FALSE)

rosmap_ids <- read_csv("/Users/ga0034de/Documents/R_projs/R_qc_metrics/ID_list.csv")
rosmap_ids <- rosmap_ids %>%
  mutate(sub_ses = str_c(sub_id, ses_id, sep = "_")) %>%
  right_join(ID_yes, by = c("sub_ses" = "sub_ses"))

rosmap_ids <- rosmap_ids %>%
  select(-sub_ses)
write_csv(rosmap_ids, "ID_yes.csv")

