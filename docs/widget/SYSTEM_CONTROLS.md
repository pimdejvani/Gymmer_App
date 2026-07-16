# GYMMER — System Controls design

Status: design specification only; not implemented yet. Last reviewed:
2026-07-16. The shipped implementation remains the single configurable
`GymmerWorkoutActionControl` described in `WIDGET.md`.

## Goal

Provide the high-frequency active-workout actions from Control Center while the
device remains locked, and show enough current session state to confirm that a
tap changed the intended value. This complements the richer Live Activity; it
does not attempt to reproduce the Live Activity inside Control Center.

Required actions:

- KG −2.5 and KG +2.5
- REP −1 and REP +1
- Complete Set
- Next Exercise
- Skip Rest
- Finish may be offered as a separate control after its locked-device safety is
  verified. Discard is intentionally not part of the quick layout until an
  accidental-loss safeguard is decided.

## Public-API constraints

- A third-party `ControlWidget` is a system-rendered button or toggle, not an
  arbitrary SwiftUI dashboard.
- Gymmer cannot build one custom 4×4 panel containing several metrics, a
  progress bar, and multiple independently tappable regions.
- The user arranges and resizes controls in Control Center. Gymmer cannot force
  an instance to be a particular grid size, and iOS may omit title/value text
  at smaller sizes.
- One `ControlWidgetButton` has one action. KG, REP, Set, Next, and Skip must
  remain separate actions even when a different control displays their shared
  state.
- Lock Screen control slots are much smaller than Control Center and may show
  only the icon. The composed dashboard below targets a dedicated Control
  Center page.
- Widget and Live Activity buttons remain inactive until authentication. The
  System Control is the supported locked-device action surface; Now Playing is
  media-only and must not be imitated with silent audio.

## Selected feasible design

Use ordinary controls composed on one Control Center page. The status value is
one separate dynamic control; every mutation remains its own 1×1 action.

```text
┌─────────────────────────────────┐
│  Bench Press · Set 2/4          │  optional session-context control
└─────────────────────────────────┘
┌─────────────────────────────────┐
│  80 kg · 10 reps                │  combined dynamic KG/REP control
└─────────────────────────────────┘

[ KG− ] [ KG+ ] [ REP− ] [ REP+ ]
[ SET ] [ NEXT ] [ SKIP ] [ FINISH* ]
```

`FINISH*` is provisional pending the locked-device safety test described below.

The diagram describes the desired arrangement, not a custom container. Every
rectangle is an independent system Control with visible system spacing. If iOS
does not offer the wide size for either value control on the test device, use
two standard controls instead:

```text
[ Bench Press ] [ Set 2/4 ]
[ 80 kg       ] [ 10 reps ]
```

The accepted KG/REP display string is `80 kg · 10 reps`. Decimal weight must
use the same compact formatting as the workout session (`82.5`, not
`82.500000`). Inactive state displays `No active workout`. Missing current-set
values display `— kg · — reps` rather than inventing zeroes.

The dynamic status control needs one system action even though its primary job
is display. The initial implementation should use a harmless `Refresh workout
status` action; it must not open the app because that would request unlock. Its
label and value remain system-rendered, and the implementation must tolerate
iOS truncating either string.

## Current implementation versus required changes

Already implemented:

- One configurable `AppIntentControlConfiguration` whose instances dispatch
  KG/REP +/−, Complete Set, Next Exercise, or Skip Rest.
- `alwaysAllowed`, background execution, App Group JSON mutations, native
  intent tests, and Control Center availability.
- All high-frequency actions safely no-op when no session is active.

Required implementation work:

1. Add a small `GymmerControlState` value containing active/inactive state,
   exercise name, set position, KG, and reps.
2. Add a `ControlValueProvider` (or configurable value provider only if the
   final control remains configurable) that reads `session.json` cheaply from
   the App Group and returns `GymmerControlState`.
3. Add a separate dynamic status `ControlWidget` that renders the combined
   KG/REP string. Add the optional exercise/set context control only if the
   first control is legible on the real device.
4. Add a refresh-only background `AppIntent` for tapping a status control.
5. Request `ControlCenter` reload for the status-control kind after every
   successful session mutation, navigation action, start, finish, and discard.
   Reload only the affected control kinds rather than all controls.
6. Keep the current mutation dispatcher and action controls intact. Do not
   replace the tested Home Widget path or Live Activity ID targeting.
7. Evaluate Finish as a separate locked control on-device. Keep Discard out of
   the quick layout unless a deliberate confirmation/authentication policy is
   chosen.

## Verification criteria

Automated:

- Provider tests: inactive session, integer KG, decimal KG, reps, set position,
  and missing current-set values.
- Existing seven native mutation/dispatcher tests continue to pass.
- Add tests proving every successful mutation requests a status-control reload
  and inactive actions do not create session state.
- Flutter analyze/tests, native XCTest, and unsigned iOS 26 build remain
  parallel CI gates before publishing.

Real iOS 26 device after SideStore signing:

- Confirm which sizes iOS offers for each Gymmer control; documentation and
  screenshots must use only those observed sizes.
- Verify `KG · REP` is visible in the chosen size while locked and updates after
  all four KG/REP actions without opening Gymmer.
- Verify Complete Set, Next Exercise, and Skip Rest update both the status
  control and Live Activity.
- Verify inactive, rest, final-set, Finish, and app-process-terminated states.
- Verify Control Center remains allowed under Face ID & Passcode settings and
  no action unexpectedly requests authentication.

## Design references

The first generated 4×4 rich dashboard was exploratory only and is rejected as
an implementation target because it exceeds the public ControlWidget template.
The second generated mockup is accepted only as a reference for native spacing,
separate controls, and restrained colors; it still shows KG and REP separately.
This specification supersedes that detail by combining them into one dynamic
`KG · REP` value. Treat all generated imagery as layout communication until the
design is reproduced and captured from a real iOS 26 device.

Apple references:

- [ControlWidget](https://developer.apple.com/documentation/swiftui/controlwidget)
- [ControlValueProvider](https://developer.apple.com/documentation/widgetkit/controlvalueprovider)
- [Adding refinements and configuration to controls](https://developer.apple.com/documentation/widgetkit/adding-refinements-and-configuration-to-controls)
