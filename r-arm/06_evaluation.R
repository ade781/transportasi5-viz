# ==============================================================================
# STEP 6: EVALUATION METRICS
# ==============================================================================
# Input  : hasil/02_transactions_connected.csv
#          hasil/03_rules_global_raw.csv
#          hasil/04_rules_global_filtered.csv
#          hasil/04_rules_cluster_filtered.csv
#          hasil/05_cluster_stats.csv
# Output : hasil/06_arm_evaluation.csv
#          hasil/06_arm_evaluation_cluster.csv
# ==============================================================================

library(readr)
library(dplyr)
library(tidyr)

base_dir <- normalizePath(".", winslash = "/", mustWork = FALSE)
hasil_dir <- file.path(base_dir, "hasil")

path_tx <- file.path(hasil_dir, "02_transactions_connected.csv")
path_raw_global <- file.path(hasil_dir, "03_rules_global_raw.csv")
path_sel_global <- file.path(hasil_dir, "04_rules_global_filtered.csv")
path_sel_cluster <- file.path(hasil_dir, "04_rules_cluster_filtered.csv")
path_cluster_stats <- file.path(hasil_dir, "05_cluster_stats.csv")

required <- c(path_tx, path_raw_global, path_sel_global, path_sel_cluster, path_cluster_stats)
if (any(!file.exists(required))) stop("Jalankan STEP 1-5 terlebih dahulu.")

cat("=", strrep("=", 66), "\n")
cat("STEP 6: EVALUATION METRICS\n")
cat("=", strrep("=", 66), "\n\n")

tx <- read_csv(path_tx, show_col_types = FALSE)
raw_global <- read_csv(path_raw_global, show_col_types = FALSE)
sel_global <- read_csv(path_sel_global, show_col_types = FALSE)
sel_cluster <- read_csv(path_sel_cluster, show_col_types = FALSE)
cluster_stats <- read_csv(path_cluster_stats, show_col_types = FALSE)

selected_pair_global <- sel_global %>% distinct(lhs, rhs)
covered_global <- tx %>% semi_join(selected_pair_global, by = c("lhs", "rhs"))

eval_global <- tibble(
    metric = c(
        "connected_trip_total",
        "pair_candidate_total",
        "rules_selected_global",
        "rule_compression_ratio",
        "trip_coverage_by_rules_pct",
        "lhs_coverage_pct",
        "avg_support_global_pct",
        "avg_support_local_pct",
        "avg_support_degree_adj",
        "avg_lift_local",
        "median_lift_local",
        "avg_lift_global"
    ),
    value = c(
        nrow(tx),
        nrow(raw_global),
        nrow(sel_global),
        ifelse(nrow(raw_global) > 0, nrow(sel_global) / nrow(raw_global), 0),
        ifelse(nrow(tx) > 0, 100 * nrow(covered_global) / nrow(tx), 0),
        ifelse(n_distinct(tx$lhs) > 0,
               100 * n_distinct(selected_pair_global$lhs) / n_distinct(tx$lhs), 0),
        mean(sel_global$support, na.rm = TRUE) * 100,
        mean(sel_global$support_local, na.rm = TRUE) * 100,
        mean(sel_global$support_degree_adj, na.rm = TRUE),
        mean(sel_global$lift, na.rm = TRUE),
        median(sel_global$lift, na.rm = TRUE),
        mean(sel_global$lift_global, na.rm = TRUE)
    )
)

eval_cluster <- cluster_stats %>%
    transmute(cluster, cluster_label = label) %>%
    rowwise() %>%
    do({
        cl <- .$cluster
        cl_label <- .$cluster_label

        tx_cl <- tx %>% filter(cluster == cl)
        rules_cl <- sel_cluster %>% filter(cluster == cl)
        pair_cl <- rules_cl %>% distinct(lhs, rhs)
        covered_cl <- tx_cl %>% semi_join(pair_cl, by = c("lhs", "rhs"))

        tibble(
            cluster = cl,
            cluster_label = cl_label,
            rules_selected = nrow(rules_cl),
            avg_support_global_pct = mean(rules_cl$support, na.rm = TRUE) * 100,
            avg_support_local_pct = mean(rules_cl$support_local, na.rm = TRUE) * 100,
            avg_support_degree_adj = mean(rules_cl$support_degree_adj, na.rm = TRUE),
            avg_lift_local = mean(rules_cl$lift, na.rm = TRUE),
            median_lift_local = median(rules_cl$lift, na.rm = TRUE),
            avg_lift_global = mean(rules_cl$lift_global, na.rm = TRUE),
            connected_trip_total = nrow(tx_cl),
            covered_trip = nrow(covered_cl),
            trip_coverage_pct = ifelse(nrow(tx_cl) > 0, 100 * nrow(covered_cl) / nrow(tx_cl), 0)
        )
    }) %>%
    ungroup() %>%
    mutate(across(where(is.numeric), ~ ifelse(is.nan(.x), 0, .x)))

write_csv(eval_global, file.path(hasil_dir, "06_arm_evaluation.csv"))
write_csv(eval_cluster, file.path(hasil_dir, "06_arm_evaluation_cluster.csv"))

cat("[OK] hasil/06_arm_evaluation.csv\n")
cat("[OK] hasil/06_arm_evaluation_cluster.csv\n")

