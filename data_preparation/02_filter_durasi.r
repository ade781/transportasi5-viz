# ===================================================================
# STEP 02 — FILTER DURASI
# ===================================================================
# Tujuan : Menyaring observasi dengan durasi tidak logis.
# Input  : intermediate/01_parsed.rds
# Output : intermediate/02_durasi_ok.rds
#          csv_outputs/STEP_02_filter_durasi.csv
# ===================================================================
# Aturan filter:
#   - Hapus observasi dengan duration_minutes > 180
#   - Hapus observasi dengan duration_minutes <= 0 (negatif/nol)
#   - Hapus observasi dengan duration_minutes = NA (tidak lengkap)
# ===================================================================

library(dplyr, warn.conflicts = FALSE)

cat("\n", strrep("=", 60), "\n")
cat(" STEP 02 — FILTER DURASI\n")
cat(strrep("=", 60), "\n\n")

# --- [1] Load ---
df <- readRDS("data_preparation/intermediate/01_parsed.rds")
n0 <- nrow(df)
cat(sprintf("Input : %s baris\n\n", format(n0, big.mark = ",")))

# --- [2] Identifikasi anomali ---
cat("[1] Identifikasi durasi tidak logis\n")
n_na      <- sum(is.na(df$duration_minutes))
n_negatif <- sum(df$duration_minutes <= 0, na.rm = TRUE)
n_over180 <- sum(df$duration_minutes > 180, na.rm = TRUE)
cat(sprintf("    duration_minutes NA   : %s baris\n", format(n_na, big.mark = ",")))
cat(sprintf("    duration ≤ 0 menit    : %s baris\n", format(n_negatif, big.mark = ",")))
cat(sprintf("    duration > 180 menit  : %s baris\n", format(n_over180, big.mark = ",")))

# --- [3] Filter: pertahankan 0 < duration <= 180 ---
cat("\n[2] Terapkan filter: 0 < duration_minutes ≤ 180\n")
df <- df %>% filter(!is.na(duration_minutes),
                    duration_minutes > 0,
                    duration_minutes <= 180)
n_drop <- n0 - nrow(df)
cat(sprintf("    Dibuang : %s baris (%.2f%%)\n",
            format(n_drop, big.mark = ","), n_drop / n0 * 100))
cat(sprintf("    Sisa    : %s baris\n", format(nrow(df), big.mark = ",")))

# --- [4] Statistik durasi setelah filter ---
cat(sprintf("\n    Durasi setelah filter:\n"))
cat(sprintf("    Min / Median / Mean / Max : %.1f / %.1f / %.1f / %.1f menit\n",
            min(df$duration_minutes), median(df$duration_minutes),
            mean(df$duration_minutes), max(df$duration_minutes)))

# --- [5] Simpan ---
saveRDS(df, "data_preparation/intermediate/02_durasi_ok.rds")
cat(sprintf("\nOutput : intermediate/02_durasi_ok.rds\n"))

library(data.table)
csv_path <- "data_preparation/csv_outputs/STEP_02_filter_durasi.csv"
tryCatch(fwrite(df, csv_path),
         error = function(e) write.csv(df, csv_path, row.names = FALSE))
cat(sprintf("CSV    : csv_outputs/STEP_02_filter_durasi.csv\n"))

cat("\n", strrep("=", 60), "\n")
cat(" STEP 02 SELESAI\n")
cat(strrep("=", 60), "\n\n")
