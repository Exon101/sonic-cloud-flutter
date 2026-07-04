import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';

/// A glassmorphic container per the Sonic Cloud spec.
///
/// Spec:
///   - Semi-transparent white fill (5–10% opacity)
///   - `backdrop-filter: blur(20px)`
///   - 1px top + left border at 20% opacity to simulate light on glass edge
///
/// In Flutter we approximate CSS `backdrop-filter` with [BackdropFilter] +
/// [ImageFilter.blur]. The blur samples whatever is painted behind the widget
/// in the same layer, so [GlassCard] must be placed over a non-opaque parent
/// (e.g. the app's ambient gradient) for the effect to be visible.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final double fillOpacity;
  final double borderRadius;
  final VoidCallback? onTap;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blurSigma = 20,
    this.fillOpacity = 0.05,
    this.borderRadius = r.AppRadius.lg, // 16px per spec
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(fillOpacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border:
                  border ??
                  Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    left: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ambient background layer painted behind every screen.
///
/// Implements the spec's "Background Layer":
///   Deep Indigo gradient (#12122B → #0A0A0F)
/// plus a soft primary-container blob in the upper area to add atmospheric depth.
class AmbientBackground extends StatelessWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base vertical gradient
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
        ),
        // Ambient glow blob (top-left, blurred)
        Positioned(
          top: -MediaQuery.sizeOf(context).height * 0.10,
          left: -MediaQuery.sizeOf(context).width * 0.10,
          child: Container(
            width: MediaQuery.sizeOf(context).width * 1.2,
            height: MediaQuery.sizeOf(context).height * 0.5,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        // Foreground content
        Positioned.fill(child: child),
      ],
    );
  }
}
