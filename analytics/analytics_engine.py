import pandas as pd

def get_weekly_summary(df):
    latest_date = df["date"].max()
    week_ago = latest_date - pd.Timedelta(days=7)

    week_data = df[df["date"] >= week_ago]

    return {
        "distance": float(round(week_data["distance_km"].sum(), 2)),
        "trips": int(len(week_data)),
        "co2": float(round(week_data["co2_kg"].sum(), 2)),
        "cost": float(round(week_data["cost_rs"].sum(), 2))
    }


def get_weekly_trend(df):
    latest_date = df["date"].max()

    current_week = df[df["date"] >= latest_date - pd.Timedelta(days=7)]
    previous_week = df[
        (df["date"] < latest_date - pd.Timedelta(days=7)) &
        (df["date"] >= latest_date - pd.Timedelta(days=14))
    ]

    curr = current_week["distance_km"].sum()
    prev = previous_week["distance_km"].sum()

    if prev == 0:
        return 0.0

    change = ((curr - prev) / prev) * 100
    return float(round(change, 2))


def get_mode_distribution(df):
    counts = df["transport_mode"].value_counts(normalize=True) * 100
    return {int(k): float(round(v, 2)) for k, v in counts.to_dict().items()}


def calculate_mobility_score(df):
    avg_co2 = df["co2_kg"].mean()
    score = 100 - (avg_co2 * 20)
    score = max(0, min(score, 100))
    return int(score)


def get_profile_stats(df):
    return {
        "distance": float(round(df["distance_km"].sum(), 2)),
        "trips": int(len(df)),
        "co2": float(round(df["co2_kg"].sum(), 2)),
        "cost": float(round(df["cost_rs"].sum(), 2)),
        "favourite_mode": int(df["transport_mode"].mode()[0]),
        "best_score": int(df["eco_score"].max())
    }