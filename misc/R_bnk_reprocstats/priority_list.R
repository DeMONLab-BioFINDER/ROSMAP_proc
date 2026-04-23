library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)


priority_list <- read_csv("priorityList.txt")
ID_list <- read_csv("ID_list.csv")

priority_list <- priority_list %>%
  left_join(ID_list, by = c("priorityList" = "scandate_visit_projID"))

ders_list <- read_csv("/Volumes/research/LU26D1023-DemonLab/DemonLab/ROSMAP/derivatives/metadata/derivatives_list.csv")

priority_list <- priority_list %>%
  left_join(ders_list, by = c("priorityList" = "scandate_visit_projID", "sub_id" = "sub_id", "ses_id" = "ses_id")) %>%
  select(priorityList, sub_id, ses_id, site, protocol)

sourcedata_list <- priority_list %>%
  mutate(sub_ses = str_c(sub_id, ses_id, sep = "_")) %>%
  select(sub_ses)
write_csv(sourcedata_list, "sourcedata_list.csv")

babs_list <- priority_list %>%
  select(sub_id, ses_id)
write_csv(babs_list, "babs_list.csv")

write.csv(priority_list, "priority_list.csv", row.names = FALSE)

# merge sourcedata_list with rosmap_qc
rosmap_qc <- read_csv("Rosmap_QC_metrics.csv")
rosmap_qc_priority <- rosmap_qc %>%
  right_join(sourcedata_list, by = c("code" = "sub_ses"))

median(rosmap_qc_priority$nmi_t1_bold_masked, na.rm = TRUE)
