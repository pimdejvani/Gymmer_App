import Foundation
import ActivityKit
import AppIntents
import WidgetKit

/// Navigation is shared by the app and widget targets because Live Activity
/// intents must run in the containing app's process. A plain AppIntent runs in
/// the widget extension, where updating the active Activity isn't reliable.
@available(iOS 17.0, *)
struct NavIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Navigate"

  @Parameter(title: "page") var page: String

  init() {}
  init(_ page: String) { self.page = page }

  func perform() async throws -> some IntentResult {
    NavigationStore.save(page: page)
    WidgetCenter.shared.reloadTimelines(ofKind: "GymmerWidget")

    for activity in Activity<GymmerActivityAttributes>.activities {
      var state = activity.content.state
      state.page = page
      await activity.update(
        ActivityContent(state: state, staleDate: state.restEnds)
      )
    }
    return .result()
  }
}

private enum NavigationStore {
  private static let fallbackGroup = "group.com.gymmer.gymmerFlutter"

  static func save(page: String) {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: resolvedGroupID
    ) else { return }

    let url = container.appendingPathComponent("session.json")
    guard let data = try? Data(contentsOf: url),
          var session = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

    var ui = session["ui"] as? [String: Any] ?? [:]
    ui["page"] = page
    session["ui"] = ui
    session["by"] = "widget"
    session["rev"] = Int64(Date().timeIntervalSince1970 * 1_000_000)

    guard let updated = try? JSONSerialization.data(withJSONObject: session) else { return }
    try? updated.write(to: url, options: .atomic)
  }

  private static let resolvedGroupID: String = {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let start = data.range(of: Data("<plist".utf8))?.lowerBound,
          let end = data.range(of: Data("</plist>".utf8))?.upperBound else { return fallbackGroup }
    let plistData = data.subdata(in: start..<end)
    guard let object = try? PropertyListSerialization.propertyList(
      from: plistData, options: [], format: nil
    ),
          let plist = object as? [String: Any],
          let entitlements = plist["Entitlements"] as? [String: Any],
          let groups = entitlements["com.apple.security.application-groups"] as? [String],
          let first = groups.first else { return fallbackGroup }
    return first
  }()
}
