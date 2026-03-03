# ==============================================================================
# STEP 5: FITTING GMM FINAL (K DARI HASIL STEP 4)
# ==============================================================================
# Deskripsi : Fit GMM final dengan K yang dipilih dari hasil seleksi model BIC,
#             lalu simpan assignment, probabilitas posterior, dan parameter model.
# Input     : hasil/02_feature_matrix.csv, hasil/04_model_selection.csv
# Output    : hasil/05_cluster_assignments.csv, hasil/05_cluster_probabilities.csv,
#             hasil/05_gmm_parameters.csv, hasil/05_gmm_model.rds
# ==============================================================================

# -- Library --
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
cat("STEP 5: FITTING GMM FINAL (K DARI HASIL STEP 4)\n")
cat("=", strrep("=", 59), "\n\n")

# -- Load feature matrix --
fm <- read_csv(file.path(hasil_dir, "02_feature_matrix.csv"), show_col_types = FALSE)
cat("Feature matrix dimuat:", nrow(fm), "baris\n\n")

# Extract ID columns untuk traceability
id_cols <- fm %>% select(transID, payCardID)

features <- fm %>% select(
    z_tapIn_hour, z_duration_minutes, z_n_trips, z_n_days_month
)
X <- as.matrix(features)

# ==============================================================================
# 5a. Tentukan K final dari hasil Step 4
# ==============================================================================
selection_meta_path <- file.path(hasil_dir, "04_model_selection.csv")
if (!file.exists(selection_meta_path)) {
    stop("File tidak ditemukan: ", selection_meta_path, ". Jalankan 04_bic_selection.R terlebih dahulu.")
}

sel_meta <- read_csv(selection_meta_path, show_col_types = FALSE)
required_cols <- c("selected_k", "selected_model", "selected_bic")
if (!all(required_cols %in% names(sel_meta)) || nrow(sel_meta) == 0) {
    stop(
        "04_model_selection.csv tidak memiliki kolom yang dibutuhkan: ",
        paste(required_cols, collapse = ", ")
    )
}

selected_k <- as.integer(sel_meta$selected_k[1])
selected_model <- as.character(sel_meta$selected_model[1])

cat("K terpilih dari Step 4:\n")
cat("  K          :", selected_k, "\n")
cat("  ModelType  :", selected_model, "\n\n")

if (all(c("best_bic_k", "best_bic_model", "selection_method") %in% names(sel_meta))) {
    cat("Ringkasan Step 4:\n")
    cat("  Best BIC K :", as.integer(sel_meta$best_bic_k[1]), "\n")
    cat("  Best BIC Md:", as.character(sel_meta$best_bic_model[1]), "\n")
    cat("  Method     :", as.character(sel_meta$selection_method[1]), "\n\n")
}

# ==============================================================================
# 5b. Fit GMM final sesuai K terpilih
# ==============================================================================
cat(sprintf("Fitting GMM final: K=%d, model preferensi=%s\n", selected_k, selected_model))
cat("  Algoritma: Expectation-Maximization (EM)\n")
cat("  Inisialisasi: hierarchical agglomerative clustering (default mclust)\n\n")

set.seed(12345)
candidate_models <- unique(c(selected_model, "VVV", "EEE", "VII", "EII"))

fit_candidates <- list()
candidate_scores <- tibble::tibble(
    attempted_model = character(),
    fitted_model = character(),
    bic = numeric(),
    loglik = numeric(),
    nparam = numeric()
)

for (mdl in candidate_models) {
    fit_try <- tryCatch(
        Mclust(X, G = selected_k, modelNames = mdl),
        error = function(e) NULL
    )

    if (!is.null(fit_try) && !is.null(fit_try$bic) && is.finite(fit_try$bic)) {
        fit_candidates[[length(fit_candidates) + 1]] <- fit_try
        candidate_scores <- bind_rows(candidate_scores, tibble::tibble(
            attempted_model = mdl,
            fitted_model = as.character(fit_try$modelName),
            bic = as.numeric(fit_try$bic),
            loglik = as.numeric(fit_try$loglik),
            nparam = as.numeric(fit_try$df)
        ))
    }
}

if (nrow(candidate_scores) > 0) {
    best_idx <- which.max(candidate_scores$bic)
    gmm_fit <- fit_candidates[[best_idx]]
    used_model <- candidate_scores$attempted_model[best_idx]

    cat("Kandidat model valid (diurutkan BIC tertinggi):\n")
    print(candidate_scores %>% arrange(desc(bic)))
} else {
    cat("Tidak ada kandidat model valid pada daftar fallback; mencoba auto model untuk K terpilih...\n")
    gmm_fit <- Mclust(X, G = selected_k)
    used_model <- as.character(gmm_fit$modelName)
}

if (is.null(gmm_fit) || is.null(gmm_fit$loglik) || !is.finite(gmm_fit$loglik)) {
    stop("Gagal mendapatkan model GMM final yang valid untuk K=", selected_k)
}

cat("\nModel fitting selesai.\n")
cat("  Selected model:", gmm_fit$modelName, "\n")
cat("  Attempted from:", used_model, "\n")
cat("  Selected K    :", gmm_fit$G, "\n")
cat("  Log-likelihood:", round(gmm_fit$loglik, 2), "\n")
cat("  BIC           :", round(gmm_fit$bic, 2), "\n")
cat("  Jumlah param  :", gmm_fit$df, "\n\n")

k_final <- gmm_fit$G

# ==============================================================================
# 5c. Distribusi Cluster
# ==============================================================================
cluster_dist <- table(gmm_fit$classification)
cat("Distribusi cluster:\n")
for (cl in names(cluster_dist)) {
    pct <- round(cluster_dist[cl] / sum(cluster_dist) * 100, 2)
    cat(sprintf("  Cluster %s: %6d observasi (%5.2f%%)\n", cl, cluster_dist[cl], pct))
}
cat(sprintf("  Total    : %6d\n\n", sum(cluster_dist)))

# ==============================================================================
# 5d. Parameter GMM (mean, mixing proportion)
# ==============================================================================
cat("Mixing proportions (pi_k):\n")
for (k in seq_len(k_final)) {
    cat(sprintf("  Cluster %d: %.4f\n", k, gmm_fit$parameters$pro[k]))
}

cat("\nCluster means:\n")
means_df <- as.data.frame(t(gmm_fit$parameters$mean))
colnames(means_df) <- colnames(X)
means_df$cluster <- seq_len(k_final)
print(means_df)

# ==============================================================================
# 5e. Simpan cluster assignments
# ==============================================================================
assignments <- data.frame(
    obs_id = seq_len(nrow(X)),
    transID = id_cols$transID,
    payCardID = id_cols$payCardID,
    cluster = gmm_fit$classification
)
assignments <- cbind(assignments, as.data.frame(X))

# ==============================================================================
# 5f. Simpan probabilitas posterior
# ==============================================================================
probs <- as.data.frame(round(gmm_fit$z * 100, 2))
colnames(probs) <- paste0("prob_cl", seq_len(ncol(probs)))
probs$cluster <- gmm_fit$classification

# ==============================================================================
# 5g. Parameter GMM untuk laporan
# ==============================================================================
params <- data.frame(
    cluster = seq_len(k_final),
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

saveRDS(gmm_fit, file.path(hasil_dir, "05_gmm_model.rds"))
cat("[OK] Model RDS disimpan di", file.path(hasil_dir, "05_gmm_model.rds"), "\n")
