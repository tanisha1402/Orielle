#!/usr/bin/env sh
# Generates the Android + Web platform folders (not shipped in the ZIP) and
# adds the INTERNET permission needed for map tiles in Android release builds.
# Safe to re-run: `flutter create` does not overwrite existing files.
set -e
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter was not found on PATH. Install it first: https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

flutter create . --platforms=android,web --project-name earth_risk_chain

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ] && ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  awk '{ print } /<manifest /{ print "    <uses-permission android:name=\"android.permission.INTERNET\"/>" }' "$MANIFEST" > "$MANIFEST.tmp"
  mv "$MANIFEST.tmp" "$MANIFEST"
  echo "Added INTERNET permission to $MANIFEST"
fi

flutter pub get
echo "Done. Next: flutter analyze && flutter test && flutter run"
