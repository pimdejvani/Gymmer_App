# GYMMER Update Log

Short log, newest first. Full historic detail is archived in `backup/`
(gitignored) if ever needed.

## 2026-07-16 — Faster Live Activity feedback and explicit lock behavior

- KG/REP values on the Live Activity now use ActivityKit content state and
  `invalidatableContent`, producing the system blur while an update is pending.
- Live Activity mutations update the tapped Activity before requesting a Home
  Widget reload; Home Widget mutations retain their existing reload-first path.
- The configurable system Control is background-only. It remains the supported
  locked-device path because iOS disables
  ordinary Widget and Live Activity buttons until the device is unlocked.

## 2026-07-16 — Minimum deployment target raised to iOS 26

- Runner, GymmerWidget, and RunnerTests now all require iOS 26.0. CI continues
  compiling against the current iOS 26 SDK on the `macos-26` runner.

## 2026-07-16 — Configurable locked controls + HealthKit + native tests

- Removed the temporary voice/App Shortcut provider while preserving all
  widget, Live Activity, and system-Control features.
- Replaced six fixed iOS 18 Controls with one configurable Control that can be
  added multiple times and assigned to KG/REP +/−, Complete Set, Next Exercise,
  or Skip Rest. It reuses the original home-widget mutation path and requests
  `alwaysAllowed` execution.
- Every Live Activity button now injects `ActivityViewContext.activityID` into
  its intent. Updates, navigation, Finish, and Discard target that Activity
  directly instead of iterating all running Gymmer activities.
- Added an iOS 26 HealthKit workout lifecycle: indoor traditional-strength
  session + live builder on Start, save on Finish, discard on Discard, and
  active-session recovery after an iOS relaunch. Older iOS and denied HealthKit
  permission remain non-blocking.
- Added seven native XCTest cases for the shipped Swift intents and configurable
  Control dispatcher. CI now runs Flutter checks, native tests, and the macOS 26
  release build in parallel, then publishes only when every job passes.

## 2026-07-16 — Reliable session ending + iOS system Controls

- Finish and Discard now persist the terminal revision and reload the Home
  Widget before awaiting immediate ActivityKit dismissal, so an unavailable or
  slow Live Activity cannot leave either button visually stuck.
- Cold startup now reconciles widget-authored state before writing the SQLite
  draft back to the App Group, preventing a finished/discarded session from
  being resurrected when the app process had been terminated.
- Added the first iOS 18 system-Control implementation for KG/REP +/−, Complete
  Set, and Next Exercise. The current configurable form is described above.

## 2026-07-15 — iOS WidgetKit workout logger + Lock Screen Live Activity

Implemented on branch `ios` across the widget commits from `cdea8c8` through
`e5f2c88`.

- Added the `GymmerWidget` iOS 17 WidgetKit extension, limited to the medium
  family. It now has the six-page flow: Start, Add, Muscle filter, Equipment
  filter, Log, and Manage. App Intents power routine start, exercise paging and
  selection, set +/- controls, KG/REP steppers, next exercise, complete set,
  rest adjustment/skip, finish, and discard.
- Flutter now writes `catalog.json`, `routines.json`, and `session.json` to the
  shared App Group through `WidgetBridge`/`AppDelegate`. The widget writes
  session changes back with `by: "widget"` and a newer `rev`; Flutter detects
  those changes on resume, rebuilds the active workout, and persists them to
  SQLite. The bridge is a no-op outside iOS.
- Widget-added exercises autofill the most recent completed KG/REP values.
  Queued picker cells show exercise order and set count; filters are paged
  3×3, and the exercise list is paged four cells at a time. The Log layout is
  two rows: REP + next above KG + complete.
- Completing a widget set starts a rest countdown and schedules one local
  notification for the end. The widget uses SwiftUI's timer interval so the
  countdown does not consume per-second WidgetKit timeline entries.
- Added ActivityKit state shared by Runner and the extension. The foreground
  app starts/updates/ends one Live Activity; extension App Intents update the
  running activity while the app is backgrounded. The Lock Screen now reuses
  the widget's Add/Filter/Log/Rest/Manage pages and controls, omitting only the
  Start page, including a `restdone` state with a Finish button after the final
  set.
- Added runtime App Group discovery from the embedded provisioning profile so
  the app and extension continue to agree after SideStore rewrites the group
  identifier. The temporary `App Group POC v2` launch alert remains and is a
  release cleanup item in `next_step.md`.
- At this stage CI added a parallel debug iOS compile check and cancellation of
  superseded branch runs; the current three-job gated pipeline is listed above.
- Fixed Live Activity page navigation by moving `NavIntent` to a source file
  compiled into Runner and the widget target and adopting `LiveActivityIntent`.
  The expanded Dynamic Island now reuses the Lock Screen's interactive pages;
  phones without Dynamic Island use the Home Screen widget for persistent
  unlocked controls.
- Shortened iOS CI by running debug compile only for pull requests and release
  packaging only for pushes/manual runs, skipping docs-only changes, restoring
  incremental `build/ios` data, avoiding repeated pub resolution, and using
  faster IPA compression.
- Fixed delayed/stale interactive Live Activity controls by compiling all
  Activity-facing intents into Runner and adopting `LiveActivityIntent`. Weight,
  reps, exercise/set management, filters, rest controls, finish/discard, and
  navigation now update ActivityKit from the app process before reloading the
  home widget.
- Corrected the resulting Home Widget regression by splitting the intent types:
  the widget is back on its original extension-side `AppIntent` path, while the
  Live Activity uses Runner-side wrappers that dispatch to the same mutations.
  Removed numeric invalidation/transition feedback that caused KG/REP controls
  to blink. The current Live Activity-only pending blur is described above.
  Activity intents request `alwaysAllowed`, but iOS keeps this surface inactive
  while locked; Now Playing is a separate media API.

## 2026-07-14 — iOS photo permission recorded

- Confirmed `NSPhotoLibraryUsageDescription` is present in the generated iOS
  Runner plist. The old TODO in the docs was removed; photo picking is no
  longer an outstanding iOS setup item.

## 2026-07-10 — iOS platform + free CI build + SideStore sideload pipeline

Done on branch `ios` (not yet merged to `main`).

- Removed 13 unused `preview_*.png` debug renders (~36 MB) from the repo root
  and gitignored `preview_*.png`. They were one-off comparison images from the
  muscle-layer pipeline, referenced nowhere.
- Generated `gymmer_flutter/ios/` (`flutter create --platforms=ios`). Bundle id
  `com.gymmer.gymmerFlutter`, display name "Gymmer Flutter". No Mac needed to
  generate; builds happen in CI. Deleted the generic README flutter re-created.
- App icon set from `assets/Gymmer_Logo.png` via `flutter_launcher_icons`
  (dev dep + config block in `pubspec.yaml`; run `dart run flutter_launcher_icons`).
  iOS icons are flattened to RGB (no alpha) for App Store compliance. Android
  legacy mipmaps regenerated too (no adaptive icon — logo is full-bleed).
- New `.github/workflows/ios-build.yml` (runs on push to main/ios): builds an
  **unsigned** iOS app on a free `macos-15` runner, packages it as `Gymmer.ipa`,
  and on branch pushes publishes a GitHub Release (`build-<run>`) + regenerates
  `apps.json`. Build number = CI run number, so every push auto-bumps the
  version to `1.0.<run>` (iOS/SideStore see it as an update).
- New `apps.json` at repo root — a SideStore/AltStore source manifest pointing
  at the latest Release `.ipa`, committed back by CI each build. Subscribing a
  device to it gives free over-the-air auto-updates (no Mac, no $99 account).
  Source URL (branch `ios`):
  `https://raw.githubusercontent.com/pimdejvani/Gymmer_App/ios/apps.json`.
- Sideload path (Windows, free): install "Apple Devices" (Microsoft Store, gives
  usbmuxd) → iloader installs SideStore with a free Apple ID → add the source →
  install Gymmer from the Browse tab (NOT from file, or it won't auto-update) →
  SideStore Background Refresh re-signs every 7 days (data survives re-sign).

## 2026-07-10 — Delts/abs rework + session editing + media pickers

- Delts + abs anatomy layers now sample real fibre colour from an aligned
  colour plate (new `tools/render_color_plate.js`; `npm run plate` →
  `npm run layers`) instead of the old `upper-limb.glb` / thorax-glb overrides
  and the rectus-sheath overlay hack. The `Deltoid muscle.r` texture is cut by
  the Front/Rear/Side part masks (Side = `mask − (Front ∪ Rear)`); abs uses the
  whole abdominal-wall mask. Plate is rendered from `full-body.glb` at the still
  camera, so it is pixel-aligned to the masks (no projection mismatch). Abs
  reads pale, faithful to the tendon-heavy texture. Pipeline documented in
  `docs/ANATOMY_STILLS.md` (detailed spec archived in `backup/plans/`).
  (Tooling gotchas handled: Draco decompress + Chromium
  `--enable-unsafe-swiftshader`.)
- Profile workout detail: removed the "Edit Routine" entry point; the app-bar
  Edit now opens a whole-session editor (`screens/profile/edit_session_page.dart`)
  — edit the duration (h:m) and every exercise's sets (add / swipe-delete) with
  a live session summary (Sets / Volume / Reps); exercises can't be added or
  removed. New store method `updateCompletedWorkoutTimes` in both stores.
- Create/Edit Exercise thumbnail + media now pick from the device photo library
  via `image_picker` (Choose Image / Add Image / Add Video) instead of typing a
  path or URL. `NSPhotoLibraryUsageDescription` is present in the generated
  iOS Runner plist.
- Library rows gained a per-row anatomy-still expand (accessibility icon). The
  2D muscle map was intentionally not added to routine/session views.
- Home: routine folders no longer show a routine-count badge; a routine card's
  exercise-count chip expands a per-exercise list (name + set count).
- Checks: analyze clean, 65 tests pass, build web passes.

## 2026-07-09 — Plans 08-11 + home/measures follow-ups

- Added About GYMMER with required offline anatomy attribution text and a
  Flutter package-license link; Profile feed now has a quiet About row.
- Exercise stats now show Personal Records (heaviest, estimated 1RM, best set
  volume, best session volume) plus a selectable dot/line trend chart.
- Completed exercise sets can be edited from Profile → Exercises → detail;
  SQLite and memory stores refresh history-derived Previous/best snapshots.
- Create/Edit Exercise no longer shows the old Muscle Map card or still-combo
  images. Anatomy now uses 3D-derived base stills plus per-muscle primary and
  secondary diff layers; unselected muscles stay light gray in the base image.
- Interim anatomy override: Abs currently uses `External abdominal oblique
  muscle.r` texture plus an approximate anterior rectus-sheath overlay; this
  is not final and will be rebuilt.
- Interim anatomy override: Front/Side/Rear Delt currently use source
  `Muscle tiles plain` over aligned masks; all three delt layers will be
  rebuilt again.
- Profile workout detail can open the source routine in Routine Builder.
- Home routine folders can collapse/expand for the current app session.
- Measures now has a selectable per-metric trend chart.

## 2026-07-08 — Test + docs cleanup

- Trimmed 6 low-value full-app widget smoke tests whose logic is already
  covered by fast pure-Dart tests (library search-filter + sort-to-top,
  profile chip-switch + calendar-open, records feed-badge + Exercises-page).
  Kept every pure-logic, store/persistence, migration, and card-level test
  plus the core `widget_test.dart` regression suite. 62 → 56 tests, faster.
- Deleted stale/redundant `gymmer_flutter/README.md` (root `README.md` +
  `structure_file.md` are the current entry points).

## 2026-07-08 — Plan 07: Records (PR) + per-exercise stats

- New `lib/domain/records_service.dart` (pure): `recordsIn` (sets strictly
  beating every earlier session's best kg/volume; later sessions never erase
  an old badge), `statsFor` (best kg/volume, sessions, top-set-per-session
  series), `exercisesWithHistory`. Nothing new persisted — history is truth.
- Feed/detail stat row → `Time | Volume | 🏅 Records` when N>0 (else Sets).
- Finish → `🏅 N new record(s)` snackbar (computed in GymmerHome vs existing
  sessions before finishing; theme-default snackbar).
- New `screens/profile/exercise_stats_page.dart` (search list → best kg/vol/
  sessions + best-kg bar chart reusing WeeklyBarChart + session list).
  Dashboard gains **Exercises**.
- New `test/records_test.dart`.

## 2026-07-08 — Plan 06: Body measurements + progress picture

- New `lib/models/measurement.dart`: MeasurementEntry (per-date, all metrics
  nullable) + `measurementFields` descriptor list that drives the log form,
  the summary, and SQLite columns from one place.
- SQLite schema v3: `measurement_entries` (date_ms PK, photo_path, one REAL
  per metric). Store CRUD `loadMeasurements`/`saveMeasurement` (upsert by
  calendar date)/`deleteMeasurement` in both stores.
- New `screens/profile/measurements_page.dart` (summary + list, swipe-delete,
  `+` → log) and `log_measurement_page.dart` (blank form, latest as hint,
  photo copied via existing media_storage). Dashboard gains **Measures**.
- New `test/measurements_test.dart`.

## 2026-07-08 — Plan 05: Workout calendar + week streak

- New `lib/domain/streaks.dart` (pure): `weekStreak` (consecutive Monday-start
  weeks; in-progress current week doesn't break it) + `restDaysThisWeek`.
- New widgets: `dashboard_grid.dart` (2-col button grid, dumb entry list),
  `month_grid.dart` (Sunday-first month; filled circle + label on workout
  days, outlined today).
- New `screens/profile/calendar_page.dart`: 🔥 streak / 🌙 rest chips + month
  sections earliest→current (auto-scroll to bottom). DashboardGrid (Calendar
  entry) inserted between chart and feed in profile_tab.
- New `test/streaks_test.dart` + a Calendar widget test.

## 2026-07-08 — Plan 04: Weekly progress chart

- New `lib/domain/workout_aggregates.dart` (pure Dart): `ProgressMetric`,
  `weeklyTotals` (Monday-start, zero-filled, bucket by startedAt), and
  `thisWeekDuration`.
- New `lib/widgets/profile/weekly_bar_chart.dart`: monochrome CustomPainter
  (white bars, grey labels, sparse x labels, max/0 gridlines; no package).
- Profile top: `Xh Ym this week` headline + chart + Duration/Volume/Reps
  chips (Duration default) + range dropdown (3M=12/6M=26/Year=52 weeks).
- New `test/aggregates_test.dart` + a chip-switch widget test.

## 2026-07-08 — Plan 03: Profile tab + workout history feed

- New `lib/models/completed_workout.dart` (CompletedWorkout +
  CompletedWorkoutExercise; duration/totalVolumeKg/totalSets).
- `buildCompletedWorkout` in finish_workout_service.dart (same qualifying-set
  rule). Store `loadCompletedWorkouts()` (newest first): SQLite join over
  completed_workout_* (no migration), memory store keeps a list + seeds 1
  demo entry mirroring WorkoutHistory.seeded.
- 3rd nav tab **Profile**: Workouts count header + feed
  (`widgets/profile/workout_feed_card.dart`, Time/Volume/Sets, first 3
  exercises, "See N more") → `screens/profile/workout_detail_page.dart`.
- New `test/profile_test.dart`.

## 2026-07-08 — Plan 02: Live rest timer + haptics + elapsed time

- New `lib/domain/rest_timer.dart` (`RestTimerController extends
  ChangeNotifier`): single `Timer.periodic(1s)`, `start/skip/addSeconds`,
  `remaining`/`running`, `onFinished`; cancels on skip/finish/dispose.
- Rest pill now live: `[−15]  mm:ss  [+15]`, tap time = skip; hidden when not
  running; keeps the accent styling. Page owns one controller; completing a
  set (re)starts it. On finish → `HapticFeedback.heavyImpact()` ×2 (200ms
  apart) + `SystemSound.click`.
- New `lib/widgets/workout/elapsed_time_label.dart`: self-contained h:mm:ss
  ticker in the Active Workout app bar (own timer, cancelled in dispose).
- Added `fake_async` dev dep; new `test/rest_timer_test.dart`.

## 2026-07-08 — Plan 01: Library search + favorites

- `Exercise.isFavorite` (mutable, last positional); store
  `setExerciseFavorite`; SQLite schema v2 migration
  (`exercises.is_favorite`); memory store mutates in place.
- Library tab: pinned search field (case-insensitive name-contains) + per-row
  star toggle (white/grey tokens, accent stays reserved); favorites sort
  first. Exercise picker got the same search + favorites-first sort
  (read-only). Shared `filterAndSortExercises` / `ExerciseSearchField`.
- Tests: extracted `pumpGymmer`/`openTestStore` into
  `test/support/test_app.dart`; new `test/library_test.dart`.

## 2026-07-08 — Device audit passed; roadmap planned (plans/)

- DB audit #1/#4 verified on a real Galaxy S22 Ultra (clean install OK; draft
  survives Force Stop). Whole audit now green.
- Decisions: app is free/non-commercial (abs NC license OK, attribution due);
  release target iOS only (Android signing dropped); Hevy-style single-user
  Profile tab approved (3rd nav tab — no social).
- New `plans/` folder originally held self-contained session specs 01–08
  (library search/favorites, live rest timer, profile+feed, weekly chart,
  calendar/streak, measurements, records/exercise stats, about/credits).
  Completed plans are now archived in `backup/plans/`; current workspace docs
  keep only actionable next steps.

## 2026-07-08 — Restructure: decentralized files, docs cleanup, −73 MB

- Code decentralized so a session reads only what it needs (map in
  `structure_file.md`): `models.dart` → barrel over `models/{exercise,routine,
  workout,history}.dart`; home screen split into `widgets/home/*`; active
  workout widgets into `widgets/workout/*`; `CreateExercisePage` into its own
  file; muscle-map painter split from panels; shared `reorderProxyDecorator`
  deduped into `shared_widgets.dart`.
- Removed dead code/deps: `model_viewer_plus` (no runtime 3D anymore),
  `runtime_flags*` (moved to backup), anatomy panel renamed
  `exercise_anatomy_panel.dart` + themed.
- Assets: kept only `full-body.glb` (stills source, no longer bundled into the
  app — pubspec now ships generated anatomy layer PNGs). Other 5 glbs (~41 MB) +
  node_modules (~26 MB) removed; `tools/render_muscle_stills.js` is now
  self-contained (vendored model-viewer, serves the glb directly), puppeteer/
  sharp added to package.json.
- Docs: merged 8 ADRs → `docs/DECISIONS.md`; new `docs/ANATOMY_STILLS.md`
  (pipeline + licensing); deleted/archived OPEN3DMODEL_RESEARCH,
  IMPLEMENTATION_PLAN, UI_REDESIGN_SPEC, implement.md, NEXT_SESSION_PROMPT,
  parent next_step/update; rewrote CONTEXT/README/next_step/update; added
  `structure_file.md`. `backup/` + `node_modules/` gitignored.
- Checks: analyze clean, 22 tests pass, build web passes.

## 2026-07-08 — UI rebuild: black-minimal theme + native gestures

- True-black theme (`lib/theme/app_theme.dart`), white primary buttons, green
  accent as signal only; iOS-style transitions everywhere.
- App shell: bottom nav (Workout / Library) + pulsing resume bar.
- Gestures replace buttons: long-press drag (routines across folders,
  exercise reorder), swipe-left action buttons (Delete / Remove / Replace)
  via `flutter_slidable`. Move Up/Down arrows and per-card menus removed.
- Anatomy tab removed at user request (stills panel on exercise page stays).

## 2026-07-07 — Anatomy stills pipeline (replaces live 3D)

- Exercise page shows pre-rendered front/back PNG layers from `full-body.glb`.
  Current generation uses a light-gray base plus primary/secondary diff
  overlays; regeneration: `docs/ANATOMY_STILLS.md`.

## 2026-07-06 — SQLite store + DB audit (automated part)

- drift store with numbered migrations, draft vs history tables, Previous /
  best snapshot tables; audit checks #2 #3 #5–#8 proven by integration tests
  (#1 #4 need a device — see next_step.md).
