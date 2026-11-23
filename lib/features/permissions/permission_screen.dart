import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/neon_button.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key, required this.onPermissionsGranted});

  final VoidCallback onPermissionsGranted;

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final _log = AppLogger.get('PermissionScreen');
  bool _isRequesting = false;

  Future<void> _checkAndRequestPermissions() async {
    setState(() => _isRequesting = true);
    HapticFeedback.lightImpact();

    final permissionsToRequest = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    final statuses = await permissionsToRequest.request();
    final allGranted = statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );

    if (allGranted) {
      _log.info('All permissions granted by user');
      HapticFeedback.mediumImpact();
      widget.onPermissionsGranted();
    } else {
      final permanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
      if (permanentlyDenied && mounted) {
        _log.warning('Permissions permanently denied. Prompting for settings.');
        _showSettingsDialog();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceHigh,
            content: Text(
              'Bluetooth and Location permissions are required to connect to your vehicle.',
              style: TextStyle(color: AppColors.warning),
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isRequesting = false);
    }
  }

  void _showSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Permissions Required',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Bluetooth and Location access are permanently denied. Please allow them in your Android App Settings to communicate with the vehicle computer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.bluetooth_searching,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Vehicle Connection Access',
                style: AppTypography.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Smart Car establishes a high-security encrypted BLE link with your Raspberry Pi car computer to transmit telemetry, diagnostics, and secure control commands.',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  children: [
                    _PermissionInfoRow(
                      icon: Icons.bluetooth,
                      title: 'Nearby Devices (Android 12+)',
                      subtitle: 'Direct communication with the BLE peripheral',
                    ),
                    Divider(color: AppColors.border, height: 16),
                    _PermissionInfoRow(
                      icon: Icons.location_on_outlined,
                      title: 'Location (Android 11 & below)',
                      subtitle: 'Required by Android OS for BLE discovery',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              NeonButton(
                label: 'Grant Access & Continue',
                icon: Icons.security,
                isLoading: _isRequesting,
                onTap: _checkAndRequestPermissions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionInfoRow extends StatelessWidget {
  const _PermissionInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 24),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.label.copyWith(
                  color: AppColors.textDisabled,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
