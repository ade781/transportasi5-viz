# Alur Penelitian GMM (Versi Sinkron Kode)

Dokumen ini merangkum alur implementasi GMM sesuai script aktual pada folder `r-gmm`.

## Alur Utama

1. Load dan eksplorasi data (`01_load_data.R`)
- Memuat data transaksi.
- Mengecek struktur, missing value, statistik deskriptif.

2. Feature engineering (`02_feature_engineering.R`)
- Fitur kontinu:
  - `tapIn_hour`
  - `duration_minutes`
  - `n_trips`
  - `n_days_month`
- Fitur biner:
  - `is_weekend`
  - `is_commuter`
- Fitur kontinu distandardisasi z-score.

3. Uji normalitas (`03_normality_test.R`)
- KS test pada fitur kontinu terstandardisasi.
- Digunakan sebagai analisis distribusi awal sebelum fitting mixture model.

4. Seleksi kandidat model (`04_bic_selection.R`)
- Kandidat:
  - `K = 2..12`
  - model covariance: `EII`, `VII`, `EEE`, `VVV`
- Untuk tiap `K`, diambil model dengan BIC terbaik.
- Penentuan `K` final memakai elbow pada perubahan BIC:
  - `BIC_delta`
  - `BIC_delta2`
- Output keputusan disimpan di `04_model_selection.csv`:
  - `selected_k`
  - `selected_model`
  - `best_bic_k`
  - `best_bic_model`
  - `selection_method`

5. Fitting GMM final (`05_gmm_fitting.R`)
- Membaca keputusan Step 4.
- Fit EM pada `selected_k` dan `selected_model`.
- Jika model tersebut gagal valid/konvergen, script fallback:
  - coba model kandidat lain pada `K` yang sama,
  - terakhir auto model pada `K` yang sama.
- Output:
  - assignment cluster
  - posterior probability
  - parameter model
  - objek model RDS

6. Profiling cluster (`06_cluster_profiling.R`)
- Join hasil assignment ke data asli via `obs_id` (row index), bukan join ulang yang memicu duplikasi kolom z-score.
- Hitung statistik per cluster.
- Beri label interpretatif cluster.

7. Evaluasi ringkas (`07_evaluation.R`)
- Evaluasi model untuk `K=4,5,6`:
  - `BIC_normalized`
  - `LogLikelihood`
  - `Cluster_balance`
- Output: `07_evaluation_scores.csv`.

8. Visualisasi (`08_visualisasi.R`)
- Membuat 9 grafik.
- Highlight K optimal di grafik dibaca dinamis dari hasil model selection, tidak hardcoded.

## Kenapa BIC + Elbow

- BIC dipakai untuk menilai tradeoff fit vs kompleksitas model.
- Elbow dipakai untuk mendeteksi titik diminishing returns saat menambah cluster.
- Praktiknya:
  - `best_bic_k` memberi model dengan skor BIC tertinggi,
  - `selected_k` memberi pilihan parsimonious berbasis perubahan BIC.

Dengan begitu, pemilihan jumlah cluster tidak hanya mengejar skor tertinggi, tetapi juga stabil dan mudah diinterpretasikan.
