# ==============================================================================
# STEP 7: EVALUASI MODEL (K=4,5,6)
# ==============================================================================
# Deskripsi : Evaluasi kualitas clustering GMM menggunakan metrik yang selaras
#             dengan template skripsi: BIC, Silhouette Score, Entropy, dan
#             Composite Score pada kandidat K=4,5,6.
# Input     : hasil/02_feature_matrix.csv
# Output    : hasil/07_evaluation_scores.csv
#             visualisasi/step7/*.png
# ==============================================================================

library(readr)
library(dplyr)
library(mclust)
library(cluster)
library(ggplot2)
library(scales)
library(tidyr)

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

minmax_norm <- function(x) {
    rng <- range(x, na.rm = TRUE)
    if (!is.finite(rng[1]) || !is.finite(rng[2]) || diff(rng) == 0) {
        return(rep(0.5, length(x)))
    }
    (x - rng[1]) / diff(rng)
}

sample_size <- min(10000, nrow(X))
set.seed(12345)
sample_idx <- sample(seq_len(nrow(X)), sample_size)
X_sample <- X[sample_idx, , drop = FALSE]
dist_sample <- dist(X_sample)

# Evaluate K=4,5,6
eval_results <- data.frame()

for (k in c(4, 5, 6)) {
    cat(sprintf("Evaluating K=%d ...", k))

    set.seed(12345)
    fit <- Mclust(X, G = k)

    if (is.null(fit)) {
        cat(" FAILED\n")
        next
    }

    bic_raw <- fit$bic
    bic_val <- fit$bic / nrow(X)
    ll_val <- fit$loglik
    model_name <- fit$modelName

    cluster_dist <- table(fit$classification)
    cluster_balance <- sd(as.numeric(cluster_dist)) / mean(as.numeric(cluster_dist))

    sil_obj <- silhouette(fit$classification[sample_idx], dist_sample)
    silhouette_val <- mean(sil_obj[, "sil_width"])

    z <- fit$z
    entropy_row <- -rowSums(z * log(pmax(z, 1e-12)))
    entropy_val <- mean(entropy_row / log(ncol(z)))

    eval_results <- rbind(eval_results, data.frame(
        K = k,
        Model = model_name,
        BIC = round(bic_raw, 2),
        LogLikelihood = round(ll_val, 2),
        BIC_normalized = round(bic_val, 4),
        Num_params = fit$df,
        Cluster_balance = round(cluster_balance, 4),
        Silhouette = round(silhouette_val, 4),
        Entropy = round(entropy_val, 4),
        stringsAsFactors = FALSE
    ))

    cat(sprintf(
        " Model=%s BIC=%.4f Sil=%.4f Ent=%.4f\n",
        model_name, bic_val, silhouette_val, entropy_val
    ))
}

eval_results <- eval_results %>%
    arrange(K) %>%
    mutate(
        BIC_delta = BIC - lag(BIC),
        norm_BIC = minmax_norm(BIC),
        norm_Silhouette = minmax_norm(Silhouette),
        norm_Entropy = minmax_norm(Entropy),
        Composite_score = round((norm_BIC + norm_Silhouette + (1 - norm_Entropy)) / 3, 4)
    ) %>%
    select(
        K, Model, BIC, BIC_delta, LogLikelihood, BIC_normalized,
        Num_params, Cluster_balance, Silhouette, Entropy, Composite_score
    )

cat("\n", strrep("=", 60), "\n")
cat("EVALUATION RESULTS:\n")
cat(strrep("=", 60), "\n")
print(eval_results)

best_k_by_bic <- eval_results %>% slice_max(BIC, n = 1, with_ties = FALSE) %>% pull(K)
best_k_by_silhouette <- eval_results %>% slice_max(Silhouette, n = 1, with_ties = FALSE) %>% pull(K)
best_k_by_composite <- eval_results %>% slice_max(Composite_score, n = 1, with_ties = FALSE) %>% pull(K)

if (preferred_k %in% eval_results$K) {
    best_k <- preferred_k
    selection_basis <- "selected_k_from_step4"
} else {
    best_k <- best_k_by_composite
    selection_basis <- "composite_fallback"
}

cat("\nINTERPRETASI:\n")
cat(sprintf("K=%d dipilih sebagai acuan evaluasi (konsisten dengan Step 4).\n", best_k))
cat(sprintf("- Basis seleksi               : %s\n", selection_basis))
cat(sprintf("- Best by BIC di Step 7       : K=%d\n", best_k_by_bic))
cat(sprintf("- Best by Silhouette di Step 7: K=%d\n", best_k_by_silhouette))
cat(sprintf("- Best by Composite di Step 7 : K=%d\n", best_k_by_composite))
cat("- Composite score merangkum BIC, Silhouette, dan inverse Entropy\n")
cat("- Interpretability tetap dipertimbangkan bersama kualitas pemisahan cluster\n")

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

# 2) Silhouette comparison
p2 <- ggplot(eval_results, aes(x = K, y = Silhouette)) +
    geom_line(color = "#2C3E50", linewidth = 1) +
    geom_point(
        aes(color = factor(K == best_k_by_silhouette)),
        size = 3,
        show.legend = FALSE
    ) +
    geom_text(
        aes(label = sprintf("%.4f", Silhouette)),
        vjust = -1, size = 3.1
    ) +
    scale_color_manual(values = c("TRUE" = "#E74C3C", "FALSE" = "#2C3E50")) +
    scale_x_continuous(breaks = eval_results$K) +
    labs(
        title = "Step 7 - Silhouette Score per K",
        subtitle = paste0("Semakin tinggi semakin baik | Best by Silhouette = K=", best_k_by_silhouette),
        x = "Jumlah Cluster (K)",
        y = "Silhouette Score"
    ) +
    theme_eval

ggsave(
    filename = file.path(step7_viz_dir, "02_silhouette_score.png"),
    plot = p2, width = 9, height = 5.5, dpi = 300
)

# 3) Entropy + composite score
eval_long <- eval_results %>%
    select(K, Entropy, Composite_score) %>%
    pivot_longer(
        cols = c(Entropy, Composite_score),
        names_to = "Metric",
        values_to = "Value"
    )

p3 <- ggplot(eval_long, aes(x = factor(K), y = Value, fill = Metric)) +
    geom_col(position = "dodge", width = 0.7) +
    scale_fill_manual(
        values = c(
            "Entropy" = "#1ABC9C",
            "Composite_score" = "#9B59B6"
        ),
        labels = c(
            "Entropy" = "Average Entropy",
            "Composite_score" = "Composite Score"
        )
    ) +
    labs(
        title = "Step 7 - Entropy dan Composite Score",
        subtitle = paste0("Composite score tertinggi pada K=", best_k_by_composite),
        x = "Jumlah Cluster (K)",
        y = "Nilai",
        fill = "Metrik"
    ) +
    theme_eval

ggsave(
    filename = file.path(step7_viz_dir, "03_entropy_vs_composite.png"),
    plot = p3, width = 9, height = 5.5, dpi = 300
)

cat("[OK] Visualisasi Step 7 disimpan di", step7_viz_dir, "\n")
cat("     - 01_bic_normalized.png\n")
cat("     - 02_silhouette_score.png\n")
cat("     - 03_entropy_vs_composite.png\n")
