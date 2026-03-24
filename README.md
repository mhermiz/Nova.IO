# Nova.IO

Nova.IO is a Flutter-based video enhancement prototype focused on fast preset-driven styling, live previewing, and on-device export testing.

The app currently supports importing videos, previewing edits in-app, applying manual grading controls, using stylized preset overlays, running a lightweight scene analysis pass, and exporting edited clips with FFmpeg.

## Current Features

- Import local videos into an in-app queue
- Generate queue thumbnails from real video frames
- Preview imported clips with in-player playback and scrubbing
- Toggle between `Before` and `After`
- Apply manual adjustments:
  - Brightness
  - Contrast
  - Saturation
  - Warmth
  - Tint
- Use built-in presets:
  - Balanced
  - Cinematic
  - Vivid
  - Low-Light Rescue
- Enable or disable preset overlay styling
- Run scene-aware analysis for preset suggestions
- Export edited video with FFmpeg
- Choose export folder with a native directory picker
- Rename the exported file before saving

## Tech Stack

- Flutter
- `video_player`
- `file_picker`
- `video_thumbnail`
- `ffmpeg_kit_flutter_new`

## Project Structure

The app started as a single-file prototype and has been incrementally refactored into smaller modules.

- [lib/main.dart](/E:/Coding%20Projects/videoenhancerapp/lib/main.dart): app wiring, state, import/export flow
- [lib/models/demo_clip.dart](/E:/Coding%20Projects/videoenhancerapp/lib/models/demo_clip.dart): imported clip model
- [lib/models/enhancement_preset.dart](/E:/Coding%20Projects/videoenhancerapp/lib/models/enhancement_preset.dart): preset model
- [lib/helpers/analyzer_helper.dart](/E:/Coding%20Projects/videoenhancerapp/lib/helpers/analyzer_helper.dart): scene analysis and recommendation helpers
- [lib/helpers/color_grading.dart](/E:/Coding%20Projects/videoenhancerapp/lib/helpers/color_grading.dart): shared grading math
- [lib/widgets/video_preview_card.dart](/E:/Coding%20Projects/videoenhancerapp/lib/widgets/video_preview_card.dart): preview and mini-preview UI
- [lib/widgets/preview_media.dart](/E:/Coding%20Projects/videoenhancerapp/lib/widgets/preview_media.dart): filtered preview media
- [lib/widgets/analysis_card.dart](/E:/Coding%20Projects/videoenhancerapp/lib/widgets/analysis_card.dart): analysis UI
- [lib/widgets/adjustments_card.dart](/E:/Coding%20Projects/videoenhancerapp/lib/widgets/adjustments_card.dart): manual adjustment controls
- [lib/widgets/presets_card.dart](/E:/Coding%20Projects/videoenhancerapp/lib/widgets/presets_card.dart): preset selection UI

## Export Notes

Exports are currently aimed at practical testing rather than perfect studio-grade parity.

- Export uses FFmpeg through `ffmpeg_kit_flutter_new`
- Manual grading controls are mapped into the export pipeline
- Preset overlay assets are composited during export when overlays are enabled
- Export destination can be:
  - original video folder
  - a user-selected folder

Because preview rendering and FFmpeg are different engines, preview and export are close but not guaranteed to be pixel-perfect in every case.

## Getting Started

1. Install Flutter dependencies:

```bash
flutter pub get
```

2. Run the app:

```bash
flutter run
```

## Build Android App Bundle

To generate an Android App Bundle for Google Play testing:

```bash
flutter build appbundle
```

The bundle is typically generated at:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Assets

Current bundled assets include:

- preset overlay PNGs in `assets/overlays/`
- a repeating star background pattern in `assets/patterns/white_star_pattern.png`

## Status

This project is currently in prototype / testing stage and is being developed incrementally with a focus on:

- stable import and preview behavior
- practical Android export flow
- better preview/export parity
- UI polish for tester feedback
