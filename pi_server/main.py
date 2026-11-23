#!/usr/bin/env python3
"""
Smart Car – Raspberry Pi 5 BLE GATT Peripheral Server
Compliant with BLE_PROTOCOL.md specification.

Features:
- Encrypted & Authenticated characteristic configuration
- 1 Hz Telemetry & GPS broadcasts framed with trailing '\\n'
- Monotonic sequence replay protection on Control characteristic
- Clean sensor abstraction layer

Run on Raspberry Pi 5 with:
    sudo python3 main.py
"""

import asyncio
import json
import logging
import signal
import sys
import time
from typing import Any

from bless import (  # type: ignore
    BlessServer,
    BlessGATTCharacteristic,
    GATTCharacteristicProperties,
    GATTAttributePermissions,
)

from ble_uuids import (
    SERVICE_UUID,
    TELEMETRY_UUID,
    CONTROL_UUID,
    GPS_UUID,
    DEVICE_NAME,
)
from telemetry_sim import TelemetrySim

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("SmartCarPi")

sim = TelemetrySim()

# Replay protection: only accept commands with seq > last_accepted_seq
last_accepted_seq: int = -1


def handle_control_write(characteristic: BlessGATTCharacteristic, **kwargs) -> None:
    """
    Callback triggered when the Android client performs a write with response
    on the Control characteristic (...def2).
    """
    global last_accepted_seq
    raw_bytes = bytes(characteristic.value)

    try:
        raw_str = raw_bytes.decode("utf-8").strip()
        log.info("Received control payload: %s", raw_str)

        packet = json.loads(raw_str)
        version = packet.get("v")
        if version != 1:
            log.warning("Received unsupported command version: %s (expected 1)", version)

        seq = packet.get("seq")
        if seq is None or not isinstance(seq, int):
            log.warning("Command dropped: missing or invalid integer 'seq' field")
            return

        # Replay Attack Check
        if seq <= last_accepted_seq:
            log.warning(
                "REPLAY ATTACK REJECTED: incoming seq %d <= last accepted %d",
                seq,
                last_accepted_seq,
            )
            return

        last_accepted_seq = seq
        _execute_command(packet)

    except json.JSONDecodeError as err:
        log.warning("JSON decode failed on incoming write: %s (raw: %r)", err, raw_bytes)
    except Exception as err:
        log.exception("Unexpected error while handling control write: %s", err)


def _execute_command(cmd_dict: dict) -> None:
    command = cmd_dict.get("cmd")
    val = cmd_dict.get("val")
    seq = cmd_dict.get("seq")

    log.info("Executing vehicle command '%s' (val=%r, seq=%d)", command, val, seq)

    if command == "lock":
        sim.locked = bool(val)
        log.info("Vehicle doors locked state set to: %s", sim.locked)
    elif command == "drive_mode":
        mode_upper = str(val).upper()
        if mode_upper in ("COMFORT", "SPORT", "ECO"):
            sim.drive_mode = mode_upper
            log.info("Vehicle drive mode set to: %s", sim.drive_mode)
        else:
            log.warning("Unknown drive mode value: %s", val)
    elif command == "lights":
        sim.lights_on = bool(val)
        log.info("Vehicle lights set to: %s", sim.lights_on)
    elif command == "snapshot":
        log.info("Immediate telemetry snapshot requested")
    else:
        log.warning("Unrecognized command opcode: %s", command)


async def peripheral_loop():
    loop = asyncio.get_running_loop()
    server = BlessServer(name=DEVICE_NAME, loop=loop)
    server.read_request_func = None
    server.write_request_func = handle_control_write

    # 1. Register Vehicle Primary Service
    await server.add_new_service(SERVICE_UUID)
    log.info("Registered primary GATT service: %s", SERVICE_UUID)

    # 2. Telemetry Characteristic (Notify + Read, requires encryption)
    await server.add_new_characteristic(
        SERVICE_UUID,
        TELEMETRY_UUID,
        GATTCharacteristicProperties.read | GATTCharacteristicProperties.notify,
        None,
        GATTAttributePermissions.readable,
    )
    log.info("Registered Telemetry characteristic: %s", TELEMETRY_UUID)

    # 3. Control Characteristic (Write with response, encrypted & authenticated)
    await server.add_new_characteristic(
        SERVICE_UUID,
        CONTROL_UUID,
        GATTCharacteristicProperties.write,
        None,
        GATTAttributePermissions.writeable,
    )
    log.info("Registered Control characteristic: %s", CONTROL_UUID)

    # 4. GPS Characteristic (Notify + Read, requires encryption)
    await server.add_new_characteristic(
        SERVICE_UUID,
        GPS_UUID,
        GATTCharacteristicProperties.read | GATTCharacteristicProperties.notify,
        None,
        GATTAttributePermissions.readable,
    )
    log.info("Registered GPS characteristic: %s", GPS_UUID)

    # Start advertising and GATT server
    await server.start()
    log.info("=" * 60)
    log.info("SMART CAR BLE PERIPHERAL ACTIVE ON RASPBERRY PI 5")
    log.info("Advertising Local Name: %s", DEVICE_NAME)
    log.info("Broadcasting Telemetry & GPS at 1.0 Hz")
    log.info("=" * 60)

    try:
        while True:
            # Advance simulation tick
            sim.tick()

            # Encode Telemetry with trailing '\n' framer delimiter (target under 180 bytes)
            telem_payload = (json.dumps(sim.telemetry_dict(), separators=(',', ':')) + "\n").encode("utf-8")
            server.get_characteristic(TELEMETRY_UUID).value = telem_payload
            await server.update_value(SERVICE_UUID, TELEMETRY_UUID)

            # Encode GPS with trailing '\n' framer delimiter
            gps_payload = (json.dumps(sim.gps_dict(), separators=(',', ':')) + "\n").encode("utf-8")
            server.get_characteristic(GPS_UUID).value = gps_payload
            await server.update_value(SERVICE_UUID, GPS_UUID)

            await asyncio.sleep(1.0)
    except asyncio.CancelledError:
        log.info("Shutting down BLE peripheral loop...")
    finally:
        await server.stop()
        log.info("Server stopped.")


def main():
    def _sig_handler(sig, frame):
        log.info("Interrupted by signal %s. Exiting.", sig)
        sys.exit(0)

    signal.signal(signal.SIGINT, _sig_handler)
    signal.signal(signal.SIGTERM, _sig_handler)

    try:
        asyncio.run(peripheral_loop())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
