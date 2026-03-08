# ==============================================================================
# STEP 7: EVALUASI MODEL (K=4,5,6 only - SIMPLIFIED)
# ==============================================================================
# Deskripsi : Evaluasi kualitas clustering untuk K=4,5,6
# Input     : hasil/02_feature_matrix.csv
# Output    : hasil/07_evaluation_scores.csv
#             visualisasi/step7/*.png
# ==============================================================================

library(readr)
library(dplyr)
library(mclust)
library(ggplot2)
library(scales)

# Set paths untuk output
base_dir <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/r-gmm"
hasil_dir <- file.path(base_dir, "hasil")
visualisasi_dir <- file.path(base_dir, "visualisasi")
step7_viz_dir <- file.path(visualisasi_dir, "step7")
if (!dir.exists(step7_viz_dir)) dir.create(step7_viz_dir, recursive = TRUE)

cat("=", strrep("=", 59), "\n")
cat("STEP 7: EVALUASI MODEL (K=4,5,6)\n")
cat("=", strrep("=", 59), "\n\n")

# Load data
fm <- read_csv(file.path(hasil_dir, "02_feature_matrix.csv"), show_col_types = FALSE)
features <- fm %>% select(
    z_tapIn_hour, z_duration_minutes, z_n_trips,
    z_n_days_month, is_weekend, is_commuter
)
X <- as.matrix(features)

cat("Feature matrix dimuat:", nrow(fm), "baris\n")
cat("(Using full data for evaluation)\n\n")

# Ambil K terpilih dari step 4 agar konsisten lintas step
selection_file <- file.path(hasil_dir, "04_model_selection.csv")
preferred_k <- 5L
if (file.exists(selection_file)) {
    sel <- read_csv(selection_file, show_col_types = FALSE)
    preferred_k <- as.integer(sel$selected_k[[1]])
}
cat("Selected K dari step 4:", preferred_k, "\n\n")

# Evaluate K=4,5,6
eval_results <- data.frame()

for (k in c(4, 5, 6)) {
    cat(sprintf("Evaluating K=%d ...", k))

    # Fit GMM dengan seed
    set.seed(12345)
    fit <- Mclust(X, G = k)

    if (is.null(fit)) {
        cat(" FAILED\n")
        next
    }

    # BIC (normalized)
    bic_val <- fit$bic / nrow(X)

    # Log-likelihood
    ll_val <- fit$loglik

    # Model name
    model_name <- fit$modelName

    # Cluster distribution
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

cat("\n", strrep("=", 60), "\n")
cat("EVALUATION RESULTS:\n")
cat(strrep("=", 60), "\n")
print(eval_results)

best_k_by_bic <- eval_results %>% slice_max(BIC_normalized, n = 1, with_ties = FALSE) %>% pull(K)
if (preferred_k %in% eval_results$K) {
    best_k <- preferred_k
    selection_basis <- "selected_k_from_step4"
} else {
    best_k <- best_k_by_bic
    selection_basis <- "bic_fallback"
}

cat("\nINTERPRETASI:\n")
cat(sprintf("K=%d dipilih sebagai acuan evaluasi (konsisten dengan Step 4).\n", best_k))
cat(sprintf("- Basis seleksi: %s\n", selection_basis))
cat(sprintf("- Best by BIC di Step 7: K=%d\n", best_k_by_bic))
cat("- Model fit quality (BIC, LogLikelihood) tetap ditampilkan sebagai pembanding\n")
cat("- Interpretability untuk clustering passenger types\n")
cat("- Business relevance untuk corridor analysis\n")

# Simpan hasil
write_csv(eval_results, file.path(hasil_dir, "07_evaluation_scores.csv"))
cat("\n[OK] File disimpan di", file.path(hasil_dir, "07_evaluation_scores.csv"), "\n")

# ==============================================================================
# Visualisasi Step 7
# ==============================================================================
theme_eval <- theme_minimal(base_size = 12) +
    theme(
        plot.title = element_text(face = "bold", hjust = 0.5),
        plot.subtitle = element_text(hjust = 0.5, color = "grey40"),
        panel.grid.minor = element_blank()
    )

# 1) BIC normalized comparison
p1 <- ggplot(eval_results, aes(x = factor(K), y = BIC_normalized)) +
    geom_col(
        aes(fill = factor(K == best_k)),
        width = 0.7,
        show.legend = FALSE
    ) +
    geom_text(aes(label = sprintf("%.4f", BIC_normalized)), vjust = -0.5, size = 3.2) +
    scale_fill_manual(values = c("TRUE" = "#E74C3C", "FALSE" = "#3498DB")) +
    labs(
        title = "Step 7 - BIC Normalized per K",
        subtitle = paste0(
            "Nilai lebih tinggi (mendekati 0) lebih baik | K acuan Step 4 = ",
            best_k, " | Best by BIC = ", best_k_by_bic
        ),
        x = "Jumlah Cluster (K)",
        y = "BIC Normalized"
    ) +
    theme_eval

ggsave(
    filename = file.path(step7_viz_dir, "01_bic_normalized.png"),
    plot = p1, width = 9, height = 5.5, dpi = 300
)

# 2) LogLikelihood comparison
p2 <- ggplot(eval_results, aes(x = K, y = LogLikelihood)) +
    geom_line(color = "#2C3E50", linewidth = 1) +
    geom_point(
        aes(color = factor(K == best_k)),
        size = 3,
        show.legend = FALSE
    ) +
    geom_text(
        aes(label = scales::comma(round(LogLikelihood, 0))),
        vjust = -1, size = 3.1
    ) +
    scale_color_manual(values = c("TRUE" = "#E74C3C", "FALSE" = "#2C3E50")) +
    scale_x_continuous(breaks = eval_results$K) +
    labs(
        title = "Step 7 - LogLikelihood per K",
        subtitle = "Semakin tinggi (kurang negatif) semakin baik",
        x = "Jumlah Cluster (K)",
        y = "LogLikelihood"
    ) +
    theme_eval

ggsave(
    filename = file.path(step7_viz_dir, "02_loglikelihood.png"),
    plot = p2, width = 9, height = 5.5, dpi = 300
)

# 3) Cluster balance + jumlah parameter
eval_long <- eval_results %>%
    select(K, Cluster_balance, Num_params) %>%
    tidyr::pivot_longer(
        cols = c(Cluster_balance, Num_params),
        names_to = "Metric",
        values_to = "Value"
    )

p3 <- ggplot(eval_long, aes(x = factor(K), y = Value, fill = Metric)) +
    geom_col(position = "dodge", width = 0.7) +
    scale_fill_manual(
        values = c(
            "Cluster_balance" = "#1ABC9C",
            "Num_params" = "#9B59B6"
        ),
        labels = c(
            "Cluster_balance" = "Cluster Balance (sd/mean)",
            "Num_params" = "Jumlah Parameter"
        )
    ) +
    labs(
        title = "Step 7 - Kompleksitas dan Keseimbangan Cluster",
        subtitle = "Perbandingan trade-off antar kandidat K",
        x = "Jumlah Cluster (K)",
        y = "Nilai",
        fill = "Metrik"
    ) +
    theme_eval

ggsave(
    filename = file.path(step7_viz_dir, "03_balance_vs_params.png"),
    plot = p3, width = 9, height = 5.5, dpi = 300
)

cat("[OK] Visualisasi Step 7 disimpan di", step7_viz_dir, "\n")
cat("     - 01_bic_normalized.png\n")
cat("     - 02_loglikelihood.png\n")
cat("     - 03_balance_vs_params.png\n")
