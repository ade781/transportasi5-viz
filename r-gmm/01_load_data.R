# ==============================================================================
# STEP 1: LOAD & EKSPLORASI DATA
# ==============================================================================
# Deskripsi : Memuat data_clean.csv dan melakukan eksplorasi awal
# Input     : ../data_clean.csv
# Output    : hasil/01_data_overview.csv, hasil/01_summary_stats.csv
# ==============================================================================

# -- Library --
library(readr)
library(dplyr)
library(tibble)

cat("=", strrep("=", 59), "\n")
cat("STEP 1: LOAD & EKSPLORASI DATA\n")
cat("=", strrep("=", 59), "\n\n")

# -- Load data --
# Path relatif dari folder r-gmm ke data_clean.csv
data_path <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/data_clean.csv"
df <- read_csv(data_path, show_col_types = FALSE)

# Set paths untuk output
base_dir <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/r-gmm"
hasil_dir <- file.path(base_dir, "hasil")

cat("Dimensi data:", nrow(df), "baris x", ncol(df), "kolom\n\n")
cat("Kolom yang tersedia:\n")
cat(paste(" -", names(df)), sep = "\n")
cat("\n")

# -- Struktur data --
cat("\nStruktur data:\n")
str(df)

# -- Cek missing values --
cat("\nMissing values per kolom:\n")
missing <- sapply(df, function(x) sum(is.na(x)))
print(missing[missing > 0])
if (all(missing == 0)) cat("  Tidak ada missing values.\n")

# -- Overview tipe data --
overview <- tibble(
    kolom        = names(df),
    tipe         = sapply(df, class),
    n_unique     = sapply(df, function(x) length(unique(x))),
    n_missing    = sapply(df, function(x) sum(is.na(x))),
    contoh_nilai = sapply(df, function(x) paste(head(unique(x), 3), collapse = ", "))
)

cat("\nOverview kolom:\n")
print(overview, n = Inf)

# -- Summary statistik untuk kolom numerik --
numeric_cols <- df %>% select(where(is.numeric))
summary_stats <- numeric_cols %>%
    summarise(across(everything(), list(
        min    = ~ min(., na.rm = TRUE),
        q25    = ~ quantile(., 0.25, na.rm = TRUE),
        median = ~ median(., na.rm = TRUE),
        mean   = ~ mean(., na.rm = TRUE),
        q75    = ~ quantile(., 0.75, na.rm = TRUE),
        max    = ~ max(., na.rm = TRUE),
        sd     = ~ sd(., na.rm = TRUE)
    ))) %>%
    tidyr::pivot_longer(everything(),
        names_to = c("kolom", "stat"),
        names_sep = "_(?=[^_]+$)"
    ) %>%
    tidyr::pivot_wider(names_from = stat, values_from = value)

cat("\nSummary statistik numerik:\n")
print(summary_stats, n = Inf)

# -- Simpan hasil --
write_csv(overview, file.path(hasil_dir, "01_data_overview.csv"))
write_csv(summary_stats, file.path(hasil_dir, "01_summary_stats.csv"))

cat("\n[OK] File disimpan di", file.path(hasil_dir, "01_data_overview.csv"), "\n")
cat("[OK] File disimpan di", file.path(hasil_dir, "01_summary_stats.csv"), "\n")
cat("\nJumlah total transaksi:", format(nrow(df), big.mark = "."), "\n")
cat("Periode data:", min(df$date), "s/d", max(df$date), "\n")
cat("Jumlah koridor unik:", length(unique(df$corridorName)), "\n")
cat("Jumlah halte unik (tap-in):", length(unique(df$tapInStopsName)), "\n")
