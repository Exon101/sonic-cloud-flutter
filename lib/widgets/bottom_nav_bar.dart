import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart' as r;
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Bottom navigation bar shown on Library / Cloud / Settings screens.
///
/// Spec:
///   - 90% surface-container tint with strong backdrop blur (2xl)
///   - Rounded top corners, 1px top border
///   - Active tab: filled icon + cyan color + drop-shadow glow
///   - Inactive tab: 60% opacity on-surface-variant
class SonicBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SonicBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(icon: Icons.library_music_rounded, label: 'Library'),
    _NavItem(icon: Icons.play_circle_outline_rounded, label: 'Player'),
    _NavItem(icon: Icons.cloud_sync_rounded, label: 'Cloud'),
    _NavItem(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(r.AppRadius.xl),
        topRight: Radius.circular(r.AppRadius.xl),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer.withOpacity(0.9),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              final color = active
                  ? AppColors.secondaryContainer
                  : AppColors.onSurfaceVariant.withOpacity(0.6);

              return _NavButton(
                icon: item.icon,
                label: item.label,
                color: color,
                active: active,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.AppRadius.def),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
              fill: active ? 1.0 : 0.0,
              shadows: active
                  ? [
                      Shadow(
                        color: AppColors.sonicGlow.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.labelSm.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Wrapper that pads a screen so its content isn't hidden behind the
/// floating bottom nav bar.
class BottomNavSpacer extends StatelessWidget {
  final Widget child;
  const BottomNavSpacer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 96), child: child);
  }
}
