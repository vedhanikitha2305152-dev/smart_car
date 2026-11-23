abstract final class BleUuids {
  // ESP32 "Natchathira" Services & Characteristics
  static const String navServiceUuid = 'f62998ce-95fe-4100-a864-f8d4c5f77b0c';
  static const String turnCharUuid   = '71aeedc3-695a-4764-a3fb-42f81ef34d72';

  static const String vehServiceUuid = '12ee7adc-bdb1-4de6-85de-a103e6a04ac4';
  static const String fuelCharUuid   = '2e3a6f52-bfed-40a3-8a29-f15bebdc8323';
  static const String battCharUuid   = '8b983343-a61e-4aaa-846f-9adaef8c6f71';

  static const String deviceName = 'Natchathira';

  // Raspberry Pi / Legacy fallbacks
  static const String serviceUuid = vehServiceUuid;
  static const String telemetryUuid = fuelCharUuid;
  static const String controlUuid = turnCharUuid;
  static const String gpsUuid = '12345678-1234-5678-1234-56789abcdef3';
}
