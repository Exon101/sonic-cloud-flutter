import '../models/models.dart';

/// In-memory mock data so the UI is fully populated without a backend.
///
/// Track art uses the same Google-hosted images as the original HTML mockups
/// so the visual parity is 1:1 with the design system reference.
class MockData {
  MockData._();

  /// Bundled audio asset used by every track for demo playback. In a real
  /// app each track would have its own URL.
  static const sampleAudioUrl = 'asset:///assets/audio/sample_track.wav';

  /// Mock user account (v3: UserAccount has name/tier/avatarUrl for display).
  static const userProfile = UserAccount(
    id: 'user-1',
    email: 'alex.mercer@example.com',
    name: 'Alex Mercer',
    tier: 'Premium Member',
    avatarUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDcdInEnwpcO6zkWUD6b5WDVSjDf07u4oLCL30trZwPSCHVnDC-laQEiM_W7dkkSERCR6TYa5okX4piYFRHXjLcxPPrUBTldgxGstWSp8ea5WtRoh_H2x82hYRSWT220jExDYxct8ZNiA_iVX0fMXaij6HBNqSXQOfCvIbRsJl1EeXhergQSarm82dVPK6gCTMW7kklwF0hU8f88j4qjkzKi5XVXMFHEBJySYyaXsGdtjHEvqqV-rs',
  );

  static const nowPlayingArtUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDGfNpsjJ7oHbxR9IOFsqLwmYvKeOwtnPG2fYmkCGgzN4IeaySjwjhsjlrI_ANDeMX0E3i4OwpyPjzg5VxsXB-yU9clhvbJbMX176ONdfwGtUv_cAHnpiU4LgB5qEJrI7QRWIX_iJ9F_urB_YbOApxROf8JDS5UEOsxVslHGpzjAlwx8EkiCOyPMtP8CtWNYOY-6prEVdU8VqmhhDGIcfsA1iZKKU2Bhu5atjl8sBnLYX0lKHpBKU8';

  static const recentlyPlayed = <Album>[
    Album(
      id: 'a1',
      title: 'Neon Pulse',
      artist: 'Synthwave Collective',
      year: 2024,
      artUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAyK7GlCdOBKx-21yFbwFUicyPQq0rGx3jfNe6RS1kBYd7zXyzSPiYAxctvWY7jtpTEf52vCSoX4dbneQoLr2TkrXzEjHIScVGxFKce625RmzvZ1Dh7ffH_wTJWo0SUIC6oCrSI8G2N8KVHICc3f3pJZpUTBJITGMj5vukP1rTHC_jCtNWYh-0VMQcwszbuGLVJBLGMd_kkRiN8dYwV81beYziBMP4i92nqv7hjTXTdLtamFapsqbg',
    ),
    Album(
      id: 'a2',
      title: 'Ethereal Clouds',
      artist: 'Ambient Echoes',
      year: 2023,
      artUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDMkGZ8plkJ52Cr-4nU-RA4ewUWc7mMMn4v1yhh7zmEp7bc9sBFtwT15F1serKgPllT1v64uQsElWc0hpb6VdmXvJS2E2XCpvLfqEC_o3mjcKejcNGYCEhk9ma6_ksppJEpEi8cRete5qfnKtUN1VXd45SSKkROQJMfRYAFXM-t4ggXTgGngxKzIWGmxFNrF8i8itZHidUT6x4os1cTkg0a227L9tYT41NpSgqHlfEm72dLOguKUKA',
    ),
    Album(
      id: 'a3',
      title: 'Frequency Response',
      artist: 'Audio Dynamics',
      year: 2024,
      artUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuD0TCSjYoLf2Wg-AoVairCltEwCCWGZcoDwddU1jAyGO4QOeldfAOVKdLKPuHynTrXa5utAX4G5FdXZF2jvmr-x0twrdRp1c71iGhlzxbBRuux2gyjnHm1-wWs76PRVV9OQK_5o4uHDrJagxODvqWu2Zr71KEP3jVC7GWdzeJoE3p9Gp028nXWHVL1dFXcHkIRr2F8kTCkSHIgKjGfuRYMYTHA_lPk7l_u0Zio47D6kRogUGqwpLYQ',
    ),
    Album(
      id: 'a4',
      title: 'Metallic Soul',
      artist: 'The Androids',
      year: 2024,
      artUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCOQoSbhY04q9HjF4hOvJpPf1MdghPmfwOP5Egsv2Rw-me0fEKVgoPx0TIM4Vox1gJkQ5Tsply-qVIlQSuzah3pUEkIJx14W9pQpZUph41WDBHe1-UtPaTBQHPXMhtoR-H561SShVd9MwfgmiQKdLYyIq2y3S0L47N5ODzVGq7t8oayxvzSV6A80C8WujbeW24duvyaRD0blMyFCRRI5avJbIpd1f0x0FSfHBwoE38bYk_0eSHVPs',
    ),
  ];

  static const allSongs = <Track>[
    Track(
      id: 't1',
      title: 'Starlight Drift',
      artist: 'Neon Pulse',
      album: 'Neon Pulse',
      year: 2024,
      duration: Duration(minutes: 4, seconds: 12),
      artUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuB2Jb8NXjnW8090GBDO9F7i1lEknIKQCP1GyxTQxY3vxpmnmhfpNOv6JbS4lW5-tMVThO5LY6KnCpBUPnT2OdctEqYDnvmwkgPos6KfPe5A2KiGkCfv2toQGlx0P-uLAXFWJDfq6uDD9ndGXPsTnTgeXQXvtE1Kx8Rpt-f1KiOEXDhORjo16SQY746h4Ktfh9GcXBGb1jq7B2i5Y6UUw0Th32aBZkAOR7GJs5R4luOqnrCjHnhaZgc',
      audioUrl: sampleAudioUrl,
      isCloudOnly: true,
      isFavorite: true,
    ),
    Track(
      id: 't2',
      title: 'Midnight Horizon',
      artist: 'Ambient Echoes',
      album: 'Ethereal Clouds',
      year: 2023,
      duration: Duration(minutes: 3, seconds: 45),
      artUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBWPmHLvWIpEtGsjaMcq1NLfOlQ0b-zJeT2ZIG4NtQe8Eg58D0P-xZqrdt0SyEo1QklmewE39tyA657cxYsvdjHZX0c6eDK9tcviYPc6udVJO_8x5YY3cGDAlbqgvWB6xIvaYyB6uQp7-QCwAmtWVYpVTF4wEd35O-DhqndBPlqnR-DQ3gmT4ZY8yZ2jcAh5ep4NSn614qRIMVSFEXoYwzIHBggPfBJU89Xo2jR70KUGOf06Mew3WQ',
      audioUrl: sampleAudioUrl,
    ),
    Track(
      id: 't3',
      title: 'Velocity',
      artist: 'Audio Dynamics',
      album: 'Frequency Response',
      year: 2024,
      duration: Duration(minutes: 5, seconds: 20),
      artUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCrd91B3cie4w3ch0ilR446bR17kttAYwzPJVxSfOs0B7a16vtVQYWsxXiWKsLNisz2jpwE9jbOglQXVWLGU9EXH0o5Vyc5SGwpHEWvyhBJVr0bNPGIt9T5a9BDuGAA3Wv_2308h-Mne_pm4DkYoUVDGb2JgOJ7QbE9eftrRXfvn7dk74FtftbVej-9fjxy0sL4HCKmqnH-3haJp4TV6z7bZshhNHAwo990FD0Frct9t7LEmX22HK4',
      audioUrl: sampleAudioUrl,
      isCloudOnly: true,
    ),
    Track(
      id: 't4',
      title: 'Ethereal Resonance',
      artist: 'The Midnight Synth',
      album: 'Sonic Horizons',
      year: 2024,
      duration: Duration(minutes: 5, seconds: 0),
      artUrl: nowPlayingArtUrl,
      audioUrl: sampleAudioUrl,
    ),
  ];

  /// Cloud provider configs (v3 renamed CloudDrive → CloudProviderConfig).
  static const cloudDrives = <CloudProviderConfig>[
    CloudProviderConfig(
      id: 'd1',
      kind: CloudProviderKind.googleDrive,
      displayName: 'Google Drive',
      account: 'alex.mercer@example.com',
      streamMode: true,
    ),
    CloudProviderConfig(
      id: 'd2',
      kind: CloudProviderKind.dropbox,
      displayName: 'Dropbox',
      account: 'alex.mercer@example.com',
      downloadForOffline: false,
    ),
  ];

  /// Recent sync activity (for the Cloud Storage screen).
  static const syncActivity = <SyncActivity>[
    SyncActivity(
      id: 's1',
      fileName: 'Midnight City Remaster (FLAC).zip',
      status: 'Downloading to local cache...',
      state: SyncState.syncing,
      progress: 0.68,
    ),
    SyncActivity(
      id: 's2',
      fileName: 'Ambient Soundscapes Vol. 4',
      status: 'Synced from Google Drive',
      state: SyncState.success,
    ),
  ];

  /// Storage breakdown (GB).
  static const storageUsedGb = 45;
  static const storageTotalGb = 100;
  static const storageMusicGb = 30;
  static const storageOtherGb = 15;
}
