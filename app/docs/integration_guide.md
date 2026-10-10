# Integration guide (short)

Full beginner-friendly steps are in the README, section 19-21. This is the
one-page version.

**Golden rules:** never overwrite your existing `pubspec.yaml`, `lib/`,
`.git/` or `android/` / `ios/` / `web/`; always work on a new Git branch;
review with `git diff` before committing.

## A. Your repository has no Flutter app yet
1. `git switch -c feature/erc-frontend`
2. Copy the *contents* of `earth_risk_chain/` into a new `app/` folder
   (matches the roadmap: `earth-risk-chain/app/`).
3. `cd app && flutter create . --platforms=android,web --project-name earth_risk_chain`
   (creates the missing platform folders; existing files are kept).
4. Add `<uses-permission android:name="android.permission.INTERNET"/>` to
   `android/app/src/main/AndroidManifest.xml` (needed for map tiles in
   release builds). `tool/bootstrap.sh` / `tool/bootstrap.ps1` do 3 + 4.
5. `flutter pub get && flutter analyze && flutter test && flutter run`.

## B. Your repository already has a Flutter app
Do not create a second app. Choose one:

* **Isolated package (recommended first step):** put this project in its own
  folder (e.g. `packages/earth_risk_chain_frontend/`), run steps 3-5 there and
  run it as a separate app. Zero risk to the existing app.
* **Merge into the existing app:** copy `lib/app`, `lib/core`, `lib/data`,
  `lib/features`, `lib/models`, `lib/state` and `test/` files under new
  sub-folders; **merge** the six dependencies from this `pubspec.yaml` into
  yours (`flutter pub add flutter_riverpod go_router flutter_map latlong2
  fl_chart http`), keeping your versions if already present; call
  `runApp(const ProviderScope(child: EarthRiskChainApp()))` from a new entry
  file (do not replace your `main.dart`). Package imports in `lib/` use
  `package:earth_risk_chain/...` in tests only; if your package name differs,
  update the test imports.

## Review and commit
```
git status
git diff --stat
git add app/ && git commit -m "Add EARTH RISK CHAIN frontend (sample data)"
```
