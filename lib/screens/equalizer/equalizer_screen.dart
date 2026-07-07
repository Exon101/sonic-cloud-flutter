import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/equalizer_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart' as r;
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Equalizer screen — 10-band EQ with presets + bass boost / virtualizer / etc.
///
/// Surfaces all of [EqualizerService]'s settings in a single screen.
class EqualizerScreen extends StatefulWidget {
  final EqualizerService eq;
  const EqualizerScreen({super.key, required this.eq});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.eq,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Equalizer'),
            actions: [
              // EQ master enable
              Switch(
                value: widget.eq.enabled,
                onChanged: (v) => widget.eq.setEnabled(v),
                activeColor: AppColors.secondaryContainer,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.edgeMargin),
            children: [
              // Presets
              _PresetsRow(eq: widget.eq),
              const SizedBox(height: AppSpacing.lg),

              // 10-band EQ
              _BandSliders(eq: widget.eq),
              const SizedBox(height: AppSpacing.lg),

              // Bass boost / virtualizer / etc.
              _EffectsSection(eq: widget.eq),
            ],
          ),
        );
      },
    );
  }
}

class _PresetsRow extends StatelessWidget {
  final EqualizerService eq;
  const _PresetsRow({required this.eq});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: EqualizerPreset.builtIns.map((p) {
          final active = eq.activePreset?.name == p.name;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(p.name),
              selected: active,
              onSelected: (_) => eq.applyPreset(p),
              selectedColor: AppColors.secondaryContainer,
              labelStyle: TextStyle(
                color: active
                    ? AppColors.surfaceLowest
                    : AppColors.onSurfaceVariant,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BandSliders extends StatelessWidget {
  final EqualizerService eq;
  const _BandSliders({required this.eq});

  @override
  Widget build(BuildContext context) {
    // Responsive height: 220 on phones, taller on tablets
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sliderHeight = (screenHeight * 0.28).clamp(180.0, 280.0);

    return SizedBox(
      height: sliderHeight,
      child: Row(
        children: List.generate(10, (i) {
          return Expanded(
            child: _BandSlider(
              eq: eq,
              index: i,
              frequency: EqualizerService.bandFrequencies[i],
              gain: eq.gains[i],
            ),
          );
        }),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final EqualizerService eq;
  final int index;
  final double frequency;
  final double gain;

  const _BandSlider({
    required this.eq,
    required this.index,
    required this.frequency,
    required this.gain,
  });

  String get _freqLabel {
    if (frequency >= 1000)
      return '${(frequency / 1000).toStringAsFixed(frequency % 1000 == 0 ? 0 : 1)}k';
    return frequency.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '+12',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: gain,
              min: -12,
              max: 12,
              divisions: 24,
              activeColor: AppColors.secondaryContainer,
              onChanged: (v) => eq.setBandGain(index, v),
            ),
          ),
        ),
        Text(
          '-12',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _freqLabel,
          style: AppTypography.labelSm.copyWith(color: AppColors.onSurface),
        ),
        Text(
          '${gain.toStringAsFixed(1)}dB',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.secondaryContainer,
          ),
        ),
      ],
    );
  }
}

class _EffectsSection extends StatelessWidget {
  final EqualizerService eq;
  const _EffectsSection({required this.eq});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audio Effects',
          style: AppTypography.headlineMd.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.md),
        _EffectToggle(
          label: 'Bass Boost',
          value: eq.bassBoost,
          onChanged: (v) => eq.setBassBoost(v),
        ),
        if (eq.bassBoost) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Slider(
              value: eq.bassBoostStrength,
              activeColor: AppColors.secondaryContainer,
              onChanged: (v) => eq.setBassBoost(true, strength: v),
            ),
          ),
        ],
        _EffectToggle(
          label: 'Virtualizer',
          value: eq.virtualizer,
          onChanged: eq.setVirtualizer,
        ),
        _EffectToggle(
          label: 'Surround',
          value: eq.surround,
          onChanged: eq.setSurround,
        ),
        _EffectToggle(
          label: 'Loudness',
          value: eq.loudness,
          onChanged: eq.setLoudness,
        ),
        _EffectToggle(
          label: 'Compressor',
          value: eq.compressor,
          onChanged: eq.setCompressor,
        ),
        _EffectToggle(
          label: 'Limiter',
          value: eq.limiter,
          onChanged: eq.setLimiter,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Note: Bass boost, virtualizer, surround, loudness, compressor, and limiter are Android-only audio effects. On iOS/macOS/Web these toggles persist but have no audible effect.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EffectToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _EffectToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        label,
        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.secondaryContainer,
    );
  }
}
