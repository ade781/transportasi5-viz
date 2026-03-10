# ===================================================================
# STEP 00 — DATA QUALITY ASSESSMENT
# ===================================================================
# Tujuan : Evaluasi kualitas dataset TANPA modifikasi data.
# Input  : tj180.csv (raw dataset)
# Output : csv_outputs/STEP_00_data_quality.csv (laporan missing values)
# ===================================================================

library(dplyr, warn.conflicts = FALSE)

cat("\n", strrep("=", 60), "\n")
cat(" STEP 00 — DATA QUALITY ASSESSMENT\n")
cat(strrep("=", 60), "\n\n")

# --- [1] Load raw dataset ---
raw <- read.csv("tj180.csv", stringsAsFactors = FALSE)
cat(sprintf("Dataset : tj180.csv\n"))
cat(sprintf("Dimensi : %s baris × %d kolom\n\n",
            format(nrow(raw), big.mark = ","), ncol(raw)))

# --- [2] Identifikasi missing values ---
# Definisi missing: NA, NULL, string kosong "", string spasi saja
cat("[1] Identifikasi missing values\n")
cat("    Definisi missing: NA | \"\" | whitespace-only\n\n")

missing_count <- sapply(names(raw), function(col) {
    x <- raw[[col]]
    sum(is.na(x) | trimws(as.character(x)) == "")
})

# --- [3] Buat summary, urutkan dari terbanyak ---
quality_df <- data.frame(
    kolom          = names(missing_count),
    missing_values = as.integer(missing_count),
    pct            = round(missing_count / nrow(raw) * 100, 2),
    stringsAsFactors = FALSE
) %>% arrange(desc(missing_values))

# --- [4] Tampilkan TOP 5 ---
cat("[2] Top 5 kolom dengan missing values terbanyak:\n\n")
top5 <- head(quality_df, 5)
for (i in seq_len(nrow(top5))) {
    cat(sprintf("    %d. %-25s : %s missing (%s%%)\n",
                i, top5$kolom[i],
                format(top5$missing_values[i], big.mark = ","),
                top5$pct[i]))
}

# --- [5] Tampilkan semua kolom ---
cat(sprintf("\n[3] Missing values seluruh kolom (%d kolom):\n\n", ncol(raw)))
for (i in seq_len(nrow(quality_df))) {
    bar <- strrep("█", min(30, round(quality_df$pct[i] / max(quality_df$pct + 0.01) * 30)))
    cat(sprintf("    %-25s : %6s (%5.2f%%) %s\n",
                quality_df$kolom[i],
                format(quality_df$missing_values[i], big.mark = ","),
                quality_df$pct[i],
                bar))
}

# --- [6] Simpan CSV ---
dir.create("data_preparation/csv_outputs", recursive = TRUE, showWarnings = FALSE)
write.csv(quality_df, "data_preparation/csv_outputs/STEP_00_data_quality.csv",
          row.names = FALSE)
cat(sprintf("\nOutput : csv_outputs/STEP_00_data_quality.csv\n"))

cat("\n CATATAN: Tidak ada data yang dimodifikasi pada tahap ini.\n")

cat("\n", strrep("=", 60), "\n")
cat(" STEP 00 SELESAI\n")
cat(strrep("=", 60), "\n\n")
