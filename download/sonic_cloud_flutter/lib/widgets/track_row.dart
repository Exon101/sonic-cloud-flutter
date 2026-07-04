import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A row in the "All Songs" list.
///
/// Spec:
///   - Active track: 5% secondary tint background, 30% secondary border,
///     4px-wide cyan glow bar on the left edge, animated pulse bars over thumb
///   - Inactive track: surface-container/20 background, white/5 border
///   - Cloud-only badge: small cloud icon next to title (cyan if active)
///   - Hover reveals favorite + more actions, hides duration
class TrackRow extends StatelessWidget {
  final Track track;
  final bool isActive;
  final VoidCallback? onTap;

  const TrackRow({
    super.key,
    required this.track,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.secondaryContainer.withOpacity(0.05)
            : AppColors.surfaceContainer.withOpacity(0.20),
        borderRadius: BorderRadius.circular(r.AppRadius.lg),
        border: Border.all(
          color: isActive
              ? AppColors.secondaryContainer.withOpacity(0.30)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Active indicator: 4px glowing cyan left bar
              if (isActive)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sonicGlow.withOpacity(0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Thumbnail
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              r.AppRadius.def,
                            ),
                            child: Image.network(
                              track.artUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.surfaceContainerHigh,
                                child: const Icon(
                                  Icons.music_note,
                                  color: AppColors.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          if (isActive)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(0.5),
                                child: const _PulseBars(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Title + meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  track.title,
                                  style: AppTypography.labelMd.copyWith(
                                    color: isActive
                                        ? AppColors.secondaryContainer
                                        : AppColors.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (track.isCloudOnly) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.cloud_outlined,
                                  size: 14,
                                  color: isActive
                                      ? AppColors.secondaryContainer
                                      : AppColors.onSurfaceVariant,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${track.artist} • ${track.year}',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Duration
                    Text(
                      track.formattedDuration,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three pulsing vertical bars that indicate an actively playing track.
class _PulseBars extends StatefulWidget {
  const _PulseBars();

  @override
  State<_PulseBars> createState() => _PulseBarsState();
}

class _PulseBarsState extends State<_PulseBars> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = [
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..repeat(reverse: true),
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true),
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat(reverse: true),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controllers[i],
            builder: (context, child) {
              final h = 4 + (_controllers[i].value * 12);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 3,
                height: h,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
