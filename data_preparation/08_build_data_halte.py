from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RAW_PATH = ROOT / "tj180.csv"
OUT_PATH = ROOT / "data_halte.csv"
VIZ_PATH = ROOT / "viz-app" / "public" / "data" / "halte.csv"


def first_mode(series: pd.Series):
    series = series.dropna()
    if series.empty:
        return np.nan
    mode = series.mode()
    if mode.empty:
        return series.iloc[0]
    return mode.iloc[0]


def build_stop_events(df: pd.DataFrame) -> pd.DataFrame:
    common = ["corridorID", "corridorName", "direction"]

    tap_in = df[
        common
        + [
            "tapInStops",
            "tapInStopsName",
            "tapInStopsLat",
            "tapInStopsLon",
            "stopStartSeq",
        ]
    ].rename(
        columns={
            "tapInStops": "stopCode",
            "tapInStopsName": "tapInStopsName",
            "tapInStopsLat": "latitude",
            "tapInStopsLon": "longitude",
            "stopStartSeq": "rawSeq",
        }
    )

    tap_out = df[
        common
        + [
            "tapOutStops",
            "tapOutStopsName",
            "tapOutStopsLat",
            "tapOutStopsLon",
            "stopEndSeq",
        ]
    ].rename(
        columns={
            "tapOutStops": "stopCode",
            "tapOutStopsName": "tapInStopsName",
            "tapOutStopsLat": "latitude",
            "tapOutStopsLon": "longitude",
            "stopEndSeq": "rawSeq",
        }
    )

    stop_events = pd.concat([tap_in, tap_out], ignore_index=True)
    stop_events["direction"] = pd.to_numeric(stop_events["direction"], errors="coerce")
    stop_events["rawSeq"] = pd.to_numeric(stop_events["rawSeq"], errors="coerce")
    stop_events["latitude"] = pd.to_numeric(stop_events["latitude"], errors="coerce")
    stop_events["longitude"] = pd.to_numeric(stop_events["longitude"], errors="coerce")

    return stop_events.dropna(
        subset=["corridorName", "tapInStopsName", "direction", "rawSeq"]
    )


def build_boarding_stats(df: pd.DataFrame) -> tuple[pd.DataFrame, int]:
    tap_in_dates = pd.to_datetime(df["tapInTime"], errors="coerce")
    n_days = max(int(tap_in_dates.dt.normalize().nunique()), 1)

    stats = (
        df.dropna(subset=["corridorName", "tapInStopsName"])
        .groupby(["corridorName", "tapInStopsName"], as_index=False)
        .size()
        .rename(columns={"size": "total_penumpang_bulan"})
    )
    stats["rata_rata_per_hari"] = (stats["total_penumpang_bulan"] / n_days).round(2)
    return stats, n_days


def main() -> None:
    usecols = [
        "corridorID",
        "corridorName",
        "direction",
        "tapInStops",
        "tapInStopsName",
        "tapInStopsLat",
        "tapInStopsLon",
        "stopStartSeq",
        "tapInTime",
        "tapOutStops",
        "tapOutStopsName",
        "tapOutStopsLat",
        "tapOutStopsLon",
        "stopEndSeq",
    ]
    df = pd.read_csv(RAW_PATH, usecols=usecols)

    boarding_stats, n_days = build_boarding_stats(df)
    stop_events = build_stop_events(df)

    stop_order = (
        stop_events.groupby(
            ["corridorName", "direction", "tapInStopsName"], as_index=False
        )
        .agg(
            corridorID=("corridorID", first_mode),
            stopCode=("stopCode", first_mode),
            latitude=("latitude", "median"),
            longitude=("longitude", "median"),
            seq_direction=("rawSeq", "median"),
            n_obs=("rawSeq", "size"),
        )
    )

    dir_max = (
        stop_order.groupby(["corridorName", "direction"], as_index=False)["seq_direction"]
        .max()
        .rename(columns={"seq_direction": "max_seq_direction"})
    )
    stop_order = stop_order.merge(dir_max, on=["corridorName", "direction"], how="left")
    stop_order["aligned_seq"] = np.where(
        stop_order["direction"] == 1,
        stop_order["max_seq_direction"] - stop_order["seq_direction"],
        stop_order["seq_direction"],
    )

    canonical = (
        stop_order.groupby(["corridorName", "tapInStopsName"], as_index=False)
        .agg(
            corridorID=("corridorID", first_mode),
            stopCode=("stopCode", first_mode),
            latitude=("latitude", "median"),
            longitude=("longitude", "median"),
            canonical_pos=("aligned_seq", "mean"),
            n_directions=("direction", "nunique"),
            seq_dir_0=("seq_direction", lambda s: float(s[stop_order.loc[s.index, "direction"] == 0].median()) if (stop_order.loc[s.index, "direction"] == 0).any() else np.nan),
            seq_dir_1=("seq_direction", lambda s: float(s[stop_order.loc[s.index, "direction"] == 1].median()) if (stop_order.loc[s.index, "direction"] == 1).any() else np.nan),
        )
    )

    canonical = canonical.sort_values(
        ["corridorName", "canonical_pos", "tapInStopsName"], kind="mergesort"
    ).reset_index(drop=True)
    canonical["stopSeq"] = (
        canonical.groupby("corridorName").cumcount().astype(int)
    )

    data_halte = canonical.merge(
        boarding_stats,
        on=["corridorName", "tapInStopsName"],
        how="left",
    )
    data_halte["total_penumpang_bulan"] = (
        data_halte["total_penumpang_bulan"].fillna(0).astype(int)
    )
    data_halte["rata_rata_per_hari"] = (
        data_halte["rata_rata_per_hari"].fillna(0).round(2)
    )

    data_halte = data_halte[
        [
            "corridorID",
            "corridorName",
            "stopCode",
            "tapInStopsName",
            "stopSeq",
            "canonical_pos",
            "seq_dir_0",
            "seq_dir_1",
            "n_directions",
            "latitude",
            "longitude",
            "total_penumpang_bulan",
            "rata_rata_per_hari",
        ]
    ]

    data_halte.to_csv(OUT_PATH, index=False)
    VIZ_PATH.parent.mkdir(parents=True, exist_ok=True)
    data_halte.to_csv(VIZ_PATH, index=False)

    print(f"[OK] data_halte.csv dibuat: {len(data_halte):,} baris")
    print(f"[OK] viz-app/public/data/halte.csv diperbarui")
    print(f"[INFO] Hari unik tap-in yang dipakai untuk rata_rata_per_hari: {n_days}")


if __name__ == "__main__":
    main()
