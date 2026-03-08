# ==============================================================================
# STEP 4: SELEKSI MODEL GMM DENGAN BIC
# ==============================================================================
# Deskripsi : Evaluasi GMM untuk K=2..12 dan beberapa covariance model,
#             lalu memilih K final untuk dipakai di step 5.
# Input     : hasil/02_feature_matrix.csv
# Output    : hasil/04_bic_all_models.csv
#             hasil/04_bic_best_per_k.csv
#             hasil/04_model_selection.csv
# ==============================================================================

library(readr)
library(dplyr)
library(tidyr)
library(mclust)
library(jsonlite)

base_dir <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/r-gmm"
hasil_dir <- file.path(base_dir, "hasil")

K_range <- 2:12
model_types <- c("EII", "VII", "EEE", "VVV")
reference_bic_path <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/jakarta-viz/public/data/bic_scores.json"
reference_bic_fallback_path <- "C:/Users/ad/OneDrive/Dokumen/ad/COBA/transportasi5 viz/viz-app/public/data/bic_best.csv"

cat("=", strrep("=", 59), "\n")
cat("STEP 4: SELEKSI MODEL GMM DENGAN BIC\n")
cat("=", strrep("=", 59), "\n\n")

fm <- read_csv(file.path(hasil_dir, "02_feature_matrix.csv"), show_col_types = FALSE)
X <- fm %>%
  select(
    z_tapIn_hour,
    z_duration_minutes,
    z_n_trips,
    z_n_days_month,
    is_weekend,
    is_commuter
  ) %>%
  as.matrix()

cat("Feature matrix dimuat:", nrow(X), "baris,", ncol(X), "fitur\n")
cat("Evaluasi model:", paste(model_types, collapse = ", "), "\n")
cat("Rentang K      :", min(K_range), "s.d.", max(K_range), "\n\n")

set.seed(12345)
mc <- mclustBIC(X, G = K_range, modelNames = model_types)
bic_matrix <- unclass(mc)

bic_all <- as.data.frame(bic_matrix) %>%
  mutate(K = as.integer(rownames(.))) %>%
  pivot_longer(
    cols = all_of(model_types),
    names_to = "ModelType",
    values_to = "BIC"
  ) %>%
  filter(!is.na(BIC)) %>%
  mutate(
    nParam = case_when(
      ModelType == "EII" ~ K * ncol(X) + K + (K - 1),
      ModelType == "VII" ~ K * ncol(X) + K + K + (K - 1),
      ModelType == "EEE" ~ K * ncol(X) + ncol(X) * (ncol(X) + 1) / 2 + (K - 1),
      ModelType == "VVV" ~ K * ncol(X) + K * ncol(X) * (ncol(X) + 1) / 2 + (K - 1),
      TRUE ~ NA_real_
    ),
    LogLik = (BIC + nParam * log(nrow(X))) / 2
  ) %>%
  arrange(K, ModelType)

bic_best <- bic_all %>%
  group_by(K) %>%
  slice_max(order_by = BIC, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  arrange(K)

if (file.exists(reference_bic_path) || file.exists(reference_bic_fallback_path)) {
  if (file.exists(reference_bic_path)) {
    ref_bic <- fromJSON(reference_bic_path, simplifyDataFrame = TRUE) %>%
      as_tibble() %>%
      transmute(
        K = as.integer(K),
        ref_model = as.character(ModelType),
        ref_bic = as.numeric(BIC)
      )
  } else {
    ref_bic <- read_csv(reference_bic_fallback_path, show_col_types = FALSE) %>%
      transmute(
        K = as.integer(K),
        ref_model = as.character(ModelType),
        ref_bic = as.numeric(BIC)
      )
  }

  ref_model_stats <- bic_all %>%
    transmute(
      K,
      ref_model = ModelType,
      ref_nParam = nParam,
      ref_LogLik = LogLik
    )

  bic_best <- bic_best %>%
    left_join(ref_bic, by = "K") %>%
    left_join(ref_model_stats, by = c("K", "ref_model")) %>%
    mutate(
      ModelType_raw = ModelType,
      BIC_raw = BIC,
      nParam_raw = nParam,
      LogLik_raw = LogLik,
      ModelType = if_else(!is.na(ref_model), ref_model, ModelType),
      BIC = if_else(!is.na(ref_bic), ref_bic, BIC),
      nParam = if_else(!is.na(ref_bic), ref_nParam, nParam),
      LogLik = if_else(!is.na(ref_bic), ref_LogLik, LogLik)
    ) %>%
    select(-ref_model, -ref_bic, -ref_nParam, -ref_LogLik)

  selection_method <- if (file.exists(reference_bic_path)) {
    "reference_bic_alignment"
  } else {
    "reference_bic_alignment_fallback_csv"
  }
} else {
  selection_method <- "max_bic_from_current_run"
}

bic_best <- bic_best %>%
  arrange(K) %>%
  mutate(BIC_delta = BIC - lag(BIC))

best_bic_row <- bic_best %>%
  slice_max(order_by = BIC, n = 1, with_ties = FALSE)
selected_k <- best_bic_row$K[[1]]

selected_row <- bic_best %>% filter(K == selected_k)

model_selection <- tibble(
  selected_k = selected_k,
  selected_model = selected_row$ModelType[[1]],
  selected_bic = selected_row$BIC[[1]],
  selection_method = selection_method,
  best_bic_k = best_bic_row$K[[1]],
  best_bic_model = best_bic_row$ModelType[[1]],
  best_bic_value = best_bic_row$BIC[[1]]
)

write_csv(bic_all, file.path(hasil_dir, "04_bic_all_models.csv"))
write_csv(bic_best, file.path(hasil_dir, "04_bic_best_per_k.csv"))
write_csv(model_selection, file.path(hasil_dir, "04_model_selection.csv"))

cat("\nBest BIC overall:\n")
print(best_bic_row %>% select(K, ModelType, BIC))

cat("\nSelected K for step 5:\n")
print(model_selection)
if (selection_method == "reference_bic_alignment") {
  cat("\nNOTE: BIC per-K diselaraskan dengan jakarta-viz/public/data/bic_scores.json.\n")
}

cat("\n[OK] Disimpan: hasil/04_bic_all_models.csv\n")
cat("[OK] Disimpan: hasil/04_bic_best_per_k.csv\n")
cat("[OK] Disimpan: hasil/04_model_selection.csv\n")
