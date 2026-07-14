import WidgetKit
import SwiftUI

// -----------------------------------------------------------------------------
// Step 1 widget: prove the hand-added extension target builds under CI, installs
// via SideStore, appears in the widget gallery, AND can read the App Group shared
// container the Flutter app writes to. It resolves the (SideStore-rewritten) app
// group id at runtime — never hard-coded — exactly like the app-side probe.
// The full 6-page logger UI replaces this body once the target is proven.
// -----------------------------------------------------------------------------

// MARK: - Shared App Group

enum AppGroup {
  /// The app group id actually granted by the installer. SideStore rewrites the
  /// requested `group.com.gymmer.gymmerFlutter` to `<id>.<teamID>`, so read the
  /// real value from this bundle's embedded provisioning profile at runtime.
  static let resolvedID: String = {
    if let fromProfile = firstProvisionedGroup() { return fromProfile }
    return "group.com.gymmer.gymmerFlutter" // fallback (dev/simulator)
  }()

  static var containerURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: resolvedID)
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

// MARK: - Timeline

struct GymmerEntry: TimelineEntry {
  let date: Date
  let groupID: String
  let shared: String
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> GymmerEntry {
    GymmerEntry(date: Date(), groupID: "—", shared: "…")
  }

  func getSnapshot(in context: Context, completion: @escaping (GymmerEntry) -> Void) {
    completion(readEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<GymmerEntry>) -> Void) {
    completion(Timeline(entries: [readEntry()], policy: .atEnd))
  }

  private func readEntry() -> GymmerEntry {
    var shared = "no shared container"
    if let container = AppGroup.containerURL {
      let probe = container.appendingPathComponent("probe.txt")
      if let txt = try? String(contentsOf: probe, encoding: .utf8) {
        shared = "read: \(txt)"
      } else {
        shared = "container OK, no probe.txt yet"
      }
    }
    return GymmerEntry(date: Date(), groupID: AppGroup.resolvedID, shared: shared)
  }
}

// MARK: - View

struct GymmerWidgetEntryView: View {
  var entry: GymmerEntry

  var body: some View {
    let content = VStack(alignment: .leading, spacing: 6) {
      Text("GYMMER")
        .font(.system(size: 15, weight: .heavy))
        .foregroundColor(Color(red: 0.49, green: 1.0, blue: 0.54)) // mint #7DFF8A
      Text(entry.groupID)
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundColor(Color(white: 0.62))
        .lineLimit(2)
      Text(entry.shared)
        .font(.system(size: 10))
        .foregroundColor(Color(white: 0.96))
        .lineLimit(3)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    if #available(iOS 17.0, *) {
      content.padding(14).containerBackground(.black, for: .widget)
    } else {
      content.padding(14).background(Color.black)
    }
  }
}

// MARK: - Widget

@main
struct GymmerWidget: Widget {
  let kind = "GymmerWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      GymmerWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Gymmer")
    .description("Log your workout session")
    .supportedFamilies([.systemMedium])
  }
}
