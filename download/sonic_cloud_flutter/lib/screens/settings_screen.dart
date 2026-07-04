import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/glass_card.dart';
import '../widgets/top_app_bar.dart';

/// Settings screen.
///
/// Sections (per the HTML mockup):
///   1. Profile card (avatar, name, tier, edit)
///   2. Connections group → Cloud Accounts
///   3. Playback group → Audio Quality, Offline Mode toggle, Sync Preferences
///   4. Log Out button
///
/// This Flutter port fixes the HTML analysis finding that desktop view was
/// broken (placeholder only) — we use a single responsive layout here.
class SettingsScreen extends StatefulWidget {
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenCloud;

  const SettingsScreen({
    super.key,
    required this.onOpenLibrary,
    required this.onOpenPlayer,
    required this.onOpenCloud,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _offlineMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SonicTopAppBar(avatarUrl: MockData.userProfile.avatarUrl),
      body: SafeArea(
        minimum: const EdgeInsets.only(top: 16),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.edgeMargin,
            8,
            AppSpacing.edgeMargin,
            120,
          ),
          children: [
            // Page title
            Text(
              'Settings',
              style: AppTypography.headlineXl.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Profile
            _ProfileCard(user: MockData.userProfile),
            const SizedBox(height: AppSpacing.md),
            // Connections group
            _SettingsGroup(
              heading: 'Connections',
              children: [
                _SettingsTile(
                  icon: Icons.cloud_sync_rounded,
                  title: 'Cloud Accounts',
                  subtitle: 'Link or unlink external drives',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Playback group
            _SettingsGroup(
              heading: 'Playback',
              children: [
                _SettingsTile(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Audio Quality',
                  subtitle: 'High (Lossless)',
                  subtitleColor: AppColors.secondaryContainer,
                  onTap: () {},
                ),
                _ToggleTile(
                  icon: Icons.offline_pin_rounded,
                  title: 'Offline Mode',
                  subtitle: 'Play downloaded tracks only',
                  value: _offlineMode,
                  onChanged: (v) => setState(() => _offlineMode = v),
                ),
                _SettingsTile(
                  icon: Icons.sync_alt_rounded,
                  title: 'Sync Preferences',
                  subtitle: 'Wi-Fi only',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Log out
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.AppRadius.lg),
                ),
              ),
              child: Text(
                'Log Out',
                style: AppTypography.labelMd.copyWith(color: AppColors.error),
              ),
            ),
          ],
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
// Profile card
// ─────────────────────────────────────────────────────────────────────────────
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
            onPressed: () {},
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

// ─────────────────────────────────────────────────────────────────────────────
// Settings group (heading + card containing tiles)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsGroup extends StatelessWidget {
  final String heading;
  final List<Widget> children;

  const _SettingsGroup({required this.heading, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            heading.toUpperCase(),
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings tile (tap → chevron)
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.labelSm.copyWith(
                        color: subtitleColor ?? AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle tile
// ─────────────────────────────────────────────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _SettingsToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value
              ? AppColors.secondaryContainer.withOpacity(0.20)
              : AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(r.AppRadius.full),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.secondaryContainer
                  : AppColors.onSurfaceVariant,
              shape: BoxShape.circle,
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: AppColors.sonicGlow.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
