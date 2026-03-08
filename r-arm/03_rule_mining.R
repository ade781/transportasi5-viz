# ==============================================================================
# STEP 3: RAW RULE MINING METRICS (GLOBAL + PER CLUSTER)
# ==============================================================================
# Input  : hasil/02_transactions_connected.csv, hasil/01_corridor_connectivity.csv
# Output : hasil/03_rules_global_raw.csv
#          hasil/03_rules_cluster_raw.csv
# ==============================================================================

library(readr)
library(dplyr)
library(tidyr)

base_dir <- normalizePath(".", winslash = "/", mustWork = FALSE)
hasil_dir <- file.path(base_dir, "hasil")

path_tx <- file.path(hasil_dir, "02_transactions_connected.csv")
path_conn <- file.path(hasil_dir, "01_corridor_connectivity.csv")

if (!file.exists(path_tx)) stop("Jalankan 02_prepare_transactions.R terlebih dahulu.")
if (!file.exists(path_conn)) stop("Jalankan 01_load_data.R terlebih dahulu.")

compute_rule_metrics <- function(df, connectivity) {
    if (nrow(df) == 0) return(tibble())

    n_total <- nrow(df)
    local_alpha <- 1
    corridors <- sort(unique(c(df$lhs, df$rhs)))
    connectivity_with_self <- bind_rows(
        connectivity %>% select(lhs, rhs),
        tibble(lhs = corridors, rhs = corridors)
    ) %>%
        distinct(lhs, rhs)

    pair_counts <- df %>%
        count(lhs, rhs, n_shared_stops, name = "count_trip")

    lhs_counts <- df %>% count(lhs, name = "lhs_trip_count")
    rhs_counts <- df %>% count(rhs, name = "rhs_trip_count")

    lhs_degree <- connectivity %>%
        distinct(lhs, rhs) %>%
        count(lhs, name = "lhs_degree")

    rhs_neighbor_totals <- connectivity_with_self %>%
        distinct(lhs, rhs_neighbor = rhs) %>%
        left_join(
            rhs_counts %>% rename(rhs_neighbor = rhs, rhs_neighbor_trip_total = rhs_trip_count),
            by = "rhs_neighbor"
        ) %>%
        group_by(lhs) %>%
        summarise(rhs_neighbor_total = sum(replace_na(rhs_neighbor_trip_total, 0)), .groups = "drop")

    rules <- pair_counts %>%
        left_join(lhs_counts, by = "lhs") %>%
        left_join(rhs_counts, by = "rhs") %>%
        left_join(lhs_degree, by = "lhs") %>%
        left_join(rhs_neighbor_totals, by = "lhs") %>%
        mutate(
            lhs_degree = replace_na(lhs_degree, 0L),
            rhs_neighbor_total = replace_na(rhs_neighbor_total, 0),
            support = count_trip / n_total,
            support_global = support,
            confidence = if_else(lhs_trip_count > 0, count_trip / lhs_trip_count, NA_real_),
            # Local support: proporsi rule terhadap total trip pada neighborhood
            # koridor yang terhubung dengan LHS (bukan terhadap seluruh data).
            support_local = if_else(rhs_neighbor_total > 0, count_trip / rhs_neighbor_total, NA_real_),
            support_degree_adj = support_local * lhs_degree,
            coverage = lhs_trip_count / n_total,
            rhs_prob_global = rhs_trip_count / n_total,
            rhs_prob_local = if_else(
                rhs_neighbor_total > 0,
                (rhs_trip_count + local_alpha) / (rhs_neighbor_total + pmax(lhs_degree, 1) * local_alpha),
                NA_real_
            ),
            expected_local_count = lhs_trip_count * rhs_prob_local,
            lift_global = if_else(rhs_prob_global > 0, confidence / rhs_prob_global, NA_real_),
            # Keep local lift consistent with conditional rule strength:
            # confidence compared to local baseline probability of RHS.
            lift_local = if_else(rhs_prob_local > 0, confidence / rhs_prob_local, NA_real_),
            p_value_local = if_else(
                !is.na(rhs_prob_local),
                pbinom(
                    q = pmax(count_trip - 1, 0),
                    size = pmax(lhs_trip_count, 1),
                    prob = pmax(pmin(rhs_prob_local, 1), 0),
                    lower.tail = FALSE
                ),
                NA_real_
            ),
            q_value_local = p.adjust(p_value_local, method = "BH"),
            lift = lift_local,
            rule_score = support_degree_adj * lift * log1p(count_trip),
            is_connected = TRUE,
            count = count_trip
        ) %>%
        arrange(desc(rule_score), desc(count_trip))

    rules
}

cat("=", strrep("=", 66), "\n")
cat("STEP 3: RAW RULE MINING METRICS (GLOBAL + PER CLUSTER)\n")
cat("=", strrep("=", 66), "\n\n")

tx <- read_csv(path_tx, show_col_types = FALSE)
conn <- read_csv(path_conn, show_col_types = FALSE)

# Global
rules_global_raw <- compute_rule_metrics(tx, conn) %>%
    mutate(
        count_global = count_trip,
        count_trips_global = count_trip
    )

# Cluster
rules_cluster_raw <- tx %>%
    group_by(cluster, cluster_label) %>%
    group_modify(~ {
        r <- compute_rule_metrics(.x, conn)
        if (nrow(r) == 0) return(r)
        r %>% mutate(n_trip_cluster = nrow(.x), count_trips = count_trip)
    }) %>%
    ungroup() %>%
    arrange(cluster, desc(rule_score), desc(count_trip))

write_csv(rules_global_raw, file.path(hasil_dir, "03_rules_global_raw.csv"))
write_csv(rules_cluster_raw, file.path(hasil_dir, "03_rules_cluster_raw.csv"))

cat("Candidate rules (global):", nrow(rules_global_raw), "\n")
cat("Candidate rules (cluster):", nrow(rules_cluster_raw), "\n")
cat("\n[OK] hasil/03_rules_global_raw.csv\n")
cat("[OK] hasil/03_rules_cluster_raw.csv\n")

