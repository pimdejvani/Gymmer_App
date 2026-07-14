import WidgetKit
import SwiftUI
import AppIntents

// -----------------------------------------------------------------------------
// Step-A widget: validate the last two primitives before building the full UI:
//   1. Flutter -> shared container data (renders the real exercise-catalog count
//      the app writes to catalog.json), and
//   2. App Intent interactivity (a +1 button that mutates session.json in the
//      widget process and re-renders — proves buttons work on the SideStore build).
// The app-group id is resolved at runtime (SideStore rewrites it), never hard-coded.
// -----------------------------------------------------------------------------

// MARK: - Shared App Group

enum AppGroup {
  static let resolvedID: String = firstProvisionedGroup() ?? "group.com.gymmer.gymmerFlutter"

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

// MARK: - Shared state

struct SessionState: Codable {
  var counter: Int = 0
}

enum WidgetStore {
  static func catalogCount() -> Int {
    guard let dir = AppGroup.containerURL,
          let data = try? Data(contentsOf: dir.appendingPathComponent("catalog.json")),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let exercises = obj["exercises"] as? [[String: Any]] else { return -1 }
    return exercises.count
  }

  static func loadSession() -> SessionState {
    guard let dir = AppGroup.containerURL,
          let data = try? Data(contentsOf: dir.appendingPathComponent("session.json")),
          let session = try? JSONDecoder().decode(SessionState.self, from: data) else {
      return SessionState()
    }
    return session
  }

  static func saveSession(_ session: SessionState) {
    guard let dir = AppGroup.containerURL,
          let data = try? JSONEncoder().encode(session) else { return }
    try? data.write(to: dir.appendingPathComponent("session.json"), options: .atomic)
  }
}

// MARK: - App Intent (interactivity)

@available(iOS 17.0, *)
struct BumpCounterIntent: AppIntent {
  static var title: LocalizedStringResource = "Bump counter"

  func perform() async throws -> some IntentResult {
    var session = WidgetStore.loadSession()
    session.counter += 1
    WidgetStore.saveSession(session)
    return .result()
  }
}

// MARK: - Timeline

struct GymmerEntry: TimelineEntry {
  let date: Date
  let catalogCount: Int
  let counter: Int
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> GymmerEntry {
    GymmerEntry(date: Date(), catalogCount: 0, counter: 0)
  }

  func getSnapshot(in context: Context, completion: @escaping (GymmerEntry) -> Void) {
    completion(readEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<GymmerEntry>) -> Void) {
    completion(Timeline(entries: [readEntry()], policy: .never))
  }

  private func readEntry() -> GymmerEntry {
    GymmerEntry(
      date: Date(),
      catalogCount: WidgetStore.catalogCount(),
      counter: WidgetStore.loadSession().counter
    )
  }
}

// MARK: - View

private let mint = Color(red: 0.49, green: 1.0, blue: 0.54) // #7DFF8A

struct GymmerWidgetEntryView: View {
  var entry: GymmerEntry

  var body: some View {
    let content = VStack(alignment: .leading, spacing: 8) {
      Text("GYMMER")
        .font(.system(size: 15, weight: .heavy))
        .foregroundColor(mint)

      Text(entry.catalogCount >= 0
           ? "catalog: \(entry.catalogCount) exercises"
           : "catalog: not written yet")
        .font(.system(size: 12))
        .foregroundColor(Color(white: 0.96))

      HStack(spacing: 10) {
        Text("count: \(entry.counter)")
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundColor(Color(white: 0.96))

        if #available(iOS 17.0, *) {
          Button(intent: BumpCounterIntent()) {
            Text("+1")
              .font(.system(size: 13, weight: .bold))
              .foregroundColor(.black)
              .padding(.horizontal, 14)
              .padding(.vertical, 6)
              .background(mint)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
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
