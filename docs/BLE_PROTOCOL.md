# BLE Protocol Specification – Smart Car

> **Version:** 1.0.0  
> **Target Devices:** Android 8.0+ (minSdk 26, targetSdk 34+) & Raspberry Pi 5 (BlueZ 5.65+)  
> **Security Requirement:** LE Secure Connections (AES-128 CCM, ECDH P-256)

---

## 1. GATT Architecture

All UUIDs are 128-bit custom identifiers with standard 16-bit offsets on base `12345678-1234-5678-1234-56789abcdef0`:

| Role | UUID | Properties | Permissions / Security |
|------|------|------------|------------------------|
| **Primary Service** | `12345678-1234-5678-1234-56789abcdef0` | — | None |
| **Telemetry** | `12345678-1234-5678-1234-56789abcdef1` | `Notify`, `Read` | `encrypt-read`, `encrypt-notify` |
| **Control** | `12345678-1234-5678-1234-56789abcdef2` | `Write` (with response) | `encrypt-authenticated-write` |
| **GPS Fix** | `12345678-1234-5678-1234-56789abcdef3` | `Notify`, `Read` | `encrypt-read`, `encrypt-notify` |

---

## 2. Advertising & Discovery

To comply with the 31-byte legacy BLE advertisement limit:
- **Advertising Packet (ADV_IND, 31 bytes max):**
  - Flags (3 bytes): `0x06` (LE General Discoverable Mode, BR/EDR Not Supported)
  - 128-bit Incomplete Service UUIDs: `12345678-1234-5678-1234-56789abcdef0` (18 bytes)
  - Total: 21 bytes (Fits safely under 31 bytes)
- **Scan Response Packet (SCAN_RSP, 31 bytes max):**
  - Complete Local Name: `RP5_CAR_DASHBOARD` (19 bytes)
  - Tx Power Level (optional, 3 bytes)

---

## 3. Framing & MTU Handling

1. **MTU Negotiation:**
   - After establishing physical connection, the Android client requests MTU **247 bytes**.
   - If negotiated MTU remains default (23 bytes, yielding 20-byte payload limit) or below 100 bytes, communication continues seamlessly via the line-framer.
2. **Newline Framing:**
   - Every transmitted message (Telemetry, GPS, and Control) is encoded in UTF-8 JSON and **strictly terminated with `\n`** (`0x0A`).
   - The receiver maintains an internal `PacketFramer` buffer per characteristic and only dispatches complete JSON strings when `\n` is encountered.

---

## 4. Message Formats & Schemas

### 4.1 Telemetry Notification (Pi → Phone, 1 Hz)
Typical size: ~165 bytes (under 180-byte budget).
```json
{
  "v": 1,
  "fuel": 54.2,
  "cap": 60.0,
  "range": 62,
  "oil": 83,
  "odo": 6721,
  "tpms": [37.2, 37.0, 29.1, 29.4],
  "locked": true,
  "mode": "COMFORT",
  "lights": false,
  "alert": "OK",
  "ts": 1731900000
}
```

#### Fields:
- `v`: Protocol version integer (`1`).
- `fuel`: Remaining fuel level in liters (`0.0` to `cap`).
- `cap`: Total tank capacity in liters.
- `range`: Estimated remaining driving range in km.
- `oil`: Oil life percentage integer (`0` to `100`).
- `odo`: Total odometer reading in kilometers.
- `tpms`: Array of 4 tire pressures in PSI: `[FL, FR, RL, RR]`. Range: `0.0` to `80.0`.
- `locked`: Boolean (`true` = vehicle secured, `false` = unlocked).
- `mode`: Drive mode string: `"COMFORT"`, `"SPORT"`, or `"ECO"`.
- `lights`: Boolean exterior headlight status.
- `alert`: Standardized alert code:
  - `"OK"`: System nominal ("All Set").
  - `"LOW_FUEL"`: Tank under 15% capacity.
  - `"LOW_TIRE"`: Any tire pressure under 25.0 PSI.
  - `"LOW_OIL"`: Oil life under 10%.
  - `"DOOR_OPEN"`: Door or trunk ajar.
  - `"CRITICAL"`: Multi-system fault or fuel < 8%.
- `ts`: Unix timestamp in seconds.

### 4.2 GPS Fix Notification (Pi → Phone, 1 Hz)
```json
{
  "v": 1,
  "lat": 40.4168,
  "lng": -3.7038,
  "speed": 0.0,
  "heading": 90.0,
  "ts": 1731900000
}
```

### 4.3 Control Commands (Phone → Pi, Write with Response)

All commands include a monotonically increasing integer `seq` to prevent replay attacks:

#### Door Lock / Unlock:
```json
{"v": 1, "seq": 42, "cmd": "lock", "val": true}
{"v": 1, "seq": 43, "cmd": "lock", "val": false}
```

#### Drive Mode Change:
```json
{"v": 1, "seq": 44, "cmd": "drive_mode", "val": "SPORT"}
```

#### Exterior Lights:
```json
{"v": 1, "seq": 45, "cmd": "lights", "val": true}
```

#### Telemetry Snapshot Request:
```json
{"v": 1, "seq": 46, "cmd": "snapshot"}
```

---

## 5. Security & Replay Attack Defense

1. **Replay Protection Rule:**
   - The phone persists `last_seq` in `SharedPreferences` across application restarts.
   - The Raspberry Pi server maintains `last_accepted_seq` in memory.
   - Any incoming packet with `seq <= last_accepted_seq` is immediately dropped and flagged in security logs.
2. **Authenticated Encryption:**
   - BlueZ requires `encrypt-authenticated-write` on the Control characteristic.
   - On initial connection, Android initiates the pairing workflow and displays a 6-digit numeric comparison or Passkey confirmation.
   - Non-bonded connections attempting writes will receive an `INSUFFICIENT_AUTHENTICATION` GATT error.

---

## 6. Pairing Walkthrough

### On the Raspberry Pi:
```bash
# 1. Start BlueZ agent
bluetoothctl
[bluetooth]# agent DisplayYesNo
[bluetooth]# default-agent
[bluetooth]# discoverable on

# 2. Run the server
sudo python3 /opt/smart_car/main.py
```

### On the Android Device:
1. Open the **Smart Car** app.
2. If first launch, grant Nearby Devices / Location permissions.
3. Tap the red BLE search icon or open **Discovery Modal**.
4. Tap **RP5_CAR_DASHBOARD**.
5. When the Android system prompt appears, verify the numeric passkey and tap **Pair**.
6. The connection status advances to **Ready** with a pulsing green indicator.
