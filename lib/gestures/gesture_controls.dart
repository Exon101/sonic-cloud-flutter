import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// GestureControls — wraps a child widget with a gesture overlay for the
/// Now Playing screen.
///
/// Gestures (configurable, but defaults match the spec):
///   - Single tap        → Pause / Play toggle
///   - Double tap         → Skip to next
///   - Swipe left         → Skip to previous
///   - Swipe right        → Skip to next
///   - Long press         → Toggle favorite
///   - Swipe up           → Open lyrics
///   - Swipe down         → Open queue
///
/// Each callback is optional; missing callbacks make the gesture a no-op.
class GestureControls extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onOpenLyrics;
  final VoidCallback? onOpenQueue;

  /// Show a brief visual hint when a gesture fires (e.g. "❤" / "⏭").
  /// Default: true.
  final bool showHints;

  const GestureControls({
    super.key,
    required this.child,
    this.onTogglePlay,
    this.onNext,
    this.onPrevious,
    this.onToggleFavorite,
    this.onOpenLyrics,
    this.onOpenQueue,
    this.showHints = true,
  });

  @override
  State<GestureControls> createState() => _GestureControlsState();
}

class _GestureControlsState extends State<GestureControls> {
  String? _activeHint;
  DateTime? _lastTap;

  static const _swipeThreshold = 60.0;
  static const _doubleTapWindow = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
      onLongPress: _handleLongPress,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      onVerticalDragEnd: _handleVerticalDragEnd,
      onHorizontalDragUpdate: (details) {
        _lastDragDelta = Offset(details.delta.dx, 0);
      },
      onVerticalDragUpdate: (details) {
        _lastDragDelta = Offset(0, details.delta.dy);
      },
      child: Stack(
        children: [
          widget.child,
          if (widget.showHints && _activeHint != null)
            Positioned.fill(
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _HintBubble(text: _activeHint!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Offset? _lastDragDelta;

  void _handleTap() {
    widget.onTogglePlay?.call();
    _showHint('⏯');
  }

  void _handleDoubleTap() {
    widget.onNext?.call();
    _showHint('⏭');
  }

  void _handleLongPress() {
    widget.onToggleFavorite?.call();
    _showHint('❤');
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return; // too slow
    if (velocity < 0) {
      // Swipe left → previous
      widget.onPrevious?.call();
      _showHint('⏮');
    } else {
      // Swipe right → next
      widget.onNext?.call();
      _showHint('⏭');
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return;
    if (velocity < 0) {
      // Swipe up → lyrics
      widget.onOpenLyrics?.call();
      _showHint('♪');
    } else {
      // Swipe down → queue
      widget.onOpenQueue?.call();
      _showHint('☰');
    }
  }

  void _showHint(String text) {
    if (!widget.showHints) return;
    setState(() => _activeHint = text);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _activeHint = null);
    });
  }
}

class _HintBubble extends StatelessWidget {
  final String text;
  const _HintBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.secondaryContainer.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.sonicGlow.withOpacity(0.3),
            blurRadius: 20,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.secondaryContainer,
          fontSize: 32,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
