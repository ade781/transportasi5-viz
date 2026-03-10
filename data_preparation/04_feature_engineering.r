# ===================================================================
# STEP 04 — FEATURE ENGINEERING (MONTH-AWARE)
# ===================================================================
# Tujuan : Membuat fitur analitis berbasis agregasi bulanan.
# Input  : intermediate/03_jam_ok.rds
# Output : intermediate/04_features.rds
#          csv_outputs/STEP_04_features.csv
# ===================================================================
# Fitur baru:
#   A. day_of_week   — 1(Sen)..7(Min), dari variabel date
#   B. is_weekend    — 1 jika day_of_week ∈ {6,7}, else 0
#   C. n_trips       — jumlah transaksi per payCardID per hari
#   D. n_days_month  — |unique(date)| per payCardID (user-level)
#   E. is_commuter   — 1 jika n_days_month ≥ 15, else 0
#   F. trip_num      — urutan trip per payCardID per hari
# ===================================================================

library(dplyr, warn.conflicts = FALSE)

cat("\n", strrep("=", 60), "\n")
cat(" STEP 04 — FEATURE ENGINEERING\n")
cat(strrep("=", 60), "\n\n")

# --- [1] Load ---
df <- readRDS("data_preparation/intermediate/03_jam_ok.rds")
cat(sprintf("Input : %s baris\n\n", format(nrow(df), big.mark = ",")))

# --- A. Day-of-week ---
cat("[A] Ekstrak day_of_week (1=Senin … 7=Minggu)\n")
df$day_of_week <- as.integer(format(df$date, "%u"))
cat(sprintf("    Distribusi: %s\n",
            paste(sprintf("%d=%s", 1:7,
                  format(tabulate(df$day_of_week, nbins = 7), big.mark = ",")),
                  collapse = ", ")))

# --- B. Weekend flag ---
cat("\n[B] Buat is_weekend (1 jika day_of_week ∈ {6,7})\n")
df$is_weekend <- ifelse(df$day_of_week >= 6, 1L, 0L)
cat(sprintf("    Weekday : %s trip\n",
            format(sum(df$is_weekend == 0), big.mark = ",")))
cat(sprintf("    Weekend : %s trip\n",
            format(sum(df$is_weekend == 1), big.mark = ",")))

# --- C. n_trips per payCardID per hari ---
cat("\n[C] Hitung n_trips (jumlah transaksi per payCardID per hari)\n")
trip_counts <- df %>%
    group_by(payCardID, date) %>%
    summarise(n_trips = n(), .groups = "drop")
df <- df %>% left_join(trip_counts, by = c("payCardID", "date"))
cat(sprintf("    n_trips range : %d – %d\n",
            min(df$n_trips), max(df$n_trips)))

# --- D. n_days_month (user-level aggregation) ---
cat("\n[D] Hitung n_days_month = |unique(date)| per payCardID\n")
user_days <- df %>%
    group_by(payCardID) %>%
    summarise(n_days_month = n_distinct(date), .groups = "drop")
df <- df %>% left_join(user_days, by = "payCardID")
cat(sprintf("    n_days_month range : %d – %d\n",
            min(df$n_days_month), max(df$n_days_month)))

# --- E. Commuter identification ---
cat("\n[E] Buat is_commuter (1 jika n_days_month ≥ 15)\n")
df$is_commuter <- ifelse(df$n_days_month >= 15, 1L, 0L)
n_comm   <- sum(df$is_commuter == 1)
n_nocomm <- sum(df$is_commuter == 0)
cat(sprintf("    Commuter     : %s trip (%.1f%%)\n",
            format(n_comm, big.mark = ","), n_comm / nrow(df) * 100))
cat(sprintf("    Non-commuter : %s trip (%.1f%%)\n",
            format(n_nocomm, big.mark = ","), n_nocomm / nrow(df) * 100))

# --- F. trip_num (urutan trip dalam satu hari) ---
cat("\n[F] Buat trip_num (urutan perjalanan per hari)\n")
df <- df %>%
    arrange(payCardID, date, tapIn_hour) %>%
    group_by(payCardID, date) %>%
    mutate(trip_num = row_number()) %>%
    ungroup()
cat(sprintf("    trip_num 1: %s | trip_num 2: %s | lainnya: %s\n",
            format(sum(df$trip_num == 1), big.mark = ","),
            format(sum(df$trip_num == 2), big.mark = ","),
            format(sum(df$trip_num > 2), big.mark = ",")))

# --- Simpan ---
cat(sprintf("\nOutput : %s baris × %d kolom\n",
            format(nrow(df), big.mark = ","), ncol(df)))
saveRDS(df, "data_preparation/intermediate/04_features.rds")
cat(sprintf("RDS    : intermediate/04_features.rds\n"))

library(data.table)
csv_path <- "data_preparation/csv_outputs/STEP_04_features.csv"
tryCatch(fwrite(df, csv_path),
         error = function(e) write.csv(df, csv_path, row.names = FALSE))
cat(sprintf("CSV    : csv_outputs/STEP_04_features.csv\n"))

cat("\n", strrep("=", 60), "\n")
cat(" STEP 04 SELESAI\n")
cat(strrep("=", 60), "\n\n")
