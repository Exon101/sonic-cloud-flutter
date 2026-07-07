import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A waveform-style seek bar.
///
/// Spec: "Sonic Seeker"
///   - 45 vertical bars whose heights follow a sine-modulated pseudo-random wave
///   - Bars before the playhead are filled with vibrant cyan + drop-shadow glow
///   - Bars after the playhead are dimmed to surfaceVariant at 50% opacity
///   - A 2px wide playhead line with a small glowing thumb sits at the progress
///
/// Tap-to-seek is supported via [onSeek] (called with new progress 0..1).
class WaveformProgress extends StatelessWidget {
  final double progress; // 0..1
  final int barCount;
  final VoidCallback? onTap;
  final ValueChanged<double>? onSeek;

  const WaveformProgress({
    super.key,
    required this.progress,
    this.barCount = 45,
    this.onTap,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barGap = 3.0;
        final barWidth =
            (constraints.maxWidth - (barCount - 1) * barGap) / barCount;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onHorizontalDragUpdate: (details) {
            if (onSeek == null) return;
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final p = (local.dx / box.size.width).clamp(0.0, 1.0);
            onSeek!(p);
          },
          onTapDown: (details) {
            if (onSeek == null) return;
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final p = (local.dx / box.size.width).clamp(0.0, 1.0);
            onSeek!(p);
          },
          child: SizedBox(
            height: 64,
            child: Stack(
              children: [
                // Wave bars
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(barCount, (i) {
                      final heightPhase =
                          sin(i * 0.4) * sin(i * 0.1) * 0.5 + 0.5;
                      // Deterministic pseudo-random jitter so bars don't reshuffle on rebuild.
                      final jitter = (sin(i * 12.9898) * 43758.5453) % 1 * 0.3;
                      final finalHeight =
                          (heightPhase + jitter) * 100; // 0..100ish
                      final played = (i / barCount) <= progress;

                      return Container(
                        width: barWidth,
                        height: finalHeight.clamp(15, 100) *
                            0.6, // scale into 64px box
                        decoration: BoxDecoration(
                          color: played
                              ? AppColors.secondaryContainer
                              : AppColors.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: played
                              ? [
                                  BoxShadow(
                                    color: AppColors.sonicGlow.withOpacity(0.3),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                ),
                // Playhead
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final x = c.maxWidth * progress;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: x - 1,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 2,
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.sonicGlow.withOpacity(0.8),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: x - 6,
                            top: c.maxHeight / 2 - 6,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.sonicGlow.withOpacity(0.9),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
