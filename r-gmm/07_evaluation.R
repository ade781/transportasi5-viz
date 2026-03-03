# ==============================================================================
# STEP 7: EVALUASI MODEL GMM
# ==============================================================================
# Deskripsi : Evaluasi kualitas clustering untuk kandidat K sekitar K terpilih.
# Input     : hasil/02_feature_matrix.csv, hasil/04_model_selection.csv
# Output    : hasil/07_evaluation_scores.csv
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
cat("STEP 7: EVALUASI MODEL GMM\n")
cat("=", strrep("=", 59), "\n\n")

# Load data
fm <- read_csv(file.path(hasil_dir, "02_feature_matrix.csv"), show_col_types = FALSE)
features <- fm %>% select(
    z_tapIn_hour, z_duration_minutes, z_n_trips, z_n_days_month
)
X <- as.matrix(features)

cat("Feature matrix dimuat:", nrow(fm), "baris\n")
cat("(Using full data for evaluation)\n\n")

# Ambil K terpilih dari step 4 lalu evaluasi di sekitar titik tersebut
selection_meta_path <- file.path(hasil_dir, "04_model_selection.csv")
if (file.exists(selection_meta_path)) {
    sel_meta <- read_csv(selection_meta_path, show_col_types = FALSE)
    if ("selected_k" %in% names(sel_meta) && nrow(sel_meta) > 0) {
        k_center <- as.integer(sel_meta$selected_k[1])
    } else {
        k_center <- 5L
    }
} else {
    k_center <- 5L
}

k_candidates <- sort(unique(c(k_center - 1L, k_center, k_center + 1L)))
k_candidates <- k_candidates[k_candidates >= 2 & k_candidates <= 12]
cat("K kandidat evaluasi:", paste(k_candidates, collapse = ", "), "\n\n")

# Evaluate candidate K
set.seed(12345)
eval_results <- data.frame()

for (k in k_candidates) {
    cat(sprintf("Evaluating K=%d ...", k))

    fit <- tryCatch(Mclust(X, G = k), error = function(e) NULL)
    if (is.null(fit) || is.null(fit$bic) || !is.finite(fit$bic)) {
        cat(" FAILED\n")
        next
    }

    bic_val <- fit$bic / nrow(X)
    ll_val <- fit$loglik
    model_name <- fit$modelName

    cluster_dist <- table(fit$classification)
    cluster_balance <- sd(as.numeric(cluster_dist)) / mean(as.numeric(cluster_dist))

    eval_results <- rbind(eval_results, data.frame(
        K = k,
        Model = model_name,
        LogLikelihood = round(ll_val, 2),
        BIC_normalized = round(bic_val, 4),
        Num_params = fit$df,
        Cluster_balance = round(cluster_balance, 4),
        stringsAsFactors = FALSE
    ))

    cat(sprintf(" Model=%s BIC=%.4f LL=%.0f\n", model_name, bic_val, ll_val))
}

if (nrow(eval_results) == 0) {
    stop("Tidak ada model evaluasi yang valid.")
}

best_eval <- eval_results %>%
    arrange(desc(BIC_normalized), desc(LogLikelihood), K) %>%
    slice(1)

cat("\n", strrep("=", 60), "\n")
cat("EVALUATION RESULTS:\n")
cat(strrep("=", 60), "\n")
print(eval_results)

cat("\nINTERPRETASI:\n")
cat(sprintf("K terbaik pada evaluasi ini: K=%d (model=%s)\n", best_eval$K, best_eval$Model))
cat(sprintf("- BIC_normalized tertinggi: %.4f\n", best_eval$BIC_normalized))
cat(sprintf("- LogLikelihood: %.2f\n", best_eval$LogLikelihood))
cat(sprintf("- Cluster balance: %.4f\n", best_eval$Cluster_balance))

if (file.exists(selection_meta_path) && exists("k_center")) {
    cat(sprintf("- K terpilih dari Step 4: %d\n", k_center))
    if (best_eval$K == k_center) {
        cat("- Konsisten: hasil evaluasi selaras dengan Step 4.\n")
    } else {
        cat("- Catatan: hasil evaluasi lokal berbeda dari Step 4, cek trade-off interpretabilitas.\n")
    }
}

# Simpan hasil
write_csv(eval_results, file.path(hasil_dir, "07_evaluation_scores.csv"))
cat("\n[OK] File disimpan di", file.path(hasil_dir, "07_evaluation_scores.csv"), "\n")
