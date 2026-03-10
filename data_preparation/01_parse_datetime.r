# ===================================================================
# STEP 01 — PARSE DATETIME
# ===================================================================
# Tujuan : Mengubah variabel temporal ke representasi numerik kontinu.
# Input  : tj180.csv (raw dataset)
# Output : intermediate/01_parsed.rds
#          csv_outputs/STEP_01_parsed.csv
# ===================================================================
# Formula:
#   jam_desimal = jam + menit / 60
#   duration_minutes = (tapOut_hour - tapIn_hour) × 60
# ===================================================================

library(dplyr, warn.conflicts = FALSE)

cat("\n", strrep("=", 60), "\n")
cat(" STEP 01 — PARSE DATETIME\n")
cat(strrep("=", 60), "\n\n")

# --- [1] Load raw dataset ---
raw <- read.csv("tj180.csv", stringsAsFactors = FALSE)
cat(sprintf("Input : %s baris × %d kolom\n\n",
            format(nrow(raw), big.mark = ","), ncol(raw)))

# --- [2] Parse tapInTime → tapIn_dt (POSIXct) ---
cat("[1] Parse tapInTime → datetime object\n")
raw$tapIn_dt <- as.POSIXct(raw$tapInTime, format = "%m/%d/%Y %H:%M",
                           tz = "Asia/Jakarta")
n_fail_in <- sum(is.na(raw$tapIn_dt))
cat(sprintf("    Parse gagal : %s baris\n", format(n_fail_in, big.mark = ",")))

# --- [3] Parse tapOutTime → tapOut_dt (POSIXct) ---
cat("[2] Parse tapOutTime → datetime object\n")
raw$tapOut_dt <- as.POSIXct(raw$tapOutTime, format = "%m/%d/%Y %H:%M",
                            tz = "Asia/Jakarta")
n_fail_out <- sum(is.na(raw$tapOut_dt))
cat(sprintf("    Parse gagal : %s baris\n", format(n_fail_out, big.mark = ",")))

# --- [4] Ekstrak date ---
cat("[3] Ekstrak date dari tapIn_dt\n")
raw$date <- as.Date(raw$tapIn_dt)

# --- [5] Hitung jam desimal : jam + menit/60 ---
cat("[4] Hitung tapIn_hour (jam desimal = jam + menit/60)\n")
raw$tapIn_hour <- as.numeric(format(raw$tapIn_dt, "%H")) +
                  as.numeric(format(raw$tapIn_dt, "%M")) / 60

cat("[5] Hitung tapOut_hour (jam desimal = jam + menit/60)\n")
raw$tapOut_hour <- as.numeric(format(raw$tapOut_dt, "%H")) +
                   as.numeric(format(raw$tapOut_dt, "%M")) / 60

# --- [6] Hitung duration_minutes ---
cat("[6] Hitung duration_minutes = (tapOut_hour - tapIn_hour) × 60\n")
raw$duration_minutes <- (raw$tapOut_hour - raw$tapIn_hour) * 60

# --- [7] Drop intermediate columns (tapInTime, tapOutTime, tapIn_dt, tapOut_dt) ---
cat("[7] Drop kolom intermediate\n")
cols_before <- ncol(raw)
raw <- raw %>% select(-tapInTime, -tapOutTime, -tapIn_dt, -tapOut_dt)
cat(sprintf("    Kolom sebelum : %d → sesudah : %d\n", cols_before, ncol(raw)))

# --- [8] Ringkasan ---
cat(sprintf("\nRingkasan:\n"))
cat(sprintf("  Parse gagal tapIn  : %s baris\n", format(n_fail_in, big.mark = ",")))
cat(sprintf("  Parse gagal tapOut : %s baris (→ tapOut_hour & duration = NA)\n",
            format(n_fail_out, big.mark = ",")))
cat(sprintf("  Rentang tanggal    : %s s/d %s\n",
            min(raw$date, na.rm = TRUE), max(raw$date, na.rm = TRUE)))
cat(sprintf("  tapIn_hour range   : %.2f – %.2f\n",
            min(raw$tapIn_hour, na.rm = TRUE), max(raw$tapIn_hour, na.rm = TRUE)))
cat(sprintf("  tapOut_hour range  : %.2f – %.2f\n",
            min(raw$tapOut_hour, na.rm = TRUE), max(raw$tapOut_hour, na.rm = TRUE)))

# --- [9] Simpan ---
dir.create("data_preparation/intermediate", recursive = TRUE, showWarnings = FALSE)
saveRDS(raw, "data_preparation/intermediate/01_parsed.rds")
cat(sprintf("\nOutput : intermediate/01_parsed.rds (%s baris × %d kolom)\n",
            format(nrow(raw), big.mark = ","), ncol(raw)))

dir.create("data_preparation/csv_outputs", recursive = TRUE, showWarnings = FALSE)
library(data.table)
csv_path <- "data_preparation/csv_outputs/STEP_01_parsed.csv"
tryCatch(fwrite(raw, csv_path),
         error = function(e) write.csv(raw, csv_path, row.names = FALSE))
cat(sprintf("CSV    : csv_outputs/STEP_01_parsed.csv\n"))

cat("\n", strrep("=", 60), "\n")
cat(" STEP 01 SELESAI\n")
cat(strrep("=", 60), "\n\n")
