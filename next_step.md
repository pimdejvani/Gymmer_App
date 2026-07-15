# GYMMER Next Step

Date: 2026-07-15. Only genuinely-remaining work lives here — done items get
deleted, not checked off. Read `structure_file.md` first for the file map.

Decisions locked 2026-07-08: **free & non-commercial app** (abs NC license
therefore OK — in-app attribution now ships), **iOS is the release
target** (Android = dev stand-in only; Android signing/appbundle dropped),
**Hevy-style single-user Profile tab approved** (product pivot recorded in
CONTEXT.md; still no login/social/cloud).

## Feature roadmap

No active feature plan files remain in `plans/`. Completed plans live in
`backup/plans/`; the iOS widget work is now active and documented in
`docs/widget/WIDGET.md`.

## iOS status

The `ios/` folder is generated, the app icon ships, and CI builds an unsigned
`.ipa` on every push (`.github/workflows/ios-build.yml` → GitHub Release +
`apps.json` SideStore source). Distribution today is **free sideload via
SideStore** — no Apple Developer account. Work lives on branch `ios`.

The WidgetKit target and Lock Screen Live Activity are implemented on `ios`.
The medium widget is interactive across Start/Add/Filter/Log/Rest/Manage. The
Live Activity reuses Add/Filter/Log/Rest/Manage and omits only Start, using the
same page views and App Intents. Shared state is `catalog.json` +
`routines.json` + `session.json` in the runtime App Group container.

Remaining iOS items:

- **Merge `ios` → `main`**, then point the SideStore source URL at
  `.../main/apps.json` (more stable than the `ios` branch).
- Remove the temporary `App Group POC v2` launch alert in
  `ios/Runner/SceneDelegate.swift` before treating the sideload build as a
  polished release. Keep runtime App Group discovery used by the app and
  widget because SideStore can rewrite the group identifier.
- Test the widget and Live Activity on a real iOS 17 device after each
  SideStore re-sign. Verify start from app/widget, set completion and rest
  countdown, widget-to-app reconciliation, finish/discard, and notification
  permission behavior.
- Bundle id is `com.gymmer.gymmerFlutter` (flutter-create default). Fine for
  free sideload; revisit only if going to the App Store.
- Icon note: logo art style (galaxy/neon) vs app theme (true-black minimal) —
  the full-bleed logo currently ships as-is; simplify the mark later if wanted.

Only if going to the paid App Store later (not needed for sideload): $99/yr
Apple Developer account + signing in CI, privacy "nutrition label" + policy URL,
TestFlight, and removal of any remaining debug-only UI before archiving.

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
