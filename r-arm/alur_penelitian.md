# Alur Penelitian ARM (Implementasi)

## 1) Load Data
- Muat transaksi `datacleancoba.csv`.
- Muat hasil cluster dari GMM (`05_cluster_assignments.csv` + label cluster).
- Normalisasi nama koridor agar konsisten (hapus suffix `via ...`).

## 2) Bangun Topology Koridor
- Dari `data_halte.csv`, buat relasi koridor-halte unik.
- Bentuk graph konektivitas koridor berdasarkan halte bersama.
- Simpan `n_shared_stops` untuk setiap pasangan koridor terarah.

## 3) Bentuk Basis ARM
- Ambil transfer cross-corridor (`lhs != rhs`).
- Tandai pasangan yang valid topologi (`is_connected = TRUE`).
- Bentuk `transaction_id` (`payCardID + date`) untuk analisis frekuensi item.

## 4) Rule Mining
- Hitung kandidat aturan terarah `lhs -> rhs` pada data connected transfer.
- Hitung metrik:
  - `support`
  - `confidence`
  - `lift`
  - metrik lokal (`support_local`, `lift_local`, `rule_score`)
- Lakukan untuk global dan masing-masing cluster.

## 5) Rule Filtering
- Terapkan threshold utama sesuai skripsi (support/confidence/lift).
- Jika terlalu sedikit rule (data sparse), gunakan fallback adaptif berbasis count + confidence + lift.

## 6) Profiling + Evaluasi
- Ringkas statistik per cluster (`cluster_stats.csv`).
- Ringkas kualitas rule per cluster (`arm_summary.csv`).
- Hitung evaluasi global dan per-cluster:
  - coverage
  - compression
  - avg support
  - avg/median lift

## 7) Export ke Dashboard
- Ekspor format final yang dibaca `viz-app`:
  - `rules_all.csv`
  - `rules_global.csv`
  - `arm_summary.csv`
  - `arm_evaluation.csv`
  - `arm_evaluation_cluster.csv`
  - `cluster_stats.csv`
- Sinkron otomatis ke `viz-app/public/data`.

## 8) Visualisasi Offline (PNG)
- Bar jumlah rule per cluster.
- Histogram lift global.
- Scatter support vs confidence.
- Top koridor dalam rules.
- Ringkasan metrik evaluasi.
