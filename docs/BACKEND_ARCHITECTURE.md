# GYMMER Local Architecture

Last reviewed: 2026-07-16.

GYMMER does not use a remote backend in the prototype. The backend boundary is an on-device local data layer built with SQLite from Flutter/Dart, plus app-owned file storage for exercise icons and media.

## Local Boundary

The local backend boundary is inside the app process:

- Flutter widgets call screen state.
- Screen state calls domain services and repository interfaces.
- Domain services enforce workout, exercise library, rest timer, and statistics rules.
- SQLite-backed repositories read and write local data.
- Media storage copies imported files into app-owned storage and returns relative file metadata.
- On iOS, `WidgetBridge` mirrors selected state to a WidgetKit extension through
  an App Group container; this is a local IPC/snapshot boundary, not a remote
  backend.
- On iOS 26+, Runner mirrors the active-session lifecycle into a HealthKit
  workout session. HealthKit is a user-authorized system store, not Gymmer's
  durable database and not a synchronization source for SQLite.

Widgets do not own SQL rules.

## Storage Components

SQLite stores structured app data:

- muscles
- equipment
- exercises
- exercise secondary muscles
- exercise media metadata
- routine groups
- routines
- routine exercises
- routine set positions
- active workout sessions
- active workout exercises
- active workout sets
- completed workout sessions
- completed workout exercises
- completed workout sets
- previous set snapshots
- exercise best set snapshots
- measurement entries

The iOS companion also uses three JSON snapshots in the App Group container:

- `catalog.json` — exercise picker data plus the latest cross-routine set for
  widget autofill.
- `routines.json` — routine names, folders, exercises, and set templates for
  starting a routine from the widget.
- `session.json` — the active workout shared by Flutter and the widget. The
  widget stamps `by: "widget"` and a newer microsecond `rev` when it mutates
  the file; the app pulls that revision back into SQLite on resume.

The snapshots are disposable projections of SQLite state. The widget can
operate without the app being foregrounded, but only the Flutter app finishes
the widget-authored session into completed-history tables after reconciliation.

Exercise thumbnail and media are picked from the device photo library (`image_picker`), then copied into app storage; only the resulting relative path/metadata is persisted. The app does not keep live references to Photos or external file picker locations. Compression and camera capture are out of prototype scope.

## HealthKit Workout Projection

On iOS 26+, starting a Gymmer workout requests workout-write authorization and
starts an indoor traditional-strength `HKWorkoutSession` with an associated
live builder. Finish saves the native workout; Discard drops builder results.
Recovery reattaches delegates if iOS relaunches the app for an active workout.
This projection does not read Gymmer history back from HealthKit and failure or
denied permission never blocks the SQLite workout flow.

## Source Of Truth

Completed workout history is authoritative. Snapshot tables are caches.

When a workout finishes:

1. Read the active workout draft.
2. Save only completed sets into completed history tables.
3. Rebuild statistic snapshots in the same SQLite write transaction.
4. Clear the active draft.

If a workout has no completed sets, no completed session is saved and the active draft is cleared.

Completed session edits are allowed from Profile. For set edits stores update
the completed set rows, then rebuild the history-derived Previous and best
snapshots so active-workout stats stay consistent. Editing a session's
duration (`updateCompletedWorkoutTimes`) rewrites only the session's
start/end timestamps — the per-set rows and snapshots are untouched.

## Active Draft Model

Only one active workout session can exist at a time. Starting a new workout while one exists returns the existing active draft.

Active draft tables are separate from completed history tables because draft data changes frequently while completed history should be immutable source data.

SQLite migration v4 removes leftover prototype seed groups/routines and only
deletes seed exercises that are not referenced by active or completed history.
Fresh installs start blank; real user data survives the cleanup migration.

## Statistics Snapshots

Snapshot tables support fast reads during an active workout:

- Previous by exercise, routine, and set position
- Max Volume by exercise and routine source
- Max Weight by exercise and routine source
- All Routines source
- No Routine source

Previous never falls back to another routine. No Routine workouts do not provide Previous values, but they are included in Max Volume and Max Weight through No Routine and All Routines sources.

Exercise PRs and trend charts are computed from completed history; they are not
persisted separately.

## Measurements

Body measurement entries are keyed by calendar date. Each metric is nullable,
and saving the same date updates the existing entry. The metric descriptor list
in `lib/models/measurement.dart` drives form fields, summaries, and SQLite
columns.

## CI

GitHub Actions separates work into parallel jobs:

- Ubuntu: dependency restore, static analysis, and Flutter widget/unit tests.
- macOS 26: native XCTest against real App Intent implementations.
- macOS 26: release iOS build and unsigned IPA packaging.
- Push-only publish waits for every job, then creates the GitHub Release and
  regenerates the SideStore `apps.json` manifest.
