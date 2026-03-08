# ==============================================================================
# STEP 3: UJI NORMALITAS (KOLMOGOROV-SMIRNOV)
# ==============================================================================
# Deskripsi : Uji normalitas pada fitur kontinu menggunakan KS-test
#             Membuktikan data tidak normal, sehingga GMM (mixture of Gaussians)
#             lebih tepat dibanding single Gaussian / K-Means
# Input     : hasil/02_feature_matrix.csv
# Output    : hasil/03_normality_test.csv
# ==============================================================================

# -- Library --
library(readr)
library(dplyr)

cat("=", strrep("=", 59), "\n")
cat("STEP 3: UJI NORMALITAS (KOLMOGOROV-SMIRNOV)\n")
cat("=", strrep("=", 59), "\n\n")

# -- Load feature matrix --
hasil_dir <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/r-gmm/hasil"
fm <- read_csv(file.path(hasil_dir, "02_feature_matrix.csv"), show_col_types = FALSE)
cat("Feature matrix dimuat:", nrow(fm), "baris\n\n")

# -- Fitur kontinu yang diuji --
z_features <- c("z_tapIn_hour", "z_duration_minutes", "z_n_trips", "z_n_days_month")

cat("Uji Kolmogorov-Smirnov (H0: data berdistribusi normal)\n")
cat("Alpha = 0.05\n\n")

# -- Jalankan KS-test --
results <- data.frame(
    fitur = character(),
    ks_stat = numeric(),
    p_value = numeric(),
    normal = logical(),
    interpretasi = character(),
    stringsAsFactors = FALSE
)

for (feat in z_features) {
    x <- fm[[feat]]

    # KS test terhadap distribusi normal standar
    ks <- ks.test(x, "pnorm", mean = mean(x), sd = sd(x))

    is_normal <- ks$p.value > 0.05

    interp <- ifelse(
        is_normal,
        "normal — dapat menggunakan metode parametrik standar",
        "tidak normal — GMM mixture of Gaussians tetap sesuai"
    )

    results <- rbind(results, data.frame(
        fitur = feat,
        ks_stat = round(ks$statistic, 4),
        p_value = ks$p.value,
        normal = is_normal,
        interpretasi = interp,
        stringsAsFactors = FALSE
    ))

    cat(sprintf(
        "  %-25s D=%0.4f  p=%s  --> %s\n",
        feat, ks$statistic,
        ifelse(ks$p.value < 2.2e-16, "< 2.2e-16",
            format(ks$p.value, scientific = TRUE, digits = 3)
        ),
        ifelse(is_normal, "NORMAL", "TIDAK NORMAL")
    ))
}

rownames(results) <- NULL

cat("\n")
cat("=", strrep("=", 59), "\n")
cat("KESIMPULAN:\n")
cat("=", strrep("=", 59), "\n")
n_not_normal <- sum(!results$normal)
cat(sprintf(
    "  %d dari %d fitur TIDAK berdistribusi normal.\n",
    n_not_normal, nrow(results)
))
cat("  Hal ini membenarkan penggunaan GMM (Gaussian Mixture Model)\n")
cat("  yang mampu menangkap campuran (mixture) dari beberapa distribusi\n")
cat("  Gaussian, berbeda dengan K-Means yang mengasumsikan cluster bulat.\n\n")

cat("  Mengapa GMM tetap sesuai meskipun data tidak normal?\n")
cat("  -> GMM tidak mengasumsikan data total berdistribusi normal.\n")
cat("  -> GMM mengasumsikan data merupakan CAMPURAN dari beberapa\n")
cat("     distribusi Gaussian (mixture of Gaussians).\n")
cat("  -> Setiap komponen Gaussian menangkap satu sub-populasi.\n")
cat("  -> Justru karena data tidak normal secara keseluruhan,\n")
cat("     mengindikasikan adanya beberapa sub-populasi/cluster.\n\n")

# -- Simpan hasil --
write_csv(results, file.path(hasil_dir, "03_normality_test.csv"))
cat("[OK] File disimpan di", file.path(hasil_dir, "03_normality_test.csv"), "\n")
