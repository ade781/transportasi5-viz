# ==============================================================================
# STEP 2: FEATURE ENGINEERING & STANDARDISASI
# ==============================================================================
# Deskripsi : Membuat fitur untuk clustering dan melakukan z-score standardisasi
# Input     : ../data_clean.csv
# Output    : hasil/02_feature_matrix.csv, hasil/02_feature_stats.csv
# ==============================================================================

# -- Library --
library(readr)
library(dplyr)

cat("=", strrep("=", 59), "\n")
cat("STEP 2: FEATURE ENGINEERING & STANDARDISASI\n")
cat("=", strrep("=", 59), "\n\n")

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
parent_dir <- dirname(base_dir)

dir.create(hasil_dir, recursive = TRUE, showWarnings = FALSE)

# -- Load data --
candidate_data_paths <- c(
    file.path(parent_dir, "datacleancoba_gmm.csv"),
    file.path(parent_dir, "datacleancoba.csv"),
    file.path(parent_dir, "data_clean.csv"),
    file.path(getwd(), "datacleancoba_gmm.csv"),
    file.path(getwd(), "datacleancoba.csv"),
    file.path(getwd(), "data_clean.csv")
)
data_path <- candidate_data_paths[file.exists(candidate_data_paths)][1]
if (is.na(data_path)) {
    stop("File data_clean.csv / datacleancoba.csv tidak ditemukan di project.")
}

df <- read_csv(data_path, show_col_types = FALSE)
cat("Data dimuat:", nrow(df), "baris\n\n")

# ==============================================================================
# 2a. Seleksi Fitur
# ==============================================================================
# Fitur yang digunakan untuk GMM clustering:
#   1. tapIn_hour       (kontinu) - Jam tap-in penumpang
#   2. duration_minutes (kontinu) - Durasi perjalanan dalam menit
#   3. n_trips          (kontinu) - Jumlah trip penumpang dalam sebulan
#   4. n_days_month     (kontinu) - Jumlah hari aktif dalam sebulan
#   5. is_weekend       (biner)   - Apakah perjalanan di akhir pekan
#   6. is_commuter      (biner)   - Apakah penumpang commuter

fitur_kontinu <- c("tapIn_hour", "duration_minutes", "n_trips", "n_days_month")
fitur_biner <- c("is_weekend", "is_commuter")

cat("Fitur kontinu:", paste(fitur_kontinu, collapse = ", "), "\n")
cat("Fitur biner  :", paste(fitur_biner, collapse = ", "), "\n\n")

# ==============================================================================
# 2b. Z-Score Standardisasi (hanya fitur kontinu)
# ==============================================================================
cat("Melakukan Z-score standardisasi...\n")

# Hitung mean dan sd sebelum standardisasi
feature_stats <- data.frame(
    fitur = fitur_kontinu,
    mean  = sapply(df[fitur_kontinu], mean, na.rm = TRUE),
    sd    = sapply(df[fitur_kontinu], sd, na.rm = TRUE)
)
cat("\nStatistik fitur sebelum standardisasi:\n")
print(feature_stats)

# Standardisasi z-score: z = (x - mean) / sd
z_names <- paste0("z_", fitur_kontinu)
for (i in seq_along(fitur_kontinu)) {
    col <- fitur_kontinu[i]
    df[[z_names[i]]] <- (df[[col]] - mean(df[[col]], na.rm = TRUE)) / sd(df[[col]], na.rm = TRUE)
}

cat("\nStatistik fitur setelah standardisasi (harus mean≈0, sd≈1):\n")
for (z in z_names) {
    cat(sprintf("  %-25s mean=%7.4f  sd=%7.4f\n", z, mean(df[[z]]), sd(df[[z]])))
}

# ==============================================================================
# 2c. Matriks Fitur Final
# ==============================================================================
# Gabungkan z-score fitur kontinu + fitur biner
fitur_final <- c(z_names, fitur_biner)
feature_matrix <- df[, fitur_final]

cat("\nMatriks fitur untuk GMM:\n")
cat("  Dimensi:", nrow(feature_matrix), "x", ncol(feature_matrix), "\n")
cat("  Kolom  :", paste(fitur_final, collapse = ", "), "\n")

# -- Statistik lengkap untuk laporan --
stats_full <- data.frame(
    fitur = c(z_names, fitur_biner),
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
    df %>% select(transID, payCardID),
    feature_matrix
)
write_csv(output_df, file.path(hasil_dir, "02_feature_matrix.csv"))
write_csv(stats_full, file.path(hasil_dir, "02_feature_stats.csv"))

cat("\n[OK] File disimpan di", file.path(hasil_dir, "02_feature_matrix.csv"), "\n")
cat("[OK] File disimpan di", file.path(hasil_dir, "02_feature_stats.csv"), "\n")
