# ===================================================================
# STEP 05 — GROUP-BASED IMPUTATION (corridorName)
# ===================================================================
# Tujuan : Mengisi missing corridorName menggunakan lookup tapInStops.
# Input  : intermediate/04_features.rds
# Output : intermediate/05_imputed.rds
#          csv_outputs/STEP_05_imputed.csv
# ===================================================================
# Definisi missing corridor:
#   NA | "" | whitespace-only
#
# Aturan imputasi:
#   KONDISI 1: corridorName MISSING & tapInStops TERSEDIA
#     → Lookup corridorName dari observasi lain dgn tapInStops sama
#     → Ambil nilai pertama yang non-missing
#
#   KONDISI 2: tapInStops MISSING
#     → Lewati imputasi, tandai unresolved
#
#   KONDISI 3: tapInStops ADA tapi tidak ada referensi corridor
#     → Jangan imputasi, tandai unresolved
# ===================================================================

library(dplyr, warn.conflicts = FALSE)

cat("\n", strrep("=", 60), "\n")
cat(" STEP 05 — GROUP-BASED IMPUTATION (corridorName)\n")
cat(strrep("=", 60), "\n\n")

# --- [1] Load ---
df <- readRDS("data_preparation/intermediate/04_features.rds")
cat(sprintf("Input : %s baris\n\n", format(nrow(df), big.mark = ",")))

# --- [2] Identifikasi missing ---
# Definisi missing: NA | "" | whitespace
is_missing <- function(x) is.na(x) | trimws(as.character(x)) == ""

missing_corridor <- is_missing(df$corridorName)
missing_stops    <- is_missing(df$tapInStops)

n_miss_before <- sum(missing_corridor)
cat("[1] Status SEBELUM imputasi:\n")
cat(sprintf("    corridorName missing : %s (%s%%)\n",
            format(n_miss_before, big.mark = ","),
            round(n_miss_before / nrow(df) * 100, 2)))
cat(sprintf("    tapInStops missing   : %s\n",
            format(sum(missing_stops), big.mark = ",")))

# --- [3] Build lookup table: tapInStops → corridorName (first non-missing) ---
cat("\n[2] Build lookup table: tapInStops → corridorName\n")
lookup_data <- df %>%
    filter(!is_missing(corridorName), !is_missing(tapInStops)) %>%
    group_by(tapInStops) %>%
    summarise(
        corridor_fill = names(sort(table(corridorName), decreasing = TRUE))[1],
        .groups = "drop"
    )
cat(sprintf("    Mapping rules : %s unique tapInStops\n",
            format(nrow(lookup_data), big.mark = ",")))

# --- [4] Terapkan imputasi ---
cat("\n[3] Terapkan imputasi\n")

n_imputed  <- 0
n_no_stops <- 0
n_no_ref   <- 0

for (i in which(missing_corridor)) {
    stops_val <- df$tapInStops[i]

    # KONDISI 2: tapInStops missing → lewati
    if (is_missing(stops_val)) {
        n_no_stops <- n_no_stops + 1
        next
    }

    # KONDISI 1 & 3: cari di lookup
    match_row <- lookup_data %>% filter(tapInStops == stops_val)

    if (nrow(match_row) > 0) {
        # KONDISI 1: ditemukan → imputasi
        df$corridorName[i] <- match_row$corridor_fill[1]
        n_imputed <- n_imputed + 1
    } else {
        # KONDISI 3: tidak ada referensi → unresolved
        n_no_ref <- n_no_ref + 1
    }
}

# --- [5] Statistik imputasi ---
n_miss_after <- sum(is_missing(df$corridorName))
cat(sprintf("\n[4] Statistik imputasi:\n"))
cat(sprintf("    Missing SEBELUM    : %s\n", format(n_miss_before, big.mark = ",")))
cat(sprintf("    Imputasi berhasil  : %s\n", format(n_imputed, big.mark = ",")))
cat(sprintf("    Gagal (no stops)   : %s (KONDISI 2: tapInStops missing)\n",
            format(n_no_stops, big.mark = ",")))
cat(sprintf("    Gagal (no ref)     : %s (KONDISI 3: tidak ada referensi)\n",
            format(n_no_ref, big.mark = ",")))
cat(sprintf("    Missing SESUDAH    : %s (%s%%)\n",
            format(n_miss_after, big.mark = ","),
            round(n_miss_after / nrow(df) * 100, 4)))

# --- [6] Simpan ---
saveRDS(df, "data_preparation/intermediate/05_imputed.rds")
cat(sprintf("\nOutput : intermediate/05_imputed.rds (%s baris × %d kolom)\n",
            format(nrow(df), big.mark = ","), ncol(df)))

library(data.table)
csv_path <- "data_preparation/csv_outputs/STEP_05_imputed.csv"
tryCatch(fwrite(df, csv_path),
         error = function(e) write.csv(df, csv_path, row.names = FALSE))
cat(sprintf("CSV    : csv_outputs/STEP_05_imputed.csv\n"))

cat("\n", strrep("=", 60), "\n")
cat(" STEP 05 SELESAI\n")
cat(strrep("=", 60), "\n\n")
