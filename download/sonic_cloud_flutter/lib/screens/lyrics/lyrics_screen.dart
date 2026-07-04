import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/lyrics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart' as r;
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Lyrics screen — synced lyrics that scroll as the track plays.
///
/// Features:
///   - Highlight the currently-active line
///   - Auto-scroll to keep the active line centered
///   - Karaoke mode (line-level highlight only — no word-level timing for v2)
///   - Tap a line to seek to it (if synced)
class LyricsScreen extends StatefulWidget {
  final LyricsService lyricsService;
  final Track track;
  final Duration Function() currentPosition;
  final Stream<Duration> positionStream;
  final ValueChanged<Duration> onSeek;

  const LyricsScreen({
    super.key,
    required this.lyricsService,
    required this.track,
    required this.currentPosition,
    required this.positionStream,
    required this.onSeek,
  });

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  Lyrics? _lyrics;
  bool _loading = true;
  bool _karaokeMode = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    final lyrics = await widget.lyricsService.getLyrics(widget.track);
    if (mounted) {
      setState(() {
        _lyrics = lyrics;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final lyrics = _lyrics;
    if (lyrics == null || lyrics.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lyrics')),
        body: Center(
          child: Text(
            'No lyrics found for this track.',
            style: AppTypography.bodyLg.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lyrics.title ?? widget.track.title),
        actions: [
          IconButton(
            onPressed: () => setState(() => _karaokeMode = !_karaokeMode),
            icon: Icon(
              _karaokeMode ? Icons.mic_rounded : Icons.mic_none_rounded,
            ),
            tooltip: 'Karaoke mode',
          ),
        ],
      ),
      body: StreamBuilder<Duration>(
        stream: widget.positionStream,
        initialData: widget.currentPosition(),
        builder: (context, snapshot) {
          final pos = snapshot.data ?? Duration.zero;
          final activeIdx = widget.lyricsService.activeLineIndex(lyrics, pos);
          _scrollToActive(activeIdx);

          return ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            itemCount: lyrics.lines.length,
            itemBuilder: (context, i) {
              final line = lyrics.lines[i];
              final isActive = i == activeIdx;
              final isPast = i < activeIdx;
              return _LyricLineTile(
                line: line,
                isActive: isActive,
                isPast: isPast,
                karaokeMode: _karaokeMode,
                onTap: () {
                  if (line.timestamp != null) widget.onSeek(line.timestamp!);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _scrollToActive(int activeIdx) {
    if (activeIdx < 0 || !_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetOffset =
          (activeIdx * 64.0) -
          (_scrollCtrl.position.viewportDimension / 2) +
          32;
      _scrollCtrl.animateTo(
        targetOffset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _LyricLineTile extends StatelessWidget {
  final LyricLine line;
  final bool isActive;
  final bool isPast;
  final bool karaokeMode;
  final VoidCallback onTap;

  const _LyricLineTile({
    required this.line,
    required this.isActive,
    required this.isPast,
    required this.karaokeMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.secondaryContainer
        : isPast
        ? AppColors.onSurfaceVariant.withOpacity(0.4)
        : AppColors.onSurface;
    final fontSize = isActive && karaokeMode ? 26.0 : 20.0;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppTypography.bodyLg.copyWith(
            color: color,
            fontSize: fontSize,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
          child: Text(
            line.text.isEmpty ? '♪' : line.text,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
