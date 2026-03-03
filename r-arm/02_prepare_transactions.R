# ==============================================================================
# STEP 2: TRANSACTION PREPARATION FOR ARM
# ==============================================================================
# Input  : hasil/01_transfer_base.csv
# Output : hasil/02_transactions_connected.csv
#          hasil/02_basket_items.csv
#          hasil/02_item_frequency_global.csv
#          hasil/02_item_frequency_cluster.csv
#          hasil/02_cluster_trip_totals.csv
# ==============================================================================

library(readr)
library(dplyr)
library(stringr)

base_dir <- normalizePath(".", winslash = "/", mustWork = FALSE)
hasil_dir <- file.path(base_dir, "hasil")

path_transfer <- file.path(hasil_dir, "01_transfer_base.csv")
if (!file.exists(path_transfer)) stop("Jalankan 01_load_data.R terlebih dahulu.")

cat("=", strrep("=", 66), "\n")
cat("STEP 2: TRANSACTION PREPARATION FOR ARM\n")
cat("=", strrep("=", 66), "\n\n")

transfer <- read_csv(path_transfer, show_col_types = FALSE)

connected <- transfer %>%
    filter(is_connected) %>%
    mutate(
        transaction_id = paste(payCardID, date, sep = "_"),
        pair_id = paste(lhs, "=>", rhs)
    )

basket_items <- bind_rows(
    connected %>% transmute(cluster, cluster_label, transaction_id, item = lhs),
    connected %>% transmute(cluster, cluster_label, transaction_id, item = rhs)
) %>%
    filter(!is.na(item), item != "") %>%
    distinct(cluster, cluster_label, transaction_id, item)

item_global <- basket_items %>%
    count(item, name = "n_transaction", sort = TRUE) %>%
    mutate(support = n_transaction / n_distinct(basket_items$transaction_id))

item_cluster <- basket_items %>%
    group_by(cluster, cluster_label, item) %>%
    summarise(n_transaction = n_distinct(transaction_id), .groups = "drop") %>%
    group_by(cluster, cluster_label) %>%
    mutate(support = n_transaction / sum(n_transaction)) %>%
    ungroup() %>%
    arrange(cluster, desc(n_transaction))

cluster_totals <- connected %>%
    group_by(cluster, cluster_label) %>%
    summarise(
        n_trip_cluster = n(),
        n_transaction_cluster = n_distinct(transaction_id),
        .groups = "drop"
    ) %>%
    arrange(cluster)

write_csv(connected, file.path(hasil_dir, "02_transactions_connected.csv"))
write_csv(basket_items, file.path(hasil_dir, "02_basket_items.csv"))
write_csv(item_global, file.path(hasil_dir, "02_item_frequency_global.csv"))
write_csv(item_cluster, file.path(hasil_dir, "02_item_frequency_cluster.csv"))
write_csv(cluster_totals, file.path(hasil_dir, "02_cluster_trip_totals.csv"))

cat("Connected transfer trips:", nrow(connected), "\n")
cat("Unique transaction_id:", n_distinct(connected$transaction_id), "\n")
cat("\n[OK] hasil/02_transactions_connected.csv\n")
cat("[OK] hasil/02_basket_items.csv\n")
cat("[OK] hasil/02_item_frequency_global.csv\n")
cat("[OK] hasil/02_item_frequency_cluster.csv\n")
cat("[OK] hasil/02_cluster_trip_totals.csv\n")

