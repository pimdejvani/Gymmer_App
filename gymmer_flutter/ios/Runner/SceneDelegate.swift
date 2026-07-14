import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // ---------------------------------------------------------------------------
  // POC: verify the App Group shared container is provisioned on this sideloaded
  // (SideStore, free Apple ID) build. Remove this whole probe once confirmed.
  // ---------------------------------------------------------------------------
  private static let appGroupID = "group.com.gymmer.gymmerFlutter"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      self?.runAppGroupProbe()
    }
  }

  private func runAppGroupProbe() {
    let groupID = SceneDelegate.appGroupID
    var lines: [String] = []
    let fm = FileManager.default

    if let container = fm.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
      lines.append("✅ container OK")
      lines.append(container.path)
      let probe = container.appendingPathComponent("probe.txt")
      do {
        let stamp = ISO8601DateFormatter().string(from: Date())
        try stamp.write(to: probe, atomically: true, encoding: .utf8)
        let back = (try? String(contentsOf: probe, encoding: .utf8)) ?? "read failed"
        lines.append("write/read: \(back)")
      } catch {
        lines.append("write failed: \(error.localizedDescription)")
      }
      if let defaults = UserDefaults(suiteName: groupID) {
        let n = defaults.integer(forKey: "poc_launches") + 1
        defaults.set(n, forKey: "poc_launches")
        lines.append("UserDefaults launches: \(n)")
      } else {
        lines.append("UserDefaults(suite) = nil")
      }
    } else {
      lines.append("❌ container is nil")
      lines.append("App Group not provisioned")
    }

    let alert = UIAlertController(
      title: "App Group POC",
      message: lines.joined(separator: "\n"),
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default))

    guard let window = self.window, var top = window.rootViewController else { return }
    while let presented = top.presentedViewController { top = presented }
    top.present(alert, animated: true)
  }
}
