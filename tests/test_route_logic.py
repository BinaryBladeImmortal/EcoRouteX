import unittest

import pandas as pd

import app


class RouteLogicTests(unittest.TestCase):
    def test_weekly_trip_data_aggregates_one_point_per_weekday(self):
        trips = pd.DataFrame({
            "date": pd.to_datetime([
                "2026-09-14 08:00:00", "2026-09-14 18:00:00",
                "2026-09-15 09:00:00",
            ]),
            "distance_km": [10.123, 5.456, 2.0],
            "co2_kg": [1.0, 0.5, 0.2],
        })

        weekly = app.get_weekly_trip_data(trips)

        self.assertEqual([item["day"] for item in weekly],
                         ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        self.assertEqual(weekly[0]["distance_km"], 15.58)

    def test_recent_trips_returns_five_latest_by_date(self):
        dates = pd.date_range("2026-01-01", periods=6, freq="D")
        trips = pd.DataFrame({
            "date": dates,
            "start": [f"Start {index}" for index in range(6)],
            "destination": [f"Destination {index}" for index in range(6)],
            "transport_mode": [0] * 6,
            "distance_km": [1.0] * 6,
            "eco_score": [80] * 6,
        })

        recent = app.get_recent_trips(trips)

        self.assertEqual(len(recent), 5)
        self.assertEqual(recent[0]["start"], "Start 5")
        self.assertEqual(recent[-1]["start"], "Start 1")

    def test_backend_duration_uses_corrected_rail_formula(self):
        self.assertEqual(app.estimate_travel_minutes(2, 74.7), 87)
        self.assertEqual(app.estimate_travel_minutes(2, 15), 25)
        self.assertEqual(app.estimate_travel_minutes(2, 5), 14)

    def test_fastest_mode_prefers_metro_for_long_city_commute(self):
        options = app.get_transport_options(74.7, is_rainy=False, preference=1)
        best = app.select_best_mode(
            options,
            preference=1,
            distance=74.7,
            duration=120,
            weather=0,
            time_of_day=9,
        )
        self.assertEqual(best["name"], "Metro")

    def test_fastest_mode_uses_model_when_prediction_is_not_problematic(self):
        options = app.get_transport_options(15, is_rainy=False, preference=1)
        best = app.select_best_mode(
            options,
            preference=1,
            distance=15,
            duration=45,
            weather=0,
            time_of_day=9,
        )
        self.assertEqual(best["name"], "Car")


if __name__ == "__main__":
    unittest.main()
