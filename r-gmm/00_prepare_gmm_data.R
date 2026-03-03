# ==============================================================================
# STEP 0: SIAPKAN DATA KHUSUS GMM
# ==============================================================================
# Deskripsi : Membuat dataset baru khusus untuk GMM dari datacleancoba.csv
#             dengan trimming outlier durasi (P1-P99).
# Input     : ../datacleancoba.csv
# Output    : ../datacleancoba_gmm.csv
# ==============================================================================

library(readr)
library(dplyr)

cat("=", strrep("=", 59), "\n")
cat("STEP 0: SIAPKAN DATA KHUSUS GMM\n")
cat("=", strrep("=", 59), "\n\n")

script_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", script_args, value = TRUE)
if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg[1])
    base_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = TRUE))
} else {
    wd <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
    base_dir <- if (basename(wd) == "r-gmm") wd else file.path(wd, "r-gmm")
}
parent_dir <- dirname(base_dir)

input_path <- file.path(parent_dir, "datacleancoba.csv")
output_path <- file.path(parent_dir, "datacleancoba_gmm.csv")

if (!file.exists(input_path)) {
    stop("File tidak ditemukan: ", input_path)
}

df <- read_csv(input_path, show_col_types = FALSE)
cat("Data awal:", nrow(df), "baris\n")

required_cols <- c(
    "tapIn_hour", "duration_minutes", "n_trips",
    "n_days_month", "is_weekend", "is_commuter"
)
missing_cols <- setdiff(required_cols, names(df))
if (length(missing_cols) > 0) {
    stop("Kolom wajib tidak ditemukan: ", paste(missing_cols, collapse = ", "))
}

df <- df %>%
    filter(if_all(all_of(required_cols), ~ !is.na(.x)))

q_dur <- quantile(df$duration_minutes, probs = c(0.01, 0.99), na.rm = TRUE)

df_gmm <- df %>%
    filter(duration_minutes >= q_dur[1], duration_minutes <= q_dur[2])

write_csv(df_gmm, output_path)

cat("Data setelah cleaning:", nrow(df_gmm), "baris\n")
cat(sprintf("Trim durasi P1-P99: [%.2f, %.2f]\n", q_dur[1], q_dur[2]))
cat("[OK] File disimpan di", output_path, "\n")
