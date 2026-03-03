# ==============================================================================
# STEP 8: VISUALISASI GMM
# ==============================================================================
# Deskripsi : Menghasilkan semua grafik untuk analisis GMM
# Input     : hasil/04_bic_best_per_k.csv, hasil/05_cluster_assignments.csv,
#             hasil/06_cluster_profiles.csv, hasil/07_evaluation_scores.csv
# Output    : visualisasi/*.png
# ==============================================================================

# -- Library --
library(readr)
library(dplyr)
library(ggplot2)
library(ggrepel)
library(scales)
library(tidyr)
library(RColorBrewer)

# Set paths untuk output (otomatis berdasarkan lokasi script/project aktif)
script_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", script_args, value = TRUE)
if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg[1])
    base_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = TRUE))
} else {
    wd <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
    base_dir <- if (basename(wd) == "r-gmm") wd else file.path(wd, "r-gmm")
}

hasil_dir <- file.path(base_dir, "hasil")
visualisasi_dir <- file.path(base_dir, "visualisasi")
parent_dir <- dirname(base_dir)

if (!dir.exists(hasil_dir)) {
    stop("Folder hasil tidak ditemukan: ", hasil_dir)
}

dir.create(visualisasi_dir, recursive = TRUE, showWarnings = FALSE)

# Bersihkan file PNG lama agar folder visualisasi benar-benar terbarui
old_png <- list.files(visualisasi_dir, pattern = "\\.png$", full.names = TRUE)
if (length(old_png) > 0) {
    invisible(file.remove(old_png))
}

cat("=", strrep("=", 59), "\n")
cat("STEP 8: VISUALISASI GMM\n")
cat("=", strrep("=", 59), "\n\n")

# -- Tema kustom --
theme_thesis <- theme_minimal(base_size = 12) +
    theme(
        plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
        plot.subtitle = element_text(size = 10, hjust = 0.5, color = "grey40"),
        legend.position = "bottom",
        panel.grid.minor = element_blank()
    )

build_cluster_colors <- function(cluster_ids) {
    cluster_ids <- sort(unique(as.integer(cluster_ids)))
    n_cluster <- length(cluster_ids)
    if (n_cluster <= 9) {
        cols <- brewer.pal(max(3, n_cluster), "Set1")[seq_len(n_cluster)]
    } else {
        cols <- scales::hue_pal()(n_cluster)
    }
    names(cols) <- as.character(cluster_ids)
    cols
}

# ==============================================================================
# VIS 1: BIC Elbow Plot
# ==============================================================================
cat("1. BIC Elbow Plot...\n")

bic_df <- read_csv(file.path(hasil_dir, "04_bic_best_per_k.csv"), show_col_types = FALSE)
selection_meta_path <- file.path(hasil_dir, "04_model_selection.csv")
params_path <- file.path(hasil_dir, "05_gmm_parameters.csv")

selected_k <- NA_integer_
if (file.exists(selection_meta_path)) {
    sel_meta <- read_csv(selection_meta_path, show_col_types = FALSE)
    if ("selected_k" %in% names(sel_meta) && nrow(sel_meta) > 0) {
        selected_k <- as.integer(sel_meta$selected_k[1])
    }
}
if (is.na(selected_k) && file.exists(params_path)) {
    gmm_params <- read_csv(params_path, show_col_types = FALSE)
    selected_k <- nrow(gmm_params)
}
if (is.na(selected_k) || !(selected_k %in% bic_df$K)) {
    selected_k <- bic_df %>% filter(BIC == max(BIC, na.rm = TRUE)) %>% slice(1) %>% pull(K)
}

p1 <- ggplot(bic_df, aes(x = K, y = BIC)) +
    geom_line(color = "#2C3E50", linewidth = 1) +
    geom_point(size = 3, color = "#2C3E50") +
    geom_point(
        data = bic_df %>% filter(K == selected_k),
        aes(x = K, y = BIC), color = "red", size = 5, shape = 18
    ) +
    geom_text(
        data = bic_df %>% filter(K == selected_k),
        aes(label = sprintf("K=%d\nBIC=%.0f", K, BIC)),
        vjust = -1.5, color = "red", fontface = "bold", size = 3.5
    ) +
    labs(
        title = "BIC Score vs Jumlah Cluster (K)",
        subtitle = "Model terbaik per K | Titik merah = K optimal",
        x = "Jumlah Cluster (K)", y = "BIC Score"
    ) +
    scale_x_continuous(breaks = 2:12) +
    theme_thesis

ggsave(file.path(visualisasi_dir, "01_bic_elbow.png"), p1, width = 10, height = 6, dpi = 300)

# ==============================================================================
# VIS 2: BIC Delta Plot
# ==============================================================================
cat("2. BIC Delta Plot...\n")

bic_delta <- bic_df %>% filter(!is.na(BIC_delta))

p2 <- ggplot(bic_delta, aes(x = K, y = BIC_delta)) +
    geom_col(
        fill = ifelse(bic_delta$K == selected_k, "#E74C3C", "#3498DB"),
        width = 0.7
    ) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    labs(
        title = "Perubahan BIC (Delta BIC) antar K",
        subtitle = paste0("Nilai positif besar = peningkatan signifikan | K=", selected_k, " ditandai merah"),
        x = "Jumlah Cluster (K)", y = "Delta BIC"
    ) +
    scale_x_continuous(breaks = 2:12) +
    theme_thesis

ggsave(file.path(visualisasi_dir, "02_bic_delta.png"), p2, width = 10, height = 6, dpi = 300)

# ==============================================================================
# VIS 3: Distribusi Cluster (Pie / Bar)
# ==============================================================================
cat("3. Distribusi Cluster...\n")

profiles <- read_csv(file.path(hasil_dir, "06_cluster_profiles.csv"), show_col_types = FALSE)
cluster_colors <- build_cluster_colors(profiles$cluster)
total_obs <- sum(profiles$n_obs, na.rm = TRUE)
profiles <- profiles %>%
    mutate(cluster_label = paste0("Cluster ", cluster, "\n", label))

p3 <- ggplot(profiles, aes(x = reorder(label, -n_obs), y = n_obs, fill = factor(cluster))) +
    geom_col(width = 0.7) +
    geom_text(
        aes(label = paste0(
            format(n_obs, big.mark = "."), "\n(",
            pct_obs, "%)"
        )),
        vjust = -0.3, size = 3.5
    ) +
    scale_fill_manual(values = cluster_colors, name = "Cluster") +
    labs(
        title = "Distribusi Jumlah Observasi per Cluster",
        subtitle = paste0("Total ", format(total_obs, big.mark = "."), " transaksi TransJakarta April 2023"),
        x = "Cluster", y = "Jumlah Observasi"
    ) +
    scale_y_continuous(labels = scales::comma) +
    theme_thesis +
    theme(axis.text.x = element_text(size = 10))

ggsave(file.path(visualisasi_dir, "03_cluster_distribution.png"), p3, width = 12, height = 7, dpi = 300)

# ==============================================================================
# VIS 4: Cluster Profile Heatmap (Z-Score)
# ==============================================================================
cat("4. Cluster Profile Heatmap...\n")

z_cols <- c("mean_z_tapIn", "mean_z_duration", "mean_z_n_trips", "mean_z_n_days")
heatmap_data <- profiles %>%
    select(cluster, label, all_of(z_cols)) %>%
    pivot_longer(cols = all_of(z_cols), names_to = "fitur", values_to = "z_score") %>%
    mutate(
        fitur_clean = case_when(
            fitur == "mean_z_tapIn" ~ "Jam Tap-In",
            fitur == "mean_z_duration" ~ "Durasi Perjalanan",
            fitur == "mean_z_n_trips" ~ "Jumlah Trip",
            fitur == "mean_z_n_days" ~ "Hari Aktif/Bulan"
        ),
        cluster_label = paste0("C", cluster, ": ", label)
    )

p4 <- ggplot(heatmap_data, aes(x = fitur_clean, y = cluster_label, fill = z_score)) +
    geom_tile(color = "white", linewidth = 2) +
    geom_text(aes(label = round(z_score, 2)), color = "black", size = 4, fontface = "bold") +
    scale_fill_gradient2(
        low = "#2166AC", mid = "white", high = "#B2182B",
        midpoint = 0, name = "Z-Score"
    ) +
    labs(
        title = "Profil Cluster berdasarkan Z-Score Fitur",
        subtitle = "Biru = di bawah rata-rata | Merah = di atas rata-rata",
        x = "", y = ""
    ) +
    theme_thesis +
    theme(axis.text = element_text(size = 11))

ggsave(file.path(visualisasi_dir, "04_cluster_heatmap.png"), p4, width = 12, height = 7, dpi = 300)

# ==============================================================================
# VIS 5: Distribusi Jam Tap-In per Cluster
# ==============================================================================
cat("5. Distribusi Jam Tap-In per Cluster...\n")

assignments <- read_csv(file.path(hasil_dir, "05_cluster_assignments.csv"), show_col_types = FALSE)

candidate_data_paths <- c(
    file.path(parent_dir, "datacleancoba_gmm.csv"),
    file.path(parent_dir, "data_clean.csv"),
    file.path(parent_dir, "datacleancoba.csv"),
    file.path(getwd(), "datacleancoba_gmm.csv"),
    file.path(getwd(), "data_clean.csv"),
    file.path(getwd(), "datacleancoba.csv")
)
data_path <- candidate_data_paths[file.exists(candidate_data_paths)][1]
if (is.na(data_path)) {
    stop("File data_clean.csv / datacleancoba.csv tidak ditemukan di project.")
}

df_orig <- read_csv(data_path, show_col_types = FALSE)
df_orig$cluster <- assignments$cluster
df_orig <- df_orig %>%
    left_join(profiles %>% select(cluster, label), by = "cluster") %>%
    mutate(hour_int = round(tapIn_hour) %>% pmin(23) %>% pmax(0))

p5 <- ggplot(df_orig, aes(x = hour_int, fill = factor(cluster))) +
    geom_histogram(binwidth = 1, color = "white", linewidth = 0.2) +
    facet_wrap(~ paste0("C", cluster, ": ", label), scales = "free_y", ncol = 1) +
    scale_fill_manual(values = cluster_colors, guide = "none") +
    labs(
        title = "Distribusi Jam Tap-In per Cluster",
        subtitle = "Menunjukkan pola waktu perjalanan yang berbeda antar cluster",
        x = "Jam (0-23)", y = "Jumlah Transaksi"
    ) +
    scale_x_continuous(breaks = seq(0, 23, 2)) +
    theme_thesis +
    theme(strip.text = element_text(face = "bold"))

ggsave(file.path(visualisasi_dir, "05_hourly_per_cluster.png"), p5, width = 10, height = 14, dpi = 300)

# ==============================================================================
# VIS 6: Evaluation Metrics Comparison (BIC & LogLikelihood)
# ==============================================================================
cat("6. Evaluation Metrics...\n")

eval_df <- read_csv(file.path(hasil_dir, "07_evaluation_scores.csv"), show_col_types = FALSE)

# Prepare data for plotting
eval_plot_data <- eval_df %>%
    mutate(
        BIC_norm_scaled = BIC_normalized * -1, # For better visualization
        LL_scaled = LogLikelihood / 1000000, # Scale down for visualization
        label = paste0("K=", K)
    )

p6 <- ggplot(eval_plot_data, aes(x = K)) +
    geom_line(aes(y = BIC_norm_scaled, color = "BIC (normalized)"), linewidth = 1.2) +
    geom_point(aes(y = BIC_norm_scaled, color = "BIC (normalized)"), size = 3) +
    geom_vline(xintercept = selected_k, linetype = "dashed", color = "red", linewidth = 0.8) +
    labs(
        title = "Model Selection: BIC Comparison",
        subtitle = paste0("K=", selected_k, " ditandai sebagai K terpilih"),
        x = "Jumlah Cluster (K)", y = "BIC (normalized)",
        color = "Metrik"
    ) +
    scale_x_continuous(breaks = sort(unique(eval_plot_data$K))) +
    scale_color_manual(values = c("BIC (normalized)" = "#2166AC")) +
    theme_thesis

if (selected_k %in% eval_plot_data$K) {
    p6 <- p6 + annotate(
        "text",
        x = selected_k + 0.2,
        y = max(eval_plot_data$BIC_norm_scaled, na.rm = TRUE) * 0.95,
        label = paste0("K=", selected_k, " (terpilih)"),
        color = "red",
        fontface = "bold",
        hjust = 0
    )
}

ggsave(file.path(visualisasi_dir, "06_evaluation_metrics.png"), p6, width = 10, height = 6, dpi = 300)

# ==============================================================================
# VIS 7: Scatter Plot 2D (Jam vs Durasi) dengan Gaussian Ellipses
# ==============================================================================
cat("7. Scatter Plot 2D...\n")

# Sample untuk performa
set.seed(42)
sample_idx <- sample(nrow(df_orig), min(5000, nrow(df_orig)))
df_sample <- df_orig[sample_idx, ]

p7 <- ggplot(df_sample, aes(
    x = tapIn_hour, y = duration_minutes,
    color = factor(cluster), fill = factor(cluster)
)) +
    # Add Gaussian ellipses (covariance-based)
    stat_ellipse(
        aes(color = factor(cluster)),
        geom = "path",
        type = "norm",
        linewidth = 1,
        alpha = 0.3,
        level = 0.95,
        show.legend = FALSE
    ) +
    # Add filled ellipse behind points
    stat_ellipse(
        aes(fill = factor(cluster)),
        geom = "polygon",
        type = "norm",
        alpha = 0.1,
        level = 0.95,
        show.legend = FALSE
    ) +
    # Points on top
    geom_point(alpha = 0.5, size = 1.5) +
    scale_color_manual(
        values = cluster_colors,
        labels = paste0("C", profiles$cluster, ": ", profiles$label),
        name = "Cluster"
    ) +
    scale_fill_manual(
        values = cluster_colors,
        guide = "none"
    ) +
    labs(
        title = "Scatter Plot: Jam Tap-In vs Durasi Perjalanan (dengan Gaussian Ellipses)",
        subtitle = "Sample 5.000 transaksi | Elips = 95% covariance ellipse per cluster",
        x = "Jam Tap-In", y = "Durasi (menit)"
    ) +
    theme_thesis

ggsave(file.path(visualisasi_dir, "07_scatter_hour_duration.png"), p7, width = 10, height = 7, dpi = 300)

# ==============================================================================
# VIS 8: Boxplot Fitur per Cluster
# ==============================================================================
cat("8. Boxplot Fitur per Cluster...\n")

boxplot_data <- df_orig %>%
    select(cluster, label, tapIn_hour, duration_minutes, n_trips, n_days_month) %>%
    pivot_longer(
        cols = c(tapIn_hour, duration_minutes, n_trips, n_days_month),
        names_to = "fitur", values_to = "value"
    ) %>%
    mutate(
        fitur_label = case_when(
            fitur == "tapIn_hour" ~ "Jam Tap-In",
            fitur == "duration_minutes" ~ "Durasi (menit)",
            fitur == "n_trips" ~ "Jumlah Trip",
            fitur == "n_days_month" ~ "Hari Aktif/Bulan"
        ),
        cluster_label = paste0("C", cluster)
    )

p8 <- ggplot(boxplot_data, aes(x = cluster_label, y = value, fill = factor(cluster))) +
    geom_boxplot(outlier.alpha = 0.1, outlier.size = 0.5) +
    facet_wrap(~fitur_label, scales = "free_y", ncol = 2) +
    scale_fill_manual(values = cluster_colors, guide = "none") +
    labs(
        title = "Distribusi Fitur per Cluster",
        subtitle = "Boxplot menunjukkan perbedaan karakteristik antar cluster",
        x = "Cluster", y = "Nilai"
    ) +
    theme_thesis +
    theme(strip.text = element_text(face = "bold"))

ggsave(file.path(visualisasi_dir, "08_boxplot_features.png"), p8, width = 10, height = 8, dpi = 300)

# ==============================================================================
# VIS 9: Weekend vs Commuter per Cluster (Stacked Bar)
# ==============================================================================
cat("9. Weekend vs Commuter Proportion...\n")

prop_data <- profiles %>%
    select(cluster, label, pct_weekend, pct_commuter) %>%
    pivot_longer(
        cols = c(pct_weekend, pct_commuter),
        names_to = "metric", values_to = "percentage"
    ) %>%
    mutate(
        metric_label = ifelse(metric == "pct_weekend", "% Weekend", "% Commuter"),
        cluster_label = paste0("C", cluster, ": ", label)
    )

p9 <- ggplot(prop_data, aes(x = cluster_label, y = percentage, fill = metric_label)) +
    geom_col(position = "dodge", width = 0.6) +
    geom_text(aes(label = paste0(percentage, "%")),
        position = position_dodge(width = 0.6), vjust = -0.3, size = 3
    ) +
    scale_fill_brewer(palette = "Set2", name = "") +
    labs(
        title = "Proporsi Weekend & Commuter per Cluster",
        x = "", y = "Persentase (%)"
    ) +
    theme_thesis +
    theme(axis.text.x = element_text(angle = 15, hjust = 1))

ggsave(file.path(visualisasi_dir, "09_weekend_commuter.png"), p9, width = 12, height = 7, dpi = 300)

cat("\n[OK] Semua 9 visualisasi disimpan di folder", visualisasi_dir, "\n")
cat("File yang dihasilkan:\n")
for (f in list.files(visualisasi_dir, pattern = "\\.png$")) {
    cat("  -", f, "\n")
}
