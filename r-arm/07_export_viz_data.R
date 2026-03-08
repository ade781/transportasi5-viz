# ==============================================================================
# STEP 7: EXPORT ARM FILES FOR DASHBOARD
# ==============================================================================
# Input  : hasil/04_rules_global_filtered.csv
#          hasil/04_rules_cluster_filtered.csv
#          hasil/04_filter_params.csv
#          hasil/05_arm_summary.csv
#          hasil/05_cluster_stats.csv
#          hasil/06_arm_evaluation.csv
#          hasil/06_arm_evaluation_cluster.csv
# Output : hasil/rules_all.csv
#          hasil/rules_global.csv
#          hasil/arm_summary.csv
#          hasil/arm_evaluation.csv
#          hasil/arm_evaluation_cluster.csv
#          hasil/cluster_stats.csv
#          hasil/arm_filter_params.csv
#          viz-app/public/data/*.csv (copied)
# ==============================================================================

library(readr)
library(dplyr)

base_dir <- normalizePath(".", winslash = "/", mustWork = FALSE)
project_root <- normalizePath(file.path(base_dir, ".."), winslash = "/", mustWork = FALSE)
hasil_dir <- file.path(base_dir, "hasil")

path_rules_global <- file.path(hasil_dir, "04_rules_global_filtered.csv")
path_rules_cluster <- file.path(hasil_dir, "04_rules_cluster_filtered.csv")
path_rules_global_raw <- file.path(hasil_dir, "03_rules_global_raw.csv")
path_rules_cluster_raw <- file.path(hasil_dir, "03_rules_cluster_raw.csv")
path_filter_params <- file.path(hasil_dir, "04_filter_params.csv")
path_summary <- file.path(hasil_dir, "05_arm_summary.csv")
path_cluster_stats <- file.path(hasil_dir, "05_cluster_stats.csv")
path_eval <- file.path(hasil_dir, "06_arm_evaluation.csv")
path_eval_cluster <- file.path(hasil_dir, "06_arm_evaluation_cluster.csv")
path_connectivity <- file.path(hasil_dir, "01_corridor_connectivity.csv")

required <- c(
    path_rules_global, path_rules_cluster, path_rules_global_raw, path_rules_cluster_raw, path_filter_params,
    path_summary, path_cluster_stats, path_eval, path_eval_cluster, path_connectivity
)
if (any(!file.exists(required))) stop("Jalankan STEP 4-6 terlebih dahulu.")

ensure_cols <- function(df, cols) {
    for (nm in cols) {
        if (!nm %in% names(df)) df[[nm]] <- NA
    }
    df %>% select(all_of(cols))
}

cat("=", strrep("=", 66), "\n")
cat("STEP 7: EXPORT ARM FILES FOR DASHBOARD\n")
cat("=", strrep("=", 66), "\n\n")

rules_global <- read_csv(path_rules_global, show_col_types = FALSE)
rules_cluster <- read_csv(path_rules_cluster, show_col_types = FALSE)
rules_global_raw <- read_csv(path_rules_global_raw, show_col_types = FALSE)
rules_cluster_raw <- read_csv(path_rules_cluster_raw, show_col_types = FALSE)
filter_params <- read_csv(path_filter_params, show_col_types = FALSE)
summary_df <- read_csv(path_summary, show_col_types = FALSE)
cluster_stats <- read_csv(path_cluster_stats, show_col_types = FALSE)
eval_df <- read_csv(path_eval, show_col_types = FALSE)
eval_cluster_df <- read_csv(path_eval_cluster, show_col_types = FALSE)

rules_global_out <- rules_global %>%
    mutate(
        count = count_trip,
        count_global = count_trip,
        count_trips_global = count_trip,
        is_connected = TRUE
    ) %>%
    ensure_cols(c(
        "lhs", "rhs", "n_shared_stops", "count_trip", "lhs_trip_count", "rhs_trip_count",
        "lhs_degree", "rhs_neighbor_total", "support", "support_global", "confidence",
        "support_local", "support_degree_adj", "coverage", "rhs_prob_global", "rhs_prob_local",
        "expected_local_count", "lift_global", "lift_local", "p_value_local", "lift",
        "rule_score", "is_connected", "count", "count_global", "count_trips_global", "q_value_local"
    ))

rules_cluster_out <- rules_cluster %>%
    mutate(
        count = count_trip,
        count_trips = count_trip,
        is_connected = TRUE
    ) %>%
    ensure_cols(c(
        "lhs", "rhs", "n_shared_stops", "count_trip", "lhs_trip_count", "rhs_trip_count",
        "lhs_degree", "rhs_neighbor_total", "support", "support_global", "confidence",
        "support_local", "support_degree_adj", "coverage", "rhs_prob_global", "rhs_prob_local",
        "expected_local_count", "lift_global", "lift_local", "p_value_local", "lift",
        "rule_score", "count", "count_trips", "cluster", "cluster_label",
        "n_trip_cluster", "is_connected", "q_value_local"
    ))

cluster_stats_out <- cluster_stats %>%
    ensure_cols(c("cluster", "label", "n_total", "n_cross", "pct_cross", "n_users"))

write_csv(rules_cluster_out, file.path(hasil_dir, "rules_all.csv"))
write_csv(rules_global_out, file.path(hasil_dir, "rules_global.csv"))
write_csv(summary_df, file.path(hasil_dir, "arm_summary.csv"))
write_csv(eval_df, file.path(hasil_dir, "arm_evaluation.csv"))
write_csv(eval_cluster_df, file.path(hasil_dir, "arm_evaluation_cluster.csv"))
write_csv(cluster_stats_out, file.path(hasil_dir, "cluster_stats.csv"))
write_csv(filter_params, file.path(hasil_dir, "arm_filter_params.csv"))
write_csv(read_csv(path_connectivity, show_col_types = FALSE), file.path(hasil_dir, "arm_corridor_connectivity.csv"))
write_csv(
    rules_global_raw %>% select(lhs, rhs, support, confidence, lift = lift_local, count_trip),
    file.path(hasil_dir, "arm_rules_global_raw_min.csv")
)
write_csv(
    rules_cluster_raw %>% select(cluster, lhs, rhs, support, confidence, lift = lift_local, count_trip),
    file.path(hasil_dir, "arm_rules_cluster_raw_min.csv")
)

# Sync to viz-app
viz_data_dir <- file.path(project_root, "viz-app", "public", "data")
if (!dir.exists(viz_data_dir)) dir.create(viz_data_dir, recursive = TRUE)

files_to_copy <- c(
    "rules_all.csv",
    "rules_global.csv",
    "arm_summary.csv",
    "arm_evaluation.csv",
    "arm_evaluation_cluster.csv",
    "cluster_stats.csv",
    "arm_filter_params.csv",
    "arm_corridor_connectivity.csv",
    "arm_rules_global_raw_min.csv",
    "arm_rules_cluster_raw_min.csv"
)

for (f in files_to_copy) {
    from <- file.path(hasil_dir, f)
    to <- file.path(viz_data_dir, f)
    file.copy(from, to, overwrite = TRUE)
}

# Optional sync to dist if already exists
viz_dist_dir <- file.path(project_root, "viz-app", "dist", "data")
if (dir.exists(viz_dist_dir)) {
    for (f in files_to_copy) {
        file.copy(file.path(hasil_dir, f), file.path(viz_dist_dir, f), overwrite = TRUE)
    }
}

cat("[OK] File ARM final tersimpan di hasil/\n")
cat("[OK] File ARM disinkronkan ke viz-app/public/data/\n")
if (dir.exists(viz_dist_dir)) cat("[OK] File ARM disinkronkan ke viz-app/dist/data/\n")

