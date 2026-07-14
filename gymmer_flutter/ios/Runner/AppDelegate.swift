import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Bridge Dart -> App Group shared container. Dart serialises the exercise
    // catalog / active session to JSON and calls writeFile; we persist it into
    // the (SideStore-rewritten) app-group container and reload the widget so it
    // re-renders from the fresh snapshot. readFile lets Dart pull back the
    // widget's op-log to reconcile into SQLite on resume.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GymmerWidgetBridge") {
      let channel = FlutterMethodChannel(
        name: "gymmer/widget",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "writeFile":
          let args = call.arguments as? [String: Any]
          guard let name = args?["name"] as? String,
                let contents = args?["contents"] as? String else {
            result(FlutterError(code: "bad_args", message: "name/contents required", details: nil))
            return
          }
          let ok = AppGroupIO.write(contents, to: name)
          AppGroupIO.reloadWidgets()
          result(ok)
        case "readFile":
          let name = (call.arguments as? [String: Any])?["name"] as? String
          result(name.flatMap { AppGroupIO.read($0) })
        case "groupID":
          result(AppGroupIO.resolvedID)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}

/// App-side access to the App Group shared container. Mirrors the widget's
/// `AppGroup` helper: SideStore rewrites the requested group id, so resolve the
/// real one at runtime from the embedded provisioning profile.
enum AppGroupIO {
  static let resolvedID: String = firstProvisionedGroup() ?? "group.com.gymmer.gymmerFlutter"

  static var containerURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: resolvedID)
  }

  static func write(_ contents: String, to filename: String) -> Bool {
    guard let dir = containerURL else { return false }
    do {
      try contents.write(to: dir.appendingPathComponent(filename), atomically: true, encoding: .utf8)
      return true
    } catch {
      return false
    }
  }

  static func read(_ filename: String) -> String? {
    guard let dir = containerURL else { return nil }
    return try? String(contentsOf: dir.appendingPathComponent(filename), encoding: .utf8)
  }

  static func reloadWidgets() {
    if #available(iOS 14.0, *) { WidgetCenter.shared.reloadAllTimelines() }
  }

  private static func firstProvisionedGroup() -> String? {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let start = data.range(of: Data("<plist".utf8))?.lowerBound,
          let end = data.range(of: Data("</plist>".utf8))?.upperBound else { return nil }
    let plistData = data.subdata(in: start..<end)
    guard let obj = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
          let plist = obj as? [String: Any],
          let ent = plist["Entitlements"] as? [String: Any],
          let groups = ent["com.apple.security.application-groups"] as? [String],
          let first = groups.first else { return nil }
    return first
  }
}
