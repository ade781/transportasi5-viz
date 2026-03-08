# ==============================================================================
# STEP 1: LOAD DATA + TOPOLOGY PREPARATION
# ==============================================================================
# Input  : ../datacleancoba.csv, ../data_halte.csv, ../r-gmm/hasil/*.csv
# Output : hasil/01_data_overview.csv
#          hasil/01_trip_cluster_base.csv
#          hasil/01_transfer_base.csv
#          hasil/01_corridor_connectivity.csv
# ==============================================================================

library(readr)
library(dplyr)
library(stringr)

normalize_corridor <- function(x) {
    x %>%
        as.character() %>%
        str_replace("\\s+via\\s+.*$", "") %>%
        str_squish()
}

base_dir <- normalizePath(".", winslash = "/", mustWork = FALSE)
project_root <- normalizePath(file.path(base_dir, ".."), winslash = "/", mustWork = FALSE)
hasil_dir <- file.path(base_dir, "hasil")

if (!dir.exists(hasil_dir)) dir.create(hasil_dir, recursive = TRUE)

path_trip <- file.path(project_root, "datacleancoba.csv")
path_halte <- file.path(project_root, "data_halte.csv")
path_assign <- file.path(project_root, "r-gmm", "hasil", "05_cluster_assignments.csv")
path_profile <- file.path(project_root, "r-gmm", "hasil", "06_cluster_profiles.csv")

if (!file.exists(path_trip)) stop("File tidak ditemukan: ", path_trip)
if (!file.exists(path_halte)) stop("File tidak ditemukan: ", path_halte)
if (!file.exists(path_assign)) stop("File tidak ditemukan: ", path_assign)
if (!file.exists(path_profile)) stop("File tidak ditemukan: ", path_profile)

cat("=", strrep("=", 66), "\n")
cat("STEP 1: LOAD DATA + TOPOLOGY PREPARATION\n")
cat("=", strrep("=", 66), "\n\n")

cat("Memuat data transaksi...\n")
trip <- read_csv(path_trip, show_col_types = FALSE) %>%
    mutate(
        tapOut_corridorName = dplyr::coalesce(
            if ("tapOut_corridorName" %in% names(.)) as.character(tapOut_corridorName) else NA_character_,
            if ("tC" %in% names(.)) as.character(tC) else NA_character_
        )
    ) %>%
    mutate(
        obs_id = row_number(),
        lhs = normalize_corridor(corridorName),
        rhs = normalize_corridor(tapOut_corridorName)
    )

# Mapping koridor nama -> ID dari data transaksi (untuk referensi tap-out corridor ID)
corridor_ref <- trip %>%
    transmute(
        corridorName_ref = normalize_corridor(corridorName),
        corridorID_ref = as.character(corridorID)
    ) %>%
    filter(!is.na(corridorName_ref), corridorName_ref != "", !is.na(corridorID_ref), corridorID_ref != "") %>%
    group_by(corridorName_ref) %>%
    summarise(tapOut_corridorID = dplyr::first(corridorID_ref), .groups = "drop")

cat("Baris transaksi:", nrow(trip), "\n")

cat("Memuat assignment cluster GMM...\n")
assign <- read_csv(path_assign, show_col_types = FALSE)
if (!"obs_id" %in% names(assign)) {
    assign <- assign %>% mutate(obs_id = row_number())
}
assign <- assign %>% select(obs_id, cluster)

if (nrow(assign) != nrow(trip)) {
    stop("Jumlah baris cluster assignment tidak sama dengan data transaksi.")
}

profile <- read_csv(path_profile, show_col_types = FALSE) %>%
    select(cluster, label)

trip <- trip %>%
    left_join(assign, by = "obs_id") %>%
    left_join(profile, by = "cluster") %>%
    left_join(corridor_ref, by = c("rhs" = "corridorName_ref")) %>%
    rename(cluster_label = label)

trip <- trip %>%
    mutate(
        cluster = as.integer(cluster),
        cluster_label = if_else(is.na(cluster_label), "Unknown", cluster_label),
        is_cross = !is.na(rhs) & rhs != "" & lhs != rhs
    )

cat("Memuat data halte untuk membangun graph konektivitas koridor...\n")
halte <- read_csv(path_halte, show_col_types = FALSE) %>%
    transmute(
        corridor = normalize_corridor(corridorName),
        stop_name = str_squish(tapInStopsName)
    ) %>%
    filter(!is.na(corridor), corridor != "", !is.na(stop_name), stop_name != "") %>%
    distinct()

connectivity <- halte %>%
    inner_join(
        halte,
        by = "stop_name",
        suffix = c("_lhs", "_rhs"),
        relationship = "many-to-many"
    ) %>%
    filter(corridor_lhs != corridor_rhs) %>%
    group_by(lhs = corridor_lhs, rhs = corridor_rhs) %>%
    summarise(n_shared_stops = n_distinct(stop_name), .groups = "drop")

transfer_base <- trip %>%
    filter(is_cross) %>%
    left_join(connectivity, by = c("lhs", "rhs")) %>%
    mutate(
        n_shared_stops = if_else(is.na(n_shared_stops), 0L, as.integer(n_shared_stops)),
        is_connected = n_shared_stops > 0
    ) %>%
    select(
        obs_id, transID, payCardID, date, day_of_week,
        lhs, rhs, cluster, cluster_label, is_weekend,
        n_shared_stops, is_connected
    )

overview <- tibble(
    metric = c(
        "total_trip", "total_transfer_trip", "total_connected_transfer",
        "unique_users", "unique_corridors", "connected_pairs"
    ),
    value = c(
        nrow(trip),
        nrow(transfer_base),
        sum(transfer_base$is_connected, na.rm = TRUE),
        n_distinct(trip$payCardID),
        n_distinct(c(trip$lhs, trip$rhs), na.rm = TRUE),
        nrow(connectivity)
    )
)

write_csv(overview, file.path(hasil_dir, "01_data_overview.csv"))
write_csv(
    trip %>%
        select(
            obs_id, transID, payCardID,
            corridorID, corridorName, tapOut_corridorName, tapOut_corridorID,
            lhs, rhs, cluster, cluster_label, is_cross
        ),
    file.path(hasil_dir, "01_trip_cluster_base.csv")
)
write_csv(transfer_base, file.path(hasil_dir, "01_transfer_base.csv"))
write_csv(connectivity, file.path(hasil_dir, "01_corridor_connectivity.csv"))

cat("\n[OK] hasil/01_data_overview.csv\n")
cat("[OK] hasil/01_trip_cluster_base.csv\n")
cat("[OK] hasil/01_transfer_base.csv\n")
cat("[OK] hasil/01_corridor_connectivity.csv\n")

