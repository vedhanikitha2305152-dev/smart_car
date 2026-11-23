// STUB: Digital Key sharing — not implemented (cloud key exchange required for production)
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';

class DigitalKeyScreen extends StatelessWidget {
  const DigitalKeyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Digital Key', style: AppTypography.title.copyWith(fontSize: 20)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Visual Key Card representation
              GlassCard(
                useRealBlur: true,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.nfc, color: AppColors.accent, size: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: const Text(
                            'PAIRED',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Text(
                      'SMART PASS KEY',
                      style: AppTypography.label.copyWith(letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pixel 8 Pro • Owner',
                      style: AppTypography.title.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Passive Entry • Walk-Away Lock Active',
                      style: AppTypography.label.copyWith(color: AppColors.textDisabled, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              Text(
                'KEY MANAGEMENT',
                style: AppTypography.label.copyWith(color: AppColors.accent, letterSpacing: 1.0),
              ),
              const SizedBox(height: AppSpacing.sm),
              GlassCard(
                useRealBlur: false,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.share_outlined, color: AppColors.textDisabled),
                      title: Text(
                        'Share Digital Key',
                        style: AppTypography.body.copyWith(color: AppColors.textDisabled),
                      ),
                      subtitle: const Text(
                        '// STUB: Cloud provisioning & cryptographic sharing coming soon',
                        style: TextStyle(color: AppColors.textDisabled, fontSize: 11),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Coming Soon', style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              NeonButton(
                label: 'Test Passive Handshake',
                icon: Icons.bluetooth_connected,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.surfaceHigh,
                      content: Text('BLE Passive handshake verified: signal -52 dBm'),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
