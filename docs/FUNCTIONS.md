# GYMMER Feature Spec

Current scope for the offline, single-user Flutter workout tracker.

## Product Scope

GYMMER is a local-only workout tracker for one user:

- No login, social features, followers, likes, comments, sharing, or cloud sync.
- Data is stored locally with SQLite on device; web/test fallback uses memory.
- Release target is iPhone. Android and web are development stand-ins.
- App is free and non-commercial; anatomy attribution ships in About.

The app has exactly three bottom tabs:

- Workout
- Library
- Profile

## Workout Home

The app opens directly to Workout.

Workout contains:

- Start Empty
- New Routine
- Routine folders
- Routines inside folders
- Active-workout resume bar when a draft exists

Routine folder behavior:

- Folders can collapse/expand for the current app session.
- Folder menu supports rename, move up, move down, and delete when empty.
- Folders are drop targets for dragged routines.

Routine card behavior:

- Tap opens the routine builder.
- Start Routine starts or resumes the single active workout.
- Swipe-left deletes.
- Long-press drag reorders or moves the routine across folders.
- Tapping the exercise-count chip expands a per-exercise list (name + set
  count). Folder headers do not show a routine-count badge.

## Routine Builder

A routine defines:

- Name
- Folder
- Exercise order
- Starting set count per exercise
- Optional rest timer per exercise

A routine does not define planned kg or reps.

Routine builder supports:

- Add exercise
- Replace exercise
- Remove exercise with swipe-left
- Reorder exercises with long-press drag
- Add/delete sets
- Rest timer in 15-second increments
- Save routine

Deleting a routine removes it from Workout but does not delete completed
history. Renaming a routine updates the routine label used for future display.

## Active Workout

Only one active workout can exist at a time. Starting another workout while one
exists opens the existing draft.

An active workout supports:

- Editable session name
- Reorder exercises
- Replace or remove exercises with swipe-left actions
- Editable kg/reps fields
- Add/delete sets
- Complete set checkbox
- Workout muscle map panel
- Elapsed timer in the app bar
- Finish or discard

Drafts persist across app close/reopen. Duration is based on real elapsed time
from start to finish.

Finish behavior:

- No confirmation.
- Only completed sets are saved.
- If no completed sets exist, no completed session is saved.
- Saving completed history and rebuilding snapshot tables happens through the
  store.

Discard behavior:

- Always requires confirmation.
- Saves nothing.

## iOS Widget And Lock Screen Activity

The iOS companion is available on the `ios` branch. It is an iOS 17 medium
WidgetKit widget with six views/pages:

- Start: start No Routine or page through routines supplied by the app.
- Add: browse four exercises per page, add/remove an exercise, or adjust the
  queued set count.
- Muscle and Equipment filters: choose a filter chip from paged 3×3 cells.
- Log: adjust REP by 1 or KG by 2.5, move to the next exercise, complete the
  current set, or open Manage.
- Manage: add/remove the current set or exercise, finish, discard, or return to
  Log.

The widget cannot provide text entry or scrolling, so numeric entry is done in
the Flutter app and paging replaces scrolling. Completing a set starts a local
notification-backed rest timer; `−15`, `+15`, and Skip are available while it
runs. The widget's rest countdown uses a self-ticking SwiftUI timer rather than
per-second WidgetKit timeline entries.

The Lock Screen and expanded Dynamic Island Live Activity reuse the same Add,
Muscle/Equipment Filter, Log, Rest, and Manage views as the home widget; only
Start is omitted. The foreground Flutter app starts or ends the activity. Every
control shown in the Activity runs as a shared `LiveActivityIntent` in Runner,
persists its mutation, updates ActivityKit, then reloads the home widget.

This companion is iOS-only and does not change the Android/web feature scope.

## Completed Sets And Autofill

A set qualifies as completed only when checked.

To complete a set:

- Kg must be filled.
- Reps must be filled.
- Kg can be 0 or decimal.
- Reps must be a positive whole number.

Set autofill order:

1. Previous for same exercise + same routine + same set position.
2. Most recent completed set for the same exercise in the current session.
3. Blank.

No Routine workouts do not feed routine-specific Previous values.

## Rest Timer

Rest timers change in 15-second increments.

When a completed set has a timer:

- The timer starts automatically.
- Completing another timed set replaces the running timer.
- Skip stops it.
- Add/subtract buttons adjust remaining time.

Timer logic lives in `RestTimerController`; UI listens to that controller.

## Library And Exercises

Library supports:

- Search by exercise name
- Favorite star
- Favorites sorted first
- Add Exercise
- Edit existing exercise
- Expand a row (anatomy icon) to preview that exercise's anatomy still inline

Exercise picker reuses the same search and favorites-first ordering.

Exercise fields:

- Name
- Primary muscle
- Secondary muscles
- Equipment
- Thumbnail (picked from the device photo library)
- Media list (images/videos picked from the device photo library)

Thumbnail and media are chosen from the device photo library (`image_picker`)
and copied into app-owned storage. There are no typed path/URL fields, and the
app keeps no live references to gallery/filesystem sources.

Create/Edit Exercise shows anatomy stills:

- Front/back anatomy stills
- Light-gray base model
- Primary muscle diff layer on top
- Secondary muscle diff layers beneath primary
- No schematic muscle map card on this page

The workout muscle map remains a separate 2D CustomPainter schematic used in
active workouts.

## Profile

Profile contains:

- Workouts count
- Finished-workout feed
- Weekly progress chart
- Dashboard entries
- About row

Finished-workout feed cards show:

- Session name/date
- Time
- Volume
- Records count or set count
- First few exercises

Tapping a workout opens detail. The detail page's Edit button opens a
whole-session editor: change the workout duration and every exercise's sets
(add / swipe-delete), with a live session set summary (Sets / Volume / Reps).
Exercises can't be added or removed. Per-exercise set edits are also reachable
from the exercise stats flow. Stores rebuild history snapshots after set edits;
editing only the duration does not touch snapshots.

## Calendar And Streaks

Profile Calendar shows:

- Week streak
- Rest days this week
- Month grids from earliest history to current month
- Workout days marked in the grid

Streak logic uses Monday-start weeks. The current in-progress week does not
break a streak.

## Measures

Measures supports body measurement entries:

- One entry per calendar date
- Nullable metrics
- Optional photo path
- Latest-values summary
- Entry list with swipe-delete
- Selectable per-metric trend chart

Saving an existing date updates that date's entry.

## Records And Exercise Stats

Exercise stats include:

- Searchable list of exercises with history
- Personal Records: heaviest, estimated 1RM, best set volume, best session
  volume
- Selectable trend chart
- Tappable session list
- Completed-session set edit flow

Records and trends are computed from completed history. They are not persisted
as independent source data.

## Local Data Rules

Completed workout history is the source of truth. Snapshot tables are caches
for fast Previous and best-stat reads.

Snapshots are rebuildable from history. Stores update/rebuild them when:

- A workout is finished.
- A completed session set is edited.

No cloud sync, export/import, backup file, or camera capture is included yet.
