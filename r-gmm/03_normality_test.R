# ==============================================================================
# STEP 3: UJI NORMALITAS (KOLMOGOROV-SMIRNOV)
# ==============================================================================
# Deskripsi : Uji normalitas pada fitur kontinu menggunakan KS-test.
# Input     : hasil/02_feature_matrix.csv
# Output    : hasil/03_normality_test.csv
# ==============================================================================

library(readr)
library(dplyr)

cat("=", strrep("=", 59), "\n")
cat("STEP 3: UJI NORMALITAS (KOLMOGOROV-SMIRNOV)\n")
cat("=", strrep("=", 59), "\n\n")

# Set paths untuk output (otomatis berdasarkan lokasi script/project aktif)
script_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", script_args, value = TRUE)
if (length(file_arg) > 0) {
    script_path <- sub("^--file=", "", file_arg[1])
    base_dir <- dirname(normalizePath(script_path, winslash = "/", mustWork = TRUE))
} else {
    wd <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
    base_dir <- if (basename(wd) == "r-gmm") wd else file.path(wd, "r-gmm")
}
hasil_dir <- file.path(base_dir, "hasil")
dir.create(hasil_dir, recursive = TRUE, showWarnings = FALSE)

fm <- read_csv(file.path(hasil_dir, "02_feature_matrix.csv"), show_col_types = FALSE)
cat("Feature matrix dimuat:", nrow(fm), "baris\n\n")

z_features <- c("z_tapIn_hour", "z_duration_minutes", "z_n_trips", "z_n_days_month")

cat("Uji Kolmogorov-Smirnov (H0: data berdistribusi normal)\n")
cat("Alpha = 0.05\n\n")

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
    x <- x[is.finite(x)]
    ks <- ks.test(x, "pnorm", mean = mean(x), sd = sd(x))
    is_normal <- ks$p.value > 0.05

    interp <- ifelse(
        is_normal,
        "normal",
        "tidak normal"
    )

    results <- rbind(results, data.frame(
        fitur = feat,
        ks_stat = round(as.numeric(ks$statistic), 4),
        p_value = ks$p.value,
        normal = is_normal,
        interpretasi = interp,
        stringsAsFactors = FALSE
    ))

    cat(sprintf(
        "  %-25s D=%0.4f  p=%s  --> %s\n",
        feat,
        as.numeric(ks$statistic),
        ifelse(ks$p.value < 2.2e-16, "< 2.2e-16", format(ks$p.value, scientific = TRUE, digits = 3)),
        ifelse(is_normal, "NORMAL", "TIDAK NORMAL")
    ))
}

rownames(results) <- NULL

cat("\n")
cat("=", strrep("=", 59), "\n")
cat("KESIMPULAN:\n")
cat("=", strrep("=", 59), "\n")
n_not_normal <- sum(!results$normal)
cat(sprintf("  %d dari %d fitur TIDAK berdistribusi normal.\n", n_not_normal, nrow(results)))
cat("  Hal ini mendukung penggunaan GMM (mixture of Gaussians).\n\n")

write_csv(results, file.path(hasil_dir, "03_normality_test.csv"))
cat("[OK] File disimpan di", file.path(hasil_dir, "03_normality_test.csv"), "\n")
