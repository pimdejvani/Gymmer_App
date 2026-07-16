import Foundation
import HealthKit

/// Owns Gymmer's native HealthKit workout lifecycle on iOS 26 and later.
/// Dart starts and ends it with the same explicit session lifecycle used by the
/// app and widget; no separate voice-command integration is registered.
@available(iOS 26.0, *)
@MainActor
final class HealthWorkoutManager: NSObject {
  static let shared = HealthWorkoutManager()

  private let healthStore = HKHealthStore()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var saveWhenStopped = true
  private var recovering = false

  /// Requests only workout write access, then starts an indoor traditional
  /// strength-training session and its associated live builder.
  func start() async -> Bool {
    guard HKHealthStore.isHealthDataAvailable() else { return false }
    if session != nil { return true }
    if recovering { return true }

    do {
      let shareTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
      try await healthStore.requestAuthorization(
        toShare: shareTypes,
        read: []
      )

      let configuration = HKWorkoutConfiguration()
      configuration.activityType = .traditionalStrengthTraining
      configuration.locationType = .indoor

      let newSession = try HKWorkoutSession(
        healthStore: healthStore,
        configuration: configuration
      )
      let newBuilder = newSession.associatedWorkoutBuilder()
      newSession.delegate = self
      newBuilder.delegate = self
      newBuilder.dataSource = HKLiveWorkoutDataSource(
        healthStore: healthStore,
        workoutConfiguration: configuration
      )

      session = newSession
      builder = newBuilder
      saveWhenStopped = true

      newSession.prepare()
      let startDate = Date()
      newSession.startActivity(with: startDate)
      try await newBuilder.beginCollection(at: startDate)
      return true
    } catch {
      NSLog("Gymmer: HealthKit workout start failed: \(error.localizedDescription)")
      reset()
      return false
    }
  }

  /// Stops the running workout. A normal finish is saved to HealthKit; discard
  /// tears down the builder without creating a HealthKit workout sample.
  @discardableResult
  func stop(save: Bool) -> Bool {
    guard let session else { return false }
    saveWhenStopped = save
    session.stopActivity(with: Date())
    return true
  }

  /// Reattaches delegates after iOS relaunches the app to recover a workout.
  func prepareForRecovery() {
    recovering = true
  }

  func recover(_ recoveredSession: HKWorkoutSession) {
    recovering = false
    session = recoveredSession
    builder = recoveredSession.associatedWorkoutBuilder()
    session?.delegate = self
    builder?.delegate = self
    builder?.dataSource = HKLiveWorkoutDataSource(
      healthStore: healthStore,
      workoutConfiguration: recoveredSession.workoutConfiguration
    )
  }

  func recoveryFailed() {
    recovering = false
  }

  private func finalize(at endDate: Date) async {
    guard let session, let builder else {
      reset()
      return
    }

    if saveWhenStopped {
      do {
        try await builder.endCollection(at: endDate)
        _ = try await builder.finishWorkout()
      } catch {
        NSLog("Gymmer: HealthKit workout finish failed: \(error.localizedDescription)")
      }
    } else {
      builder.discardWorkout()
    }

    session.end()
    reset()
  }

  private func reset() {
    session = nil
    builder = nil
    saveWhenStopped = true
    recovering = false
  }
}

@available(iOS 26.0, *)
extension HealthWorkoutManager: HKWorkoutSessionDelegate {
  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date
  ) {
    guard toState == .stopped else { return }
    Task { @MainActor in
      await self.finalize(at: date)
    }
  }

  nonisolated func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didFailWithError error: Error
  ) {
    NSLog("Gymmer: HealthKit workout session failed: \(error.localizedDescription)")
    Task { @MainActor in self.reset() }
  }
}

@available(iOS 26.0, *)
extension HealthWorkoutManager: HKLiveWorkoutBuilderDelegate {
  nonisolated func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder,
    didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {}

  nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

  nonisolated func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder,
    didEnd workoutActivity: HKWorkoutActivity
  ) {}
}
