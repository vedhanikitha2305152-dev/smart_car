# Project Stubs Documentation (`docs/STUBS.md`)

This document lists every intentional `// STUB:` and sensor stub in the codebase, explaining why it exists and what is required to replace it for production deployment.

---

## Flutter Application Stubs

| Location | Stub Description | Production Requirement |
|----------|------------------|------------------------|
| `lib/features/garage/garage_screen.dart` | Local profile storage via `SharedPreferences`. No cloud synchronization. | Connect to backend fleet/cloud database (e.g., Firebase, REST API, or AWS IoT Fleet Management). |
| `lib/features/digital_key/digital_key_screen.dart` | Digital Key sharing is disabled with "Coming Soon". | Implement CCC (Car Connectivity Consortium) Digital Key 3.0 specification over BLE/UWB with secure enclave ECDSA key derivation and Apple/Google Wallet integration. |
| `lib/features/home/widgets/quick_action_grid.dart` | Digital key tile triggers stub snackbar. | Wire into CCC Digital Key pairing exchange. |
| `lib/data/map/map_services.dart` | Nominatim public geocoding API with custom User-Agent. | Replace with commercial geocoding service (e.g. Mapbox Geocoding, Google Places API, or self-hosted Nominatim cluster). |
| `lib/data/map/map_services.dart` | Public OSRM routing server (`router.project-osrm.org`). | Replace with paid routing SLA (Mapbox Directions, Google Routes API, or dedicated OSRM server). |

---

## Raspberry Pi 5 Server Stubs (`pi_server/`)

| Location | Sensor Function | Hardware Production Implementation |
|----------|-----------------|-----------------------------------|
| `pi_server/telemetry_sim.py` | `read_fuel_liters()` | Query OBD-II PID 0x2F (Fuel Level Input) or vehicle CAN bus ID 0x316 via `python-can` or `python-obd`. |
| `pi_server/telemetry_sim.py` | `read_tpms_psi()` | Connect 433.92 MHz RTL-SDR receiver with `rtl_433` daemon to read direct wireless TPMS sensor telemetries. |
| `pi_server/telemetry_sim.py` | `read_gnss()` | Interface a NEO-M8N or LC29H GNSS module over `/dev/ttyAMA0` using `gpsd` and `python-gps`. |
| `pi_server/telemetry_sim.py` | `read_odometer_km()` | Query high-speed vehicle CAN instrument cluster PID. |
