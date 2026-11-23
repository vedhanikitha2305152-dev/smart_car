# Raspberry Pi 5 BLE Peripheral Companion Server

This directory contains the Python BLE peripheral service running on a Raspberry Pi 5 (or Pi 4 with BLE support) using BlueZ. It broadcasts vehicle telemetry and GPS data at 1 Hz and handles secure vehicle commands with replay attack protection.

---

## 1. Prerequisites & Installation

### System Packages (Debian / Raspberry Pi OS Bookworm)
```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-dbus bluetooth bluez libglib2.0-dev
```

### Python Dependencies
```bash
pip3 install -r requirements.txt --break-system-packages
```

---

## 2. BlueZ Pairing & Security Configuration

The Smart Car specification requires:
- **LE Secure Connections** (AES-CCM encryption with ECDH pairing)
- **Control Characteristic:** `encrypt-authenticated-write` (requires bonding and PIN/Numeric comparison)
- **Telemetry & GPS:** `encrypt-read` and `encrypt-notify`

### Configure BlueZ for LE Secure Connections:
Edit `/etc/bluetooth/main.conf`:
```ini
[General]
Name = RP5_CAR_DASHBOARD
Class = 0x000100
DiscoverableTimeout = 0

[Policy]
AutoEnable = true

[LE]
MinConnectionInterval = 6
MaxConnectionInterval = 12
ConnectionLatency = 0
ConnectionSupervisionTimeout = 42
```

Restart the Bluetooth service:
```bash
sudo systemctl restart bluetooth
sudo hciconfig hci0 up
```

### Initial Pairing from Android:
1. Start the server manually:
   ```bash
   sudo python3 main.py
   ```
2. In another terminal, ensure the BlueZ agent is running:
   ```bash
   bluetoothctl
   [bluetooth]# agent DisplayYesNo
   [bluetooth]# default-agent
   [bluetooth]# discoverable on
   ```
3. Open the **Smart Car** app on Android → tap the red Bluetooth icon.
4. Select **RP5_CAR_DASHBOARD** (or "Raspberry Pi 5").
5. The Android pairing dialog will pop up. Confirm pairing on both the Android phone and the Pi terminal.
6. The long-term key (LTK) is stored in `/var/lib/bluetooth/[PI_MAC]/[PHONE_MAC]/info`. Subsequent connections connect instantly without user prompts.

---

## 3. Running & Autostart via systemd

### Deploy to `/opt/smart_car`:
```bash
sudo mkdir -p /opt/smart_car
sudo cp *.py /opt/smart_car/
sudo cp requirements.txt /opt/smart_car/
sudo cp smart_car.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable smart_car.service
sudo systemctl start smart_car.service
```

### Monitor Live Logs:
```bash
sudo journalctl -u smart_car.service -f
```

---

## 4. Plugging In Real Vehicle Sensors

All simulated data in `telemetry_sim.py` has dedicated sensor plug-in hooks:

| Sensor Hook | Protocol / Library | Typical Hardware |
|-------------|---------------------|------------------|
| `read_fuel_liters()` | OBD-II (`python-obd`) / CAN (`python-can`) | ELM327 USB/Bluetooth or MCP2515 CAN HAT |
| `read_tpms_psi()` | 433 MHz FSK (`rtl_433` via subprocess) | RTL-SDR USB Dongle listening to tire sensors |
| `read_gnss()` | NMEA 0183 (`gpsd` / `pyserial`) | Waveshare NEO-M8N GNSS HAT |
| `read_odometer_km()` | OBD-II PID 0xA6 / CAN Broadcast | High-speed vehicle CAN bus |

Example for OBD-II in `telemetry_sim.py`:
```python
import obd

connection = obd.OBD()  # auto-connects to USB/serial ELM327

def read_fuel_liters(self) -> float:
    cmd = obd.commands.FUEL_LEVEL  # PID 0x2F
    response = connection.query(cmd)
    if response and not response.is_null():
        return (response.value.magnitude / 100.0) * self.capacity
    return self.fuel
```
