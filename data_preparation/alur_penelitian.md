# 3.3 Tahap Persiapan Data (*Data Preparation*)

Tahap persiapan data bertujuan mengubah data mentah TransJakarta menjadi dataset yang bersih, konsisten, dan siap digunakan sebagai input model GMM dan Algoritma Apriori (ARM). Proses ini terdiri dari delapan langkah berurutan yang saling bergantung.

---

## Alur Tahapan

```
[RAW DATA]  tj180.csv  (189.500 baris × 22 kolom)
     │
     ▼
┌─────────────────────────────────────────────┐
│  STEP 00 — Penilaian Kualitas Data          │
│  Identifikasi nilai hilang tanpa modifikasi │
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  STEP 01 — Parsing Variabel Waktu           │
│  tapInTime / tapOutTime → numerik desimal   │
│  189.500 baris (tidak ada penghapusan)      │
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  STEP 02 — Filter Durasi Perjalanan         │
│  Hapus durasi ≤ 0 atau > 180 menit          │
│  182.762 baris  (−6.738 / −3,56%)           │
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  STEP 03 — Filter Jam Operasional           │
│  Pertahankan tapIn ∈ [5.0, 22.0]            │
│              tapOut ∈ [5.0, 22.5]           │
│  173.477 baris  (−9.285 / −5,08%)           │
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  STEP 04 — Rekayasa Fitur                   │
│  Tambah: day_of_week, is_weekend, n_trips,  │
│          n_days_month, is_commuter, trip_num│
│  173.477 baris (tidak ada penghapusan)      │
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  STEP 05 — Imputasi Berbasis Kelompok       │
│  Isi corridorName yang hilang via lookup    │
│  tapInStops → corridorName                  │
│  173.477 baris (11.833 nilai berhasil diisi)│
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  STEP 06 — Pembersihan Data & Outlier       │
│  Hapus: tap-out hilang, corridorName gagal, │
│         n_trips > 6                         │
│  168.132 baris  (−5.345 / −3,08%)           │
└─────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────┐
│  STEP 07 — Normalisasi Z-Score              │
│  Standarisasi tapIn_hour & duration_minutes │
│  168.132 baris (tidak ada penghapusan)      │
└─────────────────────────────────────────────┘
     │
     ▼
[OUTPUT FINAL]  tj180_final.csv  (168.132 baris × 4 kolom)
```

---

## Detail Tiap Tahap

---

### STEP 00 — Penilaian Kualitas Data

**Tujuan:** Mengidentifikasi distribusi nilai hilang (*missing values*) pada seluruh kolom sebelum proses pembersihan dimulai. Tahap ini bersifat *assessment only* — tidak ada perubahan data.

**Kriteria nilai hilang:** `NA`, string kosong `""`, atau string yang hanya berisi spasi.

**Temuan (Top 8 kolom dengan nilai hilang):**

| Kolom | Nilai Hilang | Persentase |
|-------|-------------:|-----------:|
| corridorName    | 13.528 | 7,14% |
| tapOutStops     | 12.369 | 6,53% |
| tapInStops      |  7.241 | 3,82% |
| corridorID      |  6.980 | 3,68% |
| tapOutStopsName |  6.720 | 3,55% |
| tapOutStopsLat  |  6.720 | 3,55% |
| tapOutStopsLon  |  6.720 | 3,55% |
| stopEndSeq      |  6.720 | 3,55% |

> Kolom `corridorName` menjadi prioritas penanganan karena merupakan atribut utama yang digunakan dalam analisis ARM.

---

### STEP 01 — Parsing Variabel Waktu

**Tujuan:** Mengubah kolom waktu bertipe string (`tapInTime`, `tapOutTime`) menjadi representasi numerik kontinu.

**Formula:**
- `tapIn_hour = jam_tapIn + menit_tapIn / 60`
- `tapOut_hour = jam_tapOut + menit_tapOut / 60`
- `duration_minutes = (tapOut_hour − tapIn_hour) × 60`

**Format asal:** `MM/DD/YYYY HH:MM` → diubah ke `POSIXct` lalu diekstrak.  
**Kolom dihapus:** `tapInTime`, `tapOutTime` (tidak lagi diperlukan).

**Sebelum** (data mentah):

| transID | payCardBank | corridorName | tapInTime | tapOutTime | payAmount |
|---------|-------------|--------------|-----------|------------|----------:|
| VRPJ892P3M98RA | dki    | Pulo Gadung 2 - Tosari        | 4/3/2023 6:53  | 4/3/2023 7:13  | 3.500 |
| ZWCH834I6M26HS | emoney | Kp. Rambutan - Taman Wiladatika | 4/3/2023 5:59 | 4/3/2023 6:57  | 0     |
| YRLD835V6L82GO | emoney | Bekasi Barat - Blok M         | 4/3/2023 5:13  | 4/3/2023 6:01  | 20.000|
| ZZBX143N6N83HQ | dki    | Batusari - Grogol             | 4/3/2023 5:20  | 4/3/2023 6:01  | 3.500 |
| EWEG491A2W45DR | bni    | *(NA)*                        | 4/3/2023 6:00  | 4/3/2023 6:47  | 3.500 |

**Sesudah:**

| transID | payCardBank | date | tapIn_hour | tapOut_hour | duration_minutes |
|---------|-------------|------|------------|-------------|----------------:|
| VRPJ892P3M98RA | dki    | 2023-04-02 | 6,88 | 7,22 | 20 |
| ZWCH834I6M26HS | emoney | 2023-04-02 | 5,98 | 6,95 | 58 |
| YRLD835V6L82GO | emoney | 2023-04-02 | 5,22 | 6,02 | 48 |
| ZZBX143N6N83HQ | dki    | 2023-04-02 | 5,33 | 6,02 | 41 |
| EWEG491A2W45DR | bni    | 2023-04-02 | 6,00 | 6,78 | 47 |

---

### STEP 02 — Filter Durasi Perjalanan

**Tujuan:** Menghapus observasi dengan durasi perjalanan yang tidak masuk akal secara operasional.

**Kriteria penghapusan:** `duration_minutes ≤ 0` atau `duration_minutes > 180`  
**Justifikasi:** Durasi lebih dari 180 menit (3 jam) dianggap tidak wajar untuk satu perjalanan TransJakarta dalam area DKI Jakarta.

**Sebelum** (contoh baris yang akan dihapus):

| transID | tapIn_hour | tapOut_hour | duration_minutes | date |
|---------|------------|-------------|----------------:|------|
| UQOC668B0O29CH | 19,6 | 22,6 | 179 | 2023-04-28 |
| NZTW423V4D48KV | 20,4 | 23,3 | 177 | 2023-04-09 |
| PPEN380H9O82GO |  9,8 | 12,8 | 179 | 2023-04-07 |
| QIST159H4S38RL | 16,9 | 19,9 | 178 | 2023-04-12 |
| LZRA435K7O75UO | 19,3 | 22,3 | 178 | 2023-04-18 |

**Sesudah** (baris valid yang dipertahankan):

| transID | date | tapIn_hour | tapOut_hour | duration_minutes |
|---------|------|------------|-------------|----------------:|
| VRPJ892P3M98RA | 2023-04-02 | 6,88 | 7,22 | 20 |
| ZWCH834I6M26HS | 2023-04-02 | 5,98 | 6,95 | 58 |
| YRLD835V6L82GO | 2023-04-02 | 5,22 | 6,02 | 48 |
| ZZBX143N6N83HQ | 2023-04-02 | 5,33 | 6,02 | 41 |
| EWEG491A2W45DR | 2023-04-02 | 6,00 | 6,78 | 47 |

**Hasil:** 182.762 baris (−6.738 baris, −3,56%)

---

### STEP 03 — Filter Jam Operasional

**Tujuan:** Mempertahankan hanya observasi yang sesuai dengan jam operasional TransJakarta.

**Kriteria dipertahankan:**  
- `tapIn_hour ∈ [5,0 ; 22,0]`  
- `tapOut_hour ∈ [5,0 ; 22,5]`

**Justifikasi:** TransJakarta beroperasi mulai pukul 05.00 hingga sekitar 22.00–22.30 WIB. Data di luar rentang ini dianggap sebagai anomali sistem pencatatan.

**Sebelum** (contoh baris yang akan dihapus — jam tap-out melebihi batas operasi):

| transID | date | tapIn_hour | tapOut_hour | duration_minutes |
|---------|------|------------|-------------|----------------:|
| QOQC805G4H72CY | 2023-04-03 | 20,9 | 22,7 | 106 |
| PYSE527R5D57XU | 2023-04-03 | 21,4 | 22,8 |  87 |
| YYSX315G7L65BE | 2023-04-03 | 21,8 | 23,3 |  90 |
| QDTT936R3M70EG | 2023-04-03 | 21,8 | 23,4 |  97 |
| HFQA973H9G56KF | 2023-04-03 | 21,6 | 23,3 | 101 |

**Sesudah:**

| transID | date | tapIn_hour | tapOut_hour | duration_minutes |
|---------|------|------------|-------------|----------------:|
| VRPJ892P3M98RA | 2023-04-02 | 6,88 | 7,22 | 20 |
| ZWCH834I6M26HS | 2023-04-02 | 5,98 | 6,95 | 58 |
| YRLD835V6L82GO | 2023-04-02 | 5,22 | 6,02 | 48 |
| ZZBX143N6N83HQ | 2023-04-02 | 5,33 | 6,02 | 41 |
| EWEG491A2W45DR | 2023-04-02 | 6,00 | 6,78 | 47 |

**Hasil:** 173.477 baris (−9.285 baris, −5,08%)

---

### STEP 04 — Rekayasa Fitur (*Feature Engineering*)

**Tujuan:** Membuat kolom fitur baru yang relevan untuk analisis pola mobilitas penumpang.

| Fitur | Definisi |
|-------|----------|
| `day_of_week`   | Hari dalam minggu: 1 (Senin) hingga 7 (Minggu), diekstrak dari `date` |
| `is_weekend`    | `1` jika `day_of_week ∈ {6,7}`, selain itu `0` |
| `n_trips`       | Jumlah transaksi per `payCardID` per `date` |
| `n_days_month`  | Jumlah hari unik per `payCardID` dalam bulan pengamatan |
| `is_commuter`   | `1` jika `n_days_month ≥ 15`, selain itu `0` |
| `trip_num`      | Urutan perjalanan dalam satu hari per penumpang, diurutkan berdasarkan `tapIn_hour` |

**Sebelum** (kolom fitur belum ada):

| transID | date | tapIn_hour | duration_minutes |
|---------|------|------------|----------------:|
| VRPJ892P3M98RA | 2023-04-02 | 6,88 | 20 |
| ZWCH834I6M26HS | 2023-04-02 | 5,98 | 58 |
| YRLD835V6L82GO | 2023-04-02 | 5,22 | 48 |
| ZZBX143N6N83HQ | 2023-04-02 | 5,33 | 41 |
| EWEG491A2W45DR | 2023-04-02 | 6,00 | 47 |

**Sesudah** (kolom fitur ditambahkan):

| transID | date | tapIn_hour | day_of_week | is_weekend | n_trips | n_days_month | is_commuter | trip_num |
|---------|------|------------|:-----------:|:----------:|:-------:|:------------:|:-----------:|:--------:|
| YUUK498Z3K60SR | 2023-04-23 | 16,70 | 7 | 1 | 1 |  1 | 0 | 1 |
| SANA392O9K62HG | 2023-04-08 |  5,68 | 6 | 1 | 1 |  4 | 0 | 1 |
| ICXC123J6R94RT | 2023-04-16 | 15,57 | 7 | 1 | 1 |  4 | 0 | 1 |
| BCGW644I9X97YA | 2023-04-22 | 16,23 | 6 | 1 | 1 |  4 | 0 | 1 |
| SZGB033K6L72TR | 2023-04-30 |  9,87 | 7 | 1 | 1 |  4 | 0 | 1 |

---

### STEP 05 — Imputasi Berbasis Kelompok

**Tujuan:** Mengisi nilai `corridorName` yang hilang menggunakan relasi antar baris dalam dataset berdasarkan `tapInStops` sebagai kunci pencarian.

**Mekanisme:** Dibangun *lookup table* dari baris-baris yang memiliki `tapInStops` dan `corridorName` lengkap.  
Terdapat tiga kondisi penanganan:

| Kondisi | Keterangan | Hasil |
|---------|-----------|-------|
| **K-1** | `corridorName` hilang + `tapInStops` tersedia | → Isi dari lookup table |
| **K-2** | `tapInStops` juga hilang | → Tandai *unresolved*, tidak dapat diimputasi |
| **K-3** | `tapInStops` ada, tapi tidak ada referensi di tabel | → Tandai *unresolved* |

**Statistik:** 12.376 missing → berhasil diisi 11.833 (95,6%) → sisa 543 (0,31%) tetap kosong.

**Sebelum** (corridorName masih NA):

| transID | tapInStops | tapInStopsName | corridorID | corridorName |
|---------|-----------|----------------|-----------|-------------|
| RRYX227I4G07KK | B02526P | Mutiara Taman Palem          | *(NA)* | *(NA)* |
| TYGE200E3L60HA | B06302P | Jln. Kencana Timur           | *(NA)* | *(NA)* |
| BDLS455T0O11YV | B00688P | Grand Centro Bintaro         | JAK.49 | *(NA)* |
| MNJF069F8Z71IF | B02009P | Kolong Tol Jakarta Serpong 1 | *(NA)* | *(NA)* |
| FIUJ609E4D83OB | P00179  | Pinang Ranti                 | *(NA)* | *(NA)* |

**Sesudah** (corridorName terisi via lookup):

| transID | tapInStops | tapInStopsName | corridorID | corridorName |
|---------|-----------|----------------|-----------|-------------|
| RRYX227I4G07KK | B02526P | Mutiara Taman Palem          | *(NA)* | Puri Kembangan - Sentraland Cengkareng |
| TYGE200E3L60HA | B06302P | Jln. Kencana Timur           | *(NA)* | Rusun Flamboyan - Kota |
| BDLS455T0O11YV | B00688P | Grand Centro Bintaro         | JAK.49 | Lebak Bulus - Cipulir |
| MNJF069F8Z71IF | B02009P | Kolong Tol Jakarta Serpong 1 | *(NA)* | Lebak Bulus - Cipulir |
| FIUJ609E4D83OB | P00179  | Pinang Ranti                 | *(NA)* | Pinang Ranti - Kampung Melayu |

---

### STEP 06 — Pembersihan Data dan Deteksi Outlier

**Tujuan:** Menghapus observasi yang secara logis tidak valid dan observasi yang teridentifikasi sebagai outlier perilaku perjalanan.

**Kriteria penghapusan:**

| Bagian | Aturan | Jumlah Dihapus |
|--------|--------|---------------:|
| A1 | `tapOut_hour` masih NA (tidak ada tap-out) | 0 baris |
| A2 | `corridorName` masih kosong setelah imputasi | 543 baris |
| B1 | `n_trips > 6` per penumpang per hari (outlier) | 4.802 baris |

**Justifikasi outlier:** Penumpang yang melakukan lebih dari 6 perjalanan dalam satu hari dianggap aktivitas tidak wajar yang kemungkinan merupakan kartu yang digunakan bersama atau anomali sistem.

**Sebelum** (contoh baris outlier yang akan dihapus — `n_trips > 6`):

| transID | date | n_trips | tapIn_hour | duration_minutes | corridorName |
|---------|------|:-------:|------------|----------------:|-------------|
| RNYF294... | 2023-04-03 |  7 |  5,8 |  55 | Rusun Cipinang - Cawang |
| HJYZ917... | 2023-04-03 |  7 |  6,6 |  42 | Rusun Pesakih - Grogol |
| GXPE219... | 2023-04-03 |  7 |  9,0 | 102 | Grogol - Srengseng |
| AJJT214... | 2023-04-03 |  7 |  9,1 |  34 | Pasar Minggu - Tanah Abang |
| LUNZ321... | 2023-04-03 |  7 | 17,5 |  51 | Rusun Pesakih - Grogol |

**Sesudah:**

| transID | date | tapIn_hour | duration_minutes | n_trips | corridorName |
|---------|------|------------|----------------:|:-------:|-------------|
| YUUK498Z3K60SR | 2023-04-23 | 16,7 |  80 | 1 | Term. Pulo Gadung - Lampiri |
| SANA392O9K62HG | 2023-04-08 |  5,7 |  62 | 1 | Pulo Gebang - Matraman |
| ICXC123J6R94RT | 2023-04-16 | 15,6 |  95 | 1 | BKN - Blok M |
| BCGW644I9X97YA | 2023-04-22 | 16,2 |  54 | 1 | Ragunan - Blok M via Kemang |
| SZGB033K6L72TR | 2023-04-30 |  9,9 |  87 | 1 | Rempoa - Blok M |

**Hasil:** 168.132 baris (−5.345 baris, −3,08%)

---

### STEP 07 — Normalisasi Z-Score

**Tujuan:** Menstandarisasi variabel kontinu agar memiliki skala yang setara sebagai input model GMM.

**Formula:**

$$z = \frac{x - \mu}{\sigma}$$

**Variabel yang dinormalisasi:**

| Variabel | Mean (μ) | Std Dev (σ) | Kolom Output |
|----------|--------:|------------:|-------------|
| `tapIn_hour`       | 12,547 | 5,518 | `z_tapIn_hour` |
| `duration_minutes` | 70,979 | 28,105 | `z_duration_minutes` |

> **Catatan:** Variabel biner `is_weekend` dan `is_commuter` **tidak** dinormalisasi karena hanya memiliki nilai 0 atau 1 — normalisasi akan menghilangkan makna kategorikalnya.

**Sebelum:**

| transID | tapIn_hour | duration_minutes | is_weekend | is_commuter |
|---------|------------|----------------:|:----------:|:-----------:|
| YUUK498Z3K60SR |  16,7 |  80 | 1 | 0 |
| SANA392O9K62HG |   5,7 |  62 | 1 | 0 |
| ICXC123J6R94RT |  15,6 |  95 | 1 | 0 |
| BCGW644I9X97YA |  16,2 |  54 | 1 | 0 |
| SZGB033K6L72TR |   9,9 |  87 | 1 | 0 |

**Sesudah** (output final — 4 kolom untuk GMM):

| z_tapIn_hour | z_duration_minutes | is_weekend | is_commuter |
|-------------:|-------------------:|:----------:|:-----------:|
|  0,753 |  0,321 | 1 | 0 |
| −1,241 | −0,319 | 1 | 0 |
|  0,547 |  0,855 | 1 | 0 |
|  0,668 | −0,604 | 1 | 0 |
| −0,486 |  0,570 | 1 | 0 |

---

## Ringkasan Alur Data

| Step | Proses | Jumlah Baris | Perubahan |
|:----:|--------|-------------:|----------:|
| Raw  | Data mentah original | 189.500 | — |
| 00   | Penilaian kualitas data | 189.500 | (assessment only) |
| 01   | Parsing variabel waktu | 189.500 | 0 |
| 02   | Filter durasi > 180 menit | 182.762 | −6.738 (−3,56%) |
| 03   | Filter jam operasional | 173.477 | −9.285 (−5,08%) |
| 04   | Rekayasa fitur | 173.477 | 0 |
| 05   | Imputasi corridorName | 173.477 | 0 (11.833 nilai diisi) |
| 06   | Pembersihan & outlier | 168.132 | −5.345 (−3,08%) |
| 07   | Normalisasi Z-Score | 168.132 | 0 |
| **Final** | **tj180_final.csv** | **168.132** | **−21.368 total (−11,27%)** |
