# ==============================================================================
# STEP 6: PROFILING & LABELING CLUSTER
# ==============================================================================
# Deskripsi : Membuat profil setiap cluster berdasarkan statistik deskriptif,
#             lalu memberikan label interpretatif
# Input     : ../data_clean.csv, hasil/05_cluster_assignments.csv
# Output    : hasil/06_cluster_profiles.csv, hasil/06_cluster_labeled.csv
# ==============================================================================

# -- Library --
library(readr)
library(dplyr)
library(tidyr)

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

dir.create(hasil_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visualisasi_dir, recursive = TRUE, showWarnings = FALSE)

cat("=", strrep("=", 59), "\n")
cat("STEP 6: PROFILING & LABELING CLUSTER\n")
cat("=", strrep("=", 59), "\n\n")

# -- Load data --
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

df <- read_csv(data_path, show_col_types = FALSE)
assignments <- read_csv(file.path(hasil_dir, "05_cluster_assignments.csv"), show_col_types = FALSE)

cat("Data asli:", nrow(df), "baris\n")
cat("Assignments:", nrow(assignments), "baris\n\n")

# Validasi kolom yang dibutuhkan
if (!"transID" %in% names(assignments)) {
    stop("Kolom transID tidak ditemukan di 05_cluster_assignments.csv")
}

if (!"cluster" %in% names(assignments)) {
    stop("Kolom cluster tidak ditemukan di 05_cluster_assignments.csv")
}

required_feats <- c(
    "z_tapIn_hour", "z_duration_minutes", "z_n_trips", "z_n_days_month"
)
missing_feats <- setdiff(required_feats, names(assignments))
if (length(missing_feats) > 0) {
    stop("Fitur assignment tidak lengkap: ", paste(missing_feats, collapse = ", "))
}

if (!"transID" %in% names(df)) {
    stop("Kolom transID tidak ditemukan di data asli. Pastikan step 01_load_data.R sudah dijalankan dengan benar.")
}

# Gabungkan berdasarkan transID (proper join key, bukan row number)
df <- df %>%
    left_join(
        assignments %>%
            select(transID, cluster, all_of(required_feats)),
        by = "transID"
    )

if (any(is.na(df$cluster))) {
    stop("Terdapat observasi tanpa cluster setelah proses join via transID. Check data consistency!")
}

df$cluster <- as.integer(df$cluster)

# ==============================================================================
# 6a. Profiling: Statistik per cluster
# ==============================================================================
cat("Menghitung profil setiap cluster...\n\n")

profiles <- df %>%
    group_by(cluster) %>%
    summarise(
        n_obs = n(),
        pct_obs = round(n() / nrow(df) * 100, 2),

        # Z-score means (dari data dengan z-scores)
        mean_z_tapIn = round(mean(z_tapIn_hour, na.rm = TRUE), 4),
        mean_z_duration = round(mean(z_duration_minutes, na.rm = TRUE), 4),
        mean_z_n_trips = round(mean(z_n_trips, na.rm = TRUE), 4),
        mean_z_n_days = round(mean(z_n_days_month, na.rm = TRUE), 4),

        # Original scale
        mean_tapIn_hour = round(mean(tapIn_hour), 2),
        sd_tapIn_hour = round(sd(tapIn_hour), 2),
        mean_duration_min = round(mean(duration_minutes), 2),
        sd_duration_min = round(sd(duration_minutes), 2),
        pct_weekend = round(mean(is_weekend) * 100, 2),
        pct_commuter = round(mean(is_commuter) * 100, 2),
        mean_n_trips = round(mean(n_trips), 2),
        mean_n_days_month = round(mean(n_days_month), 2),

        # Top corridor
        top_corridor = names(sort(table(corridorName), decreasing = TRUE))[1],
        .groups = "drop"
    )

# ==============================================================================
# 6b. Labeling berdasarkan profil
# ==============================================================================
# Aturan labeling berdasarkan karakteristik:
#   - Commuter Pagi Dini: tapIn rendah (sekitar 6), commuter 100%, weekend rendah
#   - Commuter Sore     : tapIn tinggi (sekitar 18), commuter tinggi
#   - Commuter Pagi     : tapIn sekitar 8, commuter tinggi
#   - Penumpang Kasual  : commuter 0%, weekend tinggi, n_days_month rendah
#   - Penumpang Intensif: n_trips tinggi, n_days_month tinggi

profiles <- profiles %>%
    mutate(label = case_when(
        pct_commuter > 90 & mean_tapIn_hour < 7 ~ "Commuter Pagi Dini",
        pct_commuter > 90 & mean_tapIn_hour > 16 ~ "Commuter Sore",
        pct_commuter > 90 & mean_tapIn_hour >= 7 &
            mean_tapIn_hour <= 10 ~ "Commuter Pagi",
        pct_commuter < 10 ~ "Penumpang Kasual",
        mean_n_trips > 3 ~ "Penumpang Intensif",
        TRUE ~ paste0("Cluster_", cluster)
    ))

cat("Profil Cluster:\n")
cat(strrep("-", 80), "\n")
for (i in 1:nrow(profiles)) {
    p <- profiles[i, ]
    cat(sprintf("\nCluster %d: %s\n", p$cluster, p$label))
    cat(sprintf("  Jumlah obs   : %s (%.2f%%)\n", format(p$n_obs, big.mark = "."), p$pct_obs))
    cat(sprintf("  Jam rata-rata: %.2f (sd=%.2f)\n", p$mean_tapIn_hour, p$sd_tapIn_hour))
    cat(sprintf("  Durasi       : %.2f menit\n", p$mean_duration_min))
    cat(sprintf("  %% Weekend    : %.2f%%\n", p$pct_weekend))
    cat(sprintf("  %% Commuter   : %.2f%%\n", p$pct_commuter))
    cat(sprintf("  Trip/bulan   : %.2f\n", p$mean_n_trips))
    cat(sprintf("  Hari/bulan   : %.2f\n", p$mean_n_days_month))
    cat(sprintf("  Top koridor  : %s\n", p$top_corridor))
}
cat(strrep("-", 80), "\n")

# ==============================================================================
# 6c. Gabungkan label ke data lengkap
# ==============================================================================
label_map <- profiles %>% select(cluster, label)
df_labeled <- df %>%
    left_join(label_map, by = "cluster")

# -- Simpan hasil --
write_csv(profiles, file.path(hasil_dir, "06_cluster_profiles.csv"))
write_csv(df_labeled, file.path(hasil_dir, "06_cluster_labeled.csv"))

cat("\n[OK] File disimpan di", file.path(hasil_dir, "06_cluster_profiles.csv"), "\n")
cat("[OK] File disimpan di", file.path(hasil_dir, "06_cluster_labeled.csv"), "\n")
cat(sprintf(
    "\nRingkasan: %d cluster teridentifikasi dari %s observasi\n",
    nrow(profiles), format(nrow(df_labeled), big.mark = ".")
))
