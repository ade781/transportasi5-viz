# ==============================================================================
# STEP 4: SELEKSI MODEL GMM DENGAN BIC + ELBOW
# ==============================================================================
# Deskripsi : Menjalankan GMM untuk K=2..12 dan beberapa tipe covariance,
#             lalu memilih K final dengan elbow pada kurva BIC.
# Input     : hasil/02_feature_matrix.csv
# Output    : hasil/04_bic_all_models.csv, hasil/04_bic_best_per_k.csv,
#             hasil/04_model_selection.csv
# ==============================================================================

library(readr)
library(dplyr)
library(mclust)

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
visualisasi_dir <- file.path(base_dir, "visualisasi")

dir.create(hasil_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visualisasi_dir, recursive = TRUE, showWarnings = FALSE)

cat("=", strrep("=", 59), "\n")
cat("STEP 4: SELEKSI MODEL GMM DENGAN BIC + ELBOW\n")
cat("=", strrep("=", 59), "\n\n")

fm <- read_csv(file.path(hasil_dir, "02_feature_matrix.csv"), show_col_types = FALSE)
cat("Feature matrix dimuat:", nrow(fm), "baris\n\n")

features <- fm %>% select(
    z_tapIn_hour, z_duration_minutes, z_n_trips, z_n_days_month
)
X <- as.matrix(features)

cat("Menjalankan Mclust untuk K=2 hingga K=12...\n")
cat("Model types: EII, VII, EEE, VVV\n\n")

model_types <- c("EII", "VII", "EEE", "VVV")
K_range <- 2:12

set.seed(12345)
mc <- mclustBIC(X, G = K_range, modelNames = model_types)

cat("BIC computation selesai.\n\n")

bic_matrix <- as.data.frame(mc[, ])
bic_matrix$K <- K_range

bic_all <- data.frame()
for (model in model_types) {
    if (model %in% colnames(bic_matrix)) {
        tmp <- data.frame(
            K = K_range,
            ModelType = model,
            BIC = bic_matrix[[model]],
            stringsAsFactors = FALSE
        )
        bic_all <- rbind(bic_all, tmp)
    }
}

p <- ncol(X)
bic_all <- bic_all %>%
    filter(!is.na(BIC)) %>%
    mutate(
        nParam = case_when(
            ModelType == "EII" ~ K * p + K + (K - 1),
            ModelType == "VII" ~ K * p + K + K + (K - 1),
            ModelType == "EEE" ~ K * p + p * (p + 1) / 2 + (K - 1),
            ModelType == "VVV" ~ K * p + K * p * (p + 1) / 2 + (K - 1),
            TRUE ~ NA_real_
        ),
        LogLik = (BIC + nParam * log(nrow(X))) / 2
    ) %>%
    arrange(K, ModelType)

cat("Tabel BIC semua model:\n")
print(as.data.frame(head(bic_all, 20)))
cat("...(showing first 20 rows out of", nrow(bic_all), ")\n")

bic_best <- bic_all %>%
    group_by(K) %>%
    filter(BIC == max(BIC, na.rm = TRUE)) %>%
    ungroup() %>%
    arrange(K) %>%
    mutate(BIC_delta = BIC - lag(BIC))

cat("\nBest model per K (BIC tertinggi):\n")
print(bic_best)

cat("\nBIC delta (perubahan BIC terhadap K sebelumnya):\n")
print(bic_best %>% select(K, ModelType, BIC, BIC_delta))

bic_deltas <- bic_best %>%
    filter(!is.na(BIC_delta)) %>%
    select(K, ModelType, BIC, BIC_delta) %>%
    mutate(BIC_delta2 = BIC_delta - lag(BIC_delta))

cat("\nAnalisis Elbow Method (Second Derivative):\n")
cat(strrep("-", 70), "\n")
cat(sprintf("  %-4s  %14s  %14s  %s\n", "K", "Delta BIC", "Delta2 BIC", "Interpretasi"))
cat(strrep("-", 70), "\n")

if (nrow(bic_deltas) > 0) {
    for (i in seq_len(nrow(bic_deltas))) {
        d <- bic_deltas[i, ]
        if (is.na(d$BIC_delta2)) {
            interp <- "(baseline)"
        } else if (d$BIC_delta2 < -50000) {
            interp <- "<<< PENURUNAN DRASTIS (kandidat elbow)"
        } else if (d$BIC_delta2 < 0) {
            interp <- "< melambat"
        } else {
            interp <- "> akselerasi"
        }
        cat(sprintf(
            "  K=%2d  %+14.0f  %14s  %s\n",
            d$K, d$BIC_delta,
            ifelse(is.na(d$BIC_delta2), "NA", sprintf("%+.0f", d$BIC_delta2)),
            interp
        ))
    }
}
cat(strrep("-", 70), "\n")

best_overall <- bic_best %>%
    filter(BIC == max(BIC, na.rm = TRUE)) %>%
    arrange(K) %>%
    slice(1)

# Seleksi final menggunakan BIC global tertinggi.
# Elbow tetap ditampilkan sebagai referensi diagnostik.
first_slowdown <- bic_deltas %>%
    filter(!is.na(BIC_delta2), BIC_delta2 < 0) %>%
    arrange(K) %>%
    slice(1)

selected_k <- as.integer(best_overall$K)
selected_model <- as.character(best_overall$ModelType)
selected_bic <- as.numeric(best_overall$BIC)
selection_method <- "best_bic_global"

elbow_delta2 <- NA_real_
if (nrow(first_slowdown) > 0) {
    elbow_delta2 <- as.numeric(first_slowdown$BIC_delta2)
    cat(sprintf(
        "\nReferensi Elbow: perlambatan pertama di K=%d (delta2=%+.0f)\n",
        as.integer(first_slowdown$K), elbow_delta2
    ))
}

cat(sprintf(
    "\n>>> K optimal (BIC global): K=%d (model=%s, BIC=%.2f)\n",
    selected_k, selected_model, selected_bic
))

cat(sprintf(
    "\nReferensi BIC global tertinggi: K=%d (model=%s, BIC=%.2f)\n",
    as.integer(best_overall$K), as.character(best_overall$ModelType), as.numeric(best_overall$BIC)
))

write_csv(bic_all, file.path(hasil_dir, "04_bic_all_models.csv"))
write_csv(bic_best, file.path(hasil_dir, "04_bic_best_per_k.csv"))

selection_meta <- data.frame(
    selected_k = selected_k,
    selected_model = selected_model,
    selected_bic = selected_bic,
    selection_method = selection_method,
    best_bic_k = as.integer(best_overall$K),
    best_bic_model = as.character(best_overall$ModelType),
    best_bic_value = as.numeric(best_overall$BIC),
    elbow_k = selected_k,
    elbow_model = selected_model,
    elbow_bic = selected_bic,
    elbow_delta2 = elbow_delta2,
    stringsAsFactors = FALSE
)

write_csv(selection_meta, file.path(hasil_dir, "04_model_selection.csv"))

cat("\n[OK] File disimpan di", file.path(hasil_dir, "04_bic_all_models.csv"), "\n")
cat("[OK] File disimpan di", file.path(hasil_dir, "04_bic_best_per_k.csv"), "\n")
cat("[OK] File disimpan di", file.path(hasil_dir, "04_model_selection.csv"), "\n")
