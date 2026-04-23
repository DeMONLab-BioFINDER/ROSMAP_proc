library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)

# SCRIPT FOR PLOTTING THE DIFFERENT PROCESSING MADE WITH FREESURF AND FASTSURF WITH OR WITRHOUT BBR

fastsurfer_nobbr2525 <- fastsurf_all %>%
  filter(sub_ses %in% freesurfnobbr_all$sub_ses)
fastsurfer_nobbr2525 <- fastsurfer_nobbr2525 %>%
  mutate(across(-c(1, 2), ~ as.numeric(as.character(.))))

freesurfer_nobbr2525 <- freesurfnobbr_all %>%
  filter(sub_ses %in% fastsurfer_nobbr2525$sub_ses)
freesurfer_nobbr2525 <- freesurfer_nobbr2525 %>%
  mutate(across(-c(1, 2), ~ as.numeric(as.character(.))))

freesurfer_bbr2511 <- freesurf_filtered %>%
  filter(sub_ses %in% freesurfnobbr_all$sub_ses)
freesurfer_bbr2511 <- freesurfer_bbr2511 %>%
  mutate(across(-c(1, 2), ~ as.numeric(as.character(.))))
##########
# dice scores
##########

library(dplyr)
library(ggplot2)

plot_df <- bind_rows(
  freesurfer_bbr2511 |>
    transmute(
      sub_ses,
      version = "freesurfer_bbr2511",
      dice = as.numeric(dice_bbrfreesurf2511)
    ),
  freesurfer_nobbr2525 |>
    transmute(
      sub_ses,
      version = "freesurfer_nobbr2525",
      dice = as.numeric(dice_val_nobbrfreesurf2525)
    ),
  fastsurfer_nobbr2525 |>
    transmute(
      sub_ses,
      version = "fastsurfer_nobbr2525",
      dice = as.numeric(dice_val_fastsurfnobbr2525)
    )
) |>
  mutate(
    version = factor(
      version,
      levels = c("freesurfer_bbr2511", "freesurfer_nobbr2525", "fastsurfer_nobbr2525")
    )
  )

ggplot(plot_df, aes(x = version, y = dice)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.5) +
  geom_point(
    aes(group = sub_ses),
    position = position_jitter(width = 0.05),
    alpha = 0.5
  ) +
  geom_line(aes(group = sub_ses), alpha = 0.2) +
  labs(title = "Dice score across versions (in MNI space)") +
  theme_minimal()

#########
# NMI wt1 mni masked
#########
colnames(fastsurfer_nobbr2525)

df1 <- freesurfer_bbr2511 %>%
  transmute(
    sub_ses,
    freesurfer_bbr2511 = as.numeric(nmi_boldt1_bbrfreesurf2511)
  )

df2 <- freesurfer_nobbr2525 %>%
  transmute(
    sub_ses,
    freesurfer_nobbr2525 = as.numeric(nmi_t1_bold_masked_nobbrfreesurf2525)
  )

df3 <- fastsurfer_nobbr2525 %>%
  transmute(
    sub_ses,
    fastsurfer_nobbr2525 = as.numeric(nmi_t1_bold_masked_fastsurfnobbr2525)
  )
wide_df <- df1 %>%
  full_join(df2, by = "sub_ses") %>%
  full_join(df3, by = "sub_ses")
plot_df <- wide_df %>%
  pivot_longer(
    cols = -sub_ses,
    names_to = "version",
    values_to = "nmi"
  ) %>%
  mutate(
    version = factor(
      version,
      levels = c(
        "freesurfer_bbr2511",
        "freesurfer_nobbr2525",
        "fastsurfer_nobbr2525"
      )
    )
  )
plot_df <- bind_rows(
  freesurfer_bbr2511 |>
    transmute(
      sub_ses,
      version = "freesurfer_bbr2511",
      nmi = as.numeric(nmi_mni_t1mni_bbrfreesurf2511)
    ),
  freesurfer_nobbr2525 |>
    transmute(
      sub_ses,
      version = "freesurfer_nobbr2525",
      nmi = as.numeric(nmi_wt1_mni_masked_nobbrfreesurf2525)
    ),
  fastsurfer_nobbr2525 |>
    transmute(
      sub_ses,
      version = "fastsurfer_nobbr2525",
      nmi = as.numeric(nmi_wt1_mni_masked_fastsurfnobbr2525)
    )
) |>
  mutate(
    version = factor(
      version,
      levels = c("freesurfer_bbr2511", "freesurfer_nobbr2525", "fastsurfer_nobbr2525")
    )
  )

ggplot(plot_df, aes(x = version, y = nmi)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.5) +
  geom_point(
    aes(group = sub_ses),
    position = position_jitter(width = 0.05),
    alpha = 0.5
  ) +
  geom_line(aes(group = sub_ses), alpha = 0.2) +
  labs(title = "nmi_wt1_mni_masked") +
  theme_minimal()

########
# NMI t1 bold 
########
colnames(fastsurfer_nobbr2525)
plot_df <- bind_rows(
  freesurfer_bbr2511 |>
    transmute(
      sub_ses,
      version = "freesurfer_bbr2511",
      nmi = nmi_boldt1_bbrfreesurf2511
    ),
  freesurfer_nobbr2525 |>
    transmute(
      sub_ses,
      version = "freesurfer_nobbr2525",
      nmi = nmi_t1_bold_masked_nobbrfreesurf2525
    ),
  fastsurfer_nobbr2525 |>
    transmute(
      sub_ses,
      version = "fastsurfer_nobbr2525",
      nmi = nmi_t1_bold_masked_fastsurfnobbr2525
    )
) |>
  mutate(
    version = factor(
      version,
      levels = c("freesurfer_bbr2511", "freesurfer_nobbr2525", "fastsurfer_nobbr2525")
    )
  )
ggplot(plot_df, aes(x = version, y = nmi)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.5) +
  geom_point(
    aes(group = sub_ses),
    position = position_jitter(width = 0.05),
    alpha = 0.5
  ) +
  geom_line(aes(group = sub_ses), alpha = 0.2) +
  labs(title = "nmi_t1_bold_masked") +
  theme_minimal()

#########
# NMI wt1 wbold
#########
colnames(freesurfer_nobbr2525)

plot_df <- bind_rows(
  freesurfer_bbr2511 |>
    transmute(
      sub_ses,
      version = "freesurfer_bbr2511",
      nmi = as.numeric(nmi_normt1_normbold_bbrfreesurf2511)
    ),
  freesurfer_nobbr2525 |>
    transmute(
      sub_ses,
      version = "freesurfer_nobbr2525",
      nmi = as.numeric(nmi_wt1_wbold_nobbrfreesurf2525)
    ),
  fastsurfer_nobbr2525 |>
    transmute(
      sub_ses,
      version = "fastsurfer_nobbr2525",
      nmi = as.numeric(nmi_wt1_wbold_fastsurfnobbr2525)
    )
) |>
  mutate(
    version = factor(
      version,
      levels = c("freesurfer_bbr2511", "freesurfer_nobbr2525", "fastsurfer_nobbr2525")
    )
  )
ggplot(plot_df, aes(x = version, y = nmi)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.5) +
  geom_point(
    aes(group = sub_ses),
    position = position_jitter(width = 0.05),
    alpha = 0.5
  ) +
  geom_line(aes(group = sub_ses), alpha = 0.2) +
  labs(title = "nmi_wt1_wbold") +
  theme_minimal()

#######
# dropout
#######
colnames(fastsurfer_nobbr2525)
plot_df <- bind_rows(
  freesurfer_bbr2511 |>
    transmute(
      sub_ses,
      version = "freesurfer_bbr2511",
      dropout = as.numeric(dropout_compo_perc10th_bbrfreesurf2511)
    ),
  freesurfer_nobbr2525 |>
    transmute(
      sub_ses,
      version = "freesurfer_nobbr2525",
      dropout = as.numeric(dropout_compo_perc10th_nobbrfreesurf2525)
    ),
  fastsurfer_nobbr2525 |>
    transmute(
      sub_ses,
      version = "fastsurfer_nobbr2525",
      dropout = as.numeric(dropout_compo_perc10th_fastsurfnobbr2525)
    )
) |>
  mutate(
    version = factor(
      version,
      levels = c("freesurfer_bbr2511", "freesurfer_nobbr2525", "fastsurfer_nobbr2525")
    )
  )
ggplot(plot_df, aes(x = version, y = dropout)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.5) +
  geom_point(
    aes(group = sub_ses),
    position = position_jitter(width = 0.05),
    alpha = 0.5
  ) +
  geom_line(aes(group = sub_ses), alpha = 0.2) +
  labs(title = "dropout composite score") +
  theme_minimal()


#####
count_fsnobbr <- read.delim("~/Desktop/freesurfnobbr_count_non-coverage_156parcels_priorityl.tsv")

count_covg_df <- count_covg_df %>%
  left_join(yes_no, by = "sub_ses")

count_covg_df_2 <- count_covg_df %>%
  right_join(count_fsnobbr, by = "sub_ses")
# rename 
count_covg_df_2 <- count_covg_df_2 %>%
  rename(
    count_covg_bbrfreesurf2511 = count_covg_v2511,
    count_covg_bbrfreesurf2525 = count_covg_v2525,
    count_covg_nobbrfreesurf2525 = zero_count
  )

plot_before_after(
  df = count_covg_df,
  before_col = count_covg_v2511,
  after_col = count_covg_v2525,
  id_col = sub_ses,
  y_label = "NA parcels count",
  title = "count of NA parcels per ID"
)

plot_before_after <- function(df, before_col, middle_col, after_col, id_col,
                              y_label = NULL, title = NULL) {
  
  before_name <- as_name(enquo(before_col))
  middle_name <- as_name(enquo(middle_col))
  after_name  <- as_name(enquo(after_col))
  
  df |>
    pivot_longer(
      cols = c({{ before_col }}, {{ middle_col }}, {{ after_col }}),
      names_to = "version",
      values_to = "value"
    ) |>
    mutate(
      version = recode(
        version,
        !!before_name := "bbr_v2511",
        !!middle_name := "bbr_v2525",
        !!after_name  := "nobbr_v2525"
      ),
      version = factor(version, levels = c("bbr_v2511", "bbr_v2525", "nobbr_v2525")),
      rating_plot = if_else(version == "v2525", visual_rating, NA_character_)
    ) |>
    ggplot(aes(x = version, y = value)) +
    geom_boxplot(outlier.shape = NA, alpha = 0.4) +
    geom_line(aes(group = {{ id_col }}), alpha = 0.2) +
    geom_point(
      data = \(df) dplyr::filter(df, version %in% c("bbr_v2511", "bbr_v2525")),
      color = "grey60",
      position = position_jitter(width = 0.05),
      size = 2,
      show.legend = FALSE
    ) +
    geom_point(
      aes(color = rating_plot),
      data = \(df) dplyr::filter(df, version == "nobbr_v2525"),
      position = position_jitter(width = 0.05),
      size = 2,
      alpha = 0.9
    ) +
    scale_color_manual(
      values = c("fail" = "#D55E00", "pass" = "#009E73"),
      name = "Visual rating",
      na.translate = FALSE
    ) +
    labs(
      x = NULL,
      y = y_label,
      title = title
    ) +
    theme_minimal(base_size = 10) +
    theme(legend.position = "top")
}

plot_before_after(
  df = count_covg_df_2,
  before_col = count_covg_bbrfreesurf2511,
  middle_col = count_covg_bbrfreesurf2525,
  after_col = count_covg_nobbrfreesurf2525,
  id_col = sub_ses,
  y_label = "NA parcels count",
  title = "count of NA parcels per ID"
)
