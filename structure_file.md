# GYMMER Structure Map

Read THIS FILE FIRST every session. It tells you which files to read for a
given task — read only those. Last updated: 2026-07-15.

App code root: `gymmer_flutter/lib/`. Run commands from `gymmer_flutter/`
with `C:\Users\pimde\develop\flutter\bin\flutter.bat` (not on PATH).

```powershell
flutter.bat analyze ; flutter.bat test        # quick check (every change)
flutter.bat build web                         # release-shaped compile check
flutter.bat run -d chrome                     # run the app
```

## File map (what each file is)

### Entry / theme
| File | Contents |
|---|---|
| `lib/main.dart` | MaterialApp + theme wiring only |
| `lib/theme/app_theme.dart` | ALL colors (AppColors), anatomy highlight colors, radii, text styles, transitions. Never hardcode a color anywhere else |

### Models (pure data, no UI) — import via barrel `lib/models.dart`
| File | Contents |
|---|---|
| `lib/models/exercise.dart` | Exercise, ExerciseMedia (catalog entities) |
| `lib/models/completed_workout.dart` | CompletedWorkout + CompletedWorkoutExercise (finished-workout view for Profile; nullable store id for session edits; duration/totalVolumeKg/totalSets) |
| `lib/models/measurement.dart` | MeasurementEntry (per-date body metrics, all nullable) + `measurementFields` descriptor list (drives form/summary/SQL) |
| `lib/models/routine.dart` | RoutineGroup (folder), Routine, RoutineExercise (plans) |
| `lib/models/workout.dart` | ActiveWorkout, WorkoutExercise, WorkoutSet (live session; sets hold TextEditingControllers) |
| `lib/models/history.dart` | WorkoutHistory, CompletedSetRecord + previousFor() query |

### Domain rules
| File | Contents |
|---|---|
| `lib/domain/finish_workout_service.dart` | Single source of truth for which sets get recorded at Finish; also `buildCompletedWorkout` (Profile view) — shared by both stores |
| `lib/domain/rest_timer.dart` | RestTimerController (ChangeNotifier): live rest countdown, start/skip/addSeconds/onFinished; one periodic timer |
| `lib/domain/workout_aggregates.dart` | Pure-Dart weekly bucketing (Monday-start): ProgressMetric, weeklyTotals, thisWeekDuration, mondayOf |
| `lib/domain/streaks.dart` | Pure-Dart weekStreak + restDaysThisWeek (Monday-start) |
| `lib/domain/records_service.dart` | Pure-Dart PRs (recordsIn) + per-exercise stats/trend values (statsFor, exercisesWithHistory); computed from history, nothing persisted |

### Data (persistence) — screens never touch SQL directly
| File | Contents |
|---|---|
| `lib/data/workout_store.dart` | Abstract WorkoutStore interface + WorkoutStoreState + completed-session set edit API |
| `lib/data/workout_store_sqlite.dart` | SQLite store (drift): schema, numbered migrations, snapshot tables, completed-session set edits with snapshot rebuild. The one big file — by design |
| `lib/data/workout_store_memory.dart` | In-memory store (web fallback + widget tests), including completed-session set edits |
| `lib/data/workout_store_factory.dart` | Conditional import: picks sqlite (io) or memory (web) |
| `lib/data/seed_data.dart` | Seed exercises/routines. Anatomy rendering now uses `muscleMapNames`; seed exercise combo parsing is no longer required |
| `lib/data/media_storage*.dart` | Copy exercise media into app-owned storage (io/stub pair) |
| `lib/data/widget_bridge.dart` | iOS App Group bridge: writes catalog/routines/session JSON, starts or ends the Live Activity, and rebuilds widget-authored sessions on resume |

### Screens (stateful pages; own store calls + dialogs)
| File | Contents |
|---|---|
| `lib/screens/workout_home_screen.dart` | GymmerHome: app shell (bottom nav Workout/Library/Profile), store lifecycle, resume bar, all routine/folder mutations, widget sync/reconciliation, drag auto-scroll |
| `lib/screens/active_workout_page.dart` | Active session page: reorder/swipe exercise list, set complete + rest pill, finish/discard |
| `lib/screens/routine_builder_page.dart` | Routine editor: name/folder fields + reorderable exercise list + ExerciseEditorCard |
| `lib/screens/exercise_library_page.dart` | Library tab: search field + exercise list rows + favorite star + per-row anatomy-still expand (accessibility icon). Exports `filterAndSortExercises` / `ExerciseSearchField` (reused by picker) |
| `lib/screens/create_exercise_page.dart` | Create/Edit exercise form + live muscle-map/anatomy preview + thumbnail/media pickers (image_picker; device photo library, no path/URL text) |
| `lib/screens/profile/profile_tab.dart` | Profile tab (3rd nav): Workouts count header + finished-workout feed (FutureBuilder over loadCompletedWorkouts), dashboard entries, About link |
| `lib/screens/profile/workout_detail_page.dart` | One finished workout: stat row + every exercise's sets (kg × reps); app-bar Edit → whole-session editor (no routine editing here) |
| `lib/screens/profile/edit_session_page.dart` | Whole-session editor: duration (h:m) + every exercise's sets (kg/reps, add/swipe-delete) + live session set stats; no add/remove exercise. Uses `updateCompletedExerciseSets` + `updateCompletedWorkoutTimes` |
| `lib/screens/profile/about_page.dart` | About GYMMER + required anatomy license credits + Flutter package licenses |
| `lib/screens/profile/calendar_page.dart` | Streak chips (🔥 streak / 🌙 rest) + month grids earliest→current, auto-scroll to bottom |
| `lib/screens/profile/measurements_page.dart` | Selectable per-metric trend chart + latest-values summary + entry list (swipe-delete) + `+` → log page |
| `lib/screens/profile/log_measurement_page.dart` | Blank measurement form (date, photo path, metric fields; blank=null, latest as hint) |
| `lib/screens/profile/exercise_stats_page.dart` | Searchable history-exercise list → detail (PRs + selectable trend chart + tappable session list) |
| `lib/screens/profile/edit_session_sets_page.dart` | Edit one exercise's completed-session sets (kg/reps/add/delete) then refresh history-derived stats |

### Widgets (display only; callbacks up, no store access)
| File | Contents |
|---|---|
| `lib/widgets/shared_widgets.dart` | SurfaceCard, RestTimerButton+dialog, StepperButton, reorderProxyDecorator |
| `lib/widgets/home/home_widgets.dart` | ResumeBar (pulse), WorkoutHeader, QuickActions, EmptyHome |
| `lib/widgets/home/routine_card.dart` | Routine card: long-press drag + drop-target + swipe Delete + tap-to-edit; tap the exercise-count chip → expand per-exercise list (name + set count) |
| `lib/widgets/home/routine_group_section.dart` | Collapsible folder header (drop target + menu, no routine-count badge) + cards + empty-folder drop zone |
| `lib/widgets/workout/workout_exercise_card.dart` | Exercise card in session + SetRow (swipe Delete per set) |
| `lib/widgets/workout/rest_timer_pill.dart` | Accent rest countdown pill: listens to RestTimerController, [−15] mm:ss [+15], tap = skip |
| `lib/widgets/workout/elapsed_time_label.dart` | Self-contained h:mm:ss elapsed ticker for the Active Workout app bar (own timer) |
| `lib/widgets/muscle_map.dart` | WorkoutMuscleMapPanel card (re-exports painter) |
| `lib/widgets/body_muscle_painter.dart` | 2D workout muscle-map CustomPainter + muscleMapNames + normalizeMuscle |
| `lib/widgets/exercise_anatomy_panel.dart` | Create/Edit Exercise anatomy-still layer panel (base front/back + per-muscle diff overlays, no still combos) |
| `lib/widgets/exercise_picker_page.dart` | Add/Replace exercise picker list |
| `lib/widgets/profile/workout_feed_card.dart` | Feed card (name, relative date, Time/Volume/(🏅 Records or Sets) row, first 3 exercises, "See N more") + shared `WorkoutStatsRow` + format helpers |
| `lib/widgets/profile/weekly_bar_chart.dart` | Monochrome weekly bar chart CustomPainter (white bars, grey labels, no accent, no package) |
| `lib/widgets/profile/trend_line_chart.dart` | Accent dot/line trend chart with min/max labels and semantics for exercise stats + measurements |
| `lib/widgets/profile/dashboard_grid.dart` | 2-col grid of dashboard buttons (dumb list of DashboardEntry icon/label/onTap) |
| `lib/widgets/profile/month_grid.dart` | One month grid (Sunday-first); workout day = filled circle + tiny label, today = outlined. Pure display |

### iOS native companion
| File | Contents |
|---|---|
| `ios/GymmerWidget/GymmerWidget.swift` | iOS 17 medium WidgetKit widget: Start/Add/Filter/Log/Manage pages, App Intents, rest notification, shared JSON store, and Live Activity rendering that reuses Add/Filter/Log/Rest/Manage |
| `ios/GymmerWidget/GymmerActivityAttributes.swift` | ActivityKit attributes/state shared by Runner and WidgetKit targets |
| `ios/Runner/AppDelegate.swift` | Flutter method channel for App Group files plus foreground Live Activity start/update/end |
| `ios/Runner/SceneDelegate.swift` | Temporary App Group provisioning probe; remove the launch alert before release, keep runtime group discovery in AppDelegate/widget |
| `ios/Runner/Info.plist` | Photo-library permission and `NSSupportsLiveActivities` declarations |
| `ios/Runner/Runner.entitlements` / `ios/GymmerWidget/GymmerWidget.entitlements` | App Group entitlement requested by both targets; SideStore may rewrite the installed identifier |

### Tests
| File | Contents |
|---|---|
| `test/support/test_app.dart` | Shared test helpers: `pumpGymmer` (in-memory store) + `openTestStore` (temp-file store). Import from every test file |
| `test/widget_test.dart` | Core regression tests: model rules, sqlite store audits #5–#8, widget flows incl. swipe/gesture simulation. Widget tests must stay on the in-memory store (file I/O hangs pumpAndSettle) |
| `test/library_test.dart` | Library search + favorites: filter/sort helper, star toggle persistence, sqlite is_favorite migration |
| `test/rest_timer_test.dart` | RestTimerController (fake_async) + live pill widget flow |
| `test/profile_test.dart` | Completed-workout stats, buildCompletedWorkout rule, feed card + detail navigation, Profile tab reachable |
| `test/aggregates_test.dart` | weeklyTotals bucketing / zero-fill / metric math + thisWeekDuration (pure Dart) |
| `test/streaks_test.dart` | weekStreak + restDaysThisWeek (pure Dart) |
| `test/measurements_test.dart` | measurement CRUD (memory + sqlite upsert-by-date) + log-page widget flow |
| `test/records_test.dart` | recordsIn / statsFor / exercisesWithHistory (pure Dart) |
| `test/muscle_map_capture_test.dart` | Skipped-by-default PNG generator for the schematic painter → `test_muscle/` |

### Tooling (offline, Node)
| File | Contents |
|---|---|
| `tools/render_color_plate.js` | `npm run plate` (step 1): renders the aligned real-colour plate (`backup/assets/muscle_plate/`) used for delt/abs layers. Handles Draco decompress + Chromium swiftshader |
| `tools/render_muscle_layers.js` | `npm run layers` (step 2): builds `assets/muscle_layers/` base + primary/secondary diff overlays from archived stills; delts/abs sample the colour plate |
| `tools/build_full_body.js` + `tools/highlight_groups.json` | Rebuilds full-body.glb from the 4 anatomytool sources (sources now in backup/) |
| `tools/vendor/model-viewer.min.js` | Vendored renderer for the stills + plate tools |
| `gymmer_flutter/package.json` | Node dev deps; `npm install` before running tools |

### Build & distribution (iOS, free sideload)
| File | Contents |
|---|---|
| `.github/workflows/ios-build.yml` | CI on push to main/ios: builds unsigned iOS on a free `macos-15` runner, packages `Gymmer.ipa`, publishes a GitHub Release (`build-<run>`) + regenerates `apps.json`. Build number = run number → version auto-bumps to `1.0.<run>` |
| `apps.json` (repo root) | SideStore/AltStore source manifest → latest Release `.ipa`. Committed back by CI. Device subscribes for free OTA auto-updates. Source URL: `https://raw.githubusercontent.com/pimdejvani/Gymmer_App/ios/apps.json` |
| `gymmer_flutter/ios/` | Generated iOS platform (bundle id `com.gymmer.gymmerFlutter`) plus the WidgetKit target. `flutter_launcher_icons` config + `assets/Gymmer_Logo.png` drive the app icon; photo permission and Live Activities are declared in `Runner/Info.plist` |

Full sideload/CI walkthrough: `update.md` (2026-07-15) + `README.md`.

## How things connect

```
main.dart → screens/workout_home_screen.dart (GymmerHome = shell + owns WorkoutStore)
              ├─ tab 0: widgets/home/* (header, quick actions, folders → routine cards)
              ├─ tab 1: screens/exercise_library_page.dart → create_exercise_page.dart
              │           └─ widgets/muscle_map.dart + exercise_anatomy_panel.dart
              ├─ tab 2: screens/profile/profile_tab.dart (loadCompletedWorkouts)
              │           └─ widgets/profile/workout_feed_card.dart → workout_detail_page.dart
              ├─ resume bar → screens/active_workout_page.dart
              │           └─ widgets/workout/* + muscle_map.dart + exercise_picker_page.dart
              └─ routine edit → screens/routine_builder_page.dart → exercise_picker_page.dart

screens → data/workout_store.dart (interface) ← workout_store_factory.dart
             ├─ workout_store_sqlite.dart (io) ─┐ both call
             └─ workout_store_memory.dart (web) ┘ domain/finish_workout_service.dart
models.dart (barrel) ← everyone

Flutter app ↔ AppDelegate.swift ↔ App Group container
                         ├─ catalog.json / routines.json (widget read snapshots)
                         └─ session.json (shared active session; widget writes are
                            reconciled into SQLite when Flutter resumes)

Runner foreground → starts/updates/ends Live Activity
Widget extension App Intents → mutates session.json → refreshes Live Activity
```

State flows down as constructor params; mutations flow up as callbacks to
GymmerHome (or page state), which persists via the store then reloads.

## Read paths per task

- **UI tweak (colors/spacing)** → `theme/app_theme.dart` only, then the one widget file.
- **Home / folders / drag-drop bug** → `screens/workout_home_screen.dart` + the one file in `widgets/home/`.
- **Active workout bug** → `screens/active_workout_page.dart` + `widgets/workout/`.
- **Routine builder** → `screens/routine_builder_page.dart`.
- **Library / create exercise** → `screens/exercise_library_page.dart`, `screens/create_exercise_page.dart`.
- **Profile / stats work** → `screens/profile/*`, `widgets/profile/*`, `models/completed_workout.dart`, store `loadCompletedWorkouts` + `domain/` aggregate helpers.
- **DB / persistence** → `docs/BACKEND_ARCHITECTURE.md`, `docs/DECISIONS.md`, `lib/data/`, `lib/domain/`.
- **Muscle map drawing** → `widgets/body_muscle_painter.dart`.
- **Anatomy rendering wrong/missing** → `docs/ANATOMY_STILLS.md` + `widgets/exercise_anatomy_panel.dart` + `tools/render_muscle_layers.js`.
- **iOS widget / Live Activity** → `docs/widget/WIDGET.md` + `lib/data/widget_bridge.dart` + `ios/GymmerWidget/GymmerWidget.swift` + `ios/Runner/AppDelegate.swift`.
- **Product behavior question** → `CONTEXT.md`, then `docs/FUNCTIONS.md`.
- **What to do next** → `next_step.md`.

## Docs index (everything that exists)

- `structure_file.md` — this map
- `CONTEXT.md` — product rules + current implementation state
- `next_step.md` — remaining work only (done items get deleted)
- `plans/` — empty unless a new active feature plan is created. Finished plans
  live in `backup/plans/`.
- `update.md` — short change log, newest first
- `README.md` — intro + how to run + iOS build/sideload
- `.github/workflows/ios-build.yml` — CI: iOS build → Release → SideStore source
- `apps.json` — SideStore source manifest (CI-generated)
- `docs/FUNCTIONS.md` — full feature spec
- `docs/BACKEND_ARCHITECTURE.md` — DB schema/architecture
- `docs/DECISIONS.md` — merged architecture decisions (was docs/adr/)
- `docs/ANATOMY_STILLS.md` — stills pipeline + asset licensing (IMPORTANT before commercial release)
- `docs/widget/WIDGET.md` — iOS widget + Live Activity state contract and current behavior
- `backup/` — archived files (gitignored): old docs, source glbs, superseded parent next_step/update

Old Swift project at repo root (`GYMMER/`, `GYMMER.xcodeproj`) is legacy — never read it.
