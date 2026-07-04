import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart' as r;
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Modal sheet to start / cancel a sleep timer.
///
/// Surfaces preset durations (5/15/30/45/60 minutes) and a custom picker,
/// plus the end-action choice (pause / stop / fade out).
class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context, {
    required ValueChanged<Duration> onStart,
    required VoidCallback onCancel,
    required SleepTimerEndAction currentAction,
    required ValueChanged<SleepTimerEndAction> onActionChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.AppRadius.xl)),
      ),
      builder: (_) => SleepTimerSheet._(
        onStart: onStart,
        onCancel: onCancel,
        currentAction: currentAction,
        onActionChanged: onActionChanged,
      ),
    );
  }

  const SleepTimerSheet._({
    required this.onStart,
    required this.onCancel,
    required this.currentAction,
    required this.onActionChanged,
    super.key,
  });

  final ValueChanged<Duration> onStart;
  final VoidCallback onCancel;
  final SleepTimerEndAction currentAction;
  final ValueChanged<SleepTimerEndAction> onActionChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sleep Timer',
              style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            children: [
              for (final mins in [5, 15, 30, 45, 60])
                ActionChip(
                  label: Text('$mins min'),
                  onPressed: () {
                    onStart(Duration(minutes: mins));
                    Navigator.of(context).pop();
                  },
                  backgroundColor: AppColors.secondaryContainer.withOpacity(0.2),
                  labelStyle: AppTypography.labelMd.copyWith(color: AppColors.secondaryContainer),
                ),
              ActionChip(
                label: const Text('Custom'),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 0, minute: 30),
                    helpText: 'Pick sleep timer duration',
                  );
                  if (picked != null) {
                    final dur = Duration(hours: picked.hour, minutes: picked.minute);
                    if (dur > Duration.zero) {
                      onStart(dur);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('When timer ends',
              style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: SleepTimerEndAction.values.map((a) {
              final active = a == currentAction;
              return ChoiceChip(
                label: Text(_actionLabel(a)),
                selected: active,
                onSelected: (_) => onActionChanged(a),
                selectedColor: AppColors.secondaryContainer,
                labelStyle: TextStyle(
                  color: active ? AppColors.surfaceLowest : AppColors.onSurfaceVariant,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () {
              onCancel();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel current timer'),
          ),
        ],
      ),
    );
  }

  String _actionLabel(SleepTimerEndAction a) => switch (a) {
        SleepTimerEndAction.pause => 'Pause',
        SleepTimerEndAction.stop => 'Stop',
        SleepTimerEndAction.fadeOut => 'Fade out',
      };
}
