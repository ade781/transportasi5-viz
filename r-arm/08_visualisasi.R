# ==============================================================================
# STEP 8: VISUALIZATION (ARM)
# ==============================================================================
# Input  : hasil/rules_all.csv, hasil/rules_global.csv, hasil/arm_summary.csv,
#          hasil/arm_evaluation.csv
# Output : visualisasi/01_rules_per_cluster.png
#          visualisasi/02_lift_distribution_global.png
#          visualisasi/03_support_confidence_global.png
#          visualisasi/04_top_corridors_in_rules.png
#          visualisasi/05_evaluation_metrics.png
# ==============================================================================

library(readr)
library(dplyr)
library(ggplot2)
library(scales)

base_dir <- normalizePath(".", winslash = "/", mustWork = FALSE)
hasil_dir <- file.path(base_dir, "hasil")
visual_dir <- file.path(base_dir, "visualisasi")
if (!dir.exists(visual_dir)) dir.create(visual_dir, recursive = TRUE)

path_rules_all <- file.path(hasil_dir, "rules_all.csv")
path_rules_global <- file.path(hasil_dir, "rules_global.csv")
path_summary <- file.path(hasil_dir, "arm_summary.csv")
path_eval <- file.path(hasil_dir, "arm_evaluation.csv")

required <- c(path_rules_all, path_rules_global, path_summary, path_eval)
if (any(!file.exists(required))) stop("Jalankan STEP 7 terlebih dahulu.")

cat("=", strrep("=", 66), "\n")
cat("STEP 8: VISUALIZATION (ARM)\n")
cat("=", strrep("=", 66), "\n\n")

rules_all <- read_csv(path_rules_all, show_col_types = FALSE)
rules_global <- read_csv(path_rules_global, show_col_types = FALSE)
summary_df <- read_csv(path_summary, show_col_types = FALSE)
eval_df <- read_csv(path_eval, show_col_types = FALSE)

# 1) Rules per cluster
p1 <- ggplot(summary_df, aes(x = reorder(cluster_label, n_rules), y = n_rules, fill = factor(cluster))) +
    geom_col(width = 0.7) +
    coord_flip() +
    theme_minimal(base_size = 12) +
    labs(
        title = "Jumlah Rules per Cluster",
        x = NULL,
        y = "Jumlah Rules",
        fill = "Cluster"
    )

ggsave(file.path(visual_dir, "01_rules_per_cluster.png"), p1, width = 10, height = 6, dpi = 140)

# 2) Lift distribution
p2 <- ggplot(rules_global, aes(x = lift)) +
    geom_histogram(binwidth = 1, fill = "#3498db", color = "white") +
    coord_cartesian(xlim = c(0, quantile(rules_global$lift, 0.98, na.rm = TRUE))) +
    theme_minimal(base_size = 12) +
    labs(
        title = "Distribusi Lift Global (98th percentile window)",
        x = "Lift",
        y = "Jumlah Rule"
    )

ggsave(file.path(visual_dir, "02_lift_distribution_global.png"), p2, width = 10, height = 6, dpi = 140)

# 3) Support vs confidence scatter
p3 <- ggplot(rules_global, aes(x = support * 100, y = confidence * 100, size = lift)) +
    geom_point(alpha = 0.6, color = "#e74c3c") +
    scale_size_continuous(range = c(2, 10)) +
    theme_minimal(base_size = 12) +
    labs(
        title = "Support vs Confidence (Global Rules)",
        x = "Support (%)",
        y = "Confidence (%)",
        size = "Lift"
    )

ggsave(file.path(visual_dir, "03_support_confidence_global.png"), p3, width = 10, height = 6, dpi = 140)

# 4) Top corridors in rules
corridor_freq <- bind_rows(
    rules_all %>% transmute(corridor = lhs),
    rules_all %>% transmute(corridor = rhs)
) %>%
    count(corridor, sort = TRUE) %>%
    slice_head(n = 12)

p4 <- ggplot(corridor_freq, aes(x = reorder(corridor, n), y = n)) +
    geom_col(fill = "#2ecc71") +
    coord_flip() +
    theme_minimal(base_size = 12) +
    labs(
        title = "Top Koridor dalam Rules",
        x = NULL,
        y = "Frekuensi kemunculan"
    )

ggsave(file.path(visual_dir, "04_top_corridors_in_rules.png"), p4, width = 10, height = 7, dpi = 140)

# 5) Main evaluation metrics
eval_plot <- eval_df %>%
    filter(metric %in% c("trip_coverage_by_rules_pct", "rule_compression_ratio", "avg_lift_local", "avg_support_local_pct")) %>%
    mutate(
        value_plot = case_when(
            metric == "rule_compression_ratio" ~ value * 100,
            TRUE ~ value
        ),
        metric = recode(
            metric,
            trip_coverage_by_rules_pct = "Trip Coverage (%)",
            rule_compression_ratio = "Compression (%)",
            avg_lift_local = "Avg Lift Local",
            avg_support_local_pct = "Avg Support Local (%)"
        )
    )

p5 <- ggplot(eval_plot, aes(x = reorder(metric, value_plot), y = value_plot)) +
    geom_col(fill = "#8e44ad") +
    coord_flip() +
    theme_minimal(base_size = 12) +
    labs(
        title = "Ringkasan Evaluasi ARM",
        x = NULL,
        y = "Value"
    )

ggsave(file.path(visual_dir, "05_evaluation_metrics.png"), p5, width = 10, height = 6, dpi = 140)

cat("[OK] Visualisasi ARM tersimpan di folder visualisasi/\n")

