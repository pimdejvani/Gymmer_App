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

## iOS status

The `ios/` folder is generated, the app icon ships, and CI builds an unsigned
`.ipa` on every push (`.github/workflows/ios-build.yml` → GitHub Release +
`apps.json` SideStore source). Distribution today is **free sideload via
SideStore** — no Mac, no Apple Developer account. See `update.md` (2026-07-10)
and `README.md` for the pipeline and source URL. Work lives on branch `ios`.

Remaining iOS items:

- **`NSPhotoLibraryUsageDescription`** is NOT yet in `ios/Runner/Info.plist`.
  `image_picker` needs it for the thumbnail/media "Choose Image / Add Image /
  Add Video" pickers on the Create/Edit Exercise page — **the app crashes on
  first pick without it.** The `ios/` folder now exists, so this is actionable.
- **Merge `ios` → `main`**, then point the SideStore source URL at
  `.../main/apps.json` (more stable than the `ios` branch).
- Bundle id is `com.gymmer.gymmerFlutter` (flutter-create default). Fine for
  free sideload; revisit only if going to the App Store.
- Icon note: logo art style (galaxy/neon) vs app theme (true-black minimal) —
  the full-bleed logo currently ships as-is; simplify the mark later if wanted.

Only if going to the paid App Store later (not needed for sideload): $99/yr
Apple Developer account + signing in CI, privacy "nutrition label" + policy URL,
TestFlight, remove any debug-only UI before archiving.

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
