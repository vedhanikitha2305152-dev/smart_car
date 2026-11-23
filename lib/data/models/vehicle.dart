class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    this.bleDeviceId,
    this.imageAsset,
    this.tankCapacity = 60,
  });

  final String id;
  final String name;
  final String? bleDeviceId;
  final String? imageAsset;
  final double tankCapacity;

  Vehicle copyWith({
    String? id,
    String? name,
    String? bleDeviceId,
    String? imageAsset,
    double? tankCapacity,
  }) =>
      Vehicle(
        id: id ?? this.id,
        name: name ?? this.name,
        bleDeviceId: bleDeviceId ?? this.bleDeviceId,
        imageAsset: imageAsset ?? this.imageAsset,
        tankCapacity: tankCapacity ?? this.tankCapacity,
      );

  static const defaultVehicle = Vehicle(
    id: 'default',
    name: 'BMW M Sport',
    tankCapacity: 60,
  );
}
