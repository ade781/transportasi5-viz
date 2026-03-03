# Analisis ARM (Association Rule Mining) - R Scripts

Folder ini berisi pipeline ARM berbasis data transaksi TransJakarta yang sudah disegmentasi oleh GMM.
Output utamanya langsung kompatibel dengan dashboard `viz-app` (`/arm` dan `/map`).

## Struktur Folder

```
r-arm/
|-- 01_load_data.R
|-- 02_prepare_transactions.R
|-- 03_rule_mining.R
|-- 04_rule_filtering.R
|-- 05_cluster_profiling.R
|-- 06_evaluation.R
|-- 07_export_viz_data.R
|-- 08_visualisasi.R
|-- hasil/
|-- visualisasi/
|-- README.md
|-- alur_penelitian.md
```

## Paket R

```r
install.packages(c("readr", "dplyr", "tidyr", "stringr", "ggplot2", "scales"))
```

## Urutan Menjalankan

```r
setwd("path/ke/r-arm")

source("01_load_data.R")
source("02_prepare_transactions.R")
source("03_rule_mining.R")
source("04_rule_filtering.R")
source("05_cluster_profiling.R")
source("06_evaluation.R")
source("07_export_viz_data.R")
source("08_visualisasi.R")
```

## File Input

- `../datacleancoba.csv`
- `../data_halte.csv`
- `../r-gmm/hasil/05_cluster_assignments.csv`
- `../r-gmm/hasil/06_cluster_profiles.csv`

## File Output Utama (untuk viz-app)

- `rules_all.csv`
- `rules_global.csv`
- `arm_summary.csv`
- `arm_evaluation.csv`
- `arm_evaluation_cluster.csv`
- `cluster_stats.csv`

Script `07_export_viz_data.R` otomatis menyalin file di atas ke:
- `../viz-app/public/data/`
- `../viz-app/dist/data/` (jika folder dist sudah ada)

## Catatan Metodologi

- Rules dihitung dari transfer koridor terarah (`lhs -> rhs`) pada transaksi cross-corridor.
- Topology constraint diterapkan: pasangan koridor valid jika berbagi halte (`n_shared_stops > 0`).
- Metrik utama: `support`, `confidence`, `lift` (ditambah skor lokal untuk ranking dashboard).
- Threshold mengikuti skripsi sebagai baseline (`support/confidence/lift`), dengan fallback adaptif untuk data transfer yang sparse.
