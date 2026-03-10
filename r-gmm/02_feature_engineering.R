# ==============================================================================
# STEP 2: FEATURE ENGINEERING & STANDARDISASI
# ==============================================================================
# Deskripsi : Menyusun feature matrix dari hasil normalisasi data_preparation
# Input     : ../data_clean.csv (untuk ID)
#             ../data_preparation/csv_outputs/STEP_07_normalized.csv
# Output    : hasil/02_feature_matrix.csv, hasil/02_feature_stats.csv
# ==============================================================================

# -- Library --
library(readr)
library(dplyr)

cat("=", strrep("=", 59), "\n")
cat("STEP 2: FEATURE ENGINEERING & STANDARDISASI\n")
cat("=", strrep("=", 59), "\n\n")

# -- Load data --
data_clean_path <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/data_clean.csv"
normalized_path <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/data_preparation/csv_outputs/STEP_07_normalized.csv"

df <- read_csv(data_clean_path, show_col_types = FALSE)
df_norm <- read_csv(normalized_path, show_col_types = FALSE)
cat("Data clean dimuat:", nrow(df), "baris\n")
cat("Data normalized dimuat:", nrow(df_norm), "baris\n\n")

# Set paths untuk output
base_dir <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/r-gmm"
hasil_dir <- file.path(base_dir, "hasil")

# ==============================================================================
# 2a. Validasi Input
# ==============================================================================
fitur_kontinu_z <- c("z_tapIn_hour", "z_duration_minutes", "z_n_trips", "z_n_days_month")
fitur_biner <- c("is_weekend", "is_commuter")
fitur_final <- c(fitur_kontinu_z, fitur_biner)
id_cols <- c("transID", "payCardID")

missing_norm_cols <- setdiff(fitur_final, names(df_norm))
if (length(missing_norm_cols) > 0) {
    stop(
        sprintf(
            "Kolom wajib tidak ditemukan di STEP_07_normalized.csv: %s",
            paste(missing_norm_cols, collapse = ", ")
        )
    )
}

missing_id_cols <- setdiff(id_cols, names(df))
if (length(missing_id_cols) > 0) {
    stop(
        sprintf(
            "Kolom ID tidak ditemukan di data_clean.csv: %s",
            paste(missing_id_cols, collapse = ", ")
        )
    )
}

if (nrow(df) != nrow(df_norm)) {
    stop(
        sprintf(
            "Jumlah baris tidak sama: data_clean=%d vs normalized=%d.",
            nrow(df), nrow(df_norm)
        )
    )
}

cat("Validasi input selesai.\n")
cat("Fitur kontinu (z-score):", paste(fitur_kontinu_z, collapse = ", "), "\n")
cat("Fitur biner            :", paste(fitur_biner, collapse = ", "), "\n\n")

# ==============================================================================
# 2b. Susun Matriks Fitur Final
# ==============================================================================
feature_matrix <- df_norm %>% select(all_of(fitur_final))

cat("Statistik fitur (cek mean/sd):\n")
for (z in fitur_kontinu_z) {
    cat(sprintf("  %-25s mean=%7.4f  sd=%7.4f\n", z, mean(feature_matrix[[z]]), sd(feature_matrix[[z]])))
}

cat("\nMatriks fitur untuk GMM:\n")
cat("  Dimensi:", nrow(feature_matrix), "x", ncol(feature_matrix), "\n")
cat("  Kolom  :", paste(fitur_final, collapse = ", "), "\n")

# -- Statistik lengkap untuk laporan --
stats_full <- data.frame(
    fitur = fitur_final,
    tipe = c(rep("kontinu", 4), rep("biner", 2)),
    min = sapply(feature_matrix, min),
    q25 = sapply(feature_matrix, quantile, 0.25),
    median = sapply(feature_matrix, median),
    mean = sapply(feature_matrix, mean),
    q75 = sapply(feature_matrix, quantile, 0.75),
    max = sapply(feature_matrix, max),
    sd = sapply(feature_matrix, sd),
    skewness = sapply(feature_matrix, function(x) {
        n <- length(x)
        m <- mean(x)
        s <- sd(x)
        (sum((x - m)^3) / n) / s^3
    }),
    kurtosis = sapply(feature_matrix, function(x) {
        n <- length(x)
        m <- mean(x)
        s <- sd(x)
        (sum((x - m)^4) / n) / s^4
    }),
    n_unique = sapply(feature_matrix, function(x) length(unique(x)))
)
rownames(stats_full) <- NULL

# -- Simpan hasil --
# Simpan feature matrix (z-score + biner) beserta ID
output_df <- bind_cols(
    df %>% select(all_of(id_cols)),
    feature_matrix
)
write_csv(output_df, file.path(hasil_dir, "02_feature_matrix.csv"))
write_csv(stats_full, file.path(hasil_dir, "02_feature_stats.csv"))

cat("\n[OK] File disimpan di", file.path(hasil_dir, "02_feature_matrix.csv"), "\n")
cat("[OK] File disimpan di", file.path(hasil_dir, "02_feature_stats.csv"), "\n")
