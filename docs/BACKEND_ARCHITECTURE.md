# GYMMER Local Architecture

GYMMER does not use a remote backend in the prototype. The backend boundary is an on-device local data layer built with SQLite from Flutter/Dart, plus app-owned file storage for exercise icons and media.

## Local Boundary

The local backend boundary is inside the app process:

- Flutter widgets call screen state.
- Screen state calls domain services and repository interfaces.
- Domain services enforce workout, exercise library, rest timer, and statistics rules.
- SQLite-backed repositories read and write local data.
- Media storage copies imported files into app-owned storage and returns relative file metadata.

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

Exercise thumbnail and media are picked from the device photo library (`image_picker`), then copied into app storage; only the resulting relative path/metadata is persisted. The app does not keep live references to Photos or external file picker locations. Compression and camera capture are out of prototype scope.

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

GitHub Actions should run Flutter checks from `gymmer_flutter`:

- dependency restore
- static analysis
- widget and unit tests
