# ===================================================================
# STEP 03 — FILTER JAM OPERASI
# ===================================================================
# Tujuan : Menjaga konsistensi dataset terhadap konteks operasional.
# Input  : intermediate/02_durasi_ok.rds
# Output : intermediate/03_jam_ok.rds
#          csv_outputs/STEP_03_filter_jam.csv
# ===================================================================
# Aturan filter:
#   tapIn_hour  ∈ [5.0, 22.0]   (05:00 – 22:00)
#   tapOut_hour ∈ [5.0, 22.5]   (05:00 – 22:30)
#   Observasi di luar rentang → dihapus.
# ===================================================================

library(dplyr, warn.conflicts = FALSE)

cat("\n", strrep("=", 60), "\n")
cat(" STEP 03 — FILTER JAM OPERASI\n")
cat(strrep("=", 60), "\n\n")

# --- [1] Load ---
df <- readRDS("data_preparation/intermediate/02_durasi_ok.rds")
n0 <- nrow(df)
cat(sprintf("Input : %s baris\n\n", format(n0, big.mark = ",")))

# --- [2] Identifikasi anomali ---
cat("[1] Identifikasi observasi di luar jam operasi\n")
n_in_luar  <- sum(df$tapIn_hour < 5 | df$tapIn_hour > 22)
n_out_luar <- sum(df$tapOut_hour < 5 | df$tapOut_hour > 22.5)
cat(sprintf("    tapIn_hour  di luar [5, 22]   : %s baris\n",
            format(n_in_luar, big.mark = ",")))
cat(sprintf("    tapOut_hour di luar [5, 22.5]  : %s baris\n",
            format(n_out_luar, big.mark = ",")))

# --- [3] Terapkan filter ---
cat("\n[2] Terapkan filter jam operasi\n")
df <- df %>% filter(
    tapIn_hour  >= 5, tapIn_hour  <= 22,
    tapOut_hour >= 5, tapOut_hour <= 22.5
)
n_drop <- n0 - nrow(df)
cat(sprintf("    Dibuang : %s baris (%.2f%%)\n",
            format(n_drop, big.mark = ","), n_drop / n0 * 100))
cat(sprintf("    Sisa    : %s baris\n", format(nrow(df), big.mark = ",")))

# --- [4] Distribusi jam tap-in ---
cat(sprintf("\n    Distribusi jam tap-in (per jam):\n"))
breaks <- seq(5, 22)
for (h in breaks) {
    cnt <- sum(df$tapIn_hour >= h & df$tapIn_hour < (h + 1))
    bar <- strrep("|", max(1, round(cnt / max(1, max(table(floor(df$tapIn_hour)))) * 30)))
    cat(sprintf("    %02d:xx %7s  %s\n", h, format(cnt, big.mark = ","), bar))
}

# --- [5] Simpan ---
saveRDS(df, "data_preparation/intermediate/03_jam_ok.rds")
cat(sprintf("\nOutput : intermediate/03_jam_ok.rds\n"))

library(data.table)
csv_path <- "data_preparation/csv_outputs/STEP_03_filter_jam.csv"
tryCatch(fwrite(df, csv_path),
         error = function(e) write.csv(df, csv_path, row.names = FALSE))
cat(sprintf("CSV    : csv_outputs/STEP_03_filter_jam.csv\n"))

cat("\n", strrep("=", 60), "\n")
cat(" STEP 03 SELESAI\n")
cat(strrep("=", 60), "\n\n")
