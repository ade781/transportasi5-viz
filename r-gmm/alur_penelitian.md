# Alur Penelitian: Analisis GMM (Gaussian Mixture Model)

## Bab 3 — Metodologi Penelitian: Clustering dengan GMM

---

## Diagram Alur Penelitian

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ALUR ANALISIS GMM                                │
│                  (Gaussian Mixture Model Clustering)                    │
└─────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────────┐
    │  data_clean.csv     │
    │  (168.132 transaksi)│
    └─────────┬───────────┘
              │
              ▼
    ┌─────────────────────┐    Output:
    │  STEP 1             │───────────► 01_data_overview.csv
    │  Load & Eksplorasi  │───────────► 01_summary_stats.csv
    │  Data               │
    └─────────┬───────────┘
              │
              ▼
    ┌─────────────────────┐    Output:
    │  STEP 2             │───────────► 02_feature_matrix.csv
    │  Feature Engineering│───────────► 02_feature_stats.csv
    │  & Z-Score          │
    │  Standardisasi      │
    └─────────┬───────────┘
              │
              ▼
    ┌─────────────────────┐    Output:
    │  STEP 3             │───────────► 03_normality_test.csv
    │  Uji Normalitas     │
    │  (Kolmogorov-       │    Kesimpulan: Data TIDAK normal
    │   Smirnov Test)     │    → Membenarkan penggunaan GMM
    └─────────┬───────────┘
              │
              ▼
    ┌─────────────────────┐    Output:
    │  STEP 4             │───────────► 04_bic_all_models.csv
    │  Seleksi Model &    │───────────► 04_bic_best_per_k.csv
    │  K Optimal via BIC  │
    │  (K=2..12,          │    Hasil: K=5, Model=VVV (optimal)
    │   EII/VII/EEE/VVV)  │
    └─────────┬───────────┘
              │
              ▼
    ┌─────────────────────┐    Output:
    │  STEP 5             │───────────► 05_cluster_assignments.csv
    │  Fitting GMM Final  │───────────► 05_cluster_probabilities.csv
    │  K=5, Model=VVV     │───────────► 05_gmm_parameters.csv
    │  (Algoritma EM)     │───────────► 05_gmm_model.rds
    └─────────┬───────────┘
              │
              ▼
    ┌─────────────────────┐    Output:
    │  STEP 6             │───────────► 06_cluster_profiles.csv
    │  Profiling &        │───────────► 06_cluster_labeled.csv
    │  Labeling Cluster   │
    └─────────┬───────────┘
              │
              ▼
    ┌─────────────────────┐    Output:
    │  STEP 7             │───────────► 07_evaluation_scores.csv
    │  Evaluasi Model     │
    │  (Silhouette,       │    Hasil: Composite Score = 0.9016
    │   Entropy,          │    → K=5 terkonfirmasi optimal
    │   Composite Score)  │
    └─────────┬───────────┘
              │
              ▼
    ┌─────────────────────┐    Output:
    │  STEP 8             │───────────► 9 file PNG di visualisasi/
    │  Visualisasi        │
    │  (9 grafik)         │
    └─────────────────────┘
```

---

## Detail Setiap Step

### STEP 1: Load & Eksplorasi Data

**Tujuan**: Memuat data dan memahami struktur serta distribusi awal.

**Script**: `01_load_data.R`

**Proses**:
1. Baca `data_clean.csv` (168.132 baris × 20 kolom)
2. Periksa tipe data setiap kolom
3. Cek missing values
4. Hitung summary statistics (min, Q1, median, mean, Q3, max, sd)

**Contoh Data Input** (`data_clean.csv`):

| transID | payCardID | corridorName | tapInStopsName | tapIn_hour | duration_minutes | is_weekend | n_trips | n_days_month | is_commuter |
|---------|-----------|-------------|----------------|------------|-----------------|------------|---------|-------------|-------------|
| YUUK498Z3K60SR | 60404484630 | Term. Pulo Gadung - Lampiri | Dinas Kebersihan Duren Sawit | 16.70 | 80.00 | 1 | 1 | 1 | 0 |
| SANA392O9K62HG | 60404860805 | Pulo Gebang - Matraman | Stasiun Klender | 5.68 | 62.00 | 1 | 1 | 4 | 0 |
| ICXC123J6R94RT | 60404860805 | BKN - Blok M | Gunawarman 2 | 15.57 | 95.00 | 1 | 1 | 4 | 0 |
| BCGW644I9X97YA | 60404860805 | Ragunan - Blok M via Kemang | Blok M Jalur 2 | 16.23 | 54.00 | 1 | 1 | 4 | 0 |
| DLNP271R3W05FH | 60405037726 | Puri Kembangan - Sentraland | Mutiara Taman Palem | 9.03 | 64.00 | 0 | 1 | 18 | 1 |
| BCYK213S8P81RI | 60405037726 | Puri Kembangan - Sentraland | Mutiara Taman Palem | 6.58 | 30.00 | 0 | 3 | 18 | 1 |
| XHJW198M7E84BN | 60405037726 | Puri Kembangan - Sentraland | Jln. Kencana Timur | 19.50 | 99.00 | 0 | 3 | 18 | 1 |
| ASZQ662J1O29BF | 60405037726 | Puri Kembangan - Sentraland | Mutiara Taman Palem | 6.10 | 42.00 | 0 | 3 | 18 | 1 |

---

### STEP 2: Feature Engineering & Standardisasi

**Tujuan**: Memilih fitur relevan dan melakukan z-score standardisasi agar semua fitur kontinu memiliki skala yang sama.

**Script**: `02_feature_engineering.R`

**Fitur yang Dipilih**:
- **4 fitur kontinu** (di-standardisasi z-score): `tapIn_hour`, `duration_minutes`, `n_trips`, `n_days_month`
- **2 fitur biner** (tidak di-standardisasi): `is_weekend`, `is_commuter`

**Rumus Z-Score**:
```
z = (x - μ) / σ
```
Dimana μ = mean fitur, σ = standard deviation fitur.

**Contoh Hasil** (`02_feature_stats.csv`):

| fitur | tipe | min | median | mean | max | sd | skewness | kurtosis |
|-------|------|-----|--------|------|-----|-----|----------|----------|
| z_tapIn_hour | kontinu | -1.37 | -0.30 | 0.00 | 1.71 | 1.00 | 0.08 | 1.31 |
| z_duration_minutes | kontinu | -1.99 | -0.03 | 0.00 | 3.88 | 1.00 | 0.04 | 2.05 |
| z_n_trips | kontinu | -1.11 | -0.07 | 0.00 | 4.06 | 1.00 | 1.66 | 6.96 |
| z_n_days_month | kontinu | -2.98 | 0.20 | 0.00 | 1.47 | 1.00 | -1.57 | 4.47 |
| is_weekend | biner | 0 | 0 | 0.15 | 1 | 0.35 | 2.01 | 5.03 |
| is_commuter | biner | 0 | 1 | 0.86 | 1 | 0.35 | -2.03 | 5.13 |

**Mengapa Z-Score?**
- GMM mengasumsikan Gaussian per komponen; fitur dengan skala berbeda (jam: 0-24 vs hari: 1-30) akan mendominasi jarak
- Z-score membuat semua fitur kontinu memiliki mean=0 dan sd=1, sehingga berkontribusi setara

---

### STEP 3: Uji Normalitas (Kolmogorov-Smirnov)

**Tujuan**: Membuktikan bahwa data secara keseluruhan TIDAK berdistribusi normal, sehingga membenarkan penggunaan GMM sebagai mixture of Gaussians.

**Script**: `03_normality_test.R`

**Metode**: Kolmogorov-Smirnov Test
- H₀: Data berdistribusi normal
- H₁: Data TIDAK berdistribusi normal
- α = 0,05

**Contoh Hasil** (`03_normality_test.csv`):

| fitur | ks_stat | p_value | normal | interpretasi |
|-------|---------|---------|--------|-------------|
| z_tapIn_hour | 0.1885 | < 2.2e-16 | FALSE | tidak normal — GMM mixture of Gaussians tetap sesuai |
| z_duration_minutes | 0.0603 | < 2.2e-16 | FALSE | tidak normal — GMM mixture of Gaussians tetap sesuai |
| z_n_trips | 0.3380 | < 2.2e-16 | FALSE | tidak normal — GMM mixture of Gaussians tetap sesuai |
| z_n_days_month | 0.2699 | < 2.2e-16 | FALSE | tidak normal — GMM mixture of Gaussians tetap sesuai |

**Interpretasi**: Semua p-value < 0.05, sehingga H₀ ditolak. Data tidak normal secara keseluruhan. Ini mengindikasikan adanya beberapa sub-populasi (cluster) yang tumpang tindih — justru inilah yang akan dimodelkan oleh GMM.

---

### STEP 4: Seleksi Model & K Optimal via BIC

**Tujuan**: Menentukan jumlah cluster (K) dan tipe model covariance yang optimal menggunakan Bayesian Information Criterion (BIC).

**Script**: `04_bic_selection.R`

**Proses**:
1. Jalankan GMM untuk K = 2, 3, ..., 12
2. Uji 4 tipe model covariance:
   - **EII**: Spherical, equal volume (identik dengan K-Means)
   - **VII**: Spherical, varying volume
   - **EEE**: Ellipsoidal, equal volume/shape/orientation
   - **VVV**: Ellipsoidal, varying volume/shape/orientation (paling fleksibel)
3. Pilih K dengan BIC tertinggi (di mclust, BIC tertinggi = terbaik)

**Rumus BIC**:
```
BIC = 2 × ln(L) - k × ln(n)
```
Dimana L = likelihood, k = jumlah parameter, n = jumlah observasi.

**Contoh Hasil** (`04_bic_best_per_k.csv`):

| K | ModelType | BIC | LogLik | nParam | BIC_delta |
|---|-----------|-----|--------|--------|-----------|
| 2 | VVV | -1.637.537 | -818.594 | 29 | NA |
| 3 | VVV | -1.387.743 | -693.607 | 44 | 249.794 |
| 4 | VVV | -1.329.885 | -664.588 | 59 | 57.858 |
| **5** | **VVV** | **-1.244.451** | **-621.781** | **74** | **85.434** |
| 6 | EEE | -1.481.559 | -740.545 | 39 | -237.108 |
| 7 | EEE | -1.474.254 | -736.863 | 44 | 7.305 |
| 8 | VII | -1.445.851 | -722.643 | 47 | 28.403 |

**Mengapa K=5?** BIC meningkat signifikan dari K=4 ke K=5 (delta = +85.434), lalu DROP drastis di K=6 (delta = -237.108). Ini menunjukkan K=5 adalah "elbow point".

---

### STEP 5: Fitting GMM Final (K=5, VVV)

**Tujuan**: Melatih model GMM final menggunakan algoritma Expectation-Maximization (EM).

**Script**: `05_gmm_fitting.R`

**Spesifikasi Model**:
- Jumlah komponen: K = 5
- Tipe covariance: VVV (ellipsoidal, varying)
- Algoritma: EM (Expectation-Maximization)
- Inisialisasi: Hierarchical agglomerative clustering

**Algoritma EM (2 langkah iteratif)**:

```
REPEAT hingga konvergen:
  │
  ├── E-Step (Expectation):
  │   Hitung probabilitas posterior setiap observasi
  │   terhadap setiap komponen Gaussian:
  │   
  │   P(z_k | x_i) = π_k × N(x_i | μ_k, Σ_k) / Σ_j π_j × N(x_i | μ_j, Σ_j)
  │
  └── M-Step (Maximization):
      Update parameter berdasarkan posterior:
      - π_k = Σ_i P(z_k | x_i) / N        (mixing proportion)
      - μ_k = Σ_i P(z_k | x_i) × x_i / Σ_i P(z_k | x_i)  (mean)
      - Σ_k = weighted covariance          (covariance matrix)
```

**Contoh Output Probabilitas Posterior** (5 baris pertama dari `05_cluster_probabilities.csv`):

| prob_cl1 | prob_cl2 | prob_cl3 | prob_cl4 | prob_cl5 | cluster |
|----------|----------|----------|----------|----------|---------|
| 0.0000 | 0.0000 | 0.0000 | **1.0000** | 0.0000 | 4 |
| 0.0000 | 0.0000 | 0.0000 | **1.0000** | 0.0000 | 4 |
| 0.0000 | 0.0000 | **0.9999** | 0.0000 | 0.0001 | 3 |
| 0.0000 | 0.0000 | **0.9998** | 0.0000 | 0.0002 | 3 |
| 0.0000 | **0.9999** | 0.0000 | 0.0000 | 0.0001 | 2 |

Probabilitas mendekati 1.0 menunjukkan assignment yang sangat pasti.

---

### STEP 6: Profiling & Labeling Cluster

**Tujuan**: Menghitung statistik deskriptif per cluster dan memberikan label interpretatif.

**Script**: `06_cluster_profiling.R`

**Contoh Hasil** (`06_cluster_profiles.csv`):

| cluster | label | n_obs | pct_obs | mean_tapIn_hour | pct_weekend | pct_commuter | mean_n_trips | mean_n_days_month | top_corridor |
|---------|-------|-------|---------|-----------------|-------------|-------------|-------------|-------------------|-------------|
| 1 | Commuter Pagi Dini | 24.308 | 14,46% | 6,00 | 21,21% | 100% | 1,78 | 23,79 | Matraman Baru - Ancol |
| 2 | Commuter Sore | 60.963 | 36,26% | 18,17 | 0,86% | 99,96% | 1,87 | 21,83 | Matraman Baru - Ancol |
| 3 | Commuter Pagi | 42.460 | 25,25% | 7,95 | 5,59% | 99,99% | 2,06 | 20,22 | Matraman Baru - Ancol |
| 4 | Penumpang Kasual | 24.119 | 14,35% | 13,38 | 59,53% | 0% | 1,56 | 5,49 | Matraman Baru - Ancol |
| 5 | Penumpang Intensif | 16.282 | 9,68% | 12,04 | 12,96% | 100% | 4,02 | 25,69 | Tanah Abang - Kebayoran Lama |

**Interpretasi Setiap Cluster**:

```
Cluster 1: COMMUTER PAGI DINI
├── Jam tap-in rata-rata: 06:00 (paling pagi)
├── Durasi: 40 menit (paling singkat)
├── 100% commuter, aktif ~24 hari/bulan
└── Pekerja yang berangkat pagi-pagi sekali

Cluster 2: COMMUTER SORE
├── Jam tap-in rata-rata: 18:10 (paling sore)
├── Durasi: 84 menit (paling lama)
├── 99,96% commuter, hampir tidak ada weekend
└── Pekerja pulang kantor sore hari

Cluster 3: COMMUTER PAGI
├── Jam tap-in rata-rata: 07:57
├── Durasi: 70 menit
├── 99,99% commuter, weekend rendah
└── Pekerja berangkat jam normal

Cluster 4: PENUMPANG KASUAL
├── Jam bervariasi (sd=4,74), 59,53% weekend
├── 0% commuter, hanya ~5,5 hari/bulan
├── Trip paling sedikit (1,56/bulan)
└── Penumpang non-reguler / rekreasi

Cluster 5: PENUMPANG INTENSIF
├── Jam bervariasi, 100% commuter
├── Trip paling banyak: 4,02/bulan (rata-rata)
├── Hari aktif tertinggi: 25,69 hari/bulan
└── Pengguna TransJakarta paling aktif
```

---

### STEP 7: Evaluasi Model

**Tujuan**: Mengukur kualitas clustering secara kuantitatif dan mengonfirmasi K=5 sebagai pilihan optimal.

**Script**: `07_evaluation.R`

**Metrik yang Digunakan**:

1. **Silhouette Score** (Rousseeuw, 1987)
   - Mengukur seberapa mirip observasi dengan clusternya sendiri vs cluster terdekat
   - Range: [-1, 1]. Lebih tinggi = lebih baik
   - \> 0.25 = reasonable, > 0.50 = strong

2. **Cluster Entropy**
   - Mengukur ketidakpastian probabilitas posterior
   - Entropy = -Σ p(k) × log(p(k))
   - Mendekati 0 = assignment pasti

3. **Composite Score**
   - Gabungan normalisasi BIC, Silhouette, dan inverse Entropy
   - Composite = (norm_BIC + norm_Sil + (1 - norm_Ent)) / 3

**Contoh Hasil** (`07_evaluation_scores.csv`):

| K | BIC | BIC_delta | silhouette | entropy | composite_score |
|---|-----|-----------|------------|---------|-----------------|
| 2 | -1.637.537 | NA | 0,2584 | 0,0218 | 0,3603 |
| 3 | -1.387.743 | 249.794 | 0,3273 | 0,0412 | 0,8354 |
| 4 | -1.329.885 | 57.858 | 0,2333 | 0,0645 | 0,5448 |
| **5** | **-1.244.451** | **85.434** | **0,3031** | **0,0365** | **0,9016** |
| 6 | -1.481.559 | -237.108 | 0,2129 | 0,1587 | 0,2284 |
| 7 | -1.474.254 | 7.305 | 0,2123 | 0,2286 | 0,1662 |
| 8 | -1.445.851 | 28.403 | 0,2139 | 0,1769 | 0,2506 |

**K=5 memiliki composite score tertinggi (0,9016)**, mengonfirmasi bahwa 5 cluster adalah konfigurasi optimal.

---

### STEP 8: Visualisasi

**Tujuan**: Membuat 9 grafik untuk mendukung pembahasan di Bab 3 dan Bab 4.

**Script**: `08_visualisasi.R`

**Grafik yang Dihasilkan**:

```
visualisasi/
├── 01_bic_elbow.png          # Elbow plot BIC vs K
├── 02_bic_delta.png          # Delta BIC (perubahan antar K)
├── 03_cluster_distribution.png # Bar chart distribusi cluster
├── 04_cluster_heatmap.png    # Heatmap z-score per cluster
├── 05_hourly_per_cluster.png # Histogram jam tap-in per cluster
├── 06_evaluation_metrics.png # Line plot metrik evaluasi
├── 07_scatter_hour_duration.png # Scatter jam vs durasi
├── 08_boxplot_features.png   # Boxplot fitur per cluster
└── 09_weekend_commuter.png   # Proporsi weekend & commuter
```

---

## Ringkasan Alur untuk Bab 3

```
DATA MENTAH                 PREPROCESSING               ANALISIS GMM
   │                            │                            │
   ▼                            ▼                            ▼
data_clean.csv ──────► Feature Selection ──────► Uji Normalitas
(168.132 baris)        (6 fitur)                 (KS-test)
                            │                        │
                            ▼                        ▼
                       Z-Score                  Seleksi K via BIC
                       Standardisasi            (K=2..12, 4 model)
                            │                        │
                            ▼                        ▼
                       Feature Matrix           K=5, VVV (optimal)
                       (168.132 × 6)                 │
                                                     ▼
                                                 Fitting GMM
                                                 (Algoritma EM)
                                                     │
                                            ┌────────┴────────┐
                                            ▼                 ▼
                                      Cluster             Evaluasi
                                      Profiling           (Sil, Ent, CS)
                                            │                 │
                                            ▼                 ▼
                                      5 Cluster         CS = 0.9016
                                      Teridentifikasi   (K=5 optimal)
                                            │
                                            ▼
                                      Cluster Labels:
                                      1. Commuter Pagi Dini
                                      2. Commuter Sore
                                      3. Commuter Pagi
                                      4. Penumpang Kasual
                                      5. Penumpang Intensif
                                            │
                                            ▼
                                      ┌──────────────┐
                                      │  INPUT UNTUK │
                                      │  ANALISIS ARM│ ──────► r-arm/
                                      └──────────────┘
```

---

## Catatan Penting

1. **Waktu eksekusi**: Step 4 dan 7 membutuhkan waktu lebih lama (~15-30 menit total) karena fitting GMM untuk berbagai K
2. **Reproducibility**: Hasil mungkin sedikit berbeda antar run karena inisialisasi random, namun struktur cluster yang ditemukan akan konsisten
3. **Memory**: Data 168.132 baris membutuhkan ~500MB RAM saat fitting GMM
4. **Dependensi**: Output setiap step menjadi input step berikutnya, sehingga **harus dijalankan berurutan**
