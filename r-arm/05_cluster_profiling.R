# ==============================================================================
# STEP 5: CLUSTER PROFILING FOR ARM OUTPUT
# ==============================================================================
# Input  : hasil/01_trip_cluster_base.csv, hasil/04_rules_cluster_filtered.csv
# Output : hasil/05_cluster_stats.csv
#          hasil/05_arm_summary.csv
# ==============================================================================

library(readr)
library(dplyr)
library(tidyr)

base_dir <- normalizePath(".", winslash = "/", mustWork = FALSE)
hasil_dir <- file.path(base_dir, "hasil")

path_trip <- file.path(hasil_dir, "01_trip_cluster_base.csv")
path_rules <- file.path(hasil_dir, "04_rules_cluster_filtered.csv")

if (!file.exists(path_trip) || !file.exists(path_rules)) {
    stop("Jalankan STEP 1 dan STEP 4 terlebih dahulu.")
}

cat("=", strrep("=", 66), "\n")
cat("STEP 5: CLUSTER PROFILING FOR ARM OUTPUT\n")
cat("=", strrep("=", 66), "\n\n")

trip <- read_csv(path_trip, show_col_types = FALSE)
rules_cluster <- read_csv(path_rules, show_col_types = FALSE)

cluster_stats <- trip %>%
    group_by(cluster, label = cluster_label) %>%
    summarise(
        n_total = n(),
        n_cross = sum(is_cross, na.rm = TRUE),
        pct_cross = round(100 * n_cross / n_total, 1),
        n_users = n_distinct(payCardID),
        .groups = "drop"
    ) %>%
    arrange(cluster)

arm_summary <- rules_cluster %>%
    group_by(cluster, cluster_label) %>%
    summarise(
        n_rules = n(),
        avg_lift = mean(lift, na.rm = TRUE),
        min_lift = min(lift, na.rm = TRUE),
        max_lift = max(lift, na.rm = TRUE),
        avg_lift_global = mean(lift_global, na.rm = TRUE),
        avg_conf = 100 * mean(confidence, na.rm = TRUE),
        avg_sup = mean(support, na.rm = TRUE),
        min_count = min(count_trip, na.rm = TRUE),
        max_count = max(count_trip, na.rm = TRUE),
        .groups = "drop"
    ) %>%
    rename(cluster_label_raw = cluster_label)

arm_summary_complete <- cluster_stats %>%
    select(cluster, cluster_label = label) %>%
    left_join(arm_summary, by = "cluster") %>%
    mutate(
        cluster_label = coalesce(cluster_label_raw, cluster_label),
        n_rules = replace_na(n_rules, 0L),
        avg_lift = replace_na(avg_lift, 0),
        min_lift = replace_na(min_lift, 0),
        max_lift = replace_na(max_lift, 0),
        avg_lift_global = replace_na(avg_lift_global, 0),
        avg_conf = replace_na(avg_conf, 0),
        avg_sup = replace_na(avg_sup, 0),
        min_count = replace_na(min_count, 0L),
        max_count = replace_na(max_count, 0L)
    ) %>%
    select(
        cluster, cluster_label, n_rules, avg_lift, min_lift, max_lift,
        avg_lift_global, avg_conf, avg_sup, min_count, max_count
    ) %>%
    arrange(cluster)

write_csv(cluster_stats, file.path(hasil_dir, "05_cluster_stats.csv"))
write_csv(arm_summary_complete, file.path(hasil_dir, "05_arm_summary.csv"))

cat("[OK] hasil/05_cluster_stats.csv\n")
cat("[OK] hasil/05_arm_summary.csv\n")

