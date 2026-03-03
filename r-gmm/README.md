# Analisis GMM - R Scripts

Folder `r-gmm` berisi pipeline Gaussian Mixture Model untuk segmentasi pola mobilitas penumpang TransJakarta.

## Struktur

```
r-gmm/
|-- 00_prepare_gmm_data.R
|-- 01_load_data.R
|-- 02_feature_engineering.R
|-- 03_normality_test.R
|-- 04_bic_selection.R
|-- 05_gmm_fitting.R
|-- 06_cluster_profiling.R
|-- 07_evaluation.R
|-- 08_visualisasi.R
|-- hasil/
|-- visualisasi/
|-- README.md
|-- alur_penelitian.md
```

## Ringkasan Tiap Step

0. `00_prepare_gmm_data.R`
- Membuat dataset khusus GMM `datacleancoba_gmm.csv` dari `datacleancoba.csv`
- Outlier durasi dipangkas dengan aturan kuantil P1-P99.

1. `01_load_data.R`
- Load data dan statistik awal dataset.

2. `02_feature_engineering.R`
- Bentuk feature matrix (z-score untuk fitur kontinu + fitur biner).
- Fitur untuk proses GMM (Step 4/5/7): `z_tapIn_hour`, `z_duration_minutes`, `z_n_trips`, `z_n_days_month`.

3. `03_normality_test.R`
- Uji normalitas fitur kontinu (KS test) untuk analisis distribusi awal.

4. `04_bic_selection.R`
- Fit kandidat GMM untuk `K=2..12` dengan model covariance `EII/VII/EEE/VVV`.
- Simpan:
  - `04_bic_all_models.csv`
  - `04_bic_best_per_k.csv`
  - `04_model_selection.csv` (ringkasan keputusan: `selected_k`, `selected_model`, `best_bic_k`, dll).

5. `05_gmm_fitting.R`
- Ambil `K` dari hasil Step 4 (`04_model_selection.csv`).
- Fit model final dengan EM.
- Jika model terpilih tidak valid/konvergen, fallback ke model lain pada `K` yang sama, lalu fallback auto model.
- Simpan:
  - `05_cluster_assignments.csv`
  - `05_cluster_probabilities.csv`
  - `05_gmm_parameters.csv`
  - `05_gmm_model.rds`

6. `06_cluster_profiling.R`
- Join assignment ke data asli via `transID` (tanpa duplikasi kolom z-score).
- Buat profil cluster dan label interpretatif.

7. `07_evaluation.R`
- Evaluasi sederhana untuk `K=4,5,6` dengan metrik:
  - `BIC_normalized`
  - `LogLikelihood`
  - `Cluster_balance`
- Output: `07_evaluation_scores.csv`.

8. `08_visualisasi.R`
- Generate 9 grafik.
- Highlight `K` terpilih dibaca dinamis dari `04_model_selection.csv` / hasil final, bukan hardcoded.

## Menjalankan Pipeline

```r
setwd("path/ke/r-gmm")

source("00_prepare_gmm_data.R")
source("01_load_data.R")
source("02_feature_engineering.R")
source("03_normality_test.R")
source("04_bic_selection.R")
source("05_gmm_fitting.R")
source("06_cluster_profiling.R")
source("07_evaluation.R")
source("08_visualisasi.R")
```

## Catatan Konsistensi

- Pemilihan `K` memakai pendekatan elbow pada perubahan BIC (delta dan second-delta), bukan sekadar ambil `K` dengan BIC global tertinggi.
- Step 7 saat ini adalah evaluasi ringkas (bukan silhouette/entropy/composite).
