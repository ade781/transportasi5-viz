# ==============================================================================
# STEP 4: RULE FILTERING + ITERATIVE TARGETING (30-50 RULES)
# ==============================================================================
# Input  : hasil/03_rules_global_raw.csv, hasil/03_rules_cluster_raw.csv
# Output : hasil/04_rules_global_filtered.csv
#          hasil/04_rules_cluster_filtered.csv
#          hasil/04_filter_params.csv
# ==============================================================================

library(readr)
library(dplyr)

base_dir <- normalizePath(".", winslash = "/", mustWork = FALSE)
hasil_dir <- file.path(base_dir, "hasil")

path_global <- file.path(hasil_dir, "03_rules_global_raw.csv")
path_cluster <- file.path(hasil_dir, "03_rules_cluster_raw.csv")

if (!file.exists(path_global) || !file.exists(path_cluster)) {
    stop("Jalankan 03_rule_mining.R terlebih dahulu.")
}

cat("=", strrep("=", 66), "\n")
cat("STEP 4: RULE FILTERING + ITERATIVE TARGETING (30-50 RULES)\n")
cat("=", strrep("=", 66), "\n\n")

rules_global <- read_csv(path_global, show_col_types = FALSE)
rules_cluster <- read_csv(path_cluster, show_col_types = FALSE)

# Thesis baseline
strict_support <- 0.02
strict_conf <- 0.60
strict_lift <- 1.00

target_min <- 30
target_max <- 50
target_mid <- (target_min + target_max) / 2
max_iter <- 300

filter_rules <- function(df, min_count, min_conf, min_lift) {
    df %>%
        filter(
            count_trip >= min_count,
            confidence >= min_conf,
            lift >= min_lift,
            q_value_local <= 0.05
        ) %>%
        arrange(desc(rule_score), desc(count_trip))
}

enforce_range <- function(df_full, df_selected, key_cols, min_n, max_n) {
    out <- df_selected

    if (nrow(out) > max_n) {
        out <- out %>% slice_head(n = max_n)
    }

    if (nrow(out) < min_n && nrow(df_full) >= min_n) {
        deficit <- min_n - nrow(out)
        fill <- anti_join(df_full, out, by = key_cols) %>%
            slice_head(n = deficit)
        out <- bind_rows(out, fill) %>% distinct(across(all_of(key_cols)), .keep_all = TRUE)
    }

    out %>% arrange(desc(rule_score), desc(count_trip))
}

iterative_select <- function(df, init_min_count, init_min_conf, init_min_lift) {
    min_count <- init_min_count
    min_conf <- init_min_conf
    min_lift <- init_min_lift

    best <- list(
        data = tibble(),
        n = -1,
        iter = 0,
        min_count = min_count,
        min_conf = min_conf,
        min_lift = min_lift,
        reached = FALSE
    )
    best_diff <- Inf

    for (i in seq_len(max_iter)) {
        cand <- filter_rules(df, min_count, min_conf, min_lift)
        n_cand <- nrow(cand)
        diff <- abs(n_cand - target_mid)

        if (diff < best_diff || (diff == best_diff && n_cand > best$n)) {
            best <- list(
                data = cand,
                n = n_cand,
                iter = i,
                min_count = min_count,
                min_conf = min_conf,
                min_lift = min_lift,
                reached = (n_cand >= target_min && n_cand <= target_max)
            )
            best_diff <- diff
        }

        if (n_cand >= target_min && n_cand <= target_max) {
            return(list(
                data = cand,
                n = n_cand,
                iter = i,
                min_count = min_count,
                min_conf = min_conf,
                min_lift = min_lift,
                reached = TRUE
            ))
        }

        if (n_cand > target_max) {
            min_count <- min(400, min_count + 5)
            min_conf <- min(0.90, min_conf + 0.01)
            min_lift <- min(50, min_lift + 0.15)
        } else {
            min_count <- max(5, min_count - 5)
            min_conf <- max(0.10, min_conf - 0.01)
            min_lift <- max(1.01, min_lift - 0.10)
        }
    }

    best
}

# Strict selection first (as thesis reference)
strict_global <- rules_global %>%
    filter(
        support >= strict_support,
        confidence >= strict_conf,
        lift > strict_lift
    ) %>%
    arrange(desc(rule_score), desc(count_trip))

strict_cluster <- rules_cluster %>%
    filter(
        support >= strict_support,
        confidence >= strict_conf,
        lift > strict_lift
    ) %>%
    arrange(desc(rule_score), desc(count_trip))

# Iterative target search
global_tuned <- iterative_select(
    rules_global,
    init_min_count = 60,
    init_min_conf = 0.50,
    init_min_lift = 2.00
)

cluster_tuned <- iterative_select(
    rules_cluster,
    init_min_count = 45,
    init_min_conf = 0.50,
    init_min_lift = 5.00
)

rules_global_filtered <- enforce_range(
    df_full = rules_global %>% arrange(desc(rule_score), desc(count_trip)),
    df_selected = global_tuned$data,
    key_cols = c("lhs", "rhs"),
    min_n = target_min,
    max_n = target_max
)

rules_cluster_filtered <- enforce_range(
    df_full = rules_cluster %>% arrange(desc(rule_score), desc(count_trip)),
    df_selected = cluster_tuned$data,
    key_cols = c("cluster", "lhs", "rhs"),
    min_n = target_min,
    max_n = target_max
)

write_csv(rules_global_filtered, file.path(hasil_dir, "04_rules_global_filtered.csv"))
write_csv(rules_cluster_filtered, file.path(hasil_dir, "04_rules_cluster_filtered.csv"))

filter_params <- tibble(
    parameter = c(
        "strict_support", "strict_confidence", "strict_lift",
        "adaptive_min_count_global", "adaptive_min_count_cluster",
        "adaptive_confidence", "adaptive_lift",
        "global_selection_mode", "cluster_selection_mode",
        "global_rules_selected", "cluster_rules_selected",
        "global_iter_count", "cluster_iter_count",
        "target_min_rules", "target_max_rules"
    ),
    value = c(
        strict_support, strict_conf, strict_lift,
        global_tuned$min_count, cluster_tuned$min_count,
        global_tuned$min_conf, global_tuned$min_lift,
        ifelse(global_tuned$reached, "iterative_target", "iterative_fallback"),
        ifelse(cluster_tuned$reached, "iterative_target", "iterative_fallback"),
        nrow(rules_global_filtered), nrow(rules_cluster_filtered),
        global_tuned$iter, cluster_tuned$iter,
        target_min, target_max
    )
)
write_csv(filter_params, file.path(hasil_dir, "04_filter_params.csv"))

cat("Strict global rules:", nrow(strict_global), "\n")
cat("Strict cluster rules:", nrow(strict_cluster), "\n")
cat("Global tuned rules:", nrow(rules_global_filtered), "(iter:", global_tuned$iter, ")\n")
cat("Cluster tuned rules:", nrow(rules_cluster_filtered), "(iter:", cluster_tuned$iter, ")\n")
cat("\n[OK] hasil/04_rules_global_filtered.csv\n")
cat("[OK] hasil/04_rules_cluster_filtered.csv\n")
cat("[OK] hasil/04_filter_params.csv\n")
