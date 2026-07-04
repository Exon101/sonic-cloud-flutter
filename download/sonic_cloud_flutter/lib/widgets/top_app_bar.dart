import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Top app bar shown on Library / Cloud / Settings screens.
///
/// Spec:
///   - 80% surface tint with backdrop blur
///   - Bottom border 1px white/10
///   - Left: avatar (32px circle) + "Sonic Cloud" wordmark in primary color
///   - Right: search icon
class SonicTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String avatarUrl;
  final VoidCallback? onSearchTap;
  final List<Widget>? actions;

  const SonicTopAppBar({
    super.key,
    required this.avatarUrl,
    this.onSearchTap,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: preferredSize.height,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.edgeMargin,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  image: DecorationImage(
                    image: NetworkImage(avatarUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Sonic Cloud',
                style: AppTypography.headlineLg.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              ...(actions ?? []),
              IconButton(
                onPressed: onSearchTap,
                icon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Search',
                constraints: const BoxConstraints(
                  minWidth: AppSpacing.touchTarget,
                  minHeight: AppSpacing.touchTarget,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
