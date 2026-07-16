# Architecture Decisions

Merged from the former `docs/adr/` stubs (0001–0008), one section each.
Newer decisions get appended here with a date.

## 1. Flutter, iPhone-first

Built with Flutter/Dart, iPhone-first UX. Portable implementation while the
prototype focuses on offline local storage, media picking, haptics, and
dark-mode interaction quality.

## 2. SQLite local database

SQLite from Dart (drift) for local persistence: direct control over schema,
migrations, indexes, snapshot tables, history queries, and backup/restore.

## 3. History is source of truth; snapshots are cache

Completed workout history is immutable source data. Statistic snapshots
(Previous by exercise+routine+set position; bests per source scope) are
derived cache tables written in the same transaction as history at Finish,
and can be dropped and rebuilt from history at any time.

## 4. File-based exercise media

Exercise icons/media are copied into app-owned storage; SQLite stores paths
and metadata only. No live references to the user's photo library, no blobs
in the database.

## 5. Active draft tables separate from history tables

The active workout draft changes constantly during a session; completed
history is written once at Finish. Separate tables keep the write patterns
and integrity guarantees apart.

## 6. Numbered SQLite migrations

Schema managed with numbered migrations from the start so local data evolves
without database resets.

## 7. Layered app structure

Widgets / screen state / domain rules / data access stay separated. Screens
never own SQL; domain rules (e.g. which sets qualify at Finish) live in
`lib/domain/` and are shared by every store implementation.

## 8. Dark-mode-first compact phone layout

App name GYMMER; dark-mode-first, offline-first, optimized for compact phone
layouts before broader platform polish.

## 9. (2026-07-07, updated 2026-07-09) Pre-rendered anatomy stills instead of runtime 3D

The exercise anatomy view uses offline-rendered 2D PNGs instead of a live
WebView 3D viewer — works on every platform, no heavy runtime dependency. The
runtime stack is a light-gray front/back base plus transparent per-muscle
primary and secondary diff layers. Pipeline and licensing:
`docs/ANATOMY_STILLS.md`.

## 10. (2026-07-08) Gestures replace buttons; single theme file

Native app gestures (long-press drag, swipe-left action buttons) replace the
old arrow/menu/trash buttons — a gesture and a button for the same action
never coexist. All colors/typography live in `lib/theme/app_theme.dart`;
screens must not hardcode colors.

## 11. (2026-07-15) iOS widget uses disposable App Group snapshots

The iOS WidgetKit extension cannot call the Flutter store directly. The app
therefore writes `catalog.json`, `routines.json`, and `session.json` into the
shared App Group container. `session.json` is the only bidirectional file:
widget App Intents write `by: "widget"` plus a monotonic `rev`, and Flutter
reconciles a newer revision into SQLite when the app resumes. SQLite remains
the durable source of truth; the JSON files are projections and an IPC
boundary, not a second database.

The App Group identifier is resolved from the installed provisioning profile at
runtime because SideStore can rewrite it during re-signing. Both Runner and
WidgetKit use the same resolver.

## 12. (2026-07-15) Live Activity starts and interactive intents run in Runner

Only the foreground app starts the ActivityKit Live Activity. Flutter sends the
current workout state through the `gymmer/widget` method channel; Runner starts,
updates, or ends the activity. Activity controls use dedicated
`LiveActivityIntent` wrappers compiled into Runner because Apple runs those
intents in the app process. The wrappers dispatch to the same mutation
implementations as the ordinary home-widget `AppIntent`s, then update ActivityKit
and reload the home widget. Keeping distinct intent types preserves the original
extension execution path and response behavior of the home widget.

The companion target initially used iOS 17 and supports the medium home widget plus Lock
Screen/Dynamic Island presentations. The Lock Screen and expanded Dynamic
Island deliberately reuse the home widget's Add/Filter/Log/Rest/Manage surface
and omit only Start. Although Activity intents request the `alwaysAllowed`
authentication policy, iOS keeps Widget and Live Activity buttons inactive
until unlock. Now Playing controls are a separate media-only system.
A device without Dynamic Island has no persistent unlocked Live Activity
surface, so the Home Screen widget is the unlocked alternative.

## 13. (2026-07-16) High-frequency actions use one configurable system Control

iOS 18 Control Widgets are the appropriate system-owned, non-media surface for
locked-device workout actions. Gymmer exposes one `AppIntentControlConfiguration`
that people can add multiple times and configure as KG/REP +/−, Complete Set,
Next Exercise, or Skip Rest. Its `alwaysAllowed` action dispatches to the same
ordinary mutation intents as the home widget. This does not replace the richer
Live Activity. The source retains availability annotations, while the shipped
build now requires iOS 26 per decision 17.

On iOS 26 the configurable Control explicitly supports background execution
and restricts execution to the WidgetKit extension. It is the supported path
for locked-device workout actions; the full Live Activity cannot bypass the
system's unlock requirement.

Finish and Discard persist and request the home-widget redraw before awaiting
ActivityKit dismissal. App startup must reconcile a newer widget-authored
terminal revision before pushing the SQLite draft, or an ended workout can be
accidentally restored.

## 14. (2026-07-16) Live Activity mutations target an explicit Activity ID

Every Activity button receives `ActivityViewContext.activityID`. The shared
button wrapper injects it into `LiveActivityIntent`; ActivityKit update/end then
filters `Activity.activities` by that ID. Home-widget and system-Control intents
leave the target empty and retain their existing all-running-activity refresh.
The ID is task-local during dispatch, so every action still uses one mutation
implementation and concurrent intents cannot leak a target into each other.

## 15. (2026-07-16) HealthKit follows Gymmer's session lifecycle on iOS 26+

On iOS 26 and later, the Runner starts an indoor traditional-strength
`HKWorkoutSession` and associated live builder when a Gymmer session starts.
Finish stops collection and saves the HealthKit workout; Discard calls
`discardWorkout`. Recovery reattaches the session and builder delegates if iOS
relaunches the app. The integration requests only workout write access and is
availability/permission tolerant. No voice intent extension or shortcut
provider is part of this architecture.

## 16. (2026-07-16) CI tests native intents before publishing

XCTest redirects `WStore` into a temporary directory and exercises the same
Swift intents shipped by the widget, Live Activity, and system Control. Flutter
checks, native tests, and the unsigned iOS 26 build are separate parallel jobs;
the publish job depends on all three so test speed and release gating coexist.

## 17. (2026-07-16) All Apple targets require iOS 26

Runner, GymmerWidget, and RunnerTests use deployment target iOS 26.0. The app is
intentionally optimized for the current device OS and no longer promises iOS
13–25 installation compatibility. CI continues compiling with the current iOS
26 SDK on the `macos-26` runner. Existing availability annotations remain as
local API documentation and do not change the deployment requirement.
