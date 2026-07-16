import XCTest
@testable import Runner

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

    let session = WStore.loadSession()
    XCTAssertEqual(session.rev, revision)
    XCTAssertEqual(session.exercises[0].sets[0].kg, "10")
    XCTAssertFalse(session.exercises[0].sets[0].done)
    XCTAssertEqual(session.curEx, 0)
  }

  @available(iOS 18.0, *)
  func testConfigurableControlUsesSharedMutationPipeline() async throws {
    seedSession()

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
