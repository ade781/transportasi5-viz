# ===================================================================
# STEP 07 — Z-SCORE NORMALISASI
# ===================================================================
# Tujuan : Normalisasi variabel kontinu untuk input GMM.
# Input  : intermediate/06_clean.rds
# Output : tj180_final.csv (6 kolom: z_tapIn_hour, z_duration_minutes,
#                           z_n_trips, z_n_days_month,
#                           is_weekend, is_commuter)
#          csv_outputs/STEP_07_normalized.csv
#          artifacts/scaling_params.rds
# ===================================================================
# Formula Z-score:
#   Z = (X - μ) / σ
#
# Variabel yang di-Z-score:
#   ✔ tapIn_hour        — waktu tap-in (jam)
#   ✔ duration_minutes  — durasi perjalanan
#   ✔ n_trips           — jumlah trip per orang per hari
#   ✔ n_days_month      — jumlah hari aktif per bulan (loyalitas)
#
# Variabel biner (TIDAK dinormalisasi):
#   ✔ is_weekend
#   ✔ is_commuter
# ===================================================================

library(dplyr, warn.conflicts = FALSE)

cat("\n", strrep("=", 60), "\n")
cat(" STEP 07 — Z-SCORE NORMALISASI\n")
cat(strrep("=", 60), "\n\n")

# --- [1] Load ---
df <- readRDS("data_preparation/intermediate/06_clean.rds")
cat(sprintf("Input : %s baris\n\n", format(nrow(df), big.mark = ",")))

# --- [2] Hitung mean & sd ---
feat_cont <- c("tapIn_hour", "duration_minutes", "n_trips", "n_days_month")

cat("[1] Hitung mean & SD (parameter scaling)\n")
means <- sapply(feat_cont, function(f) mean(df[[f]]))
sds   <- sapply(feat_cont, function(f) sd(df[[f]]))
for (f in feat_cont) {
    cat(sprintf("    %-25s mean = %8.4f  sd = %8.4f\n", f, means[f], sds[f]))
}

# --- [3] Terapkan Z-score: Z = (X - μ) / σ ---
cat("\n[2] Terapkan Z-score\n")
gmm_input <- data.frame(
    z_tapIn_hour       = (df$tapIn_hour - means["tapIn_hour"]) / sds["tapIn_hour"],
    z_duration_minutes = (df$duration_minutes - means["duration_minutes"]) / sds["duration_minutes"],
    z_n_trips          = (df$n_trips - means["n_trips"]) / sds["n_trips"],
    z_n_days_month     = (df$n_days_month - means["n_days_month"]) / sds["n_days_month"],
    is_weekend         = df$is_weekend,
    is_commuter        = df$is_commuter
)

# Verifikasi
cat("\n    Verifikasi Z-score (seharusnya mean≈0, sd≈1):\n")
for (f in c("z_tapIn_hour","z_duration_minutes","z_n_trips","z_n_days_month")) {
    cat(sprintf("    %-22s — mean: %8.6f  sd: %8.6f\n",
                f, mean(gmm_input[[f]]), sd(gmm_input[[f]])))}


# --- [4] Simpan scaling_params ---
cat("\n[3] Simpan scaling parameters\n")
dir.create("data_preparation/artifacts", recursive = TRUE, showWarnings = FALSE)
scaling_params <- list(mean = means, sd = sds)
saveRDS(scaling_params, "data_preparation/artifacts/scaling_params.rds")
cat("    Output : artifacts/scaling_params.rds\n")

# --- [5] Simpan final outputs ---
cat("\n[4] Simpan final outputs\n")

library(data.table)

# tj180_final.csv (root)
csv1 <- "tj180_final.csv"
tryCatch(fwrite(gmm_input, csv1),
         error = function(e) write.csv(gmm_input, csv1, row.names = FALSE))
cat(sprintf("    Output : tj180_final.csv (%s baris × %d kolom)\n",
            format(nrow(gmm_input), big.mark = ","), ncol(gmm_input)))
cat(sprintf("             Kolom: %s\n", paste(colnames(gmm_input), collapse=", ")))

# Backup ke csv_outputs
csv2 <- "data_preparation/csv_outputs/STEP_07_normalized.csv"
tryCatch(fwrite(gmm_input, csv2),
         error = function(e) write.csv(gmm_input, csv2, row.names = FALSE))
cat(sprintf("    Output : csv_outputs/STEP_07_normalized.csv\n"))

cat("\n", strrep("=", 60), "\n")
cat(" STEP 07 SELESAI\n")
cat(strrep("=", 60), "\n\n")
