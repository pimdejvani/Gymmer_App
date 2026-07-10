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
unsigned iOS `.ipa` on a free `macos-15` runner, publishes it as a GitHub
Release, and regenerates [`apps.json`](apps.json) — a SideStore source. Build
number = CI run number, so the version auto-bumps to `1.0.<run>` each push.

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
`assets/Gymmer_Logo.png`). See `update.md` (2026-07-10) for full detail.

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
