import Flutter
import HealthKit
import HealthKitUI
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if #available(iOS 26.0, *), connectionOptions.shouldHandleActiveWorkoutRecovery {
      HealthWorkoutManager.shared.prepareForRecovery()
      HKHealthStore().recoverActiveWorkoutSession { recoveredSession, error in
        if let recoveredSession {
          Task { @MainActor in
            HealthWorkoutManager.shared.recover(recoveredSession)
          }
        } else if let error {
          NSLog("Gymmer: HealthKit workout recovery failed: \(error.localizedDescription)")
          Task { @MainActor in
            HealthWorkoutManager.shared.recoveryFailed()
          }
        } else {
          Task { @MainActor in
            HealthWorkoutManager.shared.recoveryFailed()
          }
        }
      }
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
}
