import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/ble/ble_uuids.dart';
import '../../providers/repository_provider.dart';

class DiscoveryModal extends ConsumerStatefulWidget {
  const DiscoveryModal({super.key});

  @override
  ConsumerState<DiscoveryModal> createState() => _DiscoveryModalState();
}

class _DiscoveryModalState extends ConsumerState<DiscoveryModal> {
  bool _isScanning = false;
  List<ScanResult> _devices = [];
  String? _connectingDeviceId;
  String? _connectionError;
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    final isMock = ref.read(mockModeProvider);
    if (isMock) {
      // In mock mode, supply realistic mock devices
      setState(() {
        _isScanning = true;
        _connectionError = null;
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        setState(() => _isScanning = false);
      }
      return;
    }

    setState(() {
      _isScanning = true;
      _devices = [];
      _connectionError = null;
    });

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) {
        setState(() {
          _devices = results;
        });
      }
    });

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionError = 'Bluetooth scan error: $e';
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _connectDevice(String deviceId, String name) async {
    HapticFeedback.lightImpact();
    setState(() {
      _connectingDeviceId = deviceId;
      _connectionError = null;
    });

    final isMock = ref.read(mockModeProvider);
    if (isMock) {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        ref.read(vehicleRepositoryProvider).connect();
        Navigator.pop(context);
      }
      return;
    }

    try {
      final device = BluetoothDevice.fromId(deviceId);
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 12));
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString('saved_ble_device_id', deviceId);

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _connectingDeviceId = null;
          _connectionError = 'Connection failed: peripheral was unreachable or pairing was rejected.';
        });
      }
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMock = ref.watch(mockModeProvider);

    return Container(
      height: 520,
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title & Scan status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BLUETOOTH DISCOVERY', style: AppTypography.title.copyWith(fontSize: 18)),
              if (_isScanning)
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
                    const SizedBox(width: 8),
                    Text('Scanning...', style: AppTypography.label.copyWith(color: AppColors.accent)),
                  ],
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.accent),
                  onPressed: _startScan,
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          Text(
            'Searching for BLE vehicle peripheral (${BleUuids.deviceName}).',
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),

          const SizedBox(height: AppSpacing.md),

          // Error Banner
          if (_connectionError != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadiusSmall),
                border: Border.all(color: AppColors.danger),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionError!,
                      style: AppTypography.body.copyWith(fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: _startScan,
                    child: const Text('Retry', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),

          // Device List
          Expanded(
            child: isMock
                ? _buildMockDeviceList()
                : (_devices.isEmpty && !_isScanning
                    ? const Center(
                        child: Text(
                          'No BLE vehicle peripherals found nearby.\nEnsure your ESP32 is powered on and advertising.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textDisabled),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _devices.length,
                        separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                        itemBuilder: (ctx, i) {
                          final result = _devices[i];
                          final name = result.device.advName.isNotEmpty
                              ? result.device.advName
                              : (result.advertisementData.advName.isNotEmpty
                                  ? result.advertisementData.advName
                                  : 'Unnamed Peripheral');
                          final devLower = name.toLowerCase();
                          final isPi5 = devLower.contains(BleUuids.deviceName.toLowerCase()) ||
                              devLower.contains('dash') ||
                              result.advertisementData.serviceUuids.any((u) {
                                final s = u.toString().toLowerCase();
                                return s == BleUuids.vehServiceUuid.toLowerCase() ||
                                    s == BleUuids.navServiceUuid.toLowerCase();
                              });
                          final id = result.device.remoteId.str;
                          final isConnecting = _connectingDeviceId == id;

                          return _DeviceListTile(
                            name: name,
                            id: id,
                            rssi: result.rssi,
                            isPi5: isPi5,
                            isConnecting: isConnecting,
                            onTap: () => _connectDevice(id, name),
                          );
                        },
                      )),
          ),

          const Divider(color: AppColors.border),

          // Use Demo Data Toggle at bottom
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Use Demo Data (Mock Mode)', style: AppTypography.body.copyWith(fontSize: 14)),
                  Text(
                    'Simulate telemetry, drift, GPS & scenarios',
                    style: AppTypography.label.copyWith(color: AppColors.textDisabled),
                  ),
                ],
              ),
              Switch(
                value: isMock,
                activeColor: AppColors.accent,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  ref.read(mockModeProvider.notifier).state = val;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMockDeviceList() {
    return ListView(
      children: [
        _DeviceListTile(
          name: 'RP5_CAR_DASHBOARD',
          id: 'DC:A6:32:B1:44:88',
          rssi: -54,
          isPi5: true,
          isConnecting: _connectingDeviceId == 'mock_pi5',
          onTap: () => _connectDevice('mock_pi5', 'RP5_CAR_DASHBOARD'),
        ),
        _DeviceListTile(
          name: 'Generic OBDII BLE',
          id: '00:1B:44:11:3A:B7',
          rssi: -78,
          isPi5: false,
          isConnecting: false,
          onTap: () {},
        ),
      ],
    );
  }
}

class _DeviceListTile extends StatelessWidget {
  const _DeviceListTile({
    required this.name,
    required this.id,
    required this.rssi,
    required this.isPi5,
    required this.isConnecting,
    required this.onTap,
  });

  final String name;
  final String id;
  final int rssi;
  final bool isPi5;
  final bool isConnecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: isConnecting ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(
        isPi5 ? Icons.directions_car : Icons.bluetooth,
        color: isPi5 ? AppColors.accent : AppColors.textSecondary,
        size: 26,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isPi5)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.primary),
              ),
              child: const Text(
                'Raspberry Pi 5',
                style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Text(id, style: AppTypography.label.copyWith(fontSize: 10, color: AppColors.textDisabled)),
          const SizedBox(width: 8),
          Text('$rssi dBm', style: AppTypography.label.copyWith(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
      trailing: isConnecting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            )
          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
    );
  }
}
