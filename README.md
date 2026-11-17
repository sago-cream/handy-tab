<div align="center">
  <img src="assets/icon.png" alt="HandyTab icon" width="120" />

<h1>HandyTab</h1>

Open your most-used tab instantly with webcam hand wave or a quick 3-finger trackpad tap.

</div>

## Install

Install with Homebrew:

```bash
brew install --cask sago-cream/tap/handytab
```

Or build the DMG and drag HandyTab into Applications:

```bash
make dmg
open dist/HandyTab.dmg
```

## Quick Start (Dev)

```bash
pip install -r requirements.txt
curl -o gesture_recognizer.task https://storage.googleapis.com/mediapipe-tasks/gesture_recognizer/gesture_recognizer.task

make run # run swift
make dmg # build dmg
```

## Trackpad taps

A tap requires exactly three accepted fingers, at most 300 ms from the first
finger touching to the final finger lifting. Each finger must stay within the
movement limits. Extra fingers, swipes, long holds, and finger replacements cancel
the gesture until release. Each trackpad is tracked independently.

Taps near any edge or corner are supported. An edge contact is treated as a palm
only when both its contact area and an axis measurement exceed the palm limits;
position alone never disqualifies a finger. Rejected contacts stay excluded until
they leave the surface.

Run gesture replay and touch-buffer tests with `swift test`. On a Mac with a
trackpad, run the optional registration smoke test with
`HANDYTAB_TEST_TRACKPAD=1 swift test --filter realDeviceRegistration`.
This test installs no URL-opening action. Real finger taps are still needed to
calibrate the contact-size and movement thresholds for a device.

## Release packaging

Generate a versioned app archive and Homebrew cask:

```bash
make brew ARGS="--version 0.1.0"
```

Release builds use `--notarize` and require a Developer ID Application signing
identity plus Apple notarization credentials. The GitHub workflow reads the same
certificate and notarization secrets used by Comux.

To copy the generated cask into the adjacent shared tap checkout:

```bash
make tap ARGS="--version 0.1.0"
```
