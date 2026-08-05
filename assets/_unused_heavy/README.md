# Unused heavy assets (not bundled)

Moved out of the Flutter asset bundle to keep startup fast and APK small.

These files were 12–45 MB Lottie JSON / 1.2 MB full-bleed PNGs and caused
main-thread jank (`Skipped 100+ frames`) on mid-range Android devices.

Re-add only after compressing to << 500 KB each, and list them explicitly in
`pubspec.yaml` — never glob `assets/lottie/`.
