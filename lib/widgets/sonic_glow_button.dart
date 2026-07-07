import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;

/// A circular play/pause button with the signature Sonic glow.
///
/// Spec:
///   - Large circular shape
///   - Cyan gradient fill (`#006c71` → `#00f4fe`)
///   - Subtle outer cyan glow that pulses on active playback
///   - 1px secondary/30% border
class SonicGlowButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  const SonicGlowButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
    this.size = 80,
  });

  @override
  State<SonicGlowButton> createState() => _SonicGlowButtonState();
}

class _SonicGlowButtonState extends State<SonicGlowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, _) {
          // Pulse the outer glow alpha between 0.3 and 0.6 when playing.
          final t = widget.isPlaying ? _glow.value : 0.0;
          final glowAlpha = 0.30 + 0.30 * t;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer blurred glow
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.onSecondaryContainer,
                        AppColors.secondaryContainer,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sonicGlow.withOpacity(glowAlpha),
                        blurRadius: 30 + 10 * t,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
                // Inner gradient disc
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF006C71), AppColors.secondaryContainer],
                    ),
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                // Icon
                Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: widget.size * 0.5,
                  color: AppColors.surfaceLowest,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A small pill-shaped ghost button used for secondary actions.
class GhostButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final bool active;
  final Color? activeColor;

  const GhostButton({
    super.key,
    required this.icon,
    this.label,
    this.onTap,
    this.active = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (activeColor ?? AppColors.secondaryContainer)
        : AppColors.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.AppRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
