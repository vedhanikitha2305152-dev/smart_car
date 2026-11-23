"""
Vehicle Telemetry & GNSS Simulation with plug-in sensor interfaces.
Target packet size for telemetry: under 180 bytes.
"""

import random
import time
from typing import List, Tuple, Dict, Any


class TelemetrySim:
    def __init__(self):
        self.fuel: float = 54.2
        self.capacity: float = 60.0
        self.range_km: int = 62
        self.oil_life: int = 83
        self.odometer: int = 6721
        # [FL, FR, RL, RR] in PSI
        self.tpms: List[float] = [37.2, 37.0, 29.1, 29.4]
        self.locked: bool = True
        self.drive_mode: str = "COMFORT"
        self.lights_on: bool = False
        self.alert_code: str = "OK"

        # Coordinates for simulated loop (Madrid Gran Vía loop)
        self._gps_loop: List[Tuple[float, float]] = [
            (40.4168, -3.7038),
            (40.4178, -3.7020),
            (40.4190, -3.7010),
            (40.4185, -3.7025),
            (40.4170, -3.7045),
        ]
        self._gps_index: int = 0
        self.lat: float = 40.4168
        self.lng: float = -3.7038
        self.speed: float = 0.0
        self.heading: float = 90.0

    # -------------------------------------------------------------------------
    # Real Hardware Sensor Extension Points
    # -------------------------------------------------------------------------
    def read_fuel_liters(self) -> float:
        """
        STUB: Plug in OBD-II PID 0x2F (Fuel Tank Level Input) via python-obd or CAN bus.
        Example:
            response = obd_connection.query(obd.commands.FUEL_LEVEL)
            return (response.value.magnitude / 100.0) * self.capacity
        """
        return self.fuel

    def read_tpms_psi(self) -> List[float]:
        """
        STUB: Plug in 433MHz RTL-SDR TPMS receiver or direct CAN TPMS sensor bus.
        Expected order: [Front-Left, Front-Right, Rear-Left, Rear-Right]
        """
        return self.tpms

    def read_gnss(self) -> Tuple[float, float, float, float]:
        """
        STUB: Plug in USB/UART GNSS module via gpsd (python-gps) or NMEA serial stream.
        Returns: (lat, lng, speed_kmh, heading_degrees)
        """
        return self.lat, self.lng, self.speed, self.heading

    def read_odometer_km(self) -> int:
        """
        STUB: Read vehicle total distance from OBD-II / CAN instrument cluster.
        """
        return self.odometer

    # -------------------------------------------------------------------------
    # Simulation Advance (Called at 1 Hz)
    # -------------------------------------------------------------------------
    def tick(self) -> None:
        """Simulate realistic continuous sensor drift."""
        # 1. Fuel slowly decreases
        self.fuel = max(0.0, self.fuel - 0.002)
        self.range_km = int(self.fuel * 10)

        # 2. Odometer slowly increments
        self.odometer += 1

        # 3. TPMS random micro-wobble (±0.1 psi)
        self.tpms = [
            round(max(0.0, min(80.0, p + random.uniform(-0.1, 0.1))), 1)
            for p in self.tpms
        ]

        # 4. GPS waypoint progression along loop
        self._gps_index = (self._gps_index + 1) % len(self._gps_loop)
        base_lat, base_lng = self._gps_loop[self._gps_index]
        self.lat = round(base_lat + random.uniform(-0.00005, 0.00005), 6)
        self.lng = round(base_lng + random.uniform(-0.00005, 0.00005), 6)
        self.heading = round((self.heading + 5.0) % 360.0, 1)

        # 5. Alert code derivation
        fuel_ratio = self.fuel / self.capacity
        if fuel_ratio < 0.08:
            self.alert_code = "CRITICAL"
        elif fuel_ratio < 0.15:
            self.alert_code = "LOW_FUEL"
        elif any(p < 25.0 for p in self.tpms):
            self.alert_code = "LOW_TIRE"
        else:
            self.alert_code = "OK"

    # -------------------------------------------------------------------------
    # JSON Dictionaries matching BLE Protocol Spec
    # -------------------------------------------------------------------------
    def telemetry_dict(self) -> Dict[str, Any]:
        """
        Target under 180 bytes:
        {"v":1,"fuel":54.2,"cap":60,"range":62,"oil":83,"odo":6721,
         "tpms":[37.2,37.0,29.1,29.4],"locked":true,"mode":"COMFORT",
         "lights":false,"alert":"OK","ts":1731900000}
        """
        return {
            "v": 1,
            "fuel": round(self.read_fuel_liters(), 1),
            "cap": round(self.capacity, 0),
            "range": self.range_km,
            "oil": self.oil_life,
            "odo": self.read_odometer_km(),
            "tpms": self.read_tpms_psi(),
            "locked": self.locked,
            "mode": self.drive_mode,
            "lights": self.lights_on,
            "alert": self.alert_code,
            "ts": int(time.time()),
        }

    def gps_dict(self) -> Dict[str, Any]:
        """
        {"v":1,"lat":40.4168,"lng":-3.7038,"speed":0,"heading":90,"ts":1731900000}
        """
        lat, lng, spd, hdg = self.read_gnss()
        return {
            "v": 1,
            "lat": lat,
            "lng": lng,
            "speed": round(spd, 1),
            "heading": round(hdg, 1),
            "ts": int(time.time()),
        }
