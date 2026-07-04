import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Album card used in the "Recently Played" horizontal carousel.
///
/// Spec:
///   - Square aspect ratio, rounded-lg corners (16px)
///   - 1px top + left border at 20% opacity (light edge)
///   - Hover overlay with a centered play button that animates up on hover
///   - Title (label-md) + artist (label-sm, on-surface-variant)
class AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback? onTap;

  const AlbumCard({super.key, required this.album, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art with hover play overlay
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(r.AppRadius.lg),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.2)),
                    left: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(r.AppRadius.lg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        album.artUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceContainerHigh,
                          child: const Icon(
                            Icons.album,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      // Hover-style overlay (always visible on mobile tap targets)
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onTap,
                            child: Ink(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.0),
                              ),
                              child: Center(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.secondaryContainer,
                                        Color(0xFF2196F3),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.sonicGlow.withOpacity(
                                          0.6,
                                        ),
                                        blurRadius: 15,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.primaryContainer,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              album.title,
              style: AppTypography.labelMd.copyWith(color: AppColors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              album.artist,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
