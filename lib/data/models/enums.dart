enum DriveMode { comfort, sport, eco }

enum AlertCode { ok, lowFuel, lowTire, lowOil, doorOpen, critical }

enum ConnectionStatus {
  bluetoothOff,
  permissionDenied,
  idle,
  scanning,
  connecting,
  discoveringServices,
  negotiating,
  bonding,
  ready,
  reconnecting,
  failed,
}

enum MockScenario {
  normal,
  slowTireLeak,
  lowFuel,
  connectionDrops,
  commandFailure,
  staleData,
}

enum DistanceUnit { km, miles }

enum FuelUnit { liters, gallons }
