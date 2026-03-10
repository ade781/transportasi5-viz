# Analisis GMM (Gaussian Mixture Model) â€” R Scripts

## Deskripsi

Folder ini berisi **8 script R** untuk melakukan analisis **Gaussian Mixture Model (GMM)** pada data transaksi TransJakarta April 2023. Analisis ini merupakan bagian dari **Bab 3 (Metodologi Penelitian)** yang bertujuan mengelompokkan pola perjalanan penumpang berdasarkan fitur temporal dan behavioral.

## Struktur Folder

```
r-gmm/
â”‚
â”œâ”€â”€ 01_load_data.R              # Step 1: Load & eksplorasi data
â”œâ”€â”€ 02_feature_engineering.R    # Step 2: Build feature matrix dari hasil normalisasi
â”œâ”€â”€ 03_normality_test.R         # Step 3: Uji normalitas (KS-test)
â”œâ”€â”€ 04_bic_selection.R          # Step 4: Seleksi K optimal via BIC
â”œâ”€â”€ 05_gmm_fitting.R            # Step 5: Fitting GMM final (K=5, VVV)
â”œâ”€â”€ 06_cluster_profiling.R      # Step 6: Profiling & labeling cluster
â”œâ”€â”€ 07_evaluation.R             # Step 7: Evaluasi (Silhouette, Entropy)
â”œâ”€â”€ 08_visualisasi.R            # Step 8: Semua visualisasi
â”‚
â”œâ”€â”€ hasil/                      # Output CSV setiap step
â”‚   â”œâ”€â”€ 01_data_overview.csv
â”‚   â”œâ”€â”€ 01_summary_stats.csv
â”‚   â”œâ”€â”€ 02_feature_matrix.csv
â”‚   â”œâ”€â”€ 02_feature_stats.csv
â”‚   â”œâ”€â”€ 03_normality_test.csv
â”‚   â”œâ”€â”€ 04_bic_all_models.csv
â”‚   â”œâ”€â”€ 04_bic_best_per_k.csv
â”‚   â”œâ”€â”€ 05_cluster_assignments.csv
â”‚   â”œâ”€â”€ 05_cluster_probabilities.csv
â”‚   â”œâ”€â”€ 05_gmm_parameters.csv
â”‚   â”œâ”€â”€ 05_gmm_model.rds
â”‚   â”œâ”€â”€ 06_cluster_profiles.csv
â”‚   â”œâ”€â”€ 06_cluster_labeled.csv
â”‚   â””â”€â”€ 07_evaluation_scores.csv
â”‚
â”œâ”€â”€ visualisasi/                # Output grafik
â”‚   â”œâ”€â”€ 01_bic_elbow.png
â”‚   â”œâ”€â”€ 02_bic_delta.png
â”‚   â”œâ”€â”€ 03_cluster_distribution.png
â”‚   â”œâ”€â”€ 04_cluster_heatmap.png
â”‚   â”œâ”€â”€ 05_hourly_per_cluster.png
â”‚   â”œâ”€â”€ 06_evaluation_metrics.png
â”‚   â”œâ”€â”€ 07_scatter_hour_duration.png
â”‚   â”œâ”€â”€ 08_boxplot_features.png
â”‚   â””â”€â”€ 09_weekend_commuter.png
â”‚
â”œâ”€â”€ README.md                   # File ini
â””â”€â”€ alur_penelitian.md          # Alur penelitian detail + diagram
```

## Cara Menjalankan

### Prasyarat
Pastikan R dan paket berikut sudah terinstall:

```r
install.packages(c("readr", "dplyr", "tidyr", "tibble",
                    "ggplot2", "ggrepel", "scales",
                    "mclust", "cluster", "RColorBrewer"))
```

### Urutan Eksekusi

Jalankan script **secara berurutan** dari RStudio.
Catatan: sebelum menjalankan Step 2, pastikan `data_preparation/07_zscore_normalisasi.r` sudah dijalankan agar file `STEP_07_normalized.csv` tersedia.

```r
# Set working directory ke folder r-gmm
setwd("path/ke/r-gmm")

source("01_load_data.R")
source("02_feature_engineering.R")
source("03_normality_test.R")
source("04_bic_selection.R")        # ~5-10 menit
source("05_gmm_fitting.R")          # ~2-5 menit
source("06_cluster_profiling.R")
source("07_evaluation.R")           # ~15-30 menit (fitting K=2..12)
source("08_visualisasi.R")
```

## Data Input

| File | Deskripsi | Baris | Kolom |
|------|-----------|-------|-------|
| `../data_clean.csv` | Data transaksi TransJakarta yang sudah dibersihkan (untuk ID & profiling) | 168.132 | 20 |
| `../data_preparation/csv_outputs/STEP_07_normalized.csv` | Hasil z-score dari pipeline data_preparation (input utama Step 2) | 168.132 | 6 |

### Kolom Utama di `data_clean.csv`

| Kolom | Tipe | Deskripsi |
|-------|------|-----------|
| `transID` | string | ID unik transaksi |
| `payCardID` | string | ID kartu pembayaran (proxy untuk penumpang) |
| `corridorID` | string | ID koridor TransJakarta |
| `corridorName` | string | Nama koridor |
| `tapInStopsName` | string | Nama halte tap-in |
| `tapIn_hour` | float | Jam tap-in (0-24) |
| `duration_minutes` | float | Durasi perjalanan (menit) |
| `is_weekend` | binary | 1 = Sabtu/Minggu |
| `n_trips` | int | Jumlah trip penumpang dalam sebulan |
| `n_days_month` | int | Jumlah hari aktif dalam sebulan |
| `is_commuter` | binary | 1 = commuter (â‰¥15 hari/bulan) |

## Fitur yang Digunakan untuk Clustering

| # | Fitur | Tipe | Standardisasi | Deskripsi |
|---|-------|------|---------------|-----------|
| 1 | `z_tapIn_hour` | kontinu | Z-score | Jam tap-in (meanâ‰ˆ0, sdâ‰ˆ1) |
| 2 | `z_duration_minutes` | kontinu | Z-score | Durasi perjalanan |
| 3 | `z_n_trips` | kontinu | Z-score | Frekuensi trip/bulan |
| 4 | `z_n_days_month` | kontinu | Z-score | Hari aktif/bulan |
| 5 | `is_weekend` | biner | Tidak | Weekend flag |
| 6 | `is_commuter` | biner | Tidak | Commuter flag |

## Hasil Clustering

5 cluster teridentifikasi:

| Cluster | Label | N Obs | % | Jam Rata-rata | Commuter |
|---------|-------|-------|----|---------------|----------|
| 1 | Commuter Pagi Dini | 24.308 | 14,46% | 06:00 | 100% |
| 2 | Commuter Sore | 60.963 | 36,26% | 18:10 | 99,96% |
| 3 | Commuter Pagi | 42.460 | 25,25% | 07:57 | 99,99% |
| 4 | Penumpang Kasual | 24.119 | 14,35% | 13:23 | 0% |
| 5 | Penumpang Intensif | 16.282 | 9,68% | 12:02 | 100% |

## Metrik Evaluasi (K=5)

| Metrik | Nilai | Interpretasi |
|--------|-------|-------------|
| BIC | -1.244.451 | Tertinggi di antara K=2..12 (model VVV) |
| Silhouette | 0,3031 | Reasonable structure (>0,25) |
| Entropy | 0,0365 | Sangat rendah = assignment pasti |
| Composite Score | 0,9016 | Tertinggi = K optimal |

## Referensi Teori

- **GMM**: McLachlan, G.J. & Peel, D. (2000). *Finite Mixture Models*.
- **BIC**: Schwarz, G. (1978). Estimating the dimension of a model.
- **mclust**: Scrucca et al. (2016). mclust 5: Clustering, Classification and Density Estimation.
- **Silhouette**: Rousseeuw, P.J. (1987). Silhouettes: A graphical aid.

