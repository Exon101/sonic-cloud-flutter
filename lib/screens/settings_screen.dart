import 'package:flutter/material.dart';
import '../accessibility/accessibility_service.dart';
import '../api/local_api_service.dart';
import '../models/models.dart';
import '../security/security_service.dart';
import '../services/app_settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/glass_card.dart';
import '../widgets/top_app_bar.dart';

/// Settings screen — v3.2 wired to AppSettingsService + SecurityService +
/// AccessibilityService + LocalApiService.
class SettingsScreen extends StatefulWidget {
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenCloud;
  final AppSettingsService settings;
  final SecurityService security;
  final AccessibilityService accessibility;
  final LocalApiService api;

  const SettingsScreen({
    super.key,
    required this.onOpenLibrary,
    required this.onOpenPlayer,
    required this.onOpenCloud,
    required this.settings,
    required this.security,
    required this.accessibility,
    required this.api,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _apiRunning = false;

  @override
  void initState() {
    super.initState();
    _checkApiStatus();
  }

  Future<void> _checkApiStatus() async {
    // The API service doesn't expose a running flag; track it locally
  }

  Future<void> _toggleApi() async {
    if (_apiRunning) {
      await widget.api.stop();
      setState(() => _apiRunning = false);
    } else {
      try {
        await widget.api.start();
        setState(() => _apiRunning = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to start API: $e')));
        }
      }
    }
  }

  Future<void> _toggleBiometric() async {
    final enabled = await widget.security.isBiometricEnabled;
    if (!enabled) {
      final canCheck = await widget.security.canCheckBiometrics;
      if (!canCheck) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometrics not available on this device.'),
            ),
          );
        }
        return;
      }
    }
    await widget.security.setBiometricEnabled(!enabled);
  }

  Future<void> _setPin() async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set App PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: const InputDecoration(hintText: 'Enter 4-8 digit PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (pin != null && pin.length >= 4) {
      await widget.security.setPin(pin);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN set successfully.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SonicTopAppBar(avatarUrl: ''),
      body: SafeArea(
        minimum: const EdgeInsets.only(top: 16),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.settings,
            widget.accessibility,
            widget.security,
          ]),
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.edgeMargin,
                8,
                AppSpacing.edgeMargin,
                120,
              ),
              children: [
                Text(
                  'Settings',
                  style: AppTypography.headlineXl.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Profile
                _ProfileCard(
                  user: const UserAccount(
                    id: 'local',
                    email: 'Not signed in',
                    name: 'Guest User',
                    tier: 'Local Mode',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Appearance ──────────────────────────────────────────────
                _GroupHeader('Appearance'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ThemeModeTile(settings: widget.settings),
                      _AccentColorTile(settings: widget.settings),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Accessibility ───────────────────────────────────────────
                _GroupHeader('Accessibility'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          'High Contrast',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Boost text contrast',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        value: widget.accessibility.highContrast,
                        onChanged: (v) =>
                            widget.accessibility.setHighContrast(v),
                        activeColor: AppColors.secondaryContainer,
                      ),
                      _FontScaleTile(accessibility: widget.accessibility),
                      SwitchListTile(
                        title: Text(
                          'Reduced Motion',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Disable animations',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        value: widget.accessibility.reducedMotion,
                        onChanged: (v) =>
                            widget.accessibility.setReducedMotion(v),
                        activeColor: AppColors.secondaryContainer,
                      ),
                      SwitchListTile(
                        title: Text(
                          'Large Touch Targets',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '44px → 56px minimum',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        value: widget.accessibility.largeTouchTargets,
                        onChanged: (v) =>
                            widget.accessibility.setLargeTouchTargets(v),
                        activeColor: AppColors.secondaryContainer,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Security ────────────────────────────────────────────────
                _GroupHeader('Security'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.lock_outline,
                          color: AppColors.onSurfaceVariant,
                        ),
                        title: Text(
                          'Set PIN',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Require PIN to open app',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.onSurfaceVariant,
                        ),
                        onTap: _setPin,
                      ),
                      FutureBuilder<bool>(
                        future: widget.security.isBiometricEnabled,
                        builder: (context, snapshot) {
                          return SwitchListTile(
                            title: Text(
                              'Biometric Unlock',
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              'Use fingerprint / face ID',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            value: snapshot.data ?? false,
                            onChanged: (_) => _toggleBiometric(),
                            activeColor: AppColors.secondaryContainer,
                          );
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          'Offline Only Mode',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Disable all network calls',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        value: widget.settings.offlineOnlyMode,
                        onChanged: (v) => widget.settings.setOfflineOnlyMode(v),
                        activeColor: AppColors.secondaryContainer,
                      ),
                      SwitchListTile(
                        title: Text(
                          'End-to-End Encryption',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Encrypt synced data (planned)',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        value: widget.settings.endToEndEncryptionEnabled,
                        onChanged: (v) =>
                            widget.settings.setEndToEndEncryptionEnabled(v),
                        activeColor: AppColors.secondaryContainer,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Developer ───────────────────────────────────────────────
                _GroupHeader('Developer'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(
                          'Local REST API',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Port 8765 — control playback via HTTP',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        value: _apiRunning,
                        onChanged: (_) => _toggleApi(),
                        activeColor: AppColors.secondaryContainer,
                      ),
                      SwitchListTile(
                        title: Text(
                          'Telemetry',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Send anonymous usage data',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        value: widget.settings.telemetryEnabled,
                        onChanged: (v) =>
                            widget.settings.setTelemetryEnabled(v),
                        activeColor: AppColors.secondaryContainer,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Connections (placeholder) ───────────────────────────────
                _GroupHeader('Connections'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      Icons.cloud_sync,
                      color: AppColors.onSurfaceVariant,
                    ),
                    title: Text(
                      'Cloud Accounts',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Link or unlink external drives',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                    ),
                    onTap: widget.onOpenCloud,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Log out
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Log out not implemented (no auth backend).',
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.AppRadius.lg),
                    ),
                  ),
                  child: Text(
                    'Log Out',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SonicBottomNavBar(
        currentIndex: 3,
        onTap: (i) {
          if (i == 0) widget.onOpenLibrary();
          if (i == 1) widget.onOpenPlayer();
          if (i == 2) widget.onOpenCloud();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String text;
  const _GroupHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserAccount user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              image: DecorationImage(
                image: NetworkImage(user.avatarUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: AppTypography.headlineMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  user.tier,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Profile editing requires an account. Connect a cloud provider first.')),
              );
            },
            icon: const Icon(
              Icons.edit_rounded,
              color: AppColors.secondaryContainer,
            ),
            tooltip: 'Edit profile',
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final AppSettingsService settings;
  const _ThemeModeTile({required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette, color: AppColors.onSurfaceVariant),
      title: Text(
        'Theme',
        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
      ),
      trailing: DropdownButton<ThemeModePreference>(
        value: settings.themeMode,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(
            value: ThemeModePreference.system,
            child: Text('System'),
          ),
          DropdownMenuItem(
            value: ThemeModePreference.dark,
            child: Text('Dark'),
          ),
          DropdownMenuItem(
            value: ThemeModePreference.light,
            child: Text('Light'),
          ),
          DropdownMenuItem(
            value: ThemeModePreference.amoled,
            child: Text('AMOLED'),
          ),
          DropdownMenuItem(
            value: ThemeModePreference.dynamic,
            child: Text('Dynamic'),
          ),
        ],
        onChanged: (v) {
          if (v != null) settings.setThemeMode(v);
        },
      ),
    );
  }
}

class _AccentColorTile extends StatelessWidget {
  final AppSettingsService settings;
  const _AccentColorTile({required this.settings});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = [
      const Color(0xFF00F4FE), // Sonic cyan (default)
      const Color(0xFF7F66FF), // Electric violet
      const Color(0xFFFF6B6B), // Red
      const Color(0xFF4ECDC4), // Teal
      const Color(0xFFFFE66D), // Yellow
      const Color(0xFF95E1D3), // Mint
    ];
    return ListTile(
      leading: const Icon(Icons.color_lens, color: AppColors.onSurfaceVariant),
      title: Text(
        'Accent Color',
        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
      ),
      trailing: SizedBox(
        width: 180, // Constrain to prevent overflow on narrow screens
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: colors.map((c) {
            final selected = settings.accentColor == c;
            return GestureDetector(
              onTap: () => settings.setAccentColor(c),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FontScaleTile extends StatelessWidget {
  final AccessibilityService accessibility;
  const _FontScaleTile({required this.accessibility});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.text_fields, color: AppColors.onSurfaceVariant),
      title: Text(
        'Font Size',
        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
      ),
      subtitle: Slider(
        value: accessibility.fontScale,
        min: 0.85,
        max: 1.5,
        divisions: 13,
        label: '${(accessibility.fontScale * 100).round()}%',
        activeColor: AppColors.secondaryContainer,
        onChanged: (v) => accessibility.setFontScale(v),
      ),
      trailing: Text(
        '${(accessibility.fontScale * 100).round()}%',
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}
