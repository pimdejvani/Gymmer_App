import Flutter
import HealthKit
import HealthKitUI
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // ---------------------------------------------------------------------------
  // POC v2: SideStore/AltStore rewrite the app-group identifier at install time,
  // so a hard-coded "group.com.gymmer.gymmerFlutter" lookup returns nil even
  // though a shared container exists under the rewritten name. Discover the REAL
  // granted group id at runtime by reading the installed provisioning profile,
  // then open the container with that. The shipping widget will resolve the id
  // the same way (see AppGroup.resolvedID), so both processes agree without any
  // hard-coded string. Remove this probe once confirmed.
  // ---------------------------------------------------------------------------
  private static let requestedGroupID = "group.com.gymmer.gymmerFlutter"

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
    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      self?.runAppGroupProbe()
    }
  }

  private func runAppGroupProbe() {
    var lines: [String] = []
    let fm = FileManager.default

    // 1. What did the sideload tool actually grant? (ground truth)
    let granted = SceneDelegate.provisionedAppGroups()
    if granted.isEmpty {
      lines.append("profile groups: (none)")
    } else {
      lines.append("profile groups:")
      granted.forEach { lines.append("• \($0)") }
    }

    // 2. Try the requested id + every granted id; report which opens.
    var candidates = [SceneDelegate.requestedGroupID]
    granted.forEach { if !candidates.contains($0) { candidates.append($0) } }

    var workingID: String?
    for id in candidates {
      if let c = fm.containerURL(forSecurityApplicationGroupIdentifier: id) {
        lines.append("✅ \(id)")
        lines.append("   \(c.lastPathComponent)")
        if workingID == nil { workingID = id }
      } else {
        lines.append("❌ \(id)")
      }
    }

    // 3. Prove read/write on the working container + a shared launch counter.
    if let id = workingID,
       let c = fm.containerURL(forSecurityApplicationGroupIdentifier: id) {
      let probe = c.appendingPathComponent("probe.txt")
      let stamp = ISO8601DateFormatter().string(from: Date())
      if (try? stamp.write(to: probe, atomically: true, encoding: .utf8)) != nil,
         let back = try? String(contentsOf: probe, encoding: .utf8) {
        lines.append("write/read OK: \(back)")
      } else {
        lines.append("write failed")
      }
      if let d = UserDefaults(suiteName: id) {
        let n = d.integer(forKey: "poc_launches") + 1
        d.set(n, forKey: "poc_launches")
        lines.append("launches: \(n)")
      }
    } else {
      lines.append("no shared container available")
    }

    let alert = UIAlertController(
      title: "App Group POC v2",
      message: lines.joined(separator: "\n"),
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    guard let window = self.window, var top = window.rootViewController else { return }
    while let presented = top.presentedViewController { top = presented }
    top.present(alert, animated: true)
  }

  /// Application-groups actually granted in the installed provisioning profile.
  /// The `embedded.mobileprovision` file is a CMS/PKCS7 blob with a plain-text
  /// XML plist inside; scan for the plist and read its Entitlements.
  private static func provisionedAppGroups() -> [String] {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let start = data.range(of: Data("<plist".utf8))?.lowerBound,
          let end = data.range(of: Data("</plist>".utf8))?.upperBound else { return [] }
    let plistData = data.subdata(in: start..<end)
    guard let obj = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
          let plist = obj as? [String: Any],
          let ent = plist["Entitlements"] as? [String: Any] else { return [] }
    if let groups = ent["com.apple.security.application-groups"] as? [String] {
      return groups
    }
    return []
  }
}
