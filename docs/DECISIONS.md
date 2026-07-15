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

The companion target is iOS 17 and supports the medium home widget plus Lock
Screen/Dynamic Island presentations. The Lock Screen and expanded Dynamic
Island deliberately reuse the home widget's Add/Filter/Log/Rest/Manage surface
and omit only Start. Activity intents request the `alwaysAllowed` authentication
policy as a best effort, but iOS owns Lock Screen authorization and may still
require authentication. Now Playing controls are a separate media-only system.
A device without Dynamic Island has no persistent unlocked Live Activity
surface, so the Home Screen widget is the unlocked alternative.

## 13. (2026-07-16) High-frequency workout actions use iOS system Controls

iOS 18 Control Widgets are the appropriate system-owned, non-media surface for
KG/REP adjustments, Complete Set, and Next Exercise. They reuse the ordinary
widget mutation intents with `alwaysAllowed` and can be placed by the user in
Control Center, the Lock Screen control slots, or on the Action button. They do
not replace the richer Live Activity and are availability-gated so iOS 17 keeps
the existing widget and Activity behavior.

Finish and Discard persist and request the home-widget redraw before awaiting
ActivityKit dismissal. App startup must reconcile a newer widget-authored
terminal revision before pushing the SQLite draft, or an ended workout can be
accidentally restored.
