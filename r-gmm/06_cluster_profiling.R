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
library(stringr)

# Set paths untuk output
base_dir <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/r-gmm"
hasil_dir <- file.path(base_dir, "hasil")
visualisasi_dir <- file.path(base_dir, "visualisasi")
parent_dir <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz"

cat("=", strrep("=", 59), "\n")
cat("STEP 6: PROFILING & LABELING CLUSTER\n")
cat("=", strrep("=", 59), "\n\n")

# -- Load data --
df <- read_csv(file.path(parent_dir, "data_clean.csv"), show_col_types = FALSE)
assignments <- read_csv(file.path(hasil_dir, "05_cluster_assignments.csv"), show_col_types = FALSE)
probs <- read_csv(file.path(hasil_dir, "05_cluster_probabilities.csv"), show_col_types = FALSE)

# Hindari kolom z-score duplikat (.x/.y) jika data_clean sudah pernah memuat z-score
z_cols_existing <- names(df)[grepl("^z_", names(df))]
if (length(z_cols_existing) > 0) {
    df <- df %>% select(-all_of(z_cols_existing))
}

cat("Data asli:", nrow(df), "baris\n")
cat("Assignments:", nrow(assignments), "baris\n")
cat("Probabilities:", nrow(probs), "baris\n\n")

# Pastikan obs_id tersedia untuk join konsisten lintas file
if (!"obs_id" %in% names(df)) {
    df <- df %>% mutate(obs_id = row_number())
}
if (!"obs_id" %in% names(assignments)) {
    assignments <- assignments %>% mutate(obs_id = row_number())
}
if (!"obs_id" %in% names(probs)) {
    probs <- probs %>% mutate(obs_id = row_number())
}

# Gabungkan cluster dan z-scores ke data asli
df <- df %>%
    left_join(
        assignments %>%
            select(obs_id, cluster, z_tapIn_hour, z_duration_minutes, z_n_trips, z_n_days_month),
        by = "obs_id"
    )

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

prob_cols <- names(probs)[grepl("^prob_cl\\d+$", names(probs))]
required_prob_cols <- paste0("prob_cl", 1:5)

df_labeled <- df %>%
    left_join(label_map, by = "cluster") %>%
    left_join(
        probs %>% select(obs_id, all_of(prob_cols)),
        by = "obs_id"
    )

for (nm in required_prob_cols) {
    if (!nm %in% names(df_labeled)) {
        df_labeled[[nm]] <- 0
    }
}

# -- Simpan hasil --
write_csv(profiles, file.path(hasil_dir, "06_cluster_profiles.csv"))
target_labeled <- file.path(hasil_dir, "06_cluster_labeled.csv")
fallback_labeled <- file.path(hasil_dir, "06_cluster_labeled_new.csv")
write_ok <- TRUE
tryCatch(
    {
        write_csv(df_labeled, target_labeled)
    },
    error = function(e) {
        write_ok <<- FALSE
        write_csv(df_labeled, fallback_labeled)
        cat("\n[WARN] Gagal overwrite 06_cluster_labeled.csv (file sedang terkunci).\n")
        cat("[OK] File alternatif disimpan di", fallback_labeled, "\n")
    }
)

cat("\n[OK] File disimpan di", file.path(hasil_dir, "06_cluster_profiles.csv"), "\n")
if (write_ok) {
    cat("[OK] File disimpan di", target_labeled, "\n")
}
cat(sprintf(
    "\nRingkasan: %d cluster teridentifikasi dari %s observasi\n",
    nrow(profiles), format(nrow(df_labeled), big.mark = ".")
))
