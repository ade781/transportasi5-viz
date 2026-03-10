# ==============================================================================
# STEP 08 - VISUALISASI KARAKTERISTIK DATASET
# ==============================================================================
# Tujuan : Membuat visualisasi eksploratif untuk memahami karakteristik data
# Input  : ../data_clean.csv
# Output : data_preparation/visualiasi/*.png
# ==============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
  library(tidyr)
  library(scales)
})

cat("=", strrep("=", 59), "\n")
cat("STEP 08 - VISUALISASI KARAKTERISTIK DATASET\n")
cat("=", strrep("=", 59), "\n\n")

base_dir <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz"
input_path <- file.path(base_dir, "data_clean.csv")
out_dir <- file.path(base_dir, "data_preparation", "visualiasi")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

df <- read_csv(input_path, show_col_types = FALSE) %>%
  mutate(
    date = as.Date(date),
    day_name = factor(
      weekdays(date),
      levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
    ),
    tap_hour_int = pmin(pmax(floor(tapIn_hour), 0), 23),
    commuter_label = if_else(is_commuter == 1, "Commuter", "Non-Commuter"),
    weekend_label = if_else(is_weekend == 1, "Weekend", "Weekday")
  )

cat("Dataset dimuat:", nrow(df), "baris\n")
cat("Periode data :", as.character(min(df$date)), "s/d", as.character(max(df$date)), "\n\n")

# ------------------------------------------------------------------------------
# VIS 1 - 7 hari pertama, 7 panel dalam 1 PNG
# ------------------------------------------------------------------------------
first_7_dates <- sort(unique(df$date))[1:7]
first_7_data <- df %>%
  filter(date %in% first_7_dates) %>%
  count(date, tap_hour_int, name = "n_transaksi") %>%
  complete(date, tap_hour_int = 0:23, fill = list(n_transaksi = 0))

p1 <- ggplot(first_7_data, aes(x = tap_hour_int, y = n_transaksi)) +
  geom_area(fill = "#90CAF9", alpha = 0.45) +
  geom_line(color = "#1565C0", linewidth = 0.6) +
  geom_point(color = "#0D47A1", size = 1.1) +
  facet_wrap(~ date, ncol = 4, scales = "free_y") +
  scale_x_continuous(breaks = seq(0, 23, 3)) +
  scale_y_continuous(labels = label_comma()) +
  labs(
    title = "Pola Transaksi per Jam - 7 Hari Pertama Dataset",
    subtitle = "Setiap panel = 1 hari, menampilkan distribusi volume tap-in per jam",
    x = "Jam tap-in",
    y = "Jumlah transaksi"
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave(
  filename = file.path(out_dir, "01_7hari_pertama_per_jam.png"),
  plot = p1,
  width = 14,
  height = 8,
  dpi = 300
)

# ------------------------------------------------------------------------------
# VIS 2 - Heatmap kalender harian
# ------------------------------------------------------------------------------
daily_counts <- df %>%
  count(date, name = "n_transaksi") %>%
  mutate(
    week_index = as.integer(format(date, "%W")),
    week_index = week_index - min(week_index) + 1,
    day_name = factor(
      weekdays(date),
      levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
    )
  )

p2 <- ggplot(daily_counts, aes(x = week_index, y = day_name, fill = n_transaksi)) +
  geom_tile(color = "white", linewidth = 0.7) +
  geom_text(aes(label = format(date, "%d")), color = "white", size = 3, fontface = "bold") +
  scale_fill_gradient(low = "#B2DFDB", high = "#004D40", labels = label_comma()) +
  labs(
    title = "Heatmap Aktivitas Harian",
    subtitle = "Angka di setiap sel menunjukkan tanggal dalam bulan",
    x = "Urutan Minggu",
    y = "Hari",
    fill = "Transaksi"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    panel.grid = element_blank()
  )

ggsave(
  filename = file.path(out_dir, "02_heatmap_harian_kalender.png"),
  plot = p2,
  width = 11,
  height = 6,
  dpi = 300
)

# ------------------------------------------------------------------------------
# VIS 3 - Distribusi jam tap-in menurut tipe hari
# ------------------------------------------------------------------------------
hour_weektype <- df %>%
  count(weekend_label, tap_hour_int, name = "n")

p3 <- ggplot(hour_weektype, aes(x = tap_hour_int, y = n, color = weekend_label)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.7) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  scale_y_continuous(labels = label_comma()) +
  scale_color_manual(values = c("Weekday" = "#2E7D32", "Weekend" = "#C62828")) +
  labs(
    title = "Perbandingan Pola Jam Tap-In: Weekday vs Weekend",
    x = "Jam tap-in",
    y = "Jumlah transaksi",
    color = "Jenis hari"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave(
  filename = file.path(out_dir, "03_pola_jam_weekday_vs_weekend.png"),
  plot = p3,
  width = 11,
  height = 6,
  dpi = 300
)

# ------------------------------------------------------------------------------
# VIS 4 - Hubungan durasi dan jam tap-in (hex binning via stat_bin2d)
# ------------------------------------------------------------------------------
p4 <- ggplot(df, aes(x = tapIn_hour, y = duration_minutes)) +
  stat_bin2d(bins = 45) +
  scale_fill_gradient(low = "#E3F2FD", high = "#0D47A1", labels = label_comma()) +
  coord_cartesian(xlim = c(5, 22), ylim = c(0, 180)) +
  labs(
    title = "Kepadatan Perjalanan: Jam Tap-In vs Durasi",
    subtitle = "Semakin gelap, semakin banyak transaksi pada kombinasi nilai tersebut",
    x = "Jam tap-in (desimal)",
    y = "Durasi perjalanan (menit)",
    fill = "Jumlah"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave(
  filename = file.path(out_dir, "04_kepadatan_jam_vs_durasi.png"),
  plot = p4,
  width = 11,
  height = 6,
  dpi = 300
)

# ------------------------------------------------------------------------------
# VIS 5 - Komposisi commuter vs non-commuter per hari
# ------------------------------------------------------------------------------
commuter_daily <- df %>%
  count(date, commuter_label, name = "n") %>%
  group_by(date) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

p5 <- ggplot(commuter_daily, aes(x = date, y = pct, fill = commuter_label)) +
  geom_area(alpha = 0.85) +
  scale_y_continuous(labels = label_percent(accuracy = 1)) +
  scale_fill_manual(values = c("Commuter" = "#6A1B9A", "Non-Commuter" = "#FF8F00")) +
  labs(
    title = "Komposisi Harian: Commuter vs Non-Commuter",
    x = "Tanggal",
    y = "Proporsi",
    fill = "Segmen"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave(
  filename = file.path(out_dir, "05_komposisi_commuter_harian.png"),
  plot = p5,
  width = 12,
  height = 6,
  dpi = 300
)

# ------------------------------------------------------------------------------
# VIS 6 - Top 12 koridor + rata-rata durasi
# ------------------------------------------------------------------------------
corridor_stats <- df %>%
  group_by(corridorName) %>%
  summarise(
    n_transaksi = n(),
    mean_duration = mean(duration_minutes, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(n_transaksi)) %>%
  slice_head(n = 12) %>%
  mutate(corridorName = reorder(corridorName, n_transaksi))

p6 <- ggplot(corridor_stats, aes(x = corridorName, y = n_transaksi, fill = mean_duration)) +
  geom_col() +
  coord_flip() +
  scale_y_continuous(labels = label_comma()) +
  scale_fill_gradient(low = "#FFE082", high = "#E65100") +
  labs(
    title = "Top 12 Koridor Berdasarkan Volume Transaksi",
    subtitle = "Warna batang menunjukkan rata-rata durasi perjalanan",
    x = "Koridor",
    y = "Jumlah transaksi",
    fill = "Rata-rata\ndurasi"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 14))

ggsave(
  filename = file.path(out_dir, "06_top_koridor_volume_durasi.png"),
  plot = p6,
  width = 12,
  height = 7,
  dpi = 300
)

cat("[OK] Visualisasi disimpan di:", out_dir, "\n")
cat("     - 01_7hari_pertama_per_jam.png\n")
cat("     - 02_heatmap_harian_kalender.png\n")
cat("     - 03_pola_jam_weekday_vs_weekend.png\n")
cat("     - 04_kepadatan_jam_vs_durasi.png\n")
cat("     - 05_komposisi_commuter_harian.png\n")
cat("     - 06_top_koridor_volume_durasi.png\n")
