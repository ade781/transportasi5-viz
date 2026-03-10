# ===================================================================
# DATA PREPARATION — RUN ALL
# ===================================================================
# Pipeline runner: 8 steps (STEP 00 – STEP 07)
#
# Urutan eksekusi:
#   00_data_quality.r        — Data Quality Assessment
#   01_parse_datetime.r      — Parse DateTime
#   02_filter_durasi.r       — Filter Durasi (> 180 menit)
#   03_filter_jam.r          — Filter Jam Operasi (05:00–22:30)
#   04_feature_engineering.r — Feature Engineering (month-aware)
#   05_imputation.r          — Group-Based Imputation (corridorName)
#   06_data_cleaning.r       — Data Cleaning & Outlier Detection
#   07_zscore_normalisasi.r  — Z-Score Normalisasi
# ===================================================================

BASE <- "data_preparation"

steps <- c(
    "00_data_quality.r",
    "01_parse_datetime.r",
    "02_filter_durasi.r",
    "03_filter_jam.r",
    "04_feature_engineering.r",
    "05_imputation.r",
    "06_data_cleaning.r",
    "07_zscore_normalisasi.r"
)

cat("\n", strrep("=", 60), "\n")
cat(" DATA PREPARATION — RUN ALL (8 STEPS)\n")
cat(strrep("=", 60), "\n\n")

t_start <- proc.time()

for (step in steps) {
    path <- file.path(BASE, step)
    t0 <- proc.time()
    source(path, echo = FALSE)
    elapsed <- round((proc.time() - t0)[["elapsed"]], 1)
    cat(sprintf(">>> %-35s selesai (%.1f det)\n\n", step, elapsed))
}

total <- round((proc.time() - t_start)[["elapsed"]], 1)
cat(strrep("=", 60), "\n")
cat(sprintf(" SEMUA STEP SELESAI — total %.1f detik\n", total))
cat(strrep("=", 60), "\n\n")
