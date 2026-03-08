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
param_map <- setNames(as.character(filter_params$value), filter_params$parameter)
num_param <- function(key, fallback = 0) {
    v <- suppressWarnings(as.numeric(param_map[[key]]))
    if (is.na(v)) fallback else v
}

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

# Split rules: cross-corridor vs within-corridor (self)
rules_global_cross <- rules_global_out %>% filter(lhs != rhs)
rules_global_self <- rules_global_out %>% filter(lhs == rhs)
rules_cluster_cross <- rules_cluster_out %>% filter(lhs != rhs)
rules_cluster_self <- rules_cluster_out %>% filter(lhs == rhs)

# Raise support threshold for cross-corridor rules to reduce noisy/rare rules in dashboard.
cross_min_support_cluster <- 0.0018
cross_min_support_global <- 0.0012

# Fallback: jika hasil filtered hanya self-rule, isi cross dari raw dengan threshold adaptif.
select_cross_fallback <- function(df, min_count, min_conf, min_lift, target_max = 50, target_min = 30) {
    df_cross <- df %>%
        filter(lhs != rhs, is_connected %in% c(TRUE, 1, "TRUE")) %>%
        mutate(
            score = coalesce(rule_score, lift, 0),
            cnt = coalesce(count_trip, count, 0),
            conf = coalesce(confidence, 0),
            lf = coalesce(lift, 0)
        )

    pick_one <- function(d) {
        strict <- d %>% filter(cnt >= min_count, conf >= min_conf, lf >= min_lift)
        if (nrow(strict) >= target_min) {
            return(strict %>% arrange(desc(score), desc(lf), desc(conf), desc(cnt)) %>% slice_head(n = target_max))
        }
        relaxed <- d %>% filter(cnt >= pmax(1, floor(min_count * 0.5)), conf >= pmax(0.2, min_conf * 0.6), lf >= pmax(1, min_lift * 0.6))
        if (nrow(relaxed) > 0) {
            return(relaxed %>% arrange(desc(score), desc(lf), desc(conf), desc(cnt)) %>% slice_head(n = target_max))
        }
        d %>% arrange(desc(score), desc(lf), desc(conf), desc(cnt)) %>% slice_head(n = target_max)
    }

    if ("cluster" %in% names(df_cross)) {
        df_cross %>%
            group_by(cluster, cluster_label) %>%
            group_modify(~ pick_one(.x)) %>%
            ungroup() %>%
            select(-score, -cnt, -conf, -lf)
    } else {
        pick_one(df_cross) %>% select(-score, -cnt, -conf, -lf)
    }
}

if (nrow(rules_global_cross) == 0 || nrow(rules_cluster_cross) == 0) {
    target_max <- as.integer(num_param("target_max_rules", 50))
    target_min <- as.integer(num_param("target_min_rules", 30))
    rules_global_cross_fb <- select_cross_fallback(
        rules_global_raw,
        min_count = num_param("adaptive_min_count_global", 50),
        min_conf = num_param("adaptive_confidence", 0.65),
        min_lift = num_param("adaptive_lift", 4),
        target_max = target_max,
        target_min = target_min
    ) %>%
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

    rules_cluster_cross_fb <- select_cross_fallback(
        rules_cluster_raw,
        min_count = num_param("adaptive_min_count_cluster", 40),
        min_conf = num_param("adaptive_confidence", 0.65),
        min_lift = num_param("adaptive_lift", 4),
        target_max = target_max,
        target_min = target_min
    ) %>%
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

    if (nrow(rules_global_cross) == 0) rules_global_cross <- rules_global_cross_fb
    if (nrow(rules_cluster_cross) == 0) rules_cluster_cross <- rules_cluster_cross_fb
}

rules_global_cross <- rules_global_cross %>%
    filter(coalesce(support, 0) >= cross_min_support_global)
rules_cluster_cross <- rules_cluster_cross %>%
    filter(coalesce(support, 0) >= cross_min_support_cluster)

arm_summary_cross <- rules_cluster_cross %>%
    group_by(cluster, cluster_label) %>%
    summarise(
        n_rules = n(),
        avg_lift = mean(lift, na.rm = TRUE),
        max_lift = ifelse(all(is.na(lift)), NA_real_, max(lift, na.rm = TRUE)),
        avg_conf = 100 * mean(confidence, na.rm = TRUE),
        avg_sup = mean(support, na.rm = TRUE),
        .groups = "drop"
    ) %>%
    arrange(cluster)

arm_summary_self <- rules_cluster_self %>%
    group_by(cluster, cluster_label) %>%
    summarise(
        n_rules = n(),
        avg_lift = mean(lift, na.rm = TRUE),
        max_lift = max(lift, na.rm = TRUE),
        avg_conf = 100 * mean(confidence, na.rm = TRUE),
        avg_sup = mean(support, na.rm = TRUE),
        .groups = "drop"
    ) %>%
    arrange(cluster)

write_csv(rules_cluster_out, file.path(hasil_dir, "rules_all.csv"))
write_csv(rules_global_out, file.path(hasil_dir, "rules_global.csv"))
write_csv(rules_cluster_cross, file.path(hasil_dir, "rules_all_cross.csv"))
write_csv(rules_global_cross, file.path(hasil_dir, "rules_global_cross.csv"))
write_csv(rules_cluster_self, file.path(hasil_dir, "rules_all_self.csv"))
write_csv(rules_global_self, file.path(hasil_dir, "rules_global_self.csv"))
write_csv(summary_df, file.path(hasil_dir, "arm_summary.csv"))
write_csv(arm_summary_cross, file.path(hasil_dir, "arm_summary_cross.csv"))
write_csv(arm_summary_self, file.path(hasil_dir, "arm_summary_self.csv"))
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
    "rules_all_cross.csv",
    "rules_global_cross.csv",
    "rules_all_self.csv",
    "rules_global_self.csv",
    "arm_summary.csv",
    "arm_summary_cross.csv",
    "arm_summary_self.csv",
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

