# ===================================================================
# STEP 06 — DATA CLEANING & OUTLIER DETECTION
# ===================================================================
# Tujuan : Membersihkan data dan menghapus outlier.
# Input  : intermediate/05_imputed.rds
# Output : intermediate/06_clean.rds
#          csv_outputs/STEP_06_cleaned.csv
#          csv_outputs/data_clean.csv (kolom terpilih untuk analisis)
# ===================================================================
# A. DATA CLEANING:
#   - Hapus observasi dengan tap-out missing (tapOut_hour = NA)
#   - Hapus observasi dengan corridorName missing (unresolved)
#
# B. OUTLIER DETECTION:
#   - Hapus observasi dengan n_trips > 6
#   - Definisi: n_trips = jumlah transaksi per payCardID per hari
# ===================================================================

library(dplyr, warn.conflicts = FALSE)

cat("\n", strrep("=", 60), "\n")
cat(" STEP 06 — DATA CLEANING & OUTLIER DETECTION\n")
cat(strrep("=", 60), "\n\n")

# --- [1] Load ---
df <- readRDS("data_preparation/intermediate/05_imputed.rds")
n0 <- nrow(df)
cat(sprintf("Input : %s baris × %d kolom\n\n", format(n0, big.mark = ","), ncol(df)))

# --- A. DATA CLEANING ---
cat("═══ A. DATA CLEANING ═══\n\n")

# [A1] Drop tap-out missing
cat("[A1] Hapus observasi dengan tap-out missing\n")
n_no_tapout <- sum(is.na(df$tapOut_hour))
df <- df %>% filter(!is.na(tapOut_hour))
cat(sprintf("     Dibuang : %s baris\n", format(n_no_tapout, big.mark = ",")))
cat(sprintf("     Sisa    : %s baris\n\n", format(nrow(df), big.mark = ",")))

# [A2] Drop corridorName missing (unresolved)
cat("[A2] Hapus observasi dengan corridorName missing (unresolved)\n")
is_missing <- function(x) is.na(x) | trimws(as.character(x)) == ""
n_miss_corr <- sum(is_missing(df$corridorName))
df <- df %>% filter(!is_missing(corridorName))
cat(sprintf("     Dibuang : %s baris\n", format(n_miss_corr, big.mark = ",")))
cat(sprintf("     Sisa    : %s baris\n\n", format(nrow(df), big.mark = ",")))

# --- B. OUTLIER DETECTION ---
cat("═══ B. OUTLIER DETECTION ═══\n\n")

cat("[B1] Kriteria: n_trips > 6 (per payCardID per hari)\n\n")

# Distribusi n_trips
cat("     Distribusi n_trips:\n")
trip_dist <- table(df$n_trips)
for (tr in names(trip_dist)) {
    cnt <- trip_dist[tr]
    flag <- if (as.integer(tr) > 6) " <-- OUTLIER" else ""
    cat(sprintf("     %2s trip/hari : %7s rows (%5.2f%%)%s\n",
                tr, format(cnt, big.mark = ","),
                cnt / nrow(df) * 100, flag))
}

n_before_outlier <- nrow(df)
n_outliers <- sum(df$n_trips > 6)
df <- df %>% filter(n_trips <= 6)
cat(sprintf("\n     Total outlier   : %s baris (%.2f%%)\n",
            format(n_outliers, big.mark = ","),
            n_outliers / n_before_outlier * 100))
cat(sprintf("     Setelah removal : %s baris\n", format(nrow(df), big.mark = ",")))

# --- Ringkasan total ---
total_drop <- n0 - nrow(df)
cat(sprintf("\n═══ RINGKASAN STEP 06 ═══\n"))
cat(sprintf("     Input           : %s baris\n", format(n0, big.mark = ",")))
cat(sprintf("     Drop no-tapout  : %s baris\n", format(n_no_tapout, big.mark = ",")))
cat(sprintf("     Drop missing    : %s baris\n", format(n_miss_corr, big.mark = ",")))
cat(sprintf("     Drop outlier    : %s baris\n", format(n_outliers, big.mark = ",")))
cat(sprintf("     Output          : %s baris (%.2f%% retained)\n",
            format(nrow(df), big.mark = ","),
            nrow(df) / n0 * 100))

# --- [3] Verifikasi tipe data ---
cat(sprintf("\n     Tipe data key columns:\n"))
key_cols <- c("tapIn_hour", "duration_minutes", "is_weekend", "is_commuter")
for (col in key_cols) {
    cat(sprintf("     %-25s : %s\n", col, class(df[[col]])))
}

# --- [4] Simpan ---
saveRDS(df, "data_preparation/intermediate/06_clean.rds")
cat(sprintf("\nRDS    : intermediate/06_clean.rds\n"))

# Export data_clean.csv (selected columns for analysis)
data_clean_export <- df %>% select(
    transID, payCardID,
    corridorID, corridorName,
    tapInStopsName, tapInStopsLat, tapInStopsLon,
    tapOutStopsName, tapOutStopsLat, tapOutStopsLon,
    date, day_of_week,
    tapIn_hour, tapOut_hour, duration_minutes,
    is_weekend, n_trips, n_days_month, is_commuter, trip_num
)

library(data.table)
dir.create("data_preparation/csv_outputs", recursive = TRUE, showWarnings = FALSE)

csv1 <- "data_preparation/csv_outputs/data_clean.csv"
tryCatch(fwrite(data_clean_export, csv1),
         error = function(e) write.csv(data_clean_export, csv1, row.names = FALSE))
cat(sprintf("CSV    : csv_outputs/data_clean.csv (%d kolom)\n", ncol(data_clean_export)))

csv2 <- "data_preparation/csv_outputs/STEP_06_cleaned.csv"
tryCatch(fwrite(df, csv2),
         error = function(e) write.csv(df, csv2, row.names = FALSE))
cat(sprintf("CSV    : csv_outputs/STEP_06_cleaned.csv (full %d kolom)\n", ncol(df)))

cat("\n", strrep("=", 60), "\n")
cat(" STEP 06 SELESAI\n")
cat(strrep("=", 60), "\n\n")
