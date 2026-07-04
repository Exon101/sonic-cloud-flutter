import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_cloud/models/models.dart';
import 'package:sonic_cloud/widgets/track_row.dart';

const _sampleTrack = Track(
  id: 'test1',
  title: 'Test Track',
  artist: 'Test Artist',
  album: 'Test Album',
  year: 2024,
  duration: Duration(minutes: 3, seconds: 30),
  artUrl: '',
  audioUrl: 'asset:///assets/audio/sample_track.wav',
);

const _cloudTrack = Track(
  id: 'test2',
  title: 'Cloud Track',
  artist: 'Cloud Artist',
  album: 'Cloud Album',
  year: 2023,
  duration: Duration(minutes: 4, seconds: 0),
  artUrl: '',
  audioUrl: 'asset:///assets/audio/sample_track.wav',
  isCloudOnly: true,
);

void main() {
  group('TrackRow', () {
    testWidgets('renders title and artist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TrackRow(track: _sampleTrack)),
        ),
      );
      expect(find.text('Test Track'), findsOneWidget);
      expect(find.text('Test Artist • 2024'), findsOneWidget);
      expect(find.text('3:30'), findsOneWidget);
    });

    testWidgets('shows cloud icon when isCloudOnly=true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TrackRow(track: _cloudTrack)),
        ),
      );
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    });

    testWidgets('does not show cloud icon for non-cloud tracks', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TrackRow(track: _sampleTrack)),
        ),
      );
      expect(find.byIcon(Icons.cloud_outlined), findsNothing);
    });

    testWidgets('fires onTap when tapped', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackRow(track: _sampleTrack, onTap: () => taps++),
          ),
        ),
      );
      await tester.tap(find.text('Test Track'));
      expect(taps, 1);
    });

    testWidgets('renders active state without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: TrackRow(track: _sampleTrack, isActive: true)),
        ),
      );
      // Active track should still show the title (now in cyan, but the same text).
      expect(find.text('Test Track'), findsOneWidget);
    });
  });
}
