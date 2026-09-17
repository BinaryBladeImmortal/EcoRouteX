# EcoRouteX Project Deep Dive

This document is a revision guide for understanding EcoRouteX in interviews and future maintenance. It describes the current checked-out project after branding and generated-file cleanup. Legacy code paths remain in place by design.

## 1. Project Identity

EcoRouteX is a local full-stack smart mobility planner. The Flutter client collects a trip, geocodes places, calculates route distance, calls a Flask REST API, and displays a recommendation. Flask loads two scikit-learn artifacts: a route-mode classifier and a CO2 regressor. Trip results are persisted in a CSV file and reused for analytics dashboards.

The project is a working prototype, not a production deployment.

## 2. Repository Map

```text
project root/
  app.py
  requirements.txt
  README.md
  PROJECT_DEEP_DIVE.md
  .gitignore
  analytics/
    analytics_engine.py
  data/
    mobility_dataset.csv
  ml_models/
    route_optimizer_model.pkl
    co2_model_fixed.pkl
    co2_emission_dataset_50000.csv
  tests/
    test_route_logic.py
  UI/
    pubspec.yaml
    pubspec.lock
    analysis_options.yaml
    README.md
    TODO.md
    lib/
    test/
    android/
    ios/
    linux/
    macos/
    web/
    windows/
```

Generated folders removed during cleanup:

- `.venv` was preserved locally but is ignored by Git.
- Root `__pycache__` was deleted.
- `UI/build` was deleted.
- `UI/.dart_tool` was deleted.
- `UI/.flutter-plugins-dependencies` was deleted.
- `UI/.idea` was deleted.
- Platform `ephemeral` folders were deleted.

## 3. Runtime Architecture

```text
Flutter
  |
  | HTTP JSON requests
  v
Flask app.py
  |-- route_optimizer_model.pkl
  |-- co2_model_fixed.pkl
  |-- analytics/analytics_engine.py
  +-- data/mobility_dataset.csv

Flutter also calls:
  |-- Photon for geocoding
  |-- OSRM for route geometry and distance
  +-- OpenStreetMap for map tiles
```

Entry points:

- Python backend: `app.py`
- Flutter application: `UI/lib/main.dart`
- Backend client: `UI/lib/services/api_service.dart`
- Main trip workflow: `UI/lib/screens/plan_trip_screen.dart`

## 4. Backend Files

### `app.py`

This is the Flask application and the main backend module.

Startup responsibilities:

1. Import Flask, pandas, joblib, and datetime.
2. Load `co2_model_fixed.pkl`.
3. Load `route_optimizer_model.pkl`.
4. Import analytics helpers.
5. Create the Flask app.
6. Register CORS headers and routes.

Important global objects:

```python
co2_model = joblib.load("ml_models/co2_model_fixed.pkl")
route_optimizer_model = joblib.load("ml_models/route_optimizer_model.pkl")
```

Because paths are relative, the server should be started from the repository root.

#### CORS

`add_cors_headers()` allows all origins and GET, POST, and OPTIONS methods. This is convenient for local Flutter development but should be restricted in production.

#### Mode mapping

The main mapping is:

```text
0 Car
1 Bus
2 Metro
3 Bike
4 Walk
```

Auto uses ID 5 in parts of the backend but is not consistently represented everywhere else.

#### `get_transport_options(distance, is_rainy, preference)`

This builds the candidate list. It does not calculate duration.

| Mode | ID | Availability | Eco score |
|---|---:|---|---:|
| Walk | 4 | distance <= 2.5 km | 100 |
| Bike | 3 | distance <= 10 km and not rainy | 98 |
| Metro | 2 | distance >= 3 km | 88 |
| Bus | 1 | always | 72 |
| Car | 0 | always | 28 |
| Auto | 5 | distance <= 15 km | 45 |

The `preference` argument is currently unused inside this function.

#### `estimate_travel_minutes(mode, distance)`

This is the backend source of truth for the final displayed duration.

```text
Metro: distance / 57.5 * 60 + 9
Bus: distance / 17.5 * 60 + 10
Walk: distance * 12
Bike: distance * 3.5
```

Car uses distance tiers:

```text
>= 25 km: distance / 45 * 60 + 15
>= 10 km: distance / 30 * 60 + 15
< 10 km:  distance / 25 * 60 + 10
```

Auto preserves the existing tier-based estimate.

The function rounds the result to an integer.

#### `select_best_mode(...)`

This is the recommendation controller.

Inputs:

```text
options
preference
distance
duration
weather
time_of_day
```

Eco Friendly branch:

- Chooses the available option with the highest fixed eco score.
- Does not call the route model.

Fastest branch:

1. Builds a pandas DataFrame with route model features.
2. Calls `route_optimizer_model.predict()`.
3. Converts the numeric class into an available option.
4. Returns the model option normally.
5. If distance >= 25 km and the model predicts Car, logs an override and uses rule-based travel-time comparison.
6. If the model predicts an unavailable mode, uses the rule fallback.

Route model input columns:

```text
distance_km
duration_min
weather
time_of_day
preference
```

The long-distance override is deliberately narrow. It does not replace the model globally.

Cheapest branch:

Uses hardcoded costs:

```text
Walk: 0
Bike: 10 + distance * 2
Bus: 20 + distance * 2
Metro: 100 + distance * 3
Car: distance * 12
Auto: 50 + distance * 2.5
```

The selected cost is not returned in the `/plan` response. CSV persistence currently writes `distance * 10` as `cost_rs`, so cost logic is not fully consistent.

#### `/plan`

Request fields:

```json
{
  "start": "Virar",
  "destination": "Churchgate",
  "distance": 74.7,
  "duration": 100,
  "weather": 0,
  "time_of_day": 9,
  "preference": 1
}
```

Processing sequence:

```text
Read JSON
  -> read distance, duration, weather, time, preference
  -> build available options
  -> select mode with ML/rules
  -> estimate final duration
  -> create labeled CO2 DataFrame
  -> predict CO2
  -> calculate eco score
  -> append trip to CSV
  -> return JSON
```

Response:

```json
{
  "best_mode": "Metro",
  "duration": 87,
  "co2": 1.13,
  "eco_score": 88
}
```

Every successful `/plan` call persists a trip immediately. The frontend Save button does not currently control persistence.

#### Other functions and routes in `app.py`

`app.py` also contains dashboard-oriented helpers for weekly trip data, achievements, user levels, badges, mobility score breakdowns, CO2 trends, and recent trips.

Routes include:

- `GET /home`
- `GET /insights`
- `GET /profile`
- `POST /plan`
- `GET /achievements`
- `GET /weekly_trips`
- `GET /dashboard`

The first four are the main Flutter flow. The latter three appear to be legacy or future API surfaces.

## 5. Analytics

### `analytics/analytics_engine.py`

This module separates reusable analytics from the Flask route definitions.

Functions:

- `get_weekly_summary(df)`: totals distance, trips, CO2, and cost for the latest seven-day period.
- `get_weekly_trend(df)`: compares current and previous seven-day distance.
- `get_mode_distribution(df)`: returns percentages by transport-mode ID.
- `calculate_mobility_score(df)`: scores based on average CO2.
- `get_profile_stats(df)`: aggregates profile totals, favorite mode, and best eco score.

The module does not load models and does not choose routes.

## 6. Data and Models

### `data/mobility_dataset.csv`

Persistent trip history with columns:

```text
date,start,destination,distance_km,transport_mode,co2_kg,cost_rs,eco_score
```

On each `/plan` call, Flask reads the full file, appends a row, and rewrites the full file. This is understandable for a prototype but not safe for concurrent production traffic.

### `ml_models/route_optimizer_model.pkl`

A joblib/scikit-learn Random Forest classifier.

Known metadata:

- 120 estimators
- Five input features
- Classes 0 through 4
- Trained with scikit-learn 1.6.1

It predicts the preferred transport mode for the Fastest branch.

### `ml_models/co2_model_fixed.pkl`

A joblib/scikit-learn Random Forest regressor.

Expected columns:

```text
transport_mode,distance_km,weather,time_of_day
```

The backend supplies a labeled DataFrame so scikit-learn does not warn about missing feature names.

### `ml_models/co2_emission_dataset_50000.csv`

Training data for the CO2 model. It is not loaded during normal requests but is useful for retraining and provenance.

## 7. Flutter Files

### `UI/lib/main.dart`

Flutter entry point. It creates the application theme and main navigation shell. The shell uses an IndexedStack with:

1. Home
2. Plan Trip
3. AI Advisor
4. Insights
5. Dashboard

### `UI/lib/models/mobility_model.dart`

Defines Dart models:

- `TripInput`
- `TransportOption`
- `TripRecommendation`
- `ChatMessage`
- `WeeklyTripData`
- `Achievement`

It also contains an older local `MobilityAdvisor`, a keyword-based `AIChatAdvisor`, and sample data. These paths remain for reference and are not the main backend-driven trip recommendation flow.

### `UI/lib/services/api_service.dart`

The HTTP client for Flask.

Methods:

- `fetchHomeData()` -> `/home`
- `fetchInsightsData()` -> `/insights`
- `fetchProfileData()` -> `/profile`
- `planTrip()` -> `/plan`

Base URLs:

```text
Android emulator: http://10.0.2.2:5000
Other platforms:  http://127.0.0.1:5000
```

It sends the pre-model duration from the plan screen and receives the final backend duration in the response.

Limitations include no timeout, retries, authentication, schema validation, or detailed error handling.

### `UI/lib/services/map_service.dart`

Contains Photon and OSRM helpers:

- `getCoordinates()`
- `getRoute()`
- `getDistance()`

`plan_trip_screen.dart` also contains direct map HTTP logic, so this service overlaps with the screen implementation.

### `UI/lib/screens/home_screen.dart`

Loads `/home` and displays summaries, score, recent trips, tips, and navigation actions. Some status and ranking values are hardcoded.

### `UI/lib/screens/plan_trip_screen.dart`

The primary user workflow:

1. Collect origin and destination.
2. Request Photon autocomplete.
3. Resolve selected coordinates.
4. Request OSRM route and distance.
5. Map weather, time, and preference labels to numeric values.
6. Calculate the neutral model duration feature:

```dart
(distance / 50 * 60 + 10).round()
```

7. Call Flask `/plan`.
8. Use the returned `duration` directly.
9. Navigate to `RecommendationScreen`.

The old local `_estimateTravelMinutes()` function was removed from this recommendation path.

Known redundant state and logic remain, including duplicate map helpers, unused animation state, and some coordinate-management edge cases.

### `UI/lib/screens/recommendation_screen.dart`

Displays the recommended mode, backend duration, eco score, cost estimate, explanatory text, and decision bars. The decision bars are frontend heuristics, not actual model explanations. Alternatives are currently empty.

### `UI/lib/screens/insights_screen.dart`

Loads `/insights` and displays charts, weekly totals, mode distribution, CO2 trends, and mobility breakdowns. Some goal labels and percentages are static.

### `UI/lib/screens/dashboard_screen.dart`

Loads `/profile` and displays user level, badges, achievements, statistics, and environmental impact estimates.

### `UI/lib/screens/ai_advisor_screen.dart`

Local keyword-based chat. It does not call Flask, a language model, or an external AI provider. It uses fixed responses and an artificial typing delay.

### `UI/lib/widgets/mobility_widgets.dart`

Reusable UI components such as cards, headers, badges, action buttons, rings, chips, route visualizers, and quick-stat widgets. Some are unused legacy components.

### `UI/lib/utils/app_theme.dart`

Central theme and design system: colors, typography, Material settings, cards, inputs, buttons, shadows, gradients, and navigation styling.

## 8. Flutter Configuration and Tests

### `UI/pubspec.yaml`

Declares the Flutter SDK and packages such as `http`, `flutter_map`, `latlong2`, `fl_chart`, `google_fonts`, `flutter_animate`, and `percent_indicator`.

### `UI/pubspec.lock`

Locks resolved Dart package versions.

### `UI/analysis_options.yaml`

Dart analyzer configuration. The project has existing informational lints, especially deprecated `withOpacity`, unused declarations, and production `print` calls.

### `UI/test/widget_test.dart`

Smoke test that verifies the app builds and has the expected navigation structure. It does not test backend communication, maps, route planning, or error states.

### `UI/README.md`

Flutter-specific README, now branded as EcoRouteX.

### `UI/TODO.md`

Development notes. It is not runtime logic.

## 9. Platform Folders

These folders are Flutter build targets and native runner projects. They contain platform glue, packaging, generated plugin registration, and native launch configuration rather than core business logic.

### `UI/android/`

Android Gradle project. Important files include:

- `app/build.gradle.kts`: Android namespace, application ID, SDK and signing configuration.
- `app/src/main/AndroidManifest.xml`: application label, activity, permissions/queries, and Flutter embedding metadata.
- `app/src/main/kotlin/com/example/ecoroutex/MainActivity.kt`: Android Flutter activity.
- `build.gradle.kts`, `settings.gradle.kts`, `gradle.properties`: Gradle project configuration.
- `gradlew` and `gradlew.bat`: Gradle wrapper launchers.
- `gradle/`: Gradle wrapper support files.
- `local.properties`: machine-specific Flutter/Android SDK paths; should not be treated as portable project configuration.

### `UI/ios/`

Xcode project and Runner application. `Info.plist` contains iOS display metadata; `Runner.xcodeproj` contains build settings and bundle identifiers; `RunnerTests` contains native template tests.

### `UI/macos/`

macOS Runner, Xcode project, scheme, app configuration, assets, and generated Flutter integration. The product name and scheme now use EcoRouteX.

### `UI/linux/`

CMake project and GTK runner. `CMakeLists.txt` defines the executable and application ID; `runner/my_application.cc` creates the native window and sets the EcoRouteX title.

### `UI/windows/`

CMake and Win32 runner. `CMakeLists.txt` defines the project and binary; `runner/main.cpp` creates the window; `Runner.rc` contains Windows product metadata and icon/resource information.

### `UI/web/`

Web shell and install metadata:

- `index.html`: Flutter web host page and title.
- `manifest.json`: installable web-app metadata.
- `favicon.png` and `icons/`: web icons.

## 10. Branding Changes

The old generated project identity was `app_css`. It was changed to EcoRouteX in tracked platform source files:

- Android namespace and application ID: `com.example.ecoroutex`
- Android package declaration and directory: `com/example/ecoroutex`
- Android display label: `EcoRouteX`
- iOS bundle identifiers and display name
- macOS product name, bundle IDs, product references, and scheme names
- Linux binary name, application ID, and GTK window title
- Windows project/binary name, window title, and resource metadata
- Web title and manifest name
- Flutter README heading
- Flutter module filenames: `ecoroutex.iml` and `ecoroutex_android.iml`

## 11. End-to-End Virar to Churchgate Example

Input:

```text
Distance: 74.7 km
Preference: Fastest
Weather: Sunny
Time: Morning
```

Flutter sends a pre-model duration of approximately 100 minutes using the 50 km/h baseline.

The route model predicts Car. Because the trip is at least 25 km, the targeted override rejects that unrealistic result and evaluates rule-based travel times. Metro is selected.

Final Metro duration:

```text
74.7 / 57.5 * 60 + 9 = approximately 87 minutes
```

The CO2 model receives a labeled DataFrame and returns approximately 1.13 kg in the tested case.

The API response is:

```json
{
  "best_mode": "Metro",
  "duration": 87,
  "co2": 1.13,
  "eco_score": 88
}
```

Flutter displays the returned 87-minute duration. This fixed the earlier 169-minute display, which came from the old Flutter-only formula `distance * 2.2 + 5`.

## 12. Testing and Verification

Backend command:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -p "test*.py" -v
```

Current backend tests cover:

- Metro duration at 74.7 km, 15 km, and 5 km.
- Long-distance Car override.
- Normal model-driven selection.

Flutter command:

```powershell
cd UI
flutter test
```

The Flutter smoke test passes. Existing test output may include external OpenStreetMap tile request failures; these do not currently fail the test.

## 13. Honest Limitations

- CSV persistence is not production-grade.
- There is no authentication or authorization.
- CORS allows every origin for local development.
- Travel time uses average speeds and fixed buffers, not live traffic or train schedules.
- Public map APIs can fail or rate-limit requests.
- Some unused endpoints, duplicate map logic, local recommendation formulas, and prototype UI paths remain intentionally.
- Model explainability and confidence are not exposed.
- Some dashboard metrics are static or illustrative.
- Auto is not consistently supported across all mode mappings.
- The backend has limited validation and no production WSGI configuration.

## 14. Likely Interview Questions and Honest Answers

### 1. What problem does EcoRouteX solve?

It helps a user choose a transport mode for a trip while considering distance, weather, time of day, preference, estimated duration, emissions, cost, and historical mobility data.

### 2. What is the system architecture?

It is a Flutter client talking to a local Flask REST API. Flutter handles interaction, maps, and presentation. Flask handles recommendation logic, model inference, CO2 prediction, analytics, and CSV persistence.

### 3. Why did you use a hybrid ML plus rules approach?

The route model captures learned patterns, but a model can produce an implausible result when its training data does not represent a specific real-world corridor well. The targeted rule protects a known long-distance urban case without discarding the model for every trip.

### 4. What was the route recommendation bug?

For long trips such as Virar to Churchgate, the model could predict Car even though suburban rail is usually faster. The first rule fix changed the selector to favor rail, but the displayed duration was still wrong because Flutter used a separate local formula.

### 5. How did you find the duration bug?

I traced the request and response path. Flask returned only the selected mode, while Flutter calculated the displayed duration in `_estimateTravelMinutes()`. For 74.7 km Metro, the old formula `74.7 * 2.2 + 5` produced 169 minutes.

### 6. How was the duration bug fixed?

Flask now calculates the authoritative duration with calibrated mode formulas and returns a `duration` field in `/plan`. Flutter displays that response value instead of recalculating it independently.

### 7. Why does Flutter send duration before Flask selects a mode?

The route classifier expects duration as one of its input features. Flutter sends a neutral distance-based estimate, `distance / 50 * 60 + 10`, as a pre-model feature. Flask later calculates the final mode-specific duration after selection.

### 8. Why use CSV instead of a database?

CSV was quick and transparent for a local prototype and made it easy to inspect trip data. It is not suitable for concurrent writes, transactions, indexing, or production scale. I would replace it with PostgreSQL or another transactional database before deployment.

### 9. How is CO2 calculated?

The selected mode, distance, weather, and time of day are passed to a Random Forest regressor. The model was trained with scikit-learn 1.6.1, so that version is pinned in `requirements.txt`.

### 10. How do you prevent model compatibility warnings?

Both serialized models were trained with scikit-learn 1.6.1, so the project pins that exact version. The prediction inputs are also labeled DataFrames matching the models' training feature names.

### 11. Is the AI Advisor a real language model?

No. It is a local keyword-based assistant with fixed responses. It is a conversational UI prototype, not an LLM integration.

### 12. What would you improve for production?

I would add a real database, schema validation, authentication, restricted CORS, request timeouts, retries, structured logging, a production WSGI server, live traffic/transit data, model monitoring, confidence scores, integration tests, and environment-based configuration.

### 13. What are the main testing gaps?

The current tests focus on route logic and a Flutter smoke build. I would add Flask endpoint tests, persistence tests, invalid-input tests, model failure tests, analytics tests, API contract tests, and UI tests for loading, error, and recommendation states.

### 14. What is the most important design lesson from this project?

A single source of truth matters. Mode selection and displayed duration initially used different calculations, which created a user-visible contradiction. Moving the final duration calculation to Flask made the API contract explicit and removed that drift.

## 15. Suggested Future Work

1. Add Flask request schemas and a health endpoint.
2. Replace CSV with a database.
3. Consolidate map networking in `MapService`.
4. Add API and widget integration tests.
5. Add live traffic and transit schedule inputs.
6. Standardize Auto support across backend and Flutter.
7. Remove or clearly label prototype code after documenting it.
8. Add model confidence and monitoring.
9. Move URLs, CORS, and runtime settings into environment configuration.
10. Finish branding and release signing for each native platform.
