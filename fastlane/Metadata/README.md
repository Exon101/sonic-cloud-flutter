# Sonic Cloud — Release Tracks

This directory stores per-app Fastlane metadata. Use the standard fastlane
metadata layout:

```
fastlane/Metadata/
├── android/
│   └── en-US/
│       ├── title.txt
│       ├── short_description.txt
│       ├── full_description.txt
│       └── changelogs/
│           └── default.txt
└── ios/
    └── en-US/
        ├── name.txt
        ├── description.txt
        ├── keywords.txt
        ├── release_notes.txt
        └── privacy_url.txt
```

Run `fastlane android download_metadata` / `fastlane ios download_metadata` to
pull existing store metadata from Google Play / App Store Connect into this
folder.
