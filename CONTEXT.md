# GYMMER Context

Last reviewed: 2026-07-16 (`ios` branch, configurable controls + HealthKit).

GYMMER is a single-user offline workout tracker. Flutter only; the Swift
project at repo root is dead legacy.

Target platforms: iPhone (primary), Android (dev stand-in), Web (dev
iteration). Desktop is out of scope.

## Product rules

- Opens directly to the Workout screen. No login, no social features
  (followers/likes/comments/share), no cloud sync — single user, offline.
- Bottom navigation has exactly three tabs: Workout, Library, Profile.
  (Pivot approved 2026-07-08: Profile is a Hevy-style single-user dashboard —
  history feed, weekly chart, calendar/streak, measurements, records.)
- App is free & non-commercial (locked 2026-07-08) — keeps the CC BY-NC-SA
  abs-derived anatomy assets legal; in-app attribution ships in About.
- Routine Groups (folders) organize Routines; a Routine is a reusable plan
  (exercises, order, set counts, rest timers — never planned weight/reps).
- Only ONE Active Workout Session can exist at a time; it must survive app
  close/reopen (SQLite draft tables). A resume bar shows above the nav bar
  while one exists.
- Completed history is the source of truth; statistic snapshots (Previous,
  Max Volume, Max Weight) are rebuildable cache tables.
- Previous = same exercise + same routine + same set position. "No Routine"
  sessions never feed routine Previous values, but do count for All-Routines
  bests.
- Exercise thumbnail + media are picked from the device photo library
  (`image_picker`) then copied into app-owned storage — never live gallery
  references, never typed paths/URLs.

## UI interaction rules (as implemented 2026-07-08)

- Modern-minimal true-black theme: black `#000000` background, white primary
  buttons, one green accent used ONLY as a signal (completed set, rest pill,
  resume dot). All tokens in `lib/theme/app_theme.dart`.
- Gestures replace buttons — never both:
  - Routine card: long-press drag to reorder / move across folders (folder
    header + cards are drop targets), swipe-left → Delete, tap → edit.
  - Exercises in Routine Builder / Active Workout: long-press drag to reorder,
    swipe-left → Remove (Active Workout also has Replace).
  - Set row: swipe-left → Delete.
  - Folders keep a `...` menu (rename / move up / move down / delete empty).
- Anatomy on Create/Edit Exercise = pre-rendered 2D anatomy stills
  (front/back) with light-gray base + primary/secondary diff layers, not a
  live 3D viewer. Workout muscle map = 2D CustomPainter schematic.

## Current implementation state

- SQLite (drift) persistence with numbered migrations and snapshot tables;
  in-memory store on web. DB audit fully passed — #2/#3/#5–#8 by tests,
  #1/#4 verified on a real device (Galaxy S22 Ultra, 2026-07-08: clean
  install + draft survives Force Stop).
- Release target: iOS. The repository can generate platform files on Windows
  and CI builds the unsigned IPA on macOS; local Xcode/device work still needs
  a Mac. Android is a dev stand-in only — no Play release or Android signing.
- Library tab + exercise picker have a name search field and per-exercise
  favorite star (favorites sort first; `exercises.is_favorite`, schema v2).
- 3 bottom-nav tabs live: Workout / Library / Profile. Profile shows a
  Workouts count + finished-workout feed (tap → detail); store
  `loadCompletedWorkouts` (lazy, newest first).
- Profile also has: weekly progress chart (Duration/Volume/Reps, range
  selector), a dashboard grid → Calendar (streak/rest) and Measures (body
  measurements, schema v3 `measurement_entries`).
- Profile workout detail → app-bar Edit opens a whole-session editor: change
  the duration and every exercise's sets, with a live session set summary
  (no add/remove exercise). Per-exercise set edits are also reachable from
  Exercises → stats.
- iOS companion is implemented on branch `ios`: a WidgetKit medium widget
  provides a six-page workout flow (Start, Add, Muscle/Equipment filters, Log,
  Manage) and reads/writes the active session through the App Group container.
  The Lock Screen and expanded Dynamic Island Live Activity reuse the widget's
  Add, Muscle/Equipment Filter, Log, Rest, and Manage pages (without Start).
  Home-widget controls retain ordinary `AppIntent`s in the extension. Live
  Activity controls use Runner-side `LiveActivityIntent` wrappers that dispatch
  to the same mutation implementations, so the widget keeps its original fast
  path while ActivityKit is refreshed from the app process.
  Every Live Activity button carries `ActivityViewContext.activityID`, so its
  Runner intent updates or ends only the Activity that was tapped. On iOS 18+,
  one configurable system Control can be added multiple times and assigned to
  KG/REP +/−, Complete Set, Next Exercise, or Skip Rest in Control Center, the
  Lock Screen control slots, and Action button. No voice/shortcut integration
  is published. A composed Control Center design with a combined dynamic
  `KG · REP` value is specified but not implemented; see
  `docs/widget/SYSTEM_CONTROLS.md`.
- On iOS 26+, starting a Gymmer session also starts an indoor traditional-
  strength `HKWorkoutSession`; Finish saves it to HealthKit and Discard drops
  it. The lifecycle is availability-gated and the app remains functional when
  HealthKit is unavailable or permission is denied.
- Widget state is shared through `catalog.json`, `routines.json`, and
  `session.json`. The Flutter app reconciles widget-authored `session.json`
  revisions into SQLite when it resumes; widget/native failures are ignored on
  non-iOS platforms. Startup reconciles a terminal widget revision before
  writing SQLite draft state back, preventing a finished session from reviving.
- Library rows can expand to show the exercise's anatomy still; a routine
  card's exercise-count chip expands its exercise list (name + set count);
  routine folders no longer show a routine-count badge.
- Delts/abs anatomy layers are rebuilt from an aligned real-colour plate (real
  fibre texture, no projection mismatch); see `docs/ANATOMY_STILLS.md`.
- Verification last recorded: `flutter analyze` clean and `flutter test` (65
  tests) pass (2026-07-16). CI runs Flutter checks, seven native XCTest intent
  cases, and the iOS 26 release build in parallel, then publishes only if all
  three jobs pass.
- File layout: see `structure_file.md` (read that first each session).
