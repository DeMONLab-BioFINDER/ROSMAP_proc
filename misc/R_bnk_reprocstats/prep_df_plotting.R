library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)

######
## !!!!! should include also those that failed fastsurfers recon, their metrics!!!
######## 
# FASTSURFER NO-BBR 2525
########

fastsurf_nmi_norm <- read_csv("~/Desktop/priority_fastsurf_v2525_nmi_norm.txt")
fastsurf_nmi_masked <- read_csv("~/Desktop/priority_v2525_fastsurf_nmi_masked.txt")
fastsurf_dropout10 <- read_csv("~/Desktop/dropout10_new_fastsurf_priority.txt")
fastsurf_dice <- read_csv("~/Desktop/v2525fastsurf_dice_results.txt")

# merge all
fastsurf_all <- fastsurf_nmi_norm %>%
  inner_join(fastsurf_nmi_masked, by = c("sid", "session")) %>%
  inner_join(fastsurf_dropout10, by = c("sid" = "sub", "session" = "ses")) %>%
  inner_join(fastsurf_dice, by = c("sid" = "sub_id", "session" = "ses_id"))

fastsurf_all <- fastsurf_all %>%
  select(-c("entropy_wt1.y", "entropy_wbold.y")) %>%
  rename(entropy_wt1 = entropy_wt1.x, entropy_wbold = entropy_wbold.x)

colnames(fastsurf_all)

# make all columns numeric
fastsurf_all <- fastsurf_all %>%
  mutate(across(-c(1, 2), ~ as.numeric(as.character(.))))

fastsurf_all <- fastsurf_all %>%
  mutate(nmi_wt1_wbold = (2 * mattes_wt1_wbold) / (entropy_wt1 + entropy_wbold)) %>%
  mutate(nmi_wt1_mni = (2 * mattes_wt1_mni) / (entropy_wt1 + entropy_mni)) %>%
  mutate(nmi_wbold_mni = (2 * mattes_wbold_mni) / (entropy_wbold + entropy_mni)) %>%
  mutate(nmi_wt1_mni_masked = (2 * mask_mattes_wt1_mni) / (entropy_wt1 + entropy_mni)) %>%
  mutate(nmi_wbold_mni_masked = (2 * mask_mattes_wbold_mni) / (entropy_wbold + entropy_mni)) %>%
  mutate(nmi_t1_bold = (2 * mattes_t1_bold) / (entropy_t1 + entropy_bold)) %>%
  mutate(nmi_t1_bold_masked = (2 * mask_mattes_t1_bold) / (entropy_t1 + entropy_bold))
  
#compute dropout comp
#make all numeric
fastsurf_all <- fastsurf_all %>%
  mutate(volume_gm = as.numeric(volume_gm),
         nvox_gm = as.numeric(nvox_gm),
         intensity_gm = as.numeric(intensity_gm),
         volume_dropout = as.numeric(volume_dropout),
         nvox_dropout = as.numeric(nvox_dropout),
         intensity_dropout = as.numeric(intensity_dropout))

fastsurf_all <- fastsurf_all %>%
  mutate(dropout_intensity_perc10th=intensity_dropout/intensity_gm, dropout_ratio_perc10th=volume_dropout/volume_gm) %>%
  mutate(dropout_compo_perc10th = (1 - dropout_intensity_perc10th) + dropout_ratio_perc10th)

colnames(fastsurf_all)
fastsurf_all <- fastsurf_all %>%
  select(sid, session, dice_val, nmi_wt1_wbold, nmi_wt1_mni, nmi_wbold_mni, nmi_wt1_mni_masked, nmi_wbold_mni_masked, nmi_t1_bold, nmi_t1_bold_masked, dropout_compo_perc10th)

fastsurf_all <- fastsurf_all %>%
  mutate(sub_ses = str_c(sid, session, sep = "_"))
fastsurf_all <- fastsurf_all %>%
  select(-c(sid, session)) %>%
  relocate(sub_ses)
 
colnames(fastsurf_all)

fastsurf_all <- fastsurf_all %>%
  rename_with(~ paste0(.x, "_fastsurfnobbr2525"), -c(1))

# fastsurf_all <- fastsurf_all %>%
#   select(-c(nmi_wt1_mni_fastsurfnobbr2525, nmi_wbold_mni_fastsurfnobbr2525, nmi_t1_bold_fastsurfnobbr2525))

##############
# FREESURFER BBR 2511
##############
# aka the first version of processing. Found in the qc sheet I sent out

freesurf <- read_csv("qc_spreadsheet_beta_april2026.csv")
freesurf <- freesurf %>%
  mutate(sub_ses = str_c(sub_id, ses_id, sep = "_"))
freesurf_filtered <- freesurf %>%
  filter(sub_ses %in% fastsurf_all$sub_ses)
# delete duplicates
freesurf_filtered <- freesurf_filtered %>%
  distinct(sub_ses, .keep_all = TRUE)

freesurf_filtered <- freesurf_filtered %>%
  rename_with(~ paste0(.x, "_bbrfreesurf2511"), -c(1))

colnames(freesurf_filtered)

freesurf_filtered <- freesurf_filtered %>%
  select(sub_ses_bbrfreesurf2511, c(7:12))
# rename sub_ses
freesurf_filtered <- freesurf_filtered %>%
  rename(sub_ses = sub_ses_bbrfreesurf2511)

##########
# FREESURFER NO BBR 2525
##########

freesurfnobbr_nmi_norm <- read_csv("~/Desktop/priority_freesurfnobbr_v2525_nmi_norm.txt")
freesurfnobbr_nmi_masked <- read_csv("~/Desktop/priority_v2525_freesurfnobbr_nmi_masked.txt")
freesurfnobbr_dropout10 <- read_csv("/Users/ga0034de/Desktop/dropout10_new_freesurfnobbr_priority.txt")
freesurfnobbr_dice <- read_csv("~/Desktop/v2525freesurfnobbr_dice_results.txt")

# merge all
freesurfnobbr_all <- freesurfnobbr_nmi_norm %>%
  inner_join(freesurfnobbr_nmi_masked, by = c("sid", "session")) %>%
  inner_join(freesurfnobbr_dropout10, by = c("sid" = "sub", "session" = "ses")) %>%
  inner_join(freesurfnobbr_dice, by = c("sid" = "sub_id", "session" = "ses_id"))

freesurfnobbr_all <- freesurfnobbr_all %>%
  select(-c("entropy_wt1.y", "entropy_wbold.y")) %>%
  rename(entropy_wt1 = entropy_wt1.x, entropy_wbold = entropy_wbold.x)

colnames(freesurfnobbr_all)

# make all columns numeric
freesurfnobbr_all <- freesurfnobbr_all %>%
  mutate(across(-c(1, 2), ~ as.numeric(as.character(.))))

freesurfnobbr_all <- freesurfnobbr_all %>%
  mutate(nmi_wt1_wbold = (2 * mattes_wt1_wbold) / (entropy_wt1 + entropy_wbold)) %>%
  mutate(nmi_wt1_mni = (2 * mattes_wt1_mni) / (entropy_wt1 + entropy_mni)) %>%
  mutate(nmi_wbold_mni = (2 * mattes_wbold_mni) / (entropy_wbold + entropy_mni)) %>%
  mutate(nmi_wt1_mni_masked = (2 * mask_mattes_wt1_mni) / (entropy_wt1 + entropy_mni)) %>%
  mutate(nmi_wbold_mni_masked = (2 * mask_mattes_wbold_mni) / (entropy_wbold + entropy_mni)) %>%
  mutate(nmi_t1_bold = (2 * mattes_t1_bold) / (entropy_t1 + entropy_bold)) %>%
  mutate(nmi_t1_bold_masked = (2 * mask_mattes_t1_bold) / (entropy_t1 + entropy_bold))

#compute dropout comp
#make all numeric
freesurfnobbr_all <- freesurfnobbr_all %>%
  mutate(volume_gm = as.numeric(volume_gm),
         nvox_gm = as.numeric(nvox_gm),
         intensity_gm = as.numeric(intensity_gm),
         volume_dropout = as.numeric(volume_dropout),
         nvox_dropout = as.numeric(nvox_dropout),
         intensity_dropout = as.numeric(intensity_dropout))

freesurfnobbr_all <- freesurfnobbr_all %>%
  mutate(dropout_intensity_perc10th=intensity_dropout/intensity_gm, dropout_ratio_perc10th=volume_dropout/volume_gm) %>%
  mutate(dropout_compo_perc10th = (1 - dropout_intensity_perc10th) + dropout_ratio_perc10th)

colnames(freesurfnobbr_all)
freesurfnobbr_all <- freesurfnobbr_all %>%
  select(sid, session, dice_val, nmi_wt1_wbold, nmi_wt1_mni, nmi_wbold_mni, nmi_wt1_mni_masked, nmi_wbold_mni_masked, nmi_t1_bold, nmi_t1_bold_masked, dropout_compo_perc10th)

freesurfnobbr_all <- freesurfnobbr_all %>%
  mutate(sub_ses = str_c(sid, session, sep = "_"))
freesurfnobbr_all <- freesurfnobbr_all %>%
  select(-c(sid, session)) %>%
  relocate(sub_ses)

freesurfnobbr_all <- freesurfnobbr_all %>%
  rename_with(~ paste0(.x, "_nobbrfreesurf2525"), -c(1))

