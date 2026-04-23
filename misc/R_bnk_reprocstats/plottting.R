library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(ggplot2)
library(plotly)
library(rlang)

priority_list <- read_csv("/Users/ga0034de/Documents/R_projs/priority_rosmap/priority_list_withQC.csv")

covg_2511 <- read_tsv("/Users/ga0034de/Documents/R_projs/priority_rosmap/v2511_mean_coverage_156parcels_priorityl.tsv")
# rename second column
covg_2511 <- covg_2511 %>%
  rename(mean_covg_v2511 = 2)


covg_2525 <- read_tsv("/Users/ga0034de/Documents/R_projs/priority_rosmap/v2525_mean_coverage_156parcels_priorityl.tsv")
covg_2525 <- covg_2525 %>%
  rename(mean_covg_v2525 = 2)


# make sub_ses column in priority list
priority_list <- priority_list %>%
  mutate(sub_ses = str_c(sub_id, ses_id, sep = "_"))

# merge coverage data with priority list
priority_list <- priority_list %>%
  left_join(covg_2511, by = "sub_ses") %>%
  left_join(covg_2525, by = "sub_ses")

#save 
write_csv(priority_list, "/Users/ga0034de/Documents/R_projs/priority_rosmap/priority_list_withQC_and_covg.csv")

#######
priority_list |>
  mutate(direction = if_else(mean_covg_v2525 >= mean_covg_v2511, "Increase", "Decrease")) |>
  pivot_longer(
    cols = c(mean_covg_v2511, mean_covg_v2525),
    names_to = "version",
    values_to = "coverage"
  ) |>
  mutate(
    version = recode(version,
                     mean_covg_v2511 = "v2511",
                     mean_covg_v2525 = "v2525"
    ),
    version = factor(version, levels = c("v2511", "v2525"))
  ) |>
  ggplot(aes(x = version, y = coverage, group = sub_ses, color = direction)) +
  geom_line(alpha = 0.5, linewidth = 0.8) +
  geom_point(size = 2) +
  theme_minimal()
#######
count_df <- priority_list |>
  mutate(direction = if_else(mean_covg_v2525 >= mean_covg_v2511, "Increase", "Decrease")) |>
  count(direction)

count_label <- paste(count_df$direction, count_df$n, collapse = "\n")

priority_list |>
  mutate(direction = if_else(mean_covg_v2525 >= mean_covg_v2511, "Increase", "Decrease")) |>
  pivot_longer(
    cols = c(mean_covg_v2511, mean_covg_v2525),
    names_to = "version",
    values_to = "coverage"
  ) |>
  mutate(
    version = recode(version,
                     mean_covg_v2511 = "v2511",
                     mean_covg_v2525 = "v2525"
    ),
    version = factor(version, levels = c("v2511", "v2525"))
  ) |>
  ggplot(aes(x = version, y = coverage, group = sub_ses, color = direction)) +
  geom_line(alpha = 0.5, linewidth = 0.8) +
  geom_point(size = 2) +
  annotate(
    "text",
    x = 2.2,
    y = Inf,
    label = count_label,
    hjust = 0,
    vjust = 1.1,
    size = 4
  ) +
  coord_cartesian(clip = "off") +
  theme_minimal() +
  theme(
    plot.margin = margin(5.5, 40, 5.5, 5.5)
  )



#########
# load nmis

nmi_2525 <- read.table("priority_v2525_nmi_masked.txt", header = TRUE)

# create sub_ses and make it third col
nmi_2525 <- nmi_2525 %>%
  mutate(sub_ses = str_c(sid, session, sep = "_")) %>%
  select(sub_ses, everything())

# nmi = 2* MI / (entropy + entropy)
nmi_2525 <- nmi_2525 %>%
  mutate(nmi_boldt1 = (2 * mattes_t1_bold) / (entropy_t1 + entropy_bold))

nmi_2525 <- nmi_2525 %>%
  mutate(nmi_wt1mni = (2 * mattes_wt1_mni) / (entropy_wt1 + entropy_mni))

nmi_2525 <- nmi_2525 %>%
  mutate(nmi_wboldmni = (2 * mattes_wbold_mni) / (entropy_wbold + entropy_mni))

nmi_2525 <- nmi_2525 %>%
  mutate(mask_nmi_boldt1 = (2 * mask_mattes_t1_bold) / (entropy_t1 + entropy_bold))

nmi_2525 <- nmi_2525 %>%
  mutate(mask_nmi_wt1mni = (2 * mask_mattes_wt1_mni) / (entropy_wt1 + entropy_mni))

nmi_2525 <- nmi_2525 %>%
  mutate(mask_nmi_wboldmni = (2 * mask_mattes_wbold_mni) / (entropy_wbold + entropy_mni))

# select just the first column and the last six
nmi_2525 <- nmi_2525 %>%
  select(sub_ses, nmi_boldt1, nmi_wt1mni, nmi_wboldmni, mask_nmi_boldt1, mask_nmi_wt1mni, mask_nmi_wboldmni)
nmi_2525 <- nmi_2525 %>%
  rename(nmi_boldt1_v2525 = nmi_boldt1,
         nmi_wt1mni_v2525 = nmi_wt1mni,
         nmi_wboldmni_v2525 = nmi_wboldmni,
         mask_nmi_boldt1_v2525 = mask_nmi_boldt1,
         mask_nmi_wt1mni_v2525 = mask_nmi_wt1mni,
         mask_nmi_wboldmni_v2525 = mask_nmi_wboldmni)
write_csv(nmi_2525, "/Users/ga0034de/Documents/R_projs/priority_rosmap/nmi_2525.csv")
nmi_2511 <- read.table("v2511_nmi_masked.txt", header = TRUE)
nmi_2511 <- nmi_2511 %>%
  mutate(sub_ses = str_c(sid, session, sep = "_")) %>%
  select(sub_ses, everything())
nmi_2511 <- nmi_2511 %>%
  mutate(nmi_boldt1 = (2 * mattes_t1_bold) / (entropy_t1 + entropy_bold))

nmi_2511 <- nmi_2511 %>%
  mutate(nmi_wt1mni = (2 * mattes_wt1_mni) / (entropy_wt1 + entropy_mni))

nmi_2511 <- nmi_2511 %>%
  mutate(nmi_wboldmni = (2 * mattes_wbold_mni) / (entropy_wbold + entropy_mni))

nmi_2511 <- nmi_2511 %>%
  mutate(mask_nmi_boldt1 = (2 * mask_mattes_t1_bold) / (entropy_t1 + entropy_bold))

nmi_2511 <- nmi_2511 %>%
  mutate(mask_nmi_wt1mni = (2 * mask_mattes_wt1_mni) / (entropy_wt1 + entropy_mni))

nmi_2511 <- nmi_2511 %>%
  mutate(mask_nmi_wboldmni = (2 * mask_mattes_wbold_mni) / (entropy_wbold + entropy_mni))

# select just the first column and the last six
nmi_2511 <- nmi_2511 %>%
  select(sub_ses, nmi_boldt1, nmi_wt1mni, nmi_wboldmni, mask_nmi_boldt1, mask_nmi_wt1mni, mask_nmi_wboldmni)
nmi_2511 <- nmi_2511 %>%
  rename(nmi_boldt1_v2511 = nmi_boldt1,
         nmi_wt1mni_v2511 = nmi_wt1mni,
         nmi_wboldmni_v2511 = nmi_wboldmni,
         mask_nmi_boldt1_v2511 = mask_nmi_boldt1,
         mask_nmi_wt1mni_v2511 = mask_nmi_wt1mni,
         mask_nmi_wboldmni_v2511 = mask_nmi_wboldmni)

# create new df by merging the two by intersection subses
nmi_df <- inner_join(nmi_2511, nmi_2525, by = "sub_ses")
write_csv(nmi_df, "/Users/ga0034de/Documents/R_projs/priority_rosmap/nmi_comparison_v2511_v2525.csv")
write_csv(dice_df, "/Users/ga0034de/Documents/R_projs/priority_rosmap/dice_comparison_v2511_v2525.csv")
write_csv(count_covg_df, "/Users/ga0034de/Documents/R_projs/priority_rosmap/count_covg_comparison_v2511_v2525.csv")


nmi_df |>
  pivot_longer(
    cols = c(mask_nmi_boldt1_v2511, mask_nmi_boldt1_v2525),
    names_to = "version",
    values_to = "nmi"
  ) |>
  mutate(
    version = recode(version,
                     mask_nmi_boldt1_v2511 = "v2511",
                     mask_nmi_boldt1_v2525 = "v2525"
    ),
    version = factor(version, levels = c("v2511", "v2525"))
  ) |>
  ggplot(aes(x = version, y = nmi)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.5) +
  geom_point(aes(group = sub_ses),
             position = position_jitter(width = 0.05),
             alpha = 0.5) +
  geom_line(aes(group = sub_ses), alpha = 0.2) +
  theme_minimal()

yes_no <- priority_list %>%
  mutate(visual_rating =
    case_when(
      str_detect(`visual QC alignment`, "no") ~ "fail",
      str_detect(`visual QC alignment`, "tissue segmentation mislabeling") ~ "fail",
      str_detect(`visual QC alignment`, "h stripes") ~ "fail",
      str_detect(`visual QC alignment`, "its off") ~ "fail",
      TRUE ~ "pass"
  )) 
yes_no <- yes_no %>%
  select(sub_ses, visual_rating)

# add visual rating to nmi df
nmi_df <- nmi_df %>%
  left_join(yes_no, by = "sub_ses")
#####

masked_outliers <- nmi_df |>
  pivot_longer(
    cols = c(nmi_boldt1_v2511, nmi_boldt1_v2525),
    names_to = "version",
    values_to = "nmi"
  ) |>
  mutate(
    version = recode(version,
                     nmi_boldt1_v2511 = "v2511",
                     nmi_boldt1_v2525 = "v2525"
    )
  ) |>
  group_by(version) |>
  mutate(
    Q1 = quantile(nmi, 0.25, na.rm = TRUE),
    Q3 = quantile(nmi, 0.75, na.rm = TRUE),
    IQR = Q3 - Q1,
    lower = Q1 - 1.5 * IQR,
    upper = Q3 + 1.5 * IQR
  ) |>
  ungroup() |>
  filter(nmi < lower | nmi > upper)
#####
nmi_df |>
  pivot_longer(
    cols = c(mask_nmi_boldt1_v2511, mask_nmi_boldt1_v2525),
    names_to = "version",
    values_to = "nmi"
  ) |>
  mutate(
    version = recode(version,
                     mask_nmi_boldt1_v2511 = "v2511",
                     mask_nmi_boldt1_v2525 = "v2525"
    ),
    version = factor(version, levels = c("v2511", "v2525")),
    
    # only keep rating for "v2525"
    rating_plot = if_else(version == "v2525", visual_rating, NA_character_)
  ) |>
  ggplot(aes(x = version, y = nmi)) +
  
  # boxplot
  geom_boxplot(outlier.shape = NA, alpha = 0.4) +
  
  # paired lines
  geom_line(aes(group = sub_ses), alpha = 0.2) +
  
  # BEFORE points (grey, no legend)
  geom_point(
    data = \(df) dplyr::filter(df, version == "v2511"),
    color = "grey60",
    position = position_jitter(width = 0.05),
    size = 2,
    show.legend = FALSE
  ) +
  
  # AFTER points (colored, with legend)
  geom_point(
    aes(color = rating_plot),
    data = \(df) dplyr::filter(df, version == "v2525"),
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
    y = "Normalized mutual information",
    title = "masked NMI t1-bold before vs after"
  ) +
  
  theme_minimal(base_size = 10) +
  theme(legend.position = "top")

#####
outliers <- nmi_df |>
  pivot_longer(
    cols = c(nmi_boldt1_v2511, nmi_boldt1_v2525),
    names_to = "version",
    values_to = "nmi"
  ) |>
  mutate(
    version = recode(version,
                     nmi_boldt1_v2511 = "v2511",
                     nmi_boldt1_v2525 = "v2525"
    )
  ) |>
  group_by(version) |>
  mutate(
    Q1 = quantile(nmi, 0.25, na.rm = TRUE),
    Q3 = quantile(nmi, 0.75, na.rm = TRUE),
    IQR = Q3 - Q1,
    lower = Q1 - 1.5 * IQR,
    upper = Q3 + 1.5 * IQR
  ) |>
  ungroup() |>
  filter(nmi < lower | nmi > upper)

####
nmi_df |>
  pivot_longer(
    cols = c(nmi_boldt1_v2511, nmi_boldt1_v2525),
    names_to = "version",
    values_to = "nmi"
  ) |>
  mutate(
    version = recode(version,
                     nmi_boldt1_v2511 = "v2511",
                     nmi_boldt1_v2525 = "v2525"
    ),
    version = factor(version, levels = c("v2511", "v2525")),
    
    # only keep rating for "v2525"
    rating_plot = if_else(version == "v2525", visual_rating, NA_character_)
  ) |>
  ggplot(aes(x = version, y = nmi)) +
  
  # boxplot
  geom_boxplot(outlier.shape = NA, alpha = 0.4) +
  
  # paired lines
  geom_line(aes(group = sub_ses), alpha = 0.2) +
  
  # BEFORE points (grey, no legend)
  geom_point(
    data = \(df) dplyr::filter(df, version == "v2511"),
    color = "grey60",
    position = position_jitter(width = 0.05),
    size = 2,
    show.legend = FALSE
  ) +
  
  # AFTER points (colored, with legend)
  geom_point(
    aes(color = rating_plot),
    data = \(df) dplyr::filter(df, version == "v2525"),
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
    y = "Normalized mutual information",
    title = "NMI t1-bold before vs after"
  ) +
  
  theme_minimal(base_size = 10) +
  theme(legend.position = "top")

#########
library(plotly)
    
p <- nmi_df |>
  pivot_longer(
    cols = c(mask_nmi_boldt1_v2511, mask_nmi_boldt1_v2525),
    names_to = "version",
    values_to = "nmi"
  ) |>
  mutate(
    version = recode(version,
                     mask_nmi_boldt1_v2511 = "v2511",
                     mask_nmi_boldt1_v2525 = "v2525"
    ),
    version = factor(version, levels = c("v2511", "v2525")),
    rating_plot = if_else(version == "v2525", visual_rating, NA_character_)
  ) |>
  ggplot(aes(x = version, y = nmi)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.4) +
  geom_line(aes(group = sub_ses), alpha = 0.2) +
  geom_point(
    aes(color = rating_plot, text = sub_ses),  # 👈 THIS is key
    position = position_jitter(width = 0.05),
    size = 2
  ) +
  scale_color_manual(
    values = c("fail" = "#D55E00", "pass" = "#009E73"),
    na.translate = FALSE
  ) +
  theme_minimal()

ggplotly(p, tooltip = "text")
#######



dice_v2525 <- read.table("/Users/ga0034de/Documents/R_projs/priority_rosmap/v2525_dice_results.txt", header = TRUE) %>%
  mutate(sub_ses = str_c(sub_id, ses_id, sep = "_")) %>%
  select(sub_ses, everything()) %>%
  rename(v2525_dice = dice_val) 

dice_v2525 <- dice_v2525 %>%
  select(sub_ses, v2525_dice)

dice_v2511 <- rosmap_qc_priority %>%
  select(code, dice_masks) %>%
  rename(v2511_dice = dice_masks)

#merge the two
dice_df <- inner_join(dice_v2511, dice_v2525, by = c("code" = "sub_ses"))
dice_df <- inner_join(dice_df, yes_no, by = c("code" = "sub_ses"))

dice_df |>
  pivot_longer(
    cols = c(v2511_dice, v2525_dice),
    names_to = "version",
    values_to = "dice"
  ) |>
  mutate(
    version = recode(version,
                     v2511_dice = "v2511",
                     v2525_dice = "v2525"
    ),
    version = factor(version, levels = c("v2511", "v2525")),
    
    # only keep rating for "v2525"
    rating_plot = if_else(version == "v2525", visual_rating, NA_character_)
  ) |>
  ggplot(aes(x = version, y = dice)) +
  
  # boxplot
  geom_boxplot(outlier.shape = NA, alpha = 0.4) +
  
  # paired lines
  geom_line(aes(group = code), alpha = 0.2) +
  
  # BEFORE points (grey, no legend)
  geom_point(
    data = \(df) dplyr::filter(df, version == "v2511"),
    color = "grey60",
    position = position_jitter(width = 0.05),
    size = 2,
    show.legend = FALSE
  ) +
  
  # AFTER points (colored, with legend)
  geom_point(
    aes(color = rating_plot),
    data = \(df) dplyr::filter(df, version == "v2525"),
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
    y = "Dice score",
    title = "dice score binary masks in MNI before vs after"
  ) +
  
  theme_minimal(base_size = 10) +
  theme(legend.position = "top")
#####

p <- dice_df |>
  pivot_longer(
    cols = c(v2511_dice, v2525_dice),
    names_to = "version",
    values_to = "dice"
  ) |>
  mutate(
    version = recode(version,
                     v2511_dice = "v2511",
                     v2525_dice = "v2525"
    ),
    version = factor(version, levels = c("v2511", "v2525")),
    rating_plot = if_else(version == "v2525", visual_rating, NA_character_)
  ) |>
  ggplot(aes(x = version, y = dice)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.4) +
  geom_line(aes(group = code), alpha = 0.2) +
  geom_point(
    aes(color = rating_plot, text = code),  # 👈 THIS is key
    position = position_jitter(width = 0.05),
    size = 2
  ) +
  scale_color_manual(
    values = c("fail" = "#D55E00", "pass" = "#009E73"),
    na.translate = FALSE
  ) +
  theme_minimal()

ggplotly(p, tooltip = "text")

###########################
# functions
###########################
# simple plot
plot_before_after <- function(df, before_col, after_col, id_col,
                                                    y_label = NULL, title = NULL) {
  
  before_name <- as_name(enquo(before_col))
  after_name  <- as_name(enquo(after_col))
  
  df |>
    pivot_longer(
      cols = c({{ before_col }}, {{ after_col }}),
      names_to = "version",
      values_to = "value"
    ) |>
    mutate(
      version = recode(
        version,
        !!before_name := "v2511",
        !!after_name  := "v2525"
      ),
      version = factor(version, levels = c("v2511", "v2525")),
      rating_plot = if_else(version == "v2525", visual_rating, NA_character_)
    ) |>
    ggplot(aes(x = version, y = value)) +
    geom_boxplot(outlier.shape = NA, alpha = 0.4) +
    geom_line(aes(group = {{ id_col }}), alpha = 0.2) +
    geom_point(
      data = \(df) dplyr::filter(df, version == "v2511"),
      color = "grey60",
      position = position_jitter(width = 0.05),
      size = 2,
      show.legend = FALSE
    ) +
    geom_point(
      aes(color = rating_plot),
      data = \(df) dplyr::filter(df, version == "v2525"),
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



######
# interactive plot
#######


plot_before_after_interactive <- function(df,
                                          before_col,
                                          after_col,
                                          id_col,
                                          x_label = NULL,
                                          y_label = NULL,
                                          title = NULL) {
  
  before_name <- as_name(enquo(before_col))
  after_name  <- as_name(enquo(after_col))
  
  p <- df |>
    pivot_longer(
      cols = c({{ before_col }}, {{ after_col }}),
      names_to = "version",
      values_to = "value"
    ) |>
    mutate(
      version = recode(
        version,
        !!before_name := "v2511",
        !!after_name  := "v2525"
      ),
      version = factor(version, levels = c("v2511", "v2525")),
      rating_plot = if_else(version == "v2525", visual_rating, NA_character_)
    ) |>
    ggplot(aes(x = version, y = value)) +
    geom_boxplot(outlier.shape = NA, alpha = 0.4) +
    geom_line(aes(group = {{ id_col }}), alpha = 0.2) +
    geom_point(
      aes(
        color = rating_plot,
        text = paste0(
          "ID: ", {{ id_col }},
          "<br>Version: ", version,
          "<br>Value: ", round(value, 3),
          ifelse(is.na(rating_plot), "", paste0("<br>Rating: ", rating_plot))
        )
      ),
      position = position_jitter(width = 0.05),
      size = 2
    ) +
    scale_color_manual(
      values = c("fail" = "#D55E00", "pass" = "#009E73"),
      name = "Visual rating",
      na.translate = FALSE
    ) +
    labs(
      x = x_label,
      y = y_label,
      title = title
    ) +
    theme_minimal()
  
  ggplotly(p, tooltip = "text")
}



plot_increase_decrease <- function(df, before_col, after_col, id_col,
                                                            y_label = NULL, title = NULL) {
  
  before_name <- as_name(enquo(before_col))
  after_name  <- as_name(enquo(after_col))
  
  # counts
  count_df <- df |>
    mutate(direction = if_else({{ after_col }} >= {{ before_col }},
                               "Increase", "Decrease")) |>
    count(direction)
  
  count_label <- paste(count_df$direction, count_df$n, collapse = "\n")
  
  plot_df <- df |>
    mutate(
      direction = if_else({{ after_col }} >= {{ before_col }},
                          "Increase", "Decrease")
    ) |>
    pivot_longer(
      cols = c({{ before_col }}, {{ after_col }}),
      names_to = "version",
      values_to = "value"
    ) |>
    mutate(
      version = recode(
        version,
        !!before_name := "v2511",
        !!after_name  := "v2525"
      ),
      version = factor(version, levels = c("v2511", "v2525")),
      rating_plot = if_else(version == "v2525", visual_rating, NA_character_)
    )
  
  ggplot(plot_df, aes(x = version, y = value, group = {{ id_col }})) +
    
    # lines = direction
    geom_line(aes(color = direction), alpha = 0.8, linewidth = 0.6) +
    
    # BEFORE points (grey)
    geom_point(
      data = dplyr::filter(plot_df, version == "v2511"),
      color = "grey60",
      size = 1,
      show.legend = FALSE
    ) +
    
    # AFTER points (colored by rating)
    geom_point(
      data = dplyr::filter(plot_df, version == "v2525"),
      aes(color = rating_plot),
      size = 1
    ) +
    
    # combined color scale
    scale_color_manual(
      values = c(
        "Increase" = "#5E7AC4",
        "Decrease" = "#DD9E59",
        "fail" = "#AE2448",
        "pass" = "#009E73"
      ),
      name = NULL,
      na.translate = FALSE
    ) +
    
    annotate(
      "text",
      x = 2.2,
      y = Inf,
      label = count_label,
      hjust = 0,
      vjust = 1.1,
      size = 4
    ) +
    
    coord_cartesian(clip = "off") +
    
    labs(
      x = NULL,
      y = y_label,
      title = title
    ) +
    
    theme_minimal() +
    theme(
      legend.position = "top",
      plot.margin = margin(5.5, 40, 5.5, 5.5)
    )
}

##
# interactive

plot_increase_decrease_interactive <- function(df, before_col, after_col, id_col,
                                               y_label = NULL, title = NULL) {
  
  before_name <- as_name(enquo(before_col))
  after_name  <- as_name(enquo(after_col))
  id_name     <- as_name(enquo(id_col))
  
  count_df <- df |>
    mutate(direction = if_else({{ after_col }} >= {{ before_col }},
                               "Increase", "Decrease")) |>
    count(direction)
  
  count_label <- paste(count_df$direction, count_df$n, collapse = "\n")
  
  plot_df <- df |>
    mutate(
      direction = if_else({{ after_col }} >= {{ before_col }},
                          "Increase", "Decrease")
    ) |>
    pivot_longer(
      cols = c({{ before_col }}, {{ after_col }}),
      names_to = "version",
      values_to = "value"
    ) |>
    mutate(
      version = recode(
        version,
        !!before_name := "v2511",
        !!after_name  := "v2525"
      ),
      version = factor(version, levels = c("v2511", "v2525")),
      rating_plot = if_else(version == "v2525", visual_rating, NA_character_)
    )
  
  p <- ggplot(plot_df, aes(x = version, y = value, group = {{ id_col }})) +
    
    geom_line(
      aes(
        color = direction,
        text = paste0(
          "ID: ", .data[[id_name]],
          "<br>Direction: ", direction
        )
      ),
      alpha = 0.8,
      linewidth = 0.6
    ) +
    
    geom_point(
      data = dplyr::filter(plot_df, version == "v2511"),
      aes(
        text = paste0(
          "ID: ", .data[[id_name]],
          "<br>Version: ", version,
          "<br>Value: ", round(value, 3),
          "<br>Direction: ", direction
        )
      ),
      color = "grey60",
      size = 1,
      show.legend = FALSE
    ) +
    
    geom_point(
      data = dplyr::filter(plot_df, version == "v2525"),
      aes(
        color = rating_plot,
        text = paste0(
          "ID: ", .data[[id_name]],
          "<br>Version: ", version,
          "<br>Value: ", round(value, 3),
          "<br>Direction: ", direction,
          "<br>Visual rating: ", rating_plot
        )
      ),
      size = 1
    ) +
    
    scale_color_manual(
      values = c(
        "Increase" = "#5E7AC4",
        "Decrease" = "#DD9E59",
        "fail" = "#AE2448",
        "pass" = "#009E73"
      ),
      name = NULL,
      na.translate = FALSE
    ) +
    
    annotate(
      "text",
      x = 2.2,
      y = Inf,
      label = count_label,
      hjust = 0,
      vjust = 1.1,
      size = 4
    ) +
    
    coord_cartesian(clip = "off") +
    
    labs(
      x = NULL,
      y = y_label,
      title = title
    ) +
    
    theme_minimal() +
    theme(
      legend.position = "top",
      plot.margin = margin(5.5, 40, 5.5, 5.5)
    )
  
  ggplotly(p, tooltip = "text")
}

#####
# apply

plot_before_after_interactive(
  df = dice_df,
  before_col = v2511_dice,
  after_col = v2525_dice,
  x_label = NULL,
  y_label = "Dice score",
  title = "Dice score before vs after"
)

plot_before_after(
  df = dice_df,
  before_col = v2511_dice,
  after_col = v2525_dice,
  y_label = "Dice score",
  title = "Dice score before vs after"
)

plot_before_after(
  df = nmi_df,
  before_col = mask_nmi_boldt1_v2511,
  after_col = mask_nmi_boldt1_v2525,
  id_col = sub_ses,
  y_label = "Masked NMI t1-bold",
  title = "Masked NMI t1-bold before vs after"
)

plot_before_after(
  df = nmi_df,
  before_col = nmi_wt1mni_v2511,
  after_col = nmi_wt1mni_v2525,
  id_col = sub_ses,
  y_label = "NMI wt1-mni",
  title = "NMI wt1-mni before vs after"
)
plot_before_after_interactive(
  df = nmi_df,
  before_col = nmi_wt1mni_v2511,
  after_col = nmi_wt1mni_v2525,
  id_col = sub_ses,
  y_label = "NMI wt1-mni",
  title = "NMI wt1-mni before vs after"
)

count_covg_v2511 <- read_tsv("v2511_count_non-coverage_156parcels_priorityl.tsv")
count_covg_v2525 <- read_tsv("v2525_count_non-coverage_156parcels_priorityl.tsv")
# merge
count_covg_df <- inner_join(count_covg_v2511, count_covg_v2525, by = "sub_ses") %>%
  rename(count_covg_v2511 = 2,
         count_covg_v2525 = 3)
# add visual rating 
count_covg_df <- count_covg_df %>%
  left_join(yes_no, by = "sub_ses")
plot_before_after(
  df = count_covg_df,
  before_col = count_covg_v2511,
  after_col = count_covg_v2525,
  id_col = sub_ses,
  y_label = "NA parcels count",
  title = "count of NA parcels per ID"
)

plot_increase_decrease(
  df = count_covg_df,
  before_col = count_covg_v2511,
  after_col = count_covg_v2525,
  id_col = sub_ses,
  y_label = "NA parcels count",
  title = "count of NA parcels per ID (NA: < 0.5 of coverage)"
)

plot_increase_decrease_interactive(
  df = count_covg_df,
  before_col = count_covg_v2511,
  after_col = count_covg_v2525,
  id_col = sub_ses,
  y_label = "NA parcels count",
  title = "count of NA parcels per ID (NA: < 0.5 of coverage)"
)

