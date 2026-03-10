# Data Preparation — TransJakarta

Pipeline data preparation untuk penelitian:
**"Penerapan Gaussian Mixture Model dan Association Rule pada Data TransJakarta
untuk Analisis Pola Mobilitas Penumpang."**

## Struktur Pipeline

| Step | File | Tujuan |
|------|------|--------|
| **STEP 00** | `00_data_quality.r` | Data Quality Assessment — evaluasi missing values tanpa modifikasi |
| **STEP 01** | `01_parse_datetime.r` | Parse DateTime — konversi ke jam desimal, hitung durasi |
| **STEP 02** | `02_filter_durasi.r` | Filter Durasi — hapus duration > 180 menit |
| **STEP 03** | `03_filter_jam.r` | Filter Jam Operasi — pertahankan [05:00–22:00] tap-in, [05:00–22:30] tap-out |
| **STEP 04** | `04_feature_engineering.r` | Feature Engineering — day_of_week, is_weekend, n_trips, is_commuter |
| **STEP 05** | `05_imputation.r` | Group-Based Imputation — isi corridorName via lookup tapInStops |
| **STEP 06** | `06_data_cleaning.r` | Data Cleaning & Outlier Detection — hapus missing + n_trips > 6 |
| **STEP 07** | `07_zscore_normalisasi.r` | Z-Score Normalisasi — standardisasi tapIn_hour & duration_minutes |

## Cara Menjalankan

```r
# Jalankan seluruh pipeline
source("data_preparation/run_all.r")

# Atau jalankan per step
source("data_preparation/00_data_quality.r")
source("data_preparation/01_parse_datetime.r")
# dst...
```

## Struktur Folder

```
data_preparation/
├── 00_data_quality.r
├── 01_parse_datetime.r
├── 02_filter_durasi.r
├── 03_filter_jam.r
├── 04_feature_engineering.r
├── 05_imputation.r
├── 06_data_cleaning.r
├── 07_zscore_normalisasi.r
├── run_all.r
├── README.md
├── artifacts/
│   └── scaling_params.rds       # Mean & SD untuk de-normalisasi
├── csv_outputs/
│   ├── STEP_00_data_quality.csv
│   ├── STEP_01_parsed.csv
│   ├── STEP_02_filter_durasi.csv
│   ├── STEP_03_filter_jam.csv
│   ├── STEP_04_features.csv
│   ├── STEP_05_imputed.csv
│   ├── STEP_06_cleaned.csv
│   ├── STEP_07_normalized.csv
│   └── data_clean.csv           # Dataset bersih (20 kolom terpilih)
└── intermediate/
    ├── 01_parsed.rds
    ├── 02_durasi_ok.rds
    ├── 03_jam_ok.rds
    ├── 04_features.rds
    ├── 05_imputed.rds
    └── 06_clean.rds
```

## Output Final

- **`tj180_final.csv`** — Input untuk GMM (4 kolom: z_tapIn_hour, z_duration_minutes, is_weekend, is_commuter)
- **`data_clean.csv`** — Dataset bersih sebelum normalisasi (20 kolom terpilih)
- **`scaling_params.rds`** — Parameter scaling (mean & sd) untuk de-normalisasi

## Formula

### Jam Desimal
$$\text{jam\_desimal} = \text{jam} + \frac{\text{menit}}{60}$$

### Durasi
$$\text{duration\_minutes} = (\text{tapOut\_hour} - \text{tapIn\_hour}) \times 60$$

### Z-Score
$$Z = \frac{X - \mu}{\sigma}$$

## Variabel yang Dihasilkan

| Variabel | Tipe | Deskripsi |
|----------|------|-----------|
| `tapIn_hour` | numeric | Jam tap-in desimal |
| `tapOut_hour` | numeric | Jam tap-out desimal |
| `duration_minutes` | numeric | Durasi perjalanan (menit) |
| `day_of_week` | integer | 1=Senin … 7=Minggu |
| `is_weekend` | binary | 1 jika Sabtu/Minggu |
| `n_trips` | integer | Jumlah trip per payCardID per hari |
| `n_days_month` | integer | Jumlah hari unik per payCardID dalam 1 bulan |
| `is_commuter` | binary | 1 jika n_days_month ≥ 15 |
| `trip_num` | integer | Urutan trip dalam satu hari |
