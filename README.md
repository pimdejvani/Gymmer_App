# GYMMER

Offline, single-user workout tracker built with Flutter. iPhone-first,
true-black dark UI, all data stored locally (SQLite). The app lives in
[`gymmer_flutter/`](gymmer_flutter/); the Swift project at repo root is legacy.

## Run

```powershell
cd gymmer_flutter
C:\Users\pimde\develop\flutter\bin\flutter.bat pub get
C:\Users\pimde\develop\flutter\bin\flutter.bat run -d chrome
```

Checks: `flutter.bat analyze`, `flutter.bat test`, `flutter.bat build web`.

## iOS (free, no Mac / no $99 account)

Work lives on branch `ios`. Every push to `main`/`ios` runs
[`.github/workflows/ios-build.yml`](.github/workflows/ios-build.yml): builds an
unsigned iOS `.ipa` on a free `macos-26` runner. Flutter tests, native App
Intent XCTests, and the release build run in parallel; a GitHub Release and
[`apps.json`](apps.json) SideStore source are published only after all pass.
Build number = CI run number, so the version auto-bumps to `1.0.<run>`.

Install on an iPhone (one-time), all free:

1. Windows: install **Apple Devices** (Microsoft Store — provides usbmuxd) and
   **iloader**; iloader installs **SideStore** using a free Apple ID.
2. On iPhone: trust the developer app, enable Developer Mode, connect
   **LocalDevVPN**.
3. In SideStore → **Sources** → add
   `https://raw.githubusercontent.com/pimdejvani/Gymmer_App/ios/apps.json`
4. **Browse** tab → install **Gymmer** from the source (not from a file, or it
   won't auto-update). Enable **Background Refresh** so it re-signs every 7 days.

App regenerate helpers: `dart run flutter_launcher_icons` (app icon from
`assets/Gymmer_Logo.png`). See `update.md` (2026-07-15) for the current log.

## iOS widget and Lock Screen activity

The `ios` branch includes a WidgetKit medium widget and an interactive Live
Activity for the Lock Screen and expanded Dynamic Island. Both use the App
Group shared container; the Flutter app
writes the exercise catalog, routines, and active-session snapshot, while the
widget extension can mutate the session and the app reconciles those changes
back into SQLite on resume. The iOS app, widget, and Live Activity require iOS
26. The Live Activity uses
the same Add/Filter/Log/Rest/Manage surface as the widget, without Start. Home
widget buttons retain their extension-side `AppIntent` path; Activity buttons
use Runner-side `LiveActivityIntent` wrappers and share the same mutations.
On iPhones without Dynamic Island, use the Home Screen widget for persistent
unlocked controls; the Live Activity itself is persistent on the Lock Screen.
iOS keeps ordinary Widget and Live Activity buttons inactive while the device
is locked; `alwaysAllowed` can't override that surface rule. Media apps such as
YouTube use the separate Now Playing system. Gymmer therefore
provides one configurable system Control that can be added multiple
times for KG/REP +/−, Complete Set, Next Exercise, or Skip Rest in Control
Center, Lock Screen control slots, and the Action button. The Control runs in
the Widget extension as a background `alwaysAllowed` intent. Each Live Activity
intent also targets its exact Activity ID. On iOS 26+, Gymmer starts a native
HealthKit strength-workout session with the app session, saves it on Finish,
and discards it on Discard. This does not add voice shortcuts.
See [`docs/widget/WIDGET.md`](docs/widget/WIDGET.md) for the state contract,
pages, and known release checks.

## Docs — start here

| File | Purpose |
|---|---|
| [structure_file.md](structure_file.md) | **Read first.** File map: what each file is, how they connect, what to read per task |
| [CONTEXT.md](CONTEXT.md) | Product rules + UI interaction rules |
| [next_step.md](next_step.md) | Remaining work only |
| [update.md](update.md) | Short change log |
| [docs/FUNCTIONS.md](docs/FUNCTIONS.md) | Full feature spec |
| [docs/BACKEND_ARCHITECTURE.md](docs/BACKEND_ARCHITECTURE.md) | DB architecture |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Architecture decisions |
| [docs/ANATOMY_STILLS.md](docs/ANATOMY_STILLS.md) | Anatomy stills pipeline + licensing |
| [docs/widget/WIDGET.md](docs/widget/WIDGET.md) | iOS widget + Live Activity implementation |
