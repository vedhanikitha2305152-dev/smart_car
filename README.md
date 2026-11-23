# Smart Car – Luxury Dark Companion App (Flutter Android & Raspberry Pi 5)

[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Raspberry%20Pi-blue.svg)](https://flutter.dev)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.22.0-02569B.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

A dark-mode companion app built with **Flutter** for Android (minSdk 26, targetSdk 34+) and a **Raspberry Pi 5** on-board car computer over Bluetooth Low Energy (BLE).

---

## 1. Overview & Design System

The application is styled with an ultra-luxury dark aesthetic (`#0B0C10` background, `#14161D` surface, `#1F222E` elevated surface, 8% white borders, and primary electric `#007AFF` / accent `#00D2FF` neon glow highlights):
- **Glassmorphism:** `GlassCard` with subtle borders and gradient fills; real `BackdropFilter` hardware blur is used selectively on at most 3 cards per screen for 60fps performance on mobile GPUs.
- **Micro-interactions:** Animated value transitions with 600ms `easeOutCubic`, 1.6s pulsing connection indicators, and multi-tier haptic feedback (light tap on user inputs, success medium impact on command confirmation, heavy impact on error/rejection).
- **Accessibility:** Automatically honors the system "Reduce Motion" setting, disabling continuous pulse animations and perspective transforms.
- **Typography:** Bundled **Inter** font with tabular figures enabled (`FontFeature.tabularFigures()`) to prevent digit jiggling on live telemetry gauges.

---

## 2. Architecture & Tech Stack

```
lib/
├── main.dart                       # Entry point, SharedPreferences injection, Theme setup
├── app/
│   ├── app_router.dart             # GoRouter with 3-tab StatefulShellRoute
│   └── app_shell.dart              # Persistent luxury BottomNavigationBar
├── core/
│   ├── theme/                      # AppColors, AppTypography, AppSpacing, AppTheme
│   ├── widgets/                    # GlassCard, PulsingDot, NeonButton, StatusRing
│   └── utils/                      # AppLogger, Formatters, Debouncer
├── data/
│   ├── models/                     # Telemetry, GpsFix, VehicleCommand, Vehicle, Enums, TpmsThresholds
│   ├── ble/                        # BleGattService, BleUuids, PacketFramer
│   ├── map/                        # MapProvider, CartoDarkMapProvider, MapServices (Nominatim, OSRM, Overpass)
│   └── repositories/               # VehicleRepository (interface), BleVehicleRepository, MockVehicleRepository
├── features/
│   ├── home/                       # HomeScreen, CarPainter, CommandHub, QuickActionGrid, BrandLogo
│   ├── dashboard/                  # DashboardScreen, FuelGauge, TpmsCard
│   ├── map/                        # MapScreen, CARTO dark tiles, route polyline, search bar, POI chips
│   ├── discovery/                  # DiscoveryModal (BLE scanning & device pairing)
│   ├── settings/                   # SettingsScreen (Mock toggles, scenarios, units, forget device)
│   ├── garage/                     # GarageScreen (local multi-vehicle profiles)
│   ├── digital_key/                # DigitalKeyScreen (STUB: key provisioning & NFC/UWB visualization)
│   └── permissions/                # PermissionScreen (Android 12+ Nearby Devices & Location pre-request)
└── providers/                      # Riverpod: vehicleRepositoryProvider, commandProvider, settingsProvider...
```

---

## 3. Screens

### 3.1 Home (`/home`)
- **Header:** Generic geometric brand logo (custom vector diamond, not BMW logo), vehicle name, mini progress fuel bar with exact liter capacity (`54 / 60 L`), BLE status pulsing dot / spinner / disconnect alert icon, and settings gear.
- **Hero:** Top-down car drawn with `CustomPainter` tilted in 3D with perspective `Matrix4` transformations.
- **Command Hub:** Glowing `StatusRing` displaying system alerts (green "All Set", amber "Warning", red "Critical"). Flanked by **Lock** and **Unlock** buttons that track actual telemetry lock state, show in-flight spinners, and revert with an error snackbar if not confirmed within 3 seconds.
- **2x2 Quick Action Grid:**
  - **Drive Mode:** Shows Comfort/Sport/Eco. Opens a bottom sheet to change mode with real-time feedback.
  - **Garage:** Switch or manage vehicle profiles.
  - **Digital Key:** Shows paired phone status.
  - **Car Location:** Re-centers and switches directly to the Map tab.
- **Disconnected State:** Shows a contextual warning banner with a quick "Reconnect" action.

### 3.2 Dashboard (`/dashboard`)
- **Header:** "Dashboard" + "Updated Xs ago" badge updating every second (green under 5s, amber 5–30s, red over 30s or when disconnected).
- **Fuel Semi-Circular Gauge:** 240° arc sweep gradient (`#007AFF` to `#00D2FF`) with neon end glow. Displays fuel volume in large tabular digits and range remaining. Arc shifts to amber below 15% and red below 8%.
- **Metric Cards:** Two-column grid featuring Oil Life with thin progress indicator and locale-formatted Odometer reading.
- **TPMS Card:** Top-down wireframe chassis with 4 tags connected to wheels (FL, FR, RL, RR) colored by configurable threshold constants (Normal: 30–42 psi, Low: 25–29.9 psi, Critical: <25 psi with soft pulse, High: >42 psi).
- **Pull-to-Refresh:** Dispatches an immediate `snapshot` telemetry request command.

### 3.3 Map (`/map`)
- Fullscreen `flutter_map` powered by CARTO "Dark Matter" tiles behind a modular `MapProvider` abstraction interface.
- **Live Car Marker:** Neon-blue glowing dot with heading arrow tracking live GPS notifications. Smooth movement animations.
- **Stale Marker Handling:** Greys out marker and presents "Last seen X min ago" chip if GPS is stale >30s or disconnected. Persists last known fix in `SharedPreferences`.
- **Phone Marker:** Displays phone location if permission is granted; hides gracefully without breaking the map if denied.
- **Glass Search Bar:** Nominatim geocoding with 500ms debounce, 1 req/sec rate limiting, and proper User-Agent header.
- **Route Overlay:** Queries OSRM public server to render neon polyline route with floating distance & duration chips.
- **Bottom Floating Chips:** "My Car" (re-center), "Parking", "Stations", "Chargers" (queries Overpass API with 5-minute memory caching).

### 3.4 Discovery Modal & Settings
- **Discovery Modal:** Bottom sheet displaying scanning animation, signal strength (RSSI), "Raspberry Pi 5" badges, connection state transitions (Connecting, Pairing, Ready, Failed), and "Use demo data" toggle.
- **Settings:** Toggle between BLE and Mock Mode, select any of the 6 simulated scenarios, configure units (PSI / bar / kPa, km / miles, L / gal), forget paired BLE peripheral, and view licenses.

---

## 4. Mock Scenarios

When Mock Mode is enabled, the app runs offline simulation with realistic drift (gradual fuel decrease, odometer increments, tire micro-wobble, and a GPS loop around Madrid). Six scenarios can be triggered via Settings:
1. **Normal:** Standard driving telemetry.
2. **Slow Tire Leak:** Rear-Right tire pressure drops to critical over 60 seconds, triggering LOW_TIRE alert.
3. **Low Fuel:** Initial fuel set to 4.5 L, triggering LOW_FUEL alert.
4. **Connection Drops:** Disconnects and reconnects every 20 seconds to exercise the auto-reconnect UI.
5. **Command Failure:** Injects a 3-second delay and returns timeout to test button revert logic.
6. **Stale Data:** Halts sensor emissions after 5 seconds to test the stale location chip and dashboard indicator.

---

## 5. Raspberry Pi 5 Server (`pi_server/`)

The companion BLE server runs on Python 3.11+ using BlueZ and `bless`:
- Advertises service `12345678-1234-5678-1234-56789abcdef0` with local name `RP5_CAR_DASHBOARD`.
- Transmits Telemetry (`...def1`) and GPS (`...def3`) at 1 Hz, framed by trailing `\n`.
- Enforces **LE Secure Connections** with `encrypt-authenticated-write` on Control (`...def2`).
- Replay attack defense: incoming commands must contain monotonically increasing `seq` integers (`seq > last_accepted_seq`).

See [`pi_server/README.md`](file:///C:/Users/Godwin/.gemini/antigravity/scratch/smart_car/pi_server/README.md) for installation, pairing, and systemd autostart steps.

---

## 6. Testing

The project includes unit and widget test suites covering:
- **Packet Framer:** Multi-chunk reassembly, buffer reset, newline parsing (`test/unit/packet_framer_test.dart`).
- **Telemetry Parser:** Range clamping (fuel, oil, TPMS), enum mapping, schema validation (`test/unit/telemetry_parser_test.dart`).
- **TPMS Thresholds:** Boundary conditions for normal, low, critical, high (`test/unit/tpms_threshold_test.dart`).
- **Mock Scenarios:** Verification of all 6 mock states (`test/unit/mock_scenario_test.dart`).
- **Command Formatting:** Sequence incrementing and trailing newline validation (`test/unit/command_test.dart`).
- **Widget Tests:** Gauge rendering, TPMS tag colors, lock button state and disconnect handling (`test/widget/`).

---

## 7. Known Limits (Important)

- **BLE Range:** Bluetooth LE range is typically ~10 meters. Away from the vehicle, map position and telemetry represent "last known" cached state.
- **Production Stubs:** Garage sync, Digital Key cryptographic sharing, OSRM routing, and Nominatim search rely on stubs or free public APIs. They must be replaced with commercial cloud services before production release. See [`docs/STUBS.md`](file:///C:/Users/Godwin/.gemini/antigravity/scratch/smart_car/docs/STUBS.md).
- **Public API Usage:** OpenStreetMap, CARTO, Nominatim, and OSRM have strict rate limits and fair-use policies.
- **Branding:** Do not publish with BMW trademarks, logos, or commercial vehicle branding.
