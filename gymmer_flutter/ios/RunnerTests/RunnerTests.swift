import XCTest
@testable import Runner

@available(iOS 17.0, *)
final class RunnerTests: XCTestCase {
  private var storeURL: URL!

  override func setUpWithError() throws {
    storeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("GymmerIntentTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
    WStore.containerURLOverride = storeURL
  }

  override func tearDownWithError() throws {
    WStore.containerURLOverride = nil
    if let storeURL {
      try? FileManager.default.removeItem(at: storeURL)
    }
  }

  private func seedSession(
    active: Bool = true,
    exerciseCount: Int = 2,
    setCount: Int = 2
  ) {
    var session = Session()
    session.active = active
    session.ui.page = "log"
    session.exercises = (0..<exerciseCount).map { exerciseIndex in
      var exercise = WExercise(
        name: "Exercise \(exerciseIndex + 1)",
        muscle: "Chest",
        equipment: "Barbell"
      )
      exercise.rest = 0
      exercise.sets = (0..<setCount).map { _ in
        WSet(kg: "10", reps: "8")
      }
      return exercise
    }
    WStore.save(session)
  }

  func testAdjustIntentChangesCurrentWeightAndRepsImmediately() async throws {
    seedSession()

    _ = try await AdjustIntent(field: "kg", delta: 2.5).perform()
    _ = try await AdjustIntent(field: "rep", delta: -1).perform()

    let set = WStore.loadSession().exercises[0].sets[0]
    XCTAssertEqual(set.kg, "12.5")
    XCTAssertEqual(set.reps, "7")
  }

  func testCompleteSetAdvancesThenSkipRestClearsTimer() async throws {
    seedSession()

    _ = try await CompleteSetIntent().perform()
    var session = WStore.loadSession()
    XCTAssertTrue(session.exercises[0].sets[0].done)
    XCTAssertEqual(session.exercises[0].curSet, 1)
    XCTAssertNotNil(session.ui.restEndsAt)

    _ = try await SkipRestIntent().perform()
    session = WStore.loadSession()
    XCTAssertNil(session.ui.restEndsAt)
  }

  func testNextExerciseMovesToFollowingExercise() async throws {
    seedSession(exerciseCount: 3)

    _ = try await NextExerciseIntent().perform()

    XCTAssertEqual(WStore.loadSession().curEx, 1)
  }

  func testInactiveSessionRejectsWorkoutMutations() async throws {
    seedSession(active: false)
    let revision = WStore.loadSession().rev

    _ = try await AdjustIntent(field: "kg", delta: 2.5).perform()
    _ = try await CompleteSetIntent().perform()
    _ = try await NextExerciseIntent().perform()
    _ = try await SkipRestIntent().perform()
    _ = try await AddSetIntent().perform()
    _ = try await RemoveSetIntent().perform()

    let session = WStore.loadSession()
    XCTAssertEqual(session.rev, revision)
    XCTAssertEqual(session.exercises[0].sets.count, 2)
    XCTAssertEqual(session.exercises[0].sets[0].kg, "10")
    XCTAssertFalse(session.exercises[0].sets[0].done)
    XCTAssertEqual(session.curEx, 0)
  }

  func testAddSetSeedsFromLastAndRemoveSetTrimsTarget() async throws {
    seedSession(setCount: 2)

    _ = try await AddSetIntent().perform()
    var ex = WStore.loadSession().exercises[0]
    XCTAssertEqual(ex.sets.count, 3)
    XCTAssertEqual(ex.sets[2].kg, "10") // seeded from the previous set
    XCTAssertEqual(ex.sets[2].reps, "8")

    _ = try await RemoveSetIntent().perform()
    ex = WStore.loadSession().exercises[0]
    XCTAssertEqual(ex.sets.count, 2)
  }

  func testRemoveSetNeverDeletesACompletedSetOrTheLastRemaining() async throws {
    seedSession(setCount: 2)

    // Mark the trailing set done; Set− must refuse to delete logged work.
    var session = WStore.loadSession()
    session.exercises[0].sets[1].done = true
    WStore.save(session)
    _ = try await RemoveSetIntent().perform()
    XCTAssertEqual(WStore.loadSession().exercises[0].sets.count, 2)

    // A single planned set is the floor.
    seedSession(setCount: 1)
    _ = try await RemoveSetIntent().perform()
    XCTAssertEqual(WStore.loadSession().exercises[0].sets.count, 1)
  }

  @available(iOS 18.0, *)
  func testControlActionsDispatchSetCountMutations() async throws {
    seedSession(setCount: 2)

    _ = try await GymmerWorkoutControlIntent(action: .addSet).perform()
    XCTAssertEqual(WStore.loadSession().exercises[0].sets.count, 3)

    _ = try await GymmerWorkoutControlIntent(action: .removeSet).perform()
    XCTAssertEqual(WStore.loadSession().exercises[0].sets.count, 2)
  }

  func testControlStateReflectsCurrentSet() {
    seedSession(setCount: 3)
    let state = GymmerControlState.from(WStore.loadSession())
    XCTAssertTrue(state.active)
    XCTAssertEqual(state.kgRepValue, "10 kg · 8 reps")
    XCTAssertEqual(state.exerciseValue, "Exercise 1 · Set 1/3")
    // seedSession uses the "Chest" muscle → strength-training figure.
    XCTAssertEqual(state.exerciseSymbol, "figure.strengthtraining.traditional")
  }

  func testExerciseSymbolMapsMuscleRegionToDistinctGlyphs() {
    func symbol(for muscle: String) -> String {
      var session = Session()
      session.active = true
      var exercise = WExercise(name: "X", muscle: muscle, equipment: "Barbell")
      exercise.sets = [WSet(kg: "10", reps: "8")]
      session.exercises = [exercise]
      return GymmerControlState.from(session).exerciseSymbol
    }

    XCTAssertEqual(symbol(for: "Biceps"), "dumbbell.fill")
    XCTAssertEqual(symbol(for: "Lats"), "figure.strengthtraining.functional")
    XCTAssertEqual(symbol(for: "Abs"), "figure.core.training")
    XCTAssertEqual(symbol(for: "Quads"), "figure.run")
    XCTAssertEqual(symbol(for: "Side Delt"), "figure.arms.open")
    // Unmapped / idle falls back to the default figure.
    XCTAssertEqual(symbol(for: "Neck"), "figure.strengthtraining.traditional")
    XCTAssertEqual(GymmerControlState.inactive.exerciseSymbol, "figure.strengthtraining.traditional")
  }

  func testControlStateInactiveShowsNoWorkout() {
    seedSession(active: false)
    let state = GymmerControlState.from(WStore.loadSession())
    XCTAssertFalse(state.active)
    XCTAssertEqual(state.kgRepValue, "No active workout")
    XCTAssertEqual(state.exerciseValue, "No active workout")
  }

  func testControlStateMissingValuesUseDashesNotZeroes() {
    var session = Session()
    session.active = true
    session.ui.page = "log"
    var exercise = WExercise(name: "Squat", muscle: "Legs", equipment: "Barbell")
    exercise.sets = [WSet(kg: "", reps: "")]
    session.exercises = [exercise]
    WStore.save(session)

    let state = GymmerControlState.from(WStore.loadSession())
    XCTAssertEqual(state.kgRepValue, "— kg · — reps")
  }

  func testControlStateKeepsDecimalWeightCompact() {
    var session = Session()
    session.active = true
    var exercise = WExercise(name: "Curl", muscle: "Arms", equipment: "Dumbbell")
    exercise.sets = [WSet(kg: "82.5", reps: "10")]
    session.exercises = [exercise]
    WStore.save(session)

    let state = GymmerControlState.from(WStore.loadSession())
    XCTAssertEqual(state.kgRepValue, "82.5 kg · 10 reps")
  }

  @available(iOS 18.0, *)
  func testConfigurableControlUsesSharedMutationPipeline() async throws {
    seedSession()

    XCTAssertEqual(GymmerWorkoutControlIntent().selectedAction, .completeSet)
    _ = try await GymmerWorkoutControlIntent(action: .repUp).perform()
    _ = try await GymmerWorkoutControlIntent(action: .kgDown).perform()

    let set = WStore.loadSession().exercises[0].sets[0]
    XCTAssertEqual(set.reps, "9")
    XCTAssertEqual(set.kg, "7.5")
  }

  func testLiveActivityIntentsCarryExplicitActivityID() {
    let mutation = LiveMutationIntent(action: "completeSet")
      .targeting(activityID: "activity-123")
    let navigation = NavIntent("manage")
      .targeting(activityID: "activity-456")

    XCTAssertEqual(mutation.activityID, "activity-123")
    XCTAssertEqual(navigation.activityID, "activity-456")
  }

  func testFinishAndDiscardPersistTerminalOutcomes() async throws {
    seedSession()
    _ = try await FinishSessionIntent().perform()
    var session = WStore.loadSession()
    XCTAssertFalse(session.active)
    XCTAssertEqual(session.outcome, "finish")

    seedSession()
    _ = try await DiscardIntent().perform()
    session = WStore.loadSession()
    XCTAssertFalse(session.active)
    XCTAssertEqual(session.outcome, "discard")
  }
}
