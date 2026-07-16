# GYMMER — System Controls design

Status: implemented on branch `ios`, **pending real-device verification**. Last
reviewed: 2026-07-16. The configurable `GymmerWorkoutActionControl` now
dispatches Set +/Set − (not Skip Rest), two dynamic display controls
(`GymmerKgRepControl`, `GymmerExerciseControl`) render `session.json` through
`GymmerStatusProvider`, mutations reload the affected control kinds, and the Live
Activity Rest phase is styled as the native-timer banner. CI compiles these
paths; Control Center sizes and Lock Screen policy still need a real iOS 26
device (see verification criteria). Code lives in `GymmerWidget.swift`.

## Goal

Provide the high-frequency active-workout actions from Control Center while the
device remains locked, and show enough current session state to confirm that a
tap changed the intended value. This complements the richer Live Activity; it
does not attempt to reproduce the Live Activity inside Control Center.

Rest is **no longer a Control Center action**. It moves to a dedicated
native-timer-style Live Activity banner described under "Rest timer" below.

Control Center actions:

- KG −2.5 and KG +2.5
- REP −1 and REP +1
- Set − and Set + (change the target set count of the current exercise)
- Complete Set
- Next Exercise
- Finish may be offered as a separate control after its locked-device safety is
  verified. Discard is intentionally not part of the quick layout until an
  accidental-loss safeguard is decided.

`Set −`/`Set +` change the planned total for the current exercise (e.g.
`2/4 → 2/5` with `Set +`, `2/4 → 2/3` with `Set −`), reusing the same set-count
mutation as the widget Add/Manage pages. `Set +` appends a set seeded from the
last set's KG/REP. `Set −` must no-op when it would drop the total below the
current set position or below 1, so an in-progress or completed set is never
removed underneath the user.

## Public-API constraints

- A third-party `ControlWidget` is a system-rendered button or toggle, not an
  arbitrary SwiftUI dashboard.
- Gymmer cannot build one custom panel containing several metrics, a
  progress bar, and multiple independently tappable regions. The KG/REP and
  exercise/stats displays below are therefore separate system controls, not one
  composed tile.
- The user arranges and resizes controls in Control Center. Gymmer cannot force
  an instance to be a particular grid size, and iOS may omit title/value text
  at smaller sizes. The `1×4`, `1×3`, and `1×1` sizes in this document describe
  the intended content per control, not a layout Gymmer can enforce.
- One `ControlWidgetButton` has one action. KG, REP, Set ±, Complete Set, and
  Next must remain separate actions even when a different control displays their
  shared state.
- Lock Screen control slots are much smaller than Control Center and may show
  only the icon. The composed layout below targets a dedicated Control Center
  page.
- Widget and Live Activity buttons remain inactive until authentication. The
  System Control is the supported locked-device action surface; Now Playing is
  media-only and must not be imitated with silent audio.

## Selected feasible design

Use ordinary controls composed on one Control Center page. Two dynamic display
controls show state; every mutation remains its own 1×1 action.

```text
┌─────────────────────────────────────────────┐
│  🏋  Bench Press · 4×10 80kg · Set 2/4       │  1×4 exercise + stats display
└─────────────────────────────────────────────┘
┌───────────────────────────────┐ ┌───────────┐
│  80 kg · 10 reps              │ │   Set ✓   │  1×3 KG·REP display + 1×1 done
└───────────────────────────────┘ └───────────┘

[ KG− ] [ KG+ ] [ REP− ] [ REP+ ]
[ Set− ] [ Set+ ] [ NEXT ] [ FINISH* ]
```

`FINISH*` is provisional pending the locked-device safety test described below.

The diagram describes the desired arrangement, not a custom container. Every
rectangle is an independent system Control with visible system spacing. The two
display controls are:

1. `1×4` exercise/stats display — exercise name, icon, a compact stats summary
   (target scheme and working weight), and set position `Set n/m`. Its icon is an
   SF Symbol chosen by the current exercise's primary muscle region (chest → the
   strength-training figure, arms → `dumbbell.fill`, back → the functional
   figure, abs → `figure.core.training`, legs → `figure.run`, shoulders →
   `figure.arms.open`, else the default figure). The app's full-colour anatomy
   image cannot appear here: Control Center renders a control glyph as a
   templated (monochrome) SF Symbol, and the anatomy assets live in the Flutter
   bundle, not the App Group the extension can read. The per-muscle symbol is the
   accepted substitute.
2. `1×3` current-set display — the combined `KG · REP` value string.

The mutation controls use distinct glyph families so two adjacent buttons never
render the same icon even when their text truncates: `KG ±` use
`plus.circle`/`minus.circle`, `REP ±` use `arrow.up.circle`/`arrow.down.circle`,
`Set ±` use `plus.square`/`minus.square`, Complete Set uses
`checkmark.circle.fill`, and Next uses `chevron.right.circle`.

If iOS does not offer the wide size for a display control on the test device,
fall back to standard controls (e.g. split the stats display into
`[ Bench Press ] [ Set 2/4 ]`, and the KG/REP display into `[ 80 kg ]
[ 10 reps ]`).

The accepted KG/REP display string is `80 kg · 10 reps`. Decimal weight must
use the same compact formatting as the workout session (`82.5`, not
`82.500000`). Inactive state displays `No active workout`. Missing current-set
values display `— kg · — reps` rather than inventing zeroes.

Each dynamic display control needs one system action even though its primary job
is display. Use a harmless `Refresh workout status` action; it must not open the
app because that would request unlock. Its label and value remain
system-rendered, and the implementation must tolerate iOS truncating either
string.

## Rest timer (Live Activity, not a Control)

Rest is presented as a Live Activity styled to match the native iOS timer
banner on the Lock Screen, so it feels like a system timer rather than a custom
panel:

- Countdown on the left in the Gymmer green accent, tabular numerals, updated
  automatically with SwiftUI `Text(timerInterval:)` — no per-second timeline and
  no push required.
- Two circular buttons on the right: `−15s` and `+15s`, adjusting the remaining
  rest time. Their App Intents set `openAppWhenRun = false` so taps work while
  the device is locked, reusing the existing rest-adjust mutation.
- At `0:00` the timer auto-advances to the next set, and the existing
  `พักครบ 💪` local notification still fires.

This is a Live Activity presentation, not a `ControlWidget`; ActivityKit and the
shared session mutations own it. The fuller interactive Live Activity Rest page
in `WIDGET.md` still exists and may keep its `ข้าม` control; the minimal banner
here deliberately exposes only `−15s`/`+15s`. On iPhones without Dynamic Island
(e.g. iPhone 12 Pro) this banner appears on the Lock Screen, which is the
target surface.

## Current implementation versus required changes

Already implemented:

- One configurable `AppIntentControlConfiguration` whose instances dispatch
  KG/REP +/−, Complete Set, Next Exercise, or Skip Rest.
- `alwaysAllowed`, background execution, App Group JSON mutations, native
  intent tests, and Control Center availability.
- All high-frequency actions safely no-op when no session is active.
- A Live Activity Rest phase with `−15`/`+15` and `ข้าม` (see `WIDGET.md` 4b).

Required implementation work:

1. Add a small `GymmerControlState` value containing active/inactive state,
   exercise name, stats summary, set position, KG, and reps.
2. Add a `ControlValueProvider` that reads `session.json` cheaply from the App
   Group and returns `GymmerControlState`.
3. Add two dynamic display `ControlWidget`s: the `1×4` exercise/stats display and
   the `1×3` combined KG/REP display. Keep the fallback split controls ready if
   the wide size is not offered on the real device.
4. Add a refresh-only background `AppIntent` for tapping a display control.
5. Add `Set −` and `Set +` mutation actions (change target set count) with the
   no-op guards above, and add them to the configurable action set. Remove
   `Skip Rest` from the Control action set (rest moves to the timer banner).
6. Request `ControlCenter` reload for the affected display-control kinds after
   every successful session mutation, navigation action, start, finish, and
   discard. Reload only the affected control kinds rather than all controls.
   Submit the reload hint immediately after the `session.json` write, before
   awaiting ActivityKit, so the ActivityKit round-trip does not sit in front of
   the hint. Note this only reorders *our* work: iOS still coalesces and
   rate-limits third-party control reloads on its own budget, so the display
   controls remain a best-effort glance surface, not a real-time readout. The
   Live Activity (`Activity.update` + self-updating `Text`) is the low-latency
   locked-glance surface; the Control Center displays will always lag it.
7. Style the Live Activity Rest phase as the native-timer banner: green-accent
   countdown left, `−15s`/`+15s` circular buttons right, auto-advance at `0:00`.
8. Keep the current mutation dispatcher and remaining action controls intact. Do
   not replace the tested Home Widget path or Live Activity ID targeting.
9. Evaluate Finish as a separate locked control on-device. Keep Discard out of
   the quick layout unless a deliberate confirmation/authentication policy is
   chosen.

## Verification criteria

Automated:

- Provider tests: inactive session, integer KG, decimal KG, reps, set position,
  stats summary, and missing current-set values.
- Set-count tests: `Set +` appends a seeded set; `Set −` reduces the target;
  `Set −` no-ops at the current position and at a total of 1.
- Existing native mutation/dispatcher tests continue to pass.
- Add tests proving every successful mutation requests a display-control reload
  and inactive actions do not create session state.
- Flutter analyze/tests, native XCTest, and unsigned iOS 26 build remain
  parallel CI gates before publishing.

Real iOS 26 device after SideStore signing:

- Confirm which sizes iOS offers for each Gymmer control; documentation and
  screenshots must use only those observed sizes.
- Verify `KG · REP` is visible in the chosen size while locked and updates after
  all four KG/REP actions without opening Gymmer.
- Verify Set −/Set + update the set position on both displays and the Live
  Activity.
- Verify Complete Set and Next Exercise update both displays and the Live
  Activity.
- Verify the rest timer banner counts down while locked, `−15s`/`+15s` adjust it
  without unlocking, and it auto-advances at `0:00`.
- Verify inactive, rest, final-set, Finish, and app-process-terminated states.
- Verify Control Center remains allowed under Face ID & Passcode settings and
  no action unexpectedly requests authentication.

## Design references

The first generated 4×4 rich dashboard was exploratory only and is rejected as
an implementation target because it exceeds the public ControlWidget template.
Later mockups (composed Control Center page, `1×4`/`1×3` displays, and the
native-timer rest banner) are accepted only as layout communication for native
spacing, separate controls, and restrained colors. Treat all generated imagery
as layout communication until the design is reproduced and captured from a real
iOS 26 device.

Apple references:

- [ControlWidget](https://developer.apple.com/documentation/swiftui/controlwidget)
- [ControlValueProvider](https://developer.apple.com/documentation/widgetkit/controlvalueprovider)
- [Adding refinements and configuration to controls](https://developer.apple.com/documentation/widgetkit/adding-refinements-and-configuration-to-controls)
- [Text(timerInterval:)](https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pauseTime:countsDown:showsHours:))
