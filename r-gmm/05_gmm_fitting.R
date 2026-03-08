# ==============================================================================
# STEP 5: FITTING GMM FINAL (BERDASARKAN HASIL STEP 4)
# ==============================================================================
# Deskripsi : Fit GMM final menggunakan K/model dari hasil seleksi BIC step 4.
#             Jika file seleksi belum ada, fallback ke K=5.
# Input     : hasil/02_feature_matrix.csv
# Output    : hasil/05_cluster_assignments.csv, hasil/05_cluster_probabilities.csv,
#             hasil/05_gmm_parameters.csv
# ==============================================================================

# -- Library --
library(readr)
library(dplyr)
library(mclust)

# Set paths untuk output
base_dir <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/r-gmm"
hasil_dir <- file.path(base_dir, "hasil")
visualisasi_dir <- file.path(base_dir, "visualisasi")

cat("=", strrep("=", 59), "\n")
cat("STEP 5: FITTING GMM FINAL (BERDASARKAN STEP 4)\n")
cat("=", strrep("=", 59), "\n\n")

# -- Load feature matrix --
fm <- read_csv(file.path(hasil_dir, "02_feature_matrix.csv"), show_col_types = FALSE)
cat("Feature matrix dimuat:", nrow(fm), "baris\n\n")

features <- fm %>% select(
    z_tapIn_hour, z_duration_minutes, z_n_trips,
    z_n_days_month, is_weekend, is_commuter
)
X <- as.matrix(features)

# ==============================================================================
# 5a. Baca hasil seleksi step 4
# ==============================================================================
selection_file <- file.path(hasil_dir, "04_model_selection.csv")

if (file.exists(selection_file)) {
    sel <- read_csv(selection_file, show_col_types = FALSE)
    selected_k <- as.integer(sel$selected_k[[1]])
    selected_model <- sel$selected_model[[1]]
    cat("Hasil seleksi dimuat dari step 4:\n")
    cat("  selected_k    :", selected_k, "\n")
    cat("  selected_model:", selected_model, "\n\n")
} else {
    selected_k <- 5L
    selected_model <- NA_character_
    cat("File 04_model_selection.csv tidak ditemukan.\n")
    cat("Fallback ke default: K=5, model auto-selection.\n\n")
}

cat("Fitting GMM final...\n")
cat("  Algoritma: Expectation-Maximization (EM)\n")
cat("  Inisialisasi: hierarchical agglomerative clustering (default mclust)\n\n")

set.seed(12345)
if (!is.na(selected_model) && nzchar(selected_model)) {
    gmm_fit <- Mclust(X, G = selected_k, modelNames = selected_model)
} else {
    gmm_fit <- Mclust(X, G = selected_k)
}

# Fallback jika model yang dipilih dari step 4 tidak konvergen pada data saat ini
if (is.null(gmm_fit$modelName) || is.null(gmm_fit$loglik) || !is.numeric(gmm_fit$loglik)) {
    cat("Model terpilih tidak konvergen. Fallback ke auto model selection untuk K yang sama...\n")
    set.seed(12345)
    gmm_fit <- Mclust(X, G = selected_k)
}

cat("Model fitting selesai.\n")
cat("  Selected model:", gmm_fit$modelName, "\n")
cat("  Log-likelihood:", round(gmm_fit$loglik, 2), "\n")
cat("  BIC           :", round(gmm_fit$bic, 2), "\n")
cat("  Jumlah param  :", gmm_fit$df, "\n\n")

# ==============================================================================
# 5b. Distribusi Cluster
# ==============================================================================
cluster_dist <- table(gmm_fit$classification)
cat("Distribusi cluster:\n")
for (cl in names(cluster_dist)) {
    pct <- round(cluster_dist[cl] / sum(cluster_dist) * 100, 2)
    cat(sprintf("  Cluster %s: %6d observasi (%5.2f%%)\n", cl, cluster_dist[cl], pct))
}
cat(sprintf("  Total    : %6d\n\n", sum(cluster_dist)))

# ==============================================================================
# 5c. Parameter GMM (mean, mixing proportion)
# ==============================================================================
cat("Mixing proportions (pi_k):\n")
for (k in seq_len(gmm_fit$G)) {
    cat(sprintf("  Cluster %d: %.4f\n", k, gmm_fit$parameters$pro[k]))
}

cat("\nCluster means:\n")
means_df <- as.data.frame(t(gmm_fit$parameters$mean))
colnames(means_df) <- colnames(X)
means_df$cluster <- seq_len(gmm_fit$G)
print(means_df)

# ==============================================================================
# 5d. Simpan cluster assignments
# ==============================================================================
assignments <- data.frame(
    obs_id = 1:nrow(X),
    cluster = gmm_fit$classification
)
assignments <- cbind(assignments, as.data.frame(X))

# ==============================================================================
# 5e. Simpan probabilitas posterior (dalam persen, 2 desimal)
# ==============================================================================
probs <- as.data.frame(round(gmm_fit$z * 100, 2))
colnames(probs) <- paste0("prob_cl", seq_len(ncol(probs)))
probs$cluster <- gmm_fit$classification

# ==============================================================================
# 5f. Parameter GMM untuk laporan
# ==============================================================================
params <- data.frame(
    cluster = seq_len(gmm_fit$G),
    proportion = gmm_fit$parameters$pro,
    stringsAsFactors = FALSE
)
params <- cbind(params, t(gmm_fit$parameters$mean))

# -- Simpan hasil --
write_csv(assignments, file.path(hasil_dir, "05_cluster_assignments.csv"))
write_csv(probs, file.path(hasil_dir, "05_cluster_probabilities.csv"))
write_csv(params, file.path(hasil_dir, "05_gmm_parameters.csv"))

cat("\n[OK] File disimpan di", file.path(hasil_dir, "05_cluster_assignments.csv"), "\n")
cat("[OK] File disimpan di", file.path(hasil_dir, "05_cluster_probabilities.csv"), "\n")
cat("[OK] File disimpan di", file.path(hasil_dir, "05_gmm_parameters.csv"), "\n")

# Simpan model object untuk digunakan step selanjutnya
saveRDS(gmm_fit, file.path(hasil_dir, "05_gmm_model.rds"))
cat("[OK] Model RDS disimpan di", file.path(hasil_dir, "05_gmm_model.rds"), "\n")
