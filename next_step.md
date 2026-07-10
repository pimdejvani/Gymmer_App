# GYMMER Next Step

Date: 2026-07-10. Only genuinely-remaining work lives here — done items get
deleted, not checked off. Read `structure_file.md` first for the file map.

Decisions locked 2026-07-08: **free & non-commercial app** (abs NC license
therefore OK — in-app attribution now ships), **iOS is the release
target** (Android = dev stand-in only; Android signing/appbundle dropped),
**Hevy-style single-user Profile tab approved** (product pivot recorded in
CONTEXT.md; still no login/social/cloud).

## Feature roadmap

No active feature plan files remain in `plans/`. Completed plans live in
`backup/plans/`; far-future iOS widget notes were removed from the current
workspace docs until they become actionable.

## iOS release checklist (needs a Mac for final steps)

- App icon + launch screen from `assets/Gymmer_Logo.png`
  (`flutter_launcher_icons`; config can be staged on Windows, verified on Mac).
  Note: logo art style (galaxy/neon) vs app theme (true-black minimal) —
  decide whether to simplify the icon mark before generating sizes.
- Confirm iOS bundle identifier `com.gymmer.app`.
- Add `NSPhotoLibraryUsageDescription` to `ios/Runner/Info.plist` (the `ios/`
  folder isn't generated yet). Required by `image_picker` for the
  thumbnail/media "Choose Image / Add Image / Add Video" pickers on the Create/
  Edit Exercise page — the app will crash on first pick without it.
- App Store: privacy "nutrition label" + privacy policy URL (required even
  for free apps), TestFlight for the user's own device first.
- Remove any debug-only UI before archiving.

## Optional / nice-to-have (not scheduled)

- Export/import backup file (JSON) — offline app has no backup path today.
- Abs anatomy highlight reads pale through the rectus-sheath centre (faithful
  to the `Muscle long tendons` texture). Revisit with a targeted abs-only
  saturation boost only if it proves too subtle in the app.

## Verification block

Run from `gymmer_flutter/` after changes:

```powershell
C:\Users\pimde\develop\flutter\bin\flutter.bat analyze
C:\Users\pimde\develop\flutter\bin\flutter.bat test
C:\Users\pimde\develop\flutter\bin\flutter.bat build web
```

Widget tests must keep using the in-memory store (`pumpGymmer`) — file-based
temp-dir I/O hangs `pumpAndSettle`. File persistence is covered by the
SQLite-only tests. Timer-based features: use stepped `pump(Duration)` and
always cancel timers in dispose.
