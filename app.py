from flask import Flask, request, jsonify, send_from_directory
import os
import pandas as pd
import joblib
from datetime import datetime
import re
from urllib.parse import quote
from urllib.request import Request, urlopen
import json

# Load models
co2_model = joblib.load("ml_models/co2_model_fixed.pkl")
route_optimizer_model = joblib.load("ml_models/route_optimizer_model.pkl")


# Import analytics
from analytics.analytics_engine import *

app = Flask(__name__)

FLUTTER_WEB_DIR = os.path.join(os.path.dirname(__file__), "UI", "build", "web")

@app.route("/")
def serve_flutter():
    return send_from_directory(FLUTTER_WEB_DIR, "index.html")

@app.route("/<path:path>")
def serve_flutter_files(path):
    file_path = os.path.join(FLUTTER_WEB_DIR, path)

    if os.path.isfile(file_path):
        return send_from_directory(FLUTTER_WEB_DIR, path)

    return send_from_directory(FLUTTER_WEB_DIR, "index.html")

@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    return response

# Mode mapping
mode_map = {
    0: "Car",
    1: "Bus",
    2: "Metro",
    3: "Bike",
    4: "Walk"
}

# Reverse mapping to get mode ID from name
mode_reverse_map = {v: k for k, v in mode_map.items()}

ADVISOR_LOCATIONS = {
    "virar": (19.4559, 72.8114),
    "churchgate": (18.9322, 72.8264),
    "andheri": (19.1197, 72.8468),
    "bandra": (19.0607, 72.8362),
    "thane": (19.2183, 72.9781),
    "dadar": (19.0178, 72.8478),
    "borivali": (19.2307, 72.8567),
    "dahisar": (19.2500, 72.8590),
    "powai": (19.1176, 72.9060),
    "colaba": (18.9067, 72.8147),
    "nalasopara": (19.4173, 72.7953),
    "vasai": (19.3919, 72.8397),
    "ghatkopar": (19.0860, 72.9080),
    "lower parel": (18.9988, 72.8258),
    "worli": (19.0178, 72.8173),
    "juhu": (19.1075, 72.8263),
    "vile parle": (19.1000, 72.8490),
    "marine drive": (18.9431, 72.8235),
    "gateway of india": (18.9220, 72.8347),
    "mumbai": (19.0760, 72.8777),
}


def _advisor_location_matches(message):
    normalized = re.sub(r"[^a-z0-9 ]", " ", message.lower())
    matches = []
    for name in sorted(ADVISOR_LOCATIONS, key=len, reverse=True):
        match = re.search(r"(?<!\w)" + re.escape(name) + r"(?!\w)", normalized)
        if match:
            matches.append((match.start(), name))
    return [name for _, name in sorted(matches)][:2]


def _advisor_photon_coordinates(place):
    """Resolve an advisor place using the same Photon service as Plan Trip."""
    url = f"http://photon.komoot.io/api/?q={quote(place)}&limit=1"
    request = Request(url, headers={"User-Agent": "EcoRouteX/1.0"})
    with urlopen(request, timeout=8) as response:
        data = json.loads(response.read().decode("utf-8"))
    features = data.get("features", [])
    if not features:
        return None
    coordinates = features[0].get("geometry", {}).get("coordinates", [])
    if len(coordinates) < 2:
        return None
    return float(coordinates[0]), float(coordinates[1])


def _advisor_osrm_distance_km(origin, destination):
    """Get driving distance through the same OSRM route API as Plan Trip."""
    origin_coords = _advisor_photon_coordinates(origin)
    destination_coords = _advisor_photon_coordinates(destination)
    if not origin_coords or not destination_coords:
        return None

    lon1, lat1 = origin_coords
    lon2, lat2 = destination_coords
    url = (
        "http://router.project-osrm.org/route/v1/driving/"
        f"{lon1},{lat1};{lon2},{lat2}?overview=false"
    )
    request = Request(url, headers={"User-Agent": "EcoRouteX/1.0"})
    with urlopen(request, timeout=10) as response:
        data = json.loads(response.read().decode("utf-8"))
    routes = data.get("routes", [])
    if not routes:
        return None
    return round(float(routes[0]["distance"]) / 1000, 1)


def _advisor_preference(message):
    if any(term in message for term in ["cheapest", "cheap", "cost", "budget"]):
        return 2
    if any(term in message for term in ["eco", "green", "emission", "carbon"]):
        return 0
    return 1


def _load_advisor_dataframe():
    df = pd.read_csv("data/mobility_dataset.csv")
    df["date"] = pd.to_datetime(df["date"], errors="coerce")
    return df.dropna(subset=["date"])


def _advisor_route_response(message, origin, destination):
    try:
        distance = _advisor_osrm_distance_km(origin, destination)
    except Exception:
        return {
            "handled": True,
            "type": "error",
            "response": "I'm having trouble reaching the mapping service right now. Please try again in a moment, or use the Plan Trip screen instead.",
        }
    if distance is None:
        return {
            "handled": True,
            "type": "error",
            "response": "I couldn't find a route between those locations. Please try the Plan Trip screen instead.",
        }
    preference = _advisor_preference(message)
    is_rainy = any(term in message for term in ["rain", "rainy", "monsoon", "storm"])
    weather = 2 if is_rainy else 0
    time_of_day = 0 if "morning" in message else 1 if "evening" in message else 2
    duration_feature = round(distance / 50 * 60 + 10)
    options = get_transport_options(distance, is_rainy, preference)
    best = select_best_mode(
        options, preference, distance, duration_feature, weather, time_of_day
    )
    mode = best["mode"]
    duration = estimate_travel_minutes(mode, distance)
    co2_input = pd.DataFrame(
        [[mode, distance, weather, time_of_day]],
        columns=["transport_mode", "distance_km", "weather", "time_of_day"],
    )
    try:
        co2 = float(round(co2_model.predict(co2_input)[0], 2))
    except Exception:
        co2 = float(round((distance / 100) * 100, 2))
    explanation = (
        "The recommendation combines the route model with real-world travel rules"
        " so long trips do not rely on traffic-blind predictions."
    )
    preference_label = {0: "eco-friendly", 1: "fastest", 2: "lowest-cost"}[preference]
    return {
        "handled": True,
        "type": "route",
        "origin": origin.title(),
        "destination": destination.title(),
        "distance_km": distance,
        "mode": best["name"],
        "duration_minutes": duration,
        "co2_kg": co2,
        "response": (
            f"I found a route of approximately {distance:.1f} km from "
            f"{origin.title()} to {destination.title()}. {best['name']} is "
            f"recommended for about {duration} minutes, with an estimated "
            f"{co2:.2f} kg CO2 impact. This is the {preference_label} choice. "
            f"{explanation}"
        ),
        "follow_up_chips": ["Compare with Bus?", "What about the eco-friendly option?"],
    }


def _advisor_history_response(message, df):
    lower = message.lower()
    personal_terms = [
        "my ", "i've", "i have", "have i", "how eco", "eco-friendly have i",
        "most used", "my score", "my co2", "my carbon", "my trips",
        "how much co2", "how much carbon", "switch from car", "car to metro",
        "should i switch", "savings from metro", "how much would i save",
    ]
    if not any(term in lower for term in personal_terms):
        return None
    stats = get_profile_stats(df) if not df.empty else {
        "distance": 0.0, "trips": 0, "co2": 0.0, "cost": 0.0,
        "favourite_mode": 1, "best_score": 0,
    }
    summary = get_weekly_summary(df) if not df.empty else {"distance": 0, "trips": 0, "co2": 0, "cost": 0}
    trend = get_weekly_trend(df) if not df.empty else 0.0
    profile = get_user_level_and_badges(df)
    achievements = get_achievements(df)
    mode_name = mode_map.get(stats["favourite_mode"], "Unknown")
    trend_text = "improved" if trend < 0 else "increased" if trend > 0 else "held steady"

    if ("saved" in lower or "avoided" in lower) and any(
        term in lower for term in ["co2", "carbon", "emission"]
    ):
        estimated_saved = max(0.0, stats["distance"] * 0.12 - stats["co2"])
        return {"handled": True, "type": "history", "response": f"Based on your recorded {stats['distance']:.1f} km of travel, your estimated CO2 avoided versus the app's Car baseline is {estimated_saved:.2f} kg. Your recorded trips produced {stats['co2']:.2f} kg CO2."}

    if any(term in lower for term in ["switch from car", "car to metro", "should i switch", "savings from metro", "how much would i save"]):
        car_trips = df[df["transport_mode"] == 0].tail(5) if not df.empty else df
        if car_trips.empty:
            return {"handled": True, "type": "history", "response": "I could not find any saved Car trips to compare yet."}
        metro_co2 = 0.0
        metro_cost = 0.0
        for _, trip in car_trips.iterrows():
            distance = float(trip["distance_km"])
            co2_input = pd.DataFrame([[2, distance, 0, 2]], columns=["transport_mode", "distance_km", "weather", "time_of_day"])
            try:
                metro_co2 += float(co2_model.predict(co2_input)[0])
            except Exception:
                metro_co2 += distance * 0.02
            metro_cost += 100 + distance * 3
        co2_saved = max(0.0, float(car_trips["co2_kg"].sum()) - metro_co2)
        cost_saved = max(0.0, float(car_trips["cost_rs"].sum()) - metro_cost)
        return {"handled": True, "type": "history", "response": f"Based on your last {len(car_trips)} Car trips, switching to Metro could have saved approximately {co2_saved:.2f} kg CO2 and Rs {cost_saved:.0f}."}

    if any(term in lower for term in ["achievement", "badge", "streak", "level", "status", "progress"]):
        earned = [item["title"] for item in achievements if item["earned"]]
        badge = profile["primary_badge"]
        return {"handled": True, "type": "history", "response": f"You are at level {profile['level']} with the {badge} badge and a {profile['streak_days']}-day streak. Earned achievements: {', '.join(earned) if earned else 'none yet'}."}

    return {"handled": True, "type": "history", "response": f"Your history shows {stats['trips']} trips covering {stats['distance']:.1f} km, with {stats['co2']:.2f} kg CO2 and Rs {stats['cost']:.0f} recorded. Your most-used mode is {mode_name}. This week you travelled {summary['distance']:.1f} km and your distance {trend_text} {abs(trend):.1f}% versus the previous week."}


def get_transport_options(distance, is_rainy, preference):
    """Generate transport options based on distance and conditions."""
    options = []
    
    # Walking — only under 2.5 km
    if distance <= 2.5:
        options.append({
            "mode": 4,  # Walk
            "name": "Walk",
            "eco_score": 100,
        })
    
    # Bike — under 10 km, not rainy
    if distance <= 10 and not is_rainy:
        options.append({
            "mode": 3,  # Bike
            "name": "Bike",
            "eco_score": 98,
        })
    
    # Metro — 3 km and above
    if distance >= 3:
        options.append({
            "mode": 2,  # Metro
            "name": "Metro",
            "eco_score": 88,
        })
    
    # Bus — always available
    options.append({
        "mode": 1,  # Bus
        "name": "Bus",
        "eco_score": 72,
    })
    
    # Car — always available
    options.append({
        "mode": 0,  # Car
        "name": "Car",
        "eco_score": 28,
    })
    
    # Auto — under 15 km
    if distance <= 15:
        options.append({
            "mode": 5,  # Auto (treated as extra, not in primary modes)
            "name": "Auto",
            "eco_score": 45,
        })
    
    return options


def estimate_travel_minutes(mode, distance):
    """Estimate travel time for the selected mode in minutes."""
    if mode == 2:  # Metro / suburban rail
        minutes = distance / 57.5 * 60 + 9
    elif mode == 0:  # Car
        if distance >= 25:
            minutes = distance / 45 * 60 + 15
        elif distance >= 10:
            minutes = distance / 30 * 60 + 15
        else:
            minutes = distance / 25 * 60 + 10
    elif mode == 1:  # Bus
        minutes = distance / 17.5 * 60 + 10
    elif mode == 4:  # Walk
        minutes = distance * 12
    elif mode == 3:  # Bike
        minutes = distance * 3.5
    elif mode == 5:  # Auto, preserving the existing tiered estimate
        if distance >= 25:
            minutes = distance * 2.0 + 12
        elif distance >= 10:
            minutes = distance * 2.2 + 8
        else:
            minutes = distance * 2.5
    else:
        raise ValueError(f"Unknown transport mode: {mode}")

    return int(round(minutes))


def select_best_mode(options, preference, distance, duration, weather, time_of_day):
    """Select best mode based on preference."""
    # preference: 0=Eco Friendly, 1=Fastest, 2=Cheapest

    if preference == 0:  # Eco Friendly
        # Sort by eco_score descending
        best = max(options, key=lambda x: x["eco_score"])
    elif preference == 1:  # Fastest
        model_input = pd.DataFrame(
            [[distance, duration, weather, time_of_day, preference]],
            columns=["distance_km", "duration_min", "weather", "time_of_day", "preference"],
        )
        predicted_mode = int(route_optimizer_model.predict(model_input)[0])
        model_option = next(
            (option for option in options if option["mode"] == predicted_mode),
            None,
        )

        # The model predicts Car for long urban trips, where rail is usually faster
        # because it avoids road traffic and uses dedicated corridors.
        if distance >= 25 and predicted_mode == 0:
            app.logger.info(
                "Overriding route model Car prediction for %.1f km trip with travel-time rules",
                distance,
            )
        elif model_option is not None:
            return model_option
        else:
            app.logger.warning(
                "Route model predicted unavailable mode %s; using travel-time rules",
                predicted_mode,
            )

        if distance >= 25:
            travel_times = {
                4: distance * 18,  # Walk
                3: distance * 7.0,  # Bike
                2: distance * 1.4 + 10,  # Metro / suburban rail
                1: distance * 2.2 + 18,  # Bus
                0: distance * 2.2 + 25,  # Car
                5: distance * 2.0 + 12,  # Auto
            }
        elif distance >= 10:
            travel_times = {
                4: distance * 18,
                3: distance * 5.0,
                2: distance * 1.8 + 8,
                1: distance * 2.8 + 10,
                0: distance * 2.0 + 18,
                5: distance * 2.2 + 8,
            }
        else:
            travel_times = {
                4: distance * 12,
                3: distance * 3.5,
                2: distance * 2.2,
                1: distance * 3.8,
                0: distance * 2.0,
                5: distance * 2.5,
            }
        best = min(options, key=lambda x: travel_times.get(x["mode"], 999))
    else:  # preference == 2, Cheapest
        # Rough cost estimate (lower is better)
        costs = {
            4: 0,                                          # Walk
            3: 10 + distance * 2,                          # Bike
            2: 100 + distance * 3,                         # Metro
            1: 20 + distance * 2,                          # Bus
            0: distance * 12,                              # Car
            5: 50 + distance * 2.5,                        # Auto
        }
        best = min(options, key=lambda x: costs.get(x["mode"], 999))

    return best


# 📊 Dynamic Data Functions for Dashboard & Insights
def get_weekly_trip_data(df):
    """Get daily trip data for the past week for line chart."""
    if df.empty:
        return [{'day': d, 'distance_km': 0.0, 'co2_kg': 0.0} for d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']]
    
    try:
        latest_date = df["date"].max()
        week_ago = latest_date - pd.Timedelta(days=7)
        week_data = df[df["date"] >= week_ago].copy()
        
        if week_data.empty:
            return [{'day': d, 'distance_km': 0.0, 'co2_kg': 0.0} for d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']]
        
        # Aggregate each weekday so the chart always has one point per day.
        week_data['day'] = week_data['date'].dt.strftime('%a')
        daily_data = week_data.groupby('day').agg({
            'distance_km': 'sum',
            'co2_kg': 'sum'
        }).reindex(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'], fill_value=0).reset_index()
        
        # Ensure all days are present
        days_order = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        result = []
        for day in days_order:
            day_row = daily_data[daily_data['day'] == day]
            if not day_row.empty:
                result.append({
                    'day': day,
                    'distance_km': round(float(day_row['distance_km'].iloc[0]), 2),
                    'co2_kg': round(float(day_row['co2_kg'].iloc[0]), 2)
                })
            else:
                result.append({'day': day, 'distance_km': 0.0, 'co2_kg': 0.0})
        
        return result
    except Exception as e:
        print(f"Error in get_weekly_trip_data: {e}")
        return [{'day': d, 'distance_km': 0.0, 'co2_kg': 0.0} for d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']]


def get_achievements(df):
    """Calculate user achievements based on trip data."""
    try:
        total_trips = len(df)
        total_distance = float(df['distance_km'].sum()) if not df.empty else 0
        eco_trips = len(df[df['transport_mode'].isin([1, 2, 3, 4])]) if not df.empty else 0  # Bus, Metro, Bike, Walk
        unique_modes = df['transport_mode'].nunique() if not df.empty else 0
        metro_trips = len(df[df['transport_mode'] == 2]) if not df.empty else 0
        
        # Calculate streak (consecutive days with trips)
        current_streak = 0
        if not df.empty:
            try:
                df_sorted = df.sort_values('date')
                dates = df_sorted['date'].dt.date.unique()
                current_streak = 1
                for i in range(len(dates) - 1, 0, -1):
                    if (dates[i] - dates[i-1]).days == 1:
                        current_streak += 1
                    else:
                        break
            except:
                current_streak = 1 if len(df) > 0 else 0
        
        return [
            {
                'title': 'Green Commuter',
                'description': 'Use eco transport 10 times',
                'emoji': '🌱',
                'earned': eco_trips >= 10,
                'progress': min(100, int((eco_trips / 10) * 100)) if eco_trips > 0 else 0
            },
            {
                'title': 'Eco Traveler',
                'description': 'Travel 100 km by transit',
                'emoji': '🚆',
                'earned': total_distance >= 100,
                'progress': min(100, int((total_distance / 100) * 100)) if total_distance > 0 else 0
            },
            {
                'title': 'Carbon Saver',
                'description': 'Complete 50 trips',
                'emoji': '💚',
                'earned': total_trips >= 50,
                'progress': min(100, int((total_trips / 50) * 100)) if total_trips > 0 else 0
            },
            {
                'title': 'City Explorer',
                'description': 'Try all 5 transport modes',
                'emoji': '🗺️',
                'earned': unique_modes >= 5,
                'progress': min(100, int((unique_modes / 5) * 100)) if unique_modes > 0 else 0
            },
            {
                'title': 'Speed Commuter',
                'description': 'Complete 20 metro trips',
                'emoji': '⚡',
                'earned': metro_trips >= 20,
                'progress': min(100, int((metro_trips / 20) * 100)) if metro_trips > 0 else 0
            },
            {
                'title': 'Daily Traveler',
                'description': 'Maintain a 7-day streak',
                'emoji': '🔥',
                'earned': current_streak >= 7,
                'progress': min(100, int((current_streak / 7) * 100)) if current_streak > 0 else 0
            }
        ]
    except Exception as e:
        print(f"Error in get_achievements: {e}")
        return [
            {'title': 'Green Commuter', 'description': 'Use eco transport 10 times', 'emoji': '🌱', 'earned': False, 'progress': 0},
            {'title': 'Eco Traveler', 'description': 'Travel 100 km by transit', 'emoji': '🚆', 'earned': False, 'progress': 0},
            {'title': 'Carbon Saver', 'description': 'Complete 50 trips', 'emoji': '💚', 'earned': False, 'progress': 0},
            {'title': 'City Explorer', 'description': 'Try all 5 transport modes', 'emoji': '🗺️', 'earned': False, 'progress': 0},
            {'title': 'Speed Commuter', 'description': 'Complete 20 metro trips', 'emoji': '⚡', 'earned': False, 'progress': 0},
            {'title': 'Daily Traveler', 'description': 'Maintain a 7-day streak', 'emoji': '🔥', 'earned': False, 'progress': 0}
        ]


def get_user_level_and_badges(df):
    """Calculate user level, badges, and streak info."""
    try:
        total_trips = len(df)
        total_distance = float(df['distance_km'].sum()) if not df.empty else 0
        avg_eco_score = float(df['eco_score'].mean()) if not df.empty and 'eco_score' in df.columns else 50
        
        # Calculate level based on trips and distance
        level = min(10, 1 + int(total_trips / 10) + int(total_distance / 100))
        
        # Determine primary badge
        if avg_eco_score >= 90:
            primary_badge = '🌍 Eco Master'
        elif avg_eco_score >= 80:
            primary_badge = '🌍 Eco Warrior'
        elif avg_eco_score >= 60:
            primary_badge = '🌿 Eco Starter'
        else:
            primary_badge = '🚗 Beginner'
        
        # Calculate streak
        current_streak = 0
        if not df.empty:
            try:
                df_sorted = df.sort_values('date')
                dates = df_sorted['date'].dt.date.unique()
                if len(dates) > 0:
                    current_streak = 1
                    for i in range(len(dates) - 1, 0, -1):
                        if (dates[i] - dates[i-1]).days == 1:
                            current_streak += 1
                        else:
                            break
            except:
                current_streak = 1 if len(df) > 0 else 0
        
        streak_badge = f'🔥 {current_streak}-day streak' if current_streak > 0 else None
        
        return {
            'level': level,
            'primary_badge': primary_badge,
            'streak_days': current_streak,
            'streak_badge': streak_badge
        }
    except Exception as e:
        print(f"Error in get_user_level_and_badges: {e}")
        return {
            'level': 1,
            'primary_badge': '🚗 Beginner',
            'streak_days': 0,
            'streak_badge': None
        }


def get_mobility_score_breakdown(df):
    """Calculate mobility score breakdown from real data."""
    try:
        if df.empty:
            return {
                'overall_score': 50,
                'breakdown': [
                    {'label': 'Eco Impact', 'value': 0.5, 'emoji': '🌱'},
                    {'label': 'Travel Efficiency', 'value': 0.5, 'emoji': '⚡'},
                    {'label': 'Cost Efficiency', 'value': 0.5, 'emoji': '💰'},
                    {'label': 'Health Benefit', 'value': 0.5, 'emoji': '💪'}
                ]
            }
        
        avg_co2 = float(df['co2_kg'].mean()) if 'co2_kg' in df.columns else 0
        total_distance = float(df['distance_km'].sum()) if 'distance_km' in df.columns else 0
        total_trips = len(df)
        
        # Calculate eco impact score (inverse of CO2)
        eco_score = max(0, min(100, 100 - (avg_co2 * 20))) if avg_co2 > 0 else 50
        
        # Travel efficiency based on eco score average
        efficiency_score = float(df['eco_score'].mean()) if 'eco_score' in df.columns and not df.empty else 50
        
        # Cost efficiency (based on mode usage - lower cost modes = higher score)
        walk_bike_pct = len(df[df['transport_mode'].isin([3, 4])]) / max(1, total_trips)
        cost_score = 40 + (walk_bike_pct * 60)  # Base 40 + up to 60 for free modes
        
        # Health benefit (based on walking/biking)
        health_score = 30 + (walk_bike_pct * 70)
        
        # Overall score
        overall = int((eco_score + efficiency_score + cost_score + health_score) / 4)
        
        return {
            'overall_score': overall,
            'breakdown': [
                {'label': 'Eco Impact', 'value': round(eco_score / 100, 2), 'emoji': '🌱'},
                {'label': 'Travel Efficiency', 'value': round(efficiency_score / 100, 2), 'emoji': '⚡'},
                {'label': 'Cost Efficiency', 'value': round(cost_score / 100, 2), 'emoji': '💰'},
                {'label': 'Health Benefit', 'value': round(health_score / 100, 2), 'emoji': '💪'}
            ]
        }
    except Exception as e:
        print(f"Error in get_mobility_score_breakdown: {e}")
        return {
            'overall_score': 50,
            'breakdown': [
                {'label': 'Eco Impact', 'value': 0.5, 'emoji': '🌱'},
                {'label': 'Travel Efficiency', 'value': 0.5, 'emoji': '⚡'},
                {'label': 'Cost Efficiency', 'value': 0.5, 'emoji': '💰'},
                {'label': 'Health Benefit', 'value': 0.5, 'emoji': '💪'}
            ]
        }


def get_eco_trend_data(df):
    """Get 4-week CO2 avoided trend data."""
    try:
        if df.empty:
            return {'weeks': ['W1', 'W2', 'W3', 'W4'], 'values': [0.0, 0.0, 0.0, 0.0]}
        
        latest_date = df["date"].max()
        weeks = []
        values = []
        
        for i in range(4):
            try:
                week_start = latest_date - pd.Timedelta(days=(i + 1) * 7)
                week_end = latest_date - pd.Timedelta(days=i * 7)
                week_data = df[(df["date"] >= week_start) & (df["date"] < week_end)]
                
                # Calculate CO2 avoided vs car baseline (car emits ~0.12 kg/km)
                week_distance = float(week_data['distance_km'].sum()) if not week_data.empty else 0
                car_baseline = week_distance * 0.12
                actual_co2 = float(week_data['co2_kg'].sum()) if not week_data.empty else 0
                co2_avoided = max(0, car_baseline - actual_co2)
                
                weeks.insert(0, f'W{4-i}')
                values.insert(0, round(co2_avoided, 1))
            except:
                weeks.insert(0, f'W{4-i}')
                values.insert(0, 0.0)
        
        return {'weeks': weeks, 'values': values}
    except Exception as e:
        print(f"Error in get_eco_trend_data: {e}")
        return {'weeks': ['W1', 'W2', 'W3', 'W4'], 'values': [0.0, 0.0, 0.0, 0.0]}


# 🏠 HOME API
def get_recent_trips(df):
    recent = df.sort_values("date", ascending=False).head(5)
    trips = []
    for _, row in recent.iterrows():
        trips.append({
            "start": str(row["start"]) if pd.notna(row["start"]) else "Unknown",
            "destination": str(row["destination"]) if pd.notna(row["destination"]) else "Unknown",
            "mode": int(row["transport_mode"]),
            "distance": float(row["distance_km"]),
            "eco_score": int(row["eco_score"])
        })

    return trips

@app.route("/home", methods=["GET"])
def home():
    try:
        df = pd.read_csv("data/mobility_dataset.csv")
        df["date"] = pd.to_datetime(df["date"], errors="coerce")
        df = df.dropna(subset=["date"])

        return jsonify({
            "mobility_score": calculate_mobility_score(df),
            "weekly_summary": get_weekly_summary(df),
            "trend": get_weekly_trend(df),
            "recent_trips": get_recent_trips(df)
        })

    except Exception as e:
        print("ERROR:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/advisor", methods=["POST"])
def advisor():
    """Return real route/history advice or delegate general questions to Flutter."""
    try:
        data = request.get_json(silent=True) or {}
        message = str(data.get("message", "")).strip()
        if not message:
            return jsonify({"handled": False, "type": "general"})

        df = _load_advisor_dataframe()
        history_response = _advisor_history_response(message, df)
        if history_response is not None:
            return jsonify(history_response)

        locations = _advisor_location_matches(message)
        last_route = data.get("last_route") or {}
        if len(locations) < 2 and last_route.get("origin") and last_route.get("destination"):
            if any(term in message.lower() for term in ["cheapest", "fastest", "eco", "recommend", "best", "compare"]):
                locations = [last_route["origin"].lower(), last_route["destination"].lower()]

        if len(locations) >= 2:
            return jsonify(_advisor_route_response(message, locations[0], locations[1]))

        return jsonify({"handled": False, "type": "general"})
    except Exception as error:
        app.logger.exception("Advisor request failed")
        return jsonify({"handled": False, "type": "error", "error": str(error)}), 500


# 📊 INSIGHTS API
@app.route("/insights", methods=["GET"])
def insights():
    try:
        df = pd.read_csv("data/mobility_dataset.csv")
        df["date"] = pd.to_datetime(df["date"], errors="coerce")
        df = df.dropna(subset=["date"])

        return jsonify({
            "weekly_summary": get_weekly_summary(df),
            "trend": get_weekly_trend(df),
            "mode_distribution": get_mode_distribution(df),
            "weekly_trips": get_weekly_trip_data(df),
            "mobility_score": get_mobility_score_breakdown(df),
            "eco_trend": get_eco_trend_data(df)
        })
    except Exception as e:
        print(f"ERROR in /insights: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# 👤 PROFILE API
@app.route("/profile", methods=["GET"])
def profile():
    try:
        df = pd.read_csv("data/mobility_dataset.csv")
        df["date"] = pd.to_datetime(df["date"], errors="coerce")
        df = df.dropna(subset=["date"])
        
        stats = get_profile_stats(df)
        stats['achievements'] = get_achievements(df)
        stats['user_level'] = get_user_level_and_badges(df)
        
        return jsonify(stats)
    except Exception as e:
        print(f"ERROR in /profile: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/achievements", methods=["GET"])
def achievements():
    try:
        df = pd.read_csv("data/mobility_dataset.csv")
        df["date"] = pd.to_datetime(df["date"], errors="coerce")
        df = df.dropna(subset=["date"])
        
        return jsonify(get_achievements(df))
    except Exception as e:
        print(f"ERROR in /achievements: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/weekly_trips", methods=["GET"])
def weekly_trips():
    try:
        df = pd.read_csv("data/mobility_dataset.csv")
        df["date"] = pd.to_datetime(df["date"], errors="coerce")
        df = df.dropna(subset=["date"])
        
        return jsonify(get_weekly_trip_data(df))
    except Exception as e:
        print(f"ERROR in /weekly_trips: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/dashboard", methods=["GET"])
def dashboard():
    try:
        df = pd.read_csv("data/mobility_dataset.csv")
        df["date"] = pd.to_datetime(df["date"], errors="coerce")
        df = df.dropna(subset=["date"])
        
        return jsonify({
            "mobility_score": get_mobility_score_breakdown(df),
            "eco_trend": get_eco_trend_data(df),
            "user_level": get_user_level_and_badges(df)
        })
    except Exception as e:
        print(f"ERROR in /dashboard: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/plan", methods=["POST"])
def plan():
    data = request.json

    distance = data["distance"]
    duration = data["duration"]
    weather = data["weather"]
    time_of_day = data["time_of_day"]
    preference = data["preference"]

    is_rainy = weather == 2
    
    options = get_transport_options(distance, is_rainy, preference)
    best_option = select_best_mode(
        options, preference, distance, duration, weather, time_of_day
    )
    
    mode = best_option["mode"]
    mode_name = best_option["name"]
    travel_minutes = estimate_travel_minutes(mode, distance)

    # CO2 prediction
    try:
        co2_input = pd.DataFrame(
            [[mode, distance, weather, time_of_day]],
            columns=["transport_mode", "distance_km", "weather", "time_of_day"],
        )
        co2 = float(round(co2_model.predict(co2_input)[0], 2))
    except:
        co2 = float(round((distance / 100) * 100, 2))

    eco_score = int(max(0, min(100, 100 - co2 * 10)))

    # 🔥 ADD THIS BLOCK (THIS IS THE FIX)
    new_row = {
        "date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "start": data.get("start") if data.get("start") else "Unknown",
        "destination": data.get("destination") if data.get("destination") else "Unknown",
        "distance_km": distance,
        "transport_mode": mode,
        "co2_kg": co2,
        "cost_rs": distance * 10,
        "eco_score": eco_score
    }

    df = pd.read_csv("data/mobility_dataset.csv")
    columns = ["date","start","destination","distance_km","transport_mode","co2_kg","cost_rs","eco_score"]
    df = df[columns] if not df.empty else pd.DataFrame(columns=columns)
    new_df = pd.DataFrame([new_row])[columns]
    df = pd.concat([df, new_df], ignore_index=True)
    df.to_csv("data/mobility_dataset.csv", index=False)
    # 🔥 END FIX

    return jsonify({
        "best_mode": mode_name,
        "duration": travel_minutes,
        "co2": co2,
        "eco_score": eco_score
    })


# Run server
if __name__ == "__main__":
    app.run(debug=False)