import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/oauth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/glass_card.dart';
import '../widgets/top_app_bar.dart';

/// Cloud Storage screen.
///
/// Sections:
///   1. Storage Overview — total used, sonic-seeker progress bar, breakdown
///   2. Connected Drives — responsive grid of cloud drive cards with OAuth connect
///   3. Recent Sync Activity — list of downloading / synced items
class CloudStorageScreen extends StatelessWidget {
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenSettings;
  final OAuthService? oauth;

  const CloudStorageScreen({
    super.key,
    required this.onOpenLibrary,
    required this.onOpenPlayer,
    required this.onOpenSettings,
    this.oauth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SonicTopAppBar(avatarUrl: ''),
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
            const _StorageOverview(),
            const SizedBox(height: AppSpacing.lg),
            const _ConnectedDrives(),
            const SizedBox(height: AppSpacing.lg),
            const _SyncActivity(),
          ],
        ),
      ),
      bottomNavigationBar: SonicBottomNavBar(
        currentIndex: 2,
        onTap: (i) {
          if (i == 0) onOpenLibrary();
          if (i == 1) onOpenPlayer();
          if (i == 3) onOpenSettings();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Storage Overview
// ─────────────────────────────────────────────────────────────────────────────
class _StorageOverview extends StatelessWidget {
  const _StorageOverview();

  @override
  Widget build(BuildContext context) {
    final usedPct = 0 / 0; // 0.45
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cloud Storage',
                    style: AppTypography.headlineMd.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${0} GB / ${0} GB Used',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.cloud_done_rounded,
                color: AppColors.secondaryContainer,
                size: 32,
                shadows: [Shadow(color: AppColors.sonicGlow, blurRadius: 8)],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Sonic seeker progress
          ClipRRect(
            borderRadius: BorderRadius.circular(r.AppRadius.full),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: AppColors.surfaceContainerHighest),
                  FractionallySizedBox(
                    widthFactor: usedPct,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.onTertiaryContainer,
                            AppColors.secondaryContainer,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.sonicGlow.withOpacity(0.6),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _LegendDot(
                color: AppColors.secondaryContainer,
                label: 'Music (${0} GB)',
              ),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(
                color: AppColors.onTertiaryContainer,
                label: 'Other (${0} GB)',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connected Drives grid
// ─────────────────────────────────────────────────────────────────────────────
class _ConnectedDrives extends StatelessWidget {
  const _ConnectedDrives();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Connected Drives',
              style: AppTypography.headlineMd.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.secondaryContainer,
              ),
              label: Text(
                'Add Service',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.secondaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, c) {
            // Responsive: 1 col on phones, 2 on small tablets, 3 on wide.
            final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 600 ? 2 : 1);
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final d in <CloudProviderConfig>[])
                  SizedBox(
                    width: (c.maxWidth - AppSpacing.sm * (cols - 1)) / cols,
                    child: _DriveCard(drive: d),
                  ),
                SizedBox(
                  width: (c.maxWidth - AppSpacing.sm * (cols - 1)) / cols,
                  child: _AddNewCard(onTap: () {}),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DriveCard extends StatefulWidget {
  final CloudProviderConfig drive;
  const _DriveCard({required this.drive});

  @override
  State<_DriveCard> createState() => _DriveCardState();
}

class _DriveCardState extends State<_DriveCard> {
  late bool _stream = widget.drive.streamMode;
  late bool _offline = widget.drive.downloadForOffline;

  @override
  Widget build(BuildContext context) {
    final isGoogleDrive = widget.drive.kind == CloudProviderKind.googleDrive;
    final accent = isGoogleDrive
        ? AppColors.secondaryContainer
        : AppColors.onSurface;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 192,
        child: Stack(
          children: [
            // Soft accent blob (top-right)
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color:
                      (isGoogleDrive
                              ? AppColors.secondaryContainer
                              : AppColors.onTertiaryContainer)
                          .withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isGoogleDrive
                            ? Icons.folder_special_rounded
                            : Icons.folder_zip_rounded,
                        color: accent,
                        size: 36,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.drive.displayName,
                              style: AppTypography.bodyLg.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              "",
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.onSurfaceVariant,
                        size: 18,
                      ),
                    ],
                  ),
                  const Spacer(),
                  _ToggleRow(
                    label: isGoogleDrive
                        ? 'Stream Mode'
                        : 'Download for Offline',
                    value: isGoogleDrive ? _stream : _offline,
                    onChanged: (v) => setState(() {
                      if (isGoogleDrive) {
                        _stream = v;
                      } else {
                        _offline = v;
                      }
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(r.AppRadius.lg),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          _SonicToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SonicToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SonicToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
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

class _AddNewCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddNewCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.AppRadius.lg),
        child: Container(
          height: 192,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.AppRadius.lg),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Link New Storage',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync Activity list
// ─────────────────────────────────────────────────────────────────────────────
class _SyncActivity extends StatelessWidget {
  const _SyncActivity();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Sync Activity',
          style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.md),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <SyncActivity>[]
                .map((a) => _SyncRow(activity: a))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SyncRow extends StatelessWidget {
  final SyncActivity activity;
  const _SyncRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final isDownloading = activity.state == SyncState.syncing;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(r.AppRadius.lg),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  isDownloading
                      ? Icons.audio_file_rounded
                      : Icons.library_music_rounded,
                  color: AppColors.onSurface.withOpacity(
                    isDownloading ? 1 : 0.6,
                  ),
                  size: 20,
                ),
                if (isDownloading)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.fileName,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  activity.status,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (isDownloading && activity.progress != null)
            Text(
              '${(activity.progress! * 100).round()}%',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.secondaryContainer,
              ),
            )
          else
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.onSurface.withOpacity(0.6),
              size: 18,
            ),
        ],
      ),
    );
  }
}
