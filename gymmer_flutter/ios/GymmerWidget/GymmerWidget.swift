import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit
import UserNotifications

// =============================================================================
// GYMMER — Exercise Session Widget (6 pages, fully interactive via App Intents)
//
// Single source of truth: session.json in the App Group container, read/written
// by BOTH this widget and the Flutter app (last-writer-wins, reconciled by the
// app on resume). The app additionally writes catalog.json (exercise picker) and
// routines.json (Start page). The app-group id is resolved at runtime because
// SideStore rewrites it — never hard-coded. See docs/widget/WIDGET.md.
//
// Deployment target is iOS 17, so interactive Button(intent:) is always usable.
// =============================================================================

// MARK: - Theme

private extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: 1
    )
  }
}

private enum T {
  static let bg = Color(hex: 0x000000)
  static let surface = Color(hex: 0x121214)
  static let surfaceHigh = Color(hex: 0x1C1C1F)
  static let hairline = Color(hex: 0x242428)
  static let textPrimary = Color(hex: 0xF5F5F7)
  static let textSecondary = Color(hex: 0x9E9EA7)
  static let textTertiary = Color(hex: 0x5E5E66)
  static let accent = Color(hex: 0x7DFF8A)
  static let danger = Color(hex: 0xFF5A5A)
}

// MARK: - App Group

enum AppGroup {
  static var containerURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: resolvedID)
  }

  static let resolvedID: String = firstProvisionedGroup() ?? "group.com.gymmer.gymmerFlutter"

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

// MARK: - Shared models (lenient decoding: the app may write partial objects)

struct WSet: Codable {
  var kg: String = ""
  var reps: String = ""
  var prev: String? = nil
  var done: Bool = false

  init(kg: String = "", reps: String = "", prev: String? = nil, done: Bool = false) {
    self.kg = kg; self.reps = reps; self.prev = prev; self.done = done
  }
  init(from d: Decoder) throws {
    let c = try d.container(keyedBy: CodingKeys.self)
    kg = (try? c.decodeIfPresent(String.self, forKey: .kg)) ?? ""
    reps = (try? c.decodeIfPresent(String.self, forKey: .reps)) ?? ""
    prev = (try? c.decodeIfPresent(String.self, forKey: .prev)) ?? nil
    done = (try? c.decodeIfPresent(Bool.self, forKey: .done)) ?? false
  }
}

struct WExercise: Codable {
  var name: String = ""
  var muscle: String = ""
  var equipment: String = ""
  var rest: Int = 90
  var curSet: Int = 0
  var sets: [WSet] = [WSet()]

  init(name: String, muscle: String, equipment: String) {
    self.name = name; self.muscle = muscle; self.equipment = equipment
  }
  init(from d: Decoder) throws {
    let c = try d.container(keyedBy: CodingKeys.self)
    name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
    muscle = (try? c.decodeIfPresent(String.self, forKey: .muscle)) ?? ""
    equipment = (try? c.decodeIfPresent(String.self, forKey: .equipment)) ?? ""
    rest = (try? c.decodeIfPresent(Int.self, forKey: .rest)) ?? 90
    curSet = (try? c.decodeIfPresent(Int.self, forKey: .curSet)) ?? 0
    let s = (try? c.decodeIfPresent([WSet].self, forKey: .sets)) ?? nil
    sets = (s?.isEmpty == false) ? s! : [WSet()]
  }
}

struct WUI: Codable {
  var page: String = "log"
  var listPage: Int = 0
  var filterPage: Int = 0
  var muscleFilter: String? = nil
  var equipFilter: String? = nil
  var routinePage: Int = 0
  var restEndsAt: String? = nil
  var restDur: Int = 90

  init() {}
  init(from d: Decoder) throws {
    let c = try d.container(keyedBy: CodingKeys.self)
    page = (try? c.decodeIfPresent(String.self, forKey: .page)) ?? "log"
    listPage = (try? c.decodeIfPresent(Int.self, forKey: .listPage)) ?? 0
    filterPage = (try? c.decodeIfPresent(Int.self, forKey: .filterPage)) ?? 0
    muscleFilter = (try? c.decodeIfPresent(String.self, forKey: .muscleFilter)) ?? nil
    equipFilter = (try? c.decodeIfPresent(String.self, forKey: .equipFilter)) ?? nil
    routinePage = (try? c.decodeIfPresent(Int.self, forKey: .routinePage)) ?? 0
    restEndsAt = (try? c.decodeIfPresent(String.self, forKey: .restEndsAt)) ?? nil
    restDur = (try? c.decodeIfPresent(Int.self, forKey: .restDur)) ?? 90
  }
}

struct Session: Codable {
  var v: Int = 1
  var rev: Int = 0
  var by: String = "widget"
  var active: Bool = false
  var outcome: String? = nil
  var sessionName: String? = nil
  var source: String? = nil
  var routineName: String? = nil
  var routineGroupName: String? = nil
  var startedAt: String? = nil
  var curEx: Int = 0
  var ui: WUI = WUI()
  var exercises: [WExercise] = []

  init() {}
  init(from d: Decoder) throws {
    let c = try d.container(keyedBy: CodingKeys.self)
    v = (try? c.decodeIfPresent(Int.self, forKey: .v)) ?? 1
    rev = (try? c.decodeIfPresent(Int.self, forKey: .rev)) ?? 0
    by = (try? c.decodeIfPresent(String.self, forKey: .by)) ?? "widget"
    active = (try? c.decodeIfPresent(Bool.self, forKey: .active)) ?? false
    outcome = (try? c.decodeIfPresent(String.self, forKey: .outcome)) ?? nil
    sessionName = (try? c.decodeIfPresent(String.self, forKey: .sessionName)) ?? nil
    source = (try? c.decodeIfPresent(String.self, forKey: .source)) ?? nil
    routineName = (try? c.decodeIfPresent(String.self, forKey: .routineName)) ?? nil
    routineGroupName = (try? c.decodeIfPresent(String.self, forKey: .routineGroupName)) ?? nil
    startedAt = (try? c.decodeIfPresent(String.self, forKey: .startedAt)) ?? nil
    curEx = (try? c.decodeIfPresent(Int.self, forKey: .curEx)) ?? 0
    ui = (try? c.decodeIfPresent(WUI.self, forKey: .ui)) ?? WUI()
    exercises = (try? c.decodeIfPresent([WExercise].self, forKey: .exercises)) ?? []
  }

  // Clamped current exercise / set accessors.
  var safeExIndex: Int { exercises.isEmpty ? 0 : min(max(curEx, 0), exercises.count - 1) }
  var currentExercise: WExercise? { exercises.isEmpty ? nil : exercises[safeExIndex] }
}

struct CatalogItem: Codable {
  var name: String; var muscle: String; var equipment: String
  var prevKg: String = ""
  var prevReps: String = ""
  var prev: String? = nil
}

struct RoutineItem: Codable {
  var name: String = ""
  var group: String = ""
  var exercises: [WExercise] = []
  init(from d: Decoder) throws {
    let c = try d.container(keyedBy: CodingKeys.self)
    name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
    group = (try? c.decodeIfPresent(String.self, forKey: .group)) ?? ""
    exercises = (try? c.decodeIfPresent([WExercise].self, forKey: .exercises)) ?? []
  }
}

struct RoutinesFile: Codable {
  var routines: [RoutineItem] = []
  init(from d: Decoder) throws {
    let c = try d.container(keyedBy: CodingKeys.self)
    routines = (try? c.decodeIfPresent([RoutineItem].self, forKey: .routines)) ?? []
  }
}

// MARK: - Store

enum WStore {
  /// XCTest redirects the shared JSON store to a temporary directory so intent
  /// mutations can be verified without a provisioned App Group container.
  static var containerURLOverride: URL?

  private static func url(_ file: String) -> URL? {
    let container = containerURLOverride ?? AppGroup.containerURL
    return container?.appendingPathComponent(file)
  }

  static func loadSession() -> Session {
    guard let u = url("session.json"),
          let data = try? Data(contentsOf: u),
          let s = try? JSONDecoder().decode(Session.self, from: data) else {
      return Session()
    }
    return s
  }

  /// Persists a widget mutation: stamps `by:"widget"` + a fresh monotonic rev
  /// (microseconds, matching the Flutter scale) so the app reconciles on resume.
  static func save(_ session: Session) {
    var s = session
    s.by = "widget"
    s.rev = Int(Date().timeIntervalSince1970 * 1_000_000)
    guard let u = url("session.json"), let data = try? JSONEncoder().encode(s) else { return }
    try? data.write(to: u, options: .atomic)
  }

  static func catalog() -> [CatalogItem] {
    guard let u = url("catalog.json"),
          let data = try? Data(contentsOf: u),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let raw = obj["exercises"] as? [[String: Any]] else { return [] }
    return raw.map {
      CatalogItem(
        name: $0["name"] as? String ?? "",
        muscle: $0["muscle"] as? String ?? "",
        equipment: $0["equipment"] as? String ?? "",
        prevKg: $0["prevKg"] as? String ?? "",
        prevReps: $0["prevReps"] as? String ?? "",
        prev: $0["prev"] as? String
      )
    }
  }

  static func routines() -> [RoutineItem] {
    guard let u = url("routines.json"),
          let data = try? Data(contentsOf: u),
          let file = try? JSONDecoder().decode(RoutinesFile.self, from: data) else { return [] }
    return file.routines
  }
}

// MARK: - Rest-end notification (widgets can't run in the background, so we
// schedule a local notification — its sound + haptic fire when rest elapses).

enum RestNotify {
  static let id = "gymmer.rest.end"

  static func schedule(after seconds: Int) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [id])
    guard seconds > 0 else { return }
    // We really only want a buzz when rest ends. iOS has no background
    // haptic-only API — the vibration rides along with a delivered
    // notification, so a banner is unavoidable. Keep it to a single short
    // line (no body) so it's the least intrusive nudge possible. The sound is
    // what triggers the device's standard vibration.
    let content = UNMutableNotificationContent()
    content.title = "พักครบ 💪"
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(seconds), repeats: false)
    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
  }

  static func cancel() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
  }
}

// MARK: - Number helpers

enum Num {
  static func fmtKg(_ v: Double) -> String {
    let clamped = max(0, v)
    if clamped == clamped.rounded() { return String(Int(clamped)) }
    return String(format: "%.1f", clamped)
  }
  static func kg(_ s: String) -> Double { Double(s.trimmingCharacters(in: .whitespaces)) ?? 0 }
  static func reps(_ s: String) -> Int { Int(s.trimmingCharacters(in: .whitespaces)) ?? 0 }
}

// MARK: - App Intents

// -- Navigation -------------------------------------------------------------

@available(iOS 17.0, *)
struct WidgetNavIntent: AppIntent {
  static var title: LocalizedStringResource = "Navigate widget"
  @Parameter(title: "page") var page: String
  init() {}
  init(_ page: String) { self.page = page }
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    s.ui.page = page
    await WStore.saveAndSync(s)
    return .result()
  }
}

// -- Start page -------------------------------------------------------------

@available(iOS 17.0, *)
struct StartEmptyIntent: AppIntent {
  static var title: LocalizedStringResource = "Start empty session"
  func perform() async throws -> some IntentResult {
    var s = Session()
    s.active = true
    s.source = "No Routine"
    s.sessionName = "No Routine"
    s.startedAt = ISO8601DateFormatter().string(from: Date())
    s.exercises = []
    s.ui.page = "add"
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct StartRoutineIntent: AppIntent {
  static var title: LocalizedStringResource = "Start routine"
  @Parameter(title: "name") var name: String
  init() {}
  init(_ name: String) { self.name = name }
  func perform() async throws -> some IntentResult {
    var s = Session()
    s.active = true
    s.source = name
    s.routineName = name
    s.sessionName = name
    s.startedAt = ISO8601DateFormatter().string(from: Date())
    // Pull the routine's full exercise + set list (written by the app).
    s.exercises = WStore.routines().first(where: { $0.name == name })?.exercises ?? []
    s.curEx = 0
    s.ui.page = s.exercises.isEmpty ? "add" : "log"
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct RoutinePageIntent: AppIntent {
  static var title: LocalizedStringResource = "Page routines"
  @Parameter(title: "delta") var delta: Int
  init() {}
  init(_ delta: Int) { self.delta = delta }
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    s.ui.routinePage = max(0, s.ui.routinePage + delta)
    await WStore.saveAndSync(s)
    return .result()
  }
}

// -- Add / filter -----------------------------------------------------------

@available(iOS 17.0, *)
struct AddExerciseIntent: AppIntent {
  static var title: LocalizedStringResource = "Add exercise"
  @Parameter(title: "name") var name: String
  init() {}
  init(_ name: String) { self.name = name }
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    guard !name.isEmpty else { return .result() }
    if let existing = s.exercises.firstIndex(where: { $0.name == name }) {
      s.exercises.remove(at: existing) // toggle off
    } else if let item = WStore.catalog().first(where: { $0.name == name }) {
      var ex = WExercise(name: item.name, muscle: item.muscle, equipment: item.equipment)
      ex.sets = [WSet(kg: item.prevKg, reps: item.prevReps, prev: item.prev)] // seed from history
      s.exercises.append(ex)
    }
    await WStore.saveAndSync(s)
    return .result()
  }
}

// Picker cell, right zone: +1 set on an already-queued exercise (copies the last set).
@available(iOS 17.0, *)
struct PickerAddSetIntent: AppIntent {
  static var title: LocalizedStringResource = "Add set from picker"
  @Parameter(title: "name") var name: String
  init() {}
  init(_ name: String) { self.name = name }
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    guard let i = s.exercises.firstIndex(where: { $0.name == name }) else { return .result() }
    let last = s.exercises[i].sets.last
    s.exercises[i].sets.append(WSet(kg: last?.kg ?? "", reps: last?.reps ?? "", prev: last?.prev))
    await WStore.saveAndSync(s)
    return .result()
  }
}

// Picker cell, circle badge: −1 set; removing the last set drops the exercise from the queue.
@available(iOS 17.0, *)
struct PickerRemoveSetIntent: AppIntent {
  static var title: LocalizedStringResource = "Remove set from picker"
  @Parameter(title: "name") var name: String
  init() {}
  init(_ name: String) { self.name = name }
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    guard let i = s.exercises.firstIndex(where: { $0.name == name }) else { return .result() }
    if s.exercises[i].sets.count <= 1 {
      s.exercises.remove(at: i)
      if s.curEx >= s.exercises.count { s.curEx = max(0, s.exercises.count - 1) }
    } else {
      s.exercises[i].sets.removeLast()
      let cap = s.exercises[i].sets.count - 1
      if s.exercises[i].curSet > cap { s.exercises[i].curSet = cap }
    }
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct ListPageIntent: AppIntent {
  static var title: LocalizedStringResource = "Page exercise list"
  @Parameter(title: "delta") var delta: Int
  init() {}
  init(_ delta: Int) { self.delta = delta }
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    s.ui.listPage = max(0, s.ui.listPage + delta)
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct FilterPageIntent: AppIntent {
  static var title: LocalizedStringResource = "Page filter chips"
  @Parameter(title: "delta") var delta: Int
  init() {}
  init(_ delta: Int) { self.delta = delta }
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    s.ui.filterPage = max(0, s.ui.filterPage + delta)
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct SelectFilterIntent: AppIntent {
  static var title: LocalizedStringResource = "Select filter"
  @Parameter(title: "kind") var kind: String   // "muscle" | "equip"
  @Parameter(title: "value") var value: String // "" clears
  init() {}
  init(kind: String, value: String) { self.kind = kind; self.value = value }
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    let v: String? = value.isEmpty ? nil : value
    if kind == "muscle" { s.ui.muscleFilter = v } else { s.ui.equipFilter = v }
    s.ui.listPage = 0
    s.ui.page = "add"
    await WStore.saveAndSync(s)
    return .result()
  }
}

// -- Log page ---------------------------------------------------------------

@available(iOS 17.0, *)
struct AdjustIntent: AppIntent {
  static var title: LocalizedStringResource = "Adjust value"
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
  @Parameter(title: "field") var field: String // "kg" | "rep"
  @Parameter(title: "delta") var delta: Double
  init() {}
  init(field: String, delta: Double) { self.field = field; self.delta = delta }
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    guard s.active, !s.exercises.isEmpty else { return .result() }
    let ei = s.safeExIndex
    var ex = s.exercises[ei]
    let si = min(max(ex.curSet, 0), ex.sets.count - 1)
    if field == "kg" {
      let v = Num.kg(ex.sets[si].kg) + delta
      ex.sets[si].kg = Num.fmtKg(v)
    } else {
      let v = max(0, Num.reps(ex.sets[si].reps) + Int(delta))
      ex.sets[si].reps = String(v)
    }
    s.exercises[ei] = ex
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct CompleteSetIntent: AppIntent {
  static var title: LocalizedStringResource = "Complete set"
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    guard s.active, !s.exercises.isEmpty else { return .result() }
    let ei = s.safeExIndex
    var ex = s.exercises[ei]
    let si = min(max(ex.curSet, 0), ex.sets.count - 1)
    ex.sets[si].done = true
    if si + 1 < ex.sets.count {
      ex.curSet = si + 1 // more sets in this exercise → log the next one
    }
    s.exercises[ei] = ex
    // Exercise finished → auto-advance to the next exercise with unlogged sets.
    if !ex.sets.contains(where: { !$0.done }),
       let nextIdx = nextIncompleteExercise(s, after: ei) {
      s.curEx = nextIdx
      var nx = s.exercises[nextIdx]
      if let firstUnlogged = nx.sets.firstIndex(where: { !$0.done }) { nx.curSet = firstUnlogged }
      s.exercises[nextIdx] = nx
    }
    // Kick off the rest timer (a countdown overlay on the Log page).
    s.ui.restDur = ex.rest
    s.ui.restEndsAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(ex.rest)))
    RestNotify.schedule(after: ex.rest)
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct NextExerciseIntent: AppIntent {
  static var title: LocalizedStringResource = "Next exercise"
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    guard s.active, !s.exercises.isEmpty else { return .result() }
    s.curEx = (s.safeExIndex + 1) % s.exercises.count
    await WStore.saveAndSync(s)
    return .result()
  }
}

// -- Rest -------------------------------------------------------------------

@available(iOS 17.0, *)
struct RestAdjustIntent: AppIntent {
  static var title: LocalizedStringResource = "Adjust rest"
  @Parameter(title: "delta") var delta: Int
  init() {}
  init(_ delta: Int) { self.delta = delta }
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    let base = restRemaining(s)
    let newRemaining = max(0, base + delta)
    s.ui.restEndsAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(newRemaining)))
    RestNotify.schedule(after: newRemaining)
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct SkipRestIntent: AppIntent {
  static var title: LocalizedStringResource = "Skip rest"
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    guard s.active else { return .result() }
    s.ui.restEndsAt = nil // curSet was already advanced when the set completed
    RestNotify.cancel()
    await WStore.saveAndSync(s)
    return .result()
  }
}

// -- Manage -----------------------------------------------------------------

@available(iOS 17.0, *)
struct AddSetIntent: AppIntent {
  static var title: LocalizedStringResource = "Add set"
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    let ei = s.safeExIndex
    guard !s.exercises.isEmpty else { return .result() }
    var ex = s.exercises[ei]
    let last = ex.sets.last
    ex.sets.append(WSet(kg: last?.kg ?? "", reps: last?.reps ?? "", prev: last?.prev))
    s.exercises[ei] = ex
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct RemoveSetIntent: AppIntent {
  static var title: LocalizedStringResource = "Remove set"
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    let ei = s.safeExIndex
    guard !s.exercises.isEmpty else { return .result() }
    var ex = s.exercises[ei]
    if ex.sets.count > 1 {
      ex.sets.removeLast()
      ex.curSet = min(ex.curSet, ex.sets.count - 1)
    }
    s.exercises[ei] = ex
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct RemoveExerciseIntent: AppIntent {
  static var title: LocalizedStringResource = "Remove exercise"
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    guard !s.exercises.isEmpty else { return .result() }
    s.exercises.remove(at: s.safeExIndex)
    if s.curEx >= s.exercises.count { s.curEx = max(0, s.exercises.count - 1) }
    if s.exercises.isEmpty { s.ui.page = "add" }
    await WStore.saveAndSync(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct FinishSessionIntent: AppIntent {
  static var title: LocalizedStringResource = "Finish session"
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
  func perform() async throws -> some IntentResult {
    var s = WStore.loadSession()
    s.active = false
    s.outcome = "finish"
    s.ui = WUI()
    RestNotify.cancel()
#if !GYMMER_WIDGET_EXTENSION
    if #available(iOS 26.0, *) {
      _ = await HealthWorkoutManager.shared.stop(save: true)
    }
#endif
    await WStore.saveAndEnd(s)
    return .result()
  }
}

@available(iOS 17.0, *)
struct DiscardIntent: AppIntent {
  static var title: LocalizedStringResource = "Discard session"
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
  func perform() async throws -> some IntentResult {
    var s = Session()
    s.active = false
    s.outcome = "discard"
    RestNotify.cancel()
#if !GYMMER_WIDGET_EXTENSION
    if #available(iOS 26.0, *) {
      _ = await HealthWorkoutManager.shared.stop(save: false)
    }
#endif
    await WStore.saveAndEnd(s)
    return .result()
  }
}

/// When the current rest ends (nil if no rest scheduled).
func restEndDate(_ s: Session) -> Date? {
  guard let iso = s.ui.restEndsAt else { return nil }
  return ISO8601DateFormatter().date(from: iso)
}

/// Seconds left on the rest timer (0 if none / elapsed).
func restRemaining(_ s: Session) -> Int {
  guard let end = restEndDate(s) else { return 0 }
  return max(0, Int(end.timeIntervalSinceNow.rounded()))
}

/// True when every set of every exercise is logged — the session can finish.
func sessionComplete(_ s: Session) -> Bool {
  guard !s.exercises.isEmpty else { return false }
  for ex in s.exercises {
    if ex.sets.isEmpty { return false }
    for set in ex.sets where !set.done { return false }
  }
  return true
}

/// Index of the next exercise (searching cyclically after [i]) that still has an
/// unlogged set, or nil when every exercise is complete.
func nextIncompleteExercise(_ s: Session, after i: Int) -> Int? {
  let n = s.exercises.count
  guard n > 0 else { return nil }
  for step in 1...n {
    let idx = (i + step) % n
    if s.exercises[idx].sets.contains(where: { !$0.done }) { return idx }
  }
  return nil
}

// MARK: - Live Activity sync (extension side)

// Only the foreground app can START an Activity, but this extension can UPDATE
// and END running ones. Every session-mutating App Intent funnels through
// WStore.saveAndSync so the Lock Screen mirror tracks edits made from the home
// widget or the Live Activity itself while the app is backgrounded.
@available(iOS 17.0, *)
enum LiveSync {
  /// LiveActivityIntent execution is scoped to the Activity whose button was
  /// tapped. Home-widget and Control Center intents leave this nil and retain
  /// the existing behavior of refreshing every running Gymmer Activity.
  @TaskLocal static var targetActivityID: String?

  private static func activities(targeting activityID: String?) -> [Activity<GymmerActivityAttributes>] {
    let running = Activity<GymmerActivityAttributes>.activities
    guard let activityID, !activityID.isEmpty else { return running }
    return running.filter { $0.id == activityID }
  }

  static func contentState(_ s: Session) -> GymmerActivityAttributes.ContentState {
    let ei = s.safeExIndex
    let ex = s.currentExercise
    let si = ex.map { min(max($0.curSet, 0), $0.sets.count - 1) } ?? 0
    let set = ex?.sets[si]
    let allLogged = ex?.sets.allSatisfy { $0.done } ?? false
    let complete = sessionComplete(s)
    var phase = complete ? "done" : "log"
    var restEpoch: Double? = nil
    if let end = restEndDate(s), end.timeIntervalSinceNow > 0 {
      // "restdone" = resting after the final set: the rest UI swaps ข้าม for
      // จบ session, and an elapsed (stale) rest falls back to the done layout.
      phase = complete ? "restdone" : "rest"
      restEpoch = end.timeIntervalSince1970
    }
    return GymmerActivityAttributes.ContentState(
      phase: phase,
      exName: ex?.name ?? "",
      exIndex: s.exercises.isEmpty ? 0 : ei + 1,
      exCount: s.exercises.count,
      setLabel: allLogged ? "Done" : "เซ็ต \(si + 1)/\(max(1, ex?.sets.count ?? 1))",
      kg: set?.kg ?? "",
      reps: set?.reps ?? "",
      prev: set?.prev,
      restEndsEpoch: restEpoch,
      page: s.ui.page
    )
  }

  static func refresh(activityID: String? = nil) async {
    let s = WStore.loadSession()
    let targets = activities(targeting: activityID ?? targetActivityID)
    if s.active {
      let state = contentState(s)
      // staleDate = rest end: the system re-renders the Live Activity (isStale
      // flips) exactly when the countdown hits zero, so the view can fall back
      // to the log layout without any interaction.
      let content = ActivityContent(state: state, staleDate: state.restEnds)
      for activity in targets {
        await activity.update(content)
      }
    } else {
      await end(activityID: activityID)
    }
  }

  static func end(activityID: String? = nil) async {
    for activity in activities(targeting: activityID ?? targetActivityID) {
      await activity.end(
        ActivityContent(state: activity.content.state, staleDate: nil),
        dismissalPolicy: .immediate
      )
    }
  }
}

extension WStore {
  /// Save + mirror onto any running Live Activity, and nudge the home widget —
  /// a tap on the Live Activity does NOT auto-reload widget timelines the way a
  /// tap on the widget itself does.
  @available(iOS 17.0, *)
  static func saveAndSync(_ session: Session, activityID: String? = nil) async {
    save(session)
    WidgetCenter.shared.reloadTimelines(ofKind: "GymmerWidget")
    await LiveSync.refresh(activityID: activityID)
  }

  /// Terminal actions must redraw the home widget before awaiting ActivityKit.
  /// Otherwise a slow/missing Activity can make Finish and Discard look stuck.
  @available(iOS 17.0, *)
  static func saveAndEnd(_ session: Session, activityID: String? = nil) async {
    save(session)
    WidgetCenter.shared.reloadTimelines(ofKind: "GymmerWidget")
    await LiveSync.end(activityID: activityID)
  }
}

/// Allows the shared SwiftUI button wrapper to inject ActivityViewContext's
/// exact ID without duplicating every workout mutation intent.
@available(iOS 17.0, *)
protocol TargetedLiveActivityIntent: AppIntent {
  func targeting(activityID: String) -> Self
}

/// Live Activity counterpart to the extension-side widget intents. It runs in
/// Runner, but dispatches to the exact same mutation implementations.
@available(iOS 17.0, *)
struct LiveMutationIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Update workout"
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

  @Parameter(title: "action") var action: String
  @Parameter(title: "value") var value: String
  @Parameter(title: "extra") var extra: String
  @Parameter(title: "delta") var delta: Double
  @Parameter(title: "activityID") var activityID: String

  init() {}
  init(
    action: String,
    value: String = "",
    extra: String = "",
    delta: Double = 0,
    activityID: String = ""
  ) {
    self.action = action
    self.value = value
    self.extra = extra
    self.delta = delta
    self.activityID = activityID
  }

  func targeting(activityID: String) -> Self {
    var copy = self
    copy.activityID = activityID
    return copy
  }

  func perform() async throws -> some IntentResult {
    try await LiveSync.$targetActivityID.withValue(activityID) {
      switch action {
      case "addExercise": _ = try await AddExerciseIntent(value).perform()
      case "pickerAddSet": _ = try await PickerAddSetIntent(value).perform()
      case "pickerRemoveSet": _ = try await PickerRemoveSetIntent(value).perform()
      case "listPage": _ = try await ListPageIntent(Int(delta)).perform()
      case "filterPage": _ = try await FilterPageIntent(Int(delta)).perform()
      case "selectFilter": _ = try await SelectFilterIntent(kind: value, value: extra).perform()
      case "adjust": _ = try await AdjustIntent(field: value, delta: delta).perform()
      case "completeSet": _ = try await CompleteSetIntent().perform()
      case "nextExercise": _ = try await NextExerciseIntent().perform()
      case "restAdjust": _ = try await RestAdjustIntent(Int(delta)).perform()
      case "skipRest": _ = try await SkipRestIntent().perform()
      case "addSet": _ = try await AddSetIntent().perform()
      case "removeSet": _ = try await RemoveSetIntent().perform()
      case "removeExercise": _ = try await RemoveExerciseIntent().perform()
      case "finish": _ = try await FinishSessionIntent().perform()
      case "discard": _ = try await DiscardIntent().perform()
      default: break
      }
    }
    return .result()
  }
}

@available(iOS 17.0, *)
extension LiveMutationIntent: TargetedLiveActivityIntent {}

// This configurable intent is compiled into both Runner and the widget
// extension. Keeping the intent outside the extension-only UI block lets the
// native test target execute the exact Control Center mutation dispatcher.
@available(iOS 18.0, *)
enum GymmerWorkoutControlAction: String, AppEnum {
  case completeSet
  case kgUp
  case kgDown
  case repUp
  case repDown
  case nextExercise
  case skipRest

  static var typeDisplayRepresentation = TypeDisplayRepresentation("Workout action")
  static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
    .completeSet: "Complete Set",
    .kgUp: "Weight +2.5 kg",
    .kgDown: "Weight −2.5 kg",
    .repUp: "Reps +1",
    .repDown: "Reps −1",
    .nextExercise: "Next Exercise",
    .skipRest: "Skip Rest"
  ]

  var label: String {
    switch self {
    case .completeSet: return "Complete Set"
    case .kgUp: return "KG +2.5"
    case .kgDown: return "KG −2.5"
    case .repUp: return "REP +1"
    case .repDown: return "REP −1"
    case .nextExercise: return "Next Exercise"
    case .skipRest: return "Skip Rest"
    }
  }

  var systemImage: String {
    switch self {
    case .completeSet: return "checkmark.circle.fill"
    case .kgUp, .repUp: return "plus.circle"
    case .kgDown, .repDown: return "minus.circle"
    case .nextExercise: return "chevron.right.circle"
    case .skipRest: return "forward.end.circle"
    }
  }
}

@available(iOS 18.0, *)
struct GymmerWorkoutControlIntent: AppIntent, ControlConfigurationIntent {
  static var title: LocalizedStringResource = "Workout Control"
  static var description = IntentDescription("Control the active Gymmer session.")
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

  @Parameter(title: "Action") var action: GymmerWorkoutControlAction?

  init() {}
  init(action: GymmerWorkoutControlAction) { self.action = action }

  var selectedAction: GymmerWorkoutControlAction {
    action ?? .completeSet
  }

  func perform() async throws -> some IntentResult {
    switch selectedAction {
    case .completeSet: _ = try await CompleteSetIntent().perform()
    case .kgUp: _ = try await AdjustIntent(field: "kg", delta: 2.5).perform()
    case .kgDown: _ = try await AdjustIntent(field: "kg", delta: -2.5).perform()
    case .repUp: _ = try await AdjustIntent(field: "rep", delta: 1).perform()
    case .repDown: _ = try await AdjustIntent(field: "rep", delta: -1).perform()
    case .nextExercise: _ = try await NextExerciseIntent().perform()
    case .skipRest: _ = try await SkipRestIntent().perform()
    }
    return .result()
  }
}

#if GYMMER_WIDGET_EXTENSION
// MARK: - Timeline

private struct GymmerActivityIDKey: EnvironmentKey {
  static let defaultValue = ""
}

private extension EnvironmentValues {
  var gymmerActivityID: String {
    get { self[GymmerActivityIDKey.self] }
    set { self[GymmerActivityIDKey.self] = newValue }
  }
}

private struct SurfaceIntentButton<WidgetIntent: AppIntent, LiveIntent: TargetedLiveActivityIntent, Label: View>: View {
  @Environment(\.gymmerActivityID) private var activityID
  let isLiveActivity: Bool
  let widgetIntent: WidgetIntent
  let liveIntent: LiveIntent
  let label: Label

  init(
    isLiveActivity: Bool,
    widgetIntent: WidgetIntent,
    liveIntent: LiveIntent,
    @ViewBuilder label: () -> Label
  ) {
    self.isLiveActivity = isLiveActivity
    self.widgetIntent = widgetIntent
    self.liveIntent = liveIntent
    self.label = label()
  }

  @ViewBuilder var body: some View {
    if isLiveActivity {
      Button(intent: liveIntent.targeting(activityID: activityID)) { label }
    } else {
      Button(intent: widgetIntent) { label }
    }
  }
}

struct GymmerEntry: TimelineEntry {
  let date: Date
  let session: Session
  let catalog: [CatalogItem]
  let routines: [RoutineItem]
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> GymmerEntry {
    GymmerEntry(date: Date(), session: Session(), catalog: [], routines: [])
  }
  func getSnapshot(in context: Context, completion: @escaping (GymmerEntry) -> Void) {
    completion(current())
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<GymmerEntry>) -> Void) {
    let s = WStore.loadSession()
    let cat = WStore.catalog()
    let rts = WStore.routines()
    // The rest countdown animates via SwiftUI Text(timerInterval:) — no need to
    // pre-generate per-second entries (that hit the widget refresh budget and
    // froze the timer on the 2nd rest). We only need one entry now, plus one at
    // rest-end so the widget flips back to the Log page when the timer expires.
    if s.active && s.ui.page == "log", let end = restEndDate(s), end.timeIntervalSinceNow > 0 {
      let entries = [
        GymmerEntry(date: Date(), session: s, catalog: cat, routines: rts),
        GymmerEntry(date: end, session: s, catalog: cat, routines: rts),
      ]
      completion(Timeline(entries: entries, policy: .atEnd))
    } else {
      completion(Timeline(entries: [GymmerEntry(date: Date(), session: s, catalog: cat, routines: rts)], policy: .never))
    }
  }
  private func current() -> GymmerEntry {
    GymmerEntry(date: Date(), session: WStore.loadSession(), catalog: WStore.catalog(), routines: WStore.routines())
  }
}

// MARK: - Reusable view pieces

private struct Pill: View {
  var label: String
  var bg: Color
  var fg: Color
  var body: some View {
    Text(label)
      .font(.system(size: 13, weight: .bold))
      .foregroundColor(fg)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 7)
      .background(bg)
      .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
  }
}

private struct Header: View {
  var title: String
  var subtitle: String?
  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(.system(size: 14, weight: .heavy))
        .foregroundColor(T.accent)
      if let subtitle {
        Text(subtitle)
          .font(.system(size: 11))
          .foregroundColor(T.textSecondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
  }
}

// MARK: - Pages

private struct StartView: View {
  var entry: GymmerEntry
  private let perPage = 3
  var body: some View {
    let routines = entry.routines
    let page = entry.session.ui.routinePage
    let start = page * perPage
    let slice = Array(routines.dropFirst(start).prefix(perPage))
    let hasMore = routines.count > start + perPage

    VStack(alignment: .leading, spacing: 9) {
      Header(title: "GYMMER", subtitle: "New session")
      Button(intent: StartEmptyIntent()) {
        Pill(label: "START · No Routine", bg: T.accent, fg: .black)
      }.buttonStyle(.plain)

      if routines.isEmpty {
        Text("No routines yet — add them in the app")
          .font(.system(size: 11)).foregroundColor(T.textTertiary)
      } else {
        HStack(spacing: 6) {
          ForEach(Array(slice.enumerated()), id: \.offset) { _, r in
            Button(intent: StartRoutineIntent(r.name)) {
              VStack(spacing: 1) {
                Text(r.name).font(.system(size: 12, weight: .semibold))
                  .foregroundColor(T.textPrimary).lineLimit(1)
                Text(r.group).font(.system(size: 9))
                  .foregroundColor(T.textTertiary).lineLimit(1)
              }
              .frame(maxWidth: .infinity).padding(.vertical, 6)
              .background(T.surfaceHigh)
              .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }.buttonStyle(.plain)
          }
          if page > 0 {
            Button(intent: RoutinePageIntent(-1)) { chevron("chevron.left") }.buttonStyle(.plain)
          } else {
            dimChevron("chevron.left")
          }
          if hasMore {
            Button(intent: RoutinePageIntent(1)) { chevron("chevron.right") }.buttonStyle(.plain)
          } else {
            dimChevron("chevron.right")
          }
        }
      }
      Spacer(minLength: 0)
    }
  }
}

private func chevron(_ name: String) -> some View {
  Image(systemName: name)
    .font(.system(size: 12, weight: .bold))
    .foregroundColor(T.textPrimary)
    .frame(width: 30, height: 30)
    .background(T.surfaceHigh)
    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
}

/// A disabled-looking chevron that occupies the SAME footprint as an active one
/// so paging never shifts the surrounding buttons between pages.
private func dimChevron(_ name: String) -> some View {
  Image(systemName: name)
    .font(.system(size: 12, weight: .bold))
    .foregroundColor(T.textTertiary.opacity(0.35))
    .frame(width: 30, height: 30)
    .background(T.surface.opacity(0.4))
    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
}

private struct LogView: View {
  var entry: GymmerEntry
  var isLiveActivity: Bool
  var body: some View {
    let s = entry.session
    if s.exercises.isEmpty {
      emptyState
    } else if restRemaining(s) > 0 {
      RestView(entry: entry, isLiveActivity: isLiveActivity)
    } else {
      logBody(s)
    }
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 9) {
      Header(title: "GYMMER", subtitle: "No exercises")
      SurfaceIntentButton(isLiveActivity: isLiveActivity,
                          widgetIntent: WidgetNavIntent("add"), liveIntent: NavIntent("add")) {
        Pill(label: "เพิ่มท่า", bg: T.accent, fg: .black)
      }
        .buttonStyle(.plain)
      Spacer(minLength: 0)
    }
  }

  private func logBody(_ s: Session) -> some View {
    let ei = s.safeExIndex
    let ex = s.exercises[ei]
    let si = min(max(ex.curSet, 0), ex.sets.count - 1)
    let set = ex.sets[si]
    // When every set of this exercise is logged, show "Done" instead of the set counter.
    let counter = ex.sets.allSatisfy { $0.done } ? "Done" : "เซ็ต \(si + 1)/\(ex.sets.count)"
    return VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(ex.name).font(.system(size: 14, weight: .bold))
          .foregroundColor(T.textPrimary).lineLimit(1)
        Text("ท่า \(ei + 1)/\(s.exercises.count) · \(counter)")
          .font(.system(size: 10)).foregroundColor(T.textSecondary).lineLimit(1)
        Spacer(minLength: 0)
        // Manage moved up to the header to free the control row.
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: WidgetNavIntent("manage"), liveIntent: NavIntent("manage")) {
          Image(systemName: "ellipsis")
            .font(.system(size: 13, weight: .bold)).foregroundColor(T.textPrimary)
            .frame(width: 32, height: 26)
            .background(T.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }.buttonStyle(.plain)
      }
      Text(set.prev.map { "ครั้งก่อน \($0)" } ?? "ไม่มีข้อมูลก่อนหน้า")
        .font(.system(size: 10)).foregroundColor(T.textTertiary).lineLimit(1)

      if sessionComplete(s) {
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: FinishSessionIntent(), liveIntent: LiveMutationIntent(action: "finish")) {
          HStack(spacing: 6) {
            Image(systemName: "flag.checkered")
            Text("จบ session").font(.system(size: 15, weight: .bold))
          }
          .foregroundColor(.black)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(T.accent)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }.buttonStyle(.plain)
      } else {
        // Two rows of horizontal steppers. Row 1: REP + › next exercise.
        // Row 2: KG + ✓ complete set (the primary action, bottom-right).
        VStack(spacing: 7) {
          HStack(spacing: 7) {
            hstepper(label: "REP", value: set.reps.isEmpty ? "0" : set.reps,
                     down: AdjustIntent(field: "rep", delta: -1),
                     up: AdjustIntent(field: "rep", delta: 1),
                     liveDown: LiveMutationIntent(action: "adjust", value: "rep", delta: -1),
                     liveUp: LiveMutationIntent(action: "adjust", value: "rep", delta: 1))
            SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                widgetIntent: NextExerciseIntent(), liveIntent: LiveMutationIntent(action: "nextExercise")) {
              Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .bold)).foregroundColor(T.textPrimary)
                .frame(width: 48).frame(maxHeight: .infinity)
                .background(T.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }.buttonStyle(.plain)
          }
          HStack(spacing: 7) {
            hstepper(label: "KG", value: set.kg.isEmpty ? "0" : set.kg,
                     down: AdjustIntent(field: "kg", delta: -2.5),
                     up: AdjustIntent(field: "kg", delta: 2.5),
                     liveDown: LiveMutationIntent(action: "adjust", value: "kg", delta: -2.5),
                     liveUp: LiveMutationIntent(action: "adjust", value: "kg", delta: 2.5))
            SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                widgetIntent: CompleteSetIntent(), liveIntent: LiveMutationIntent(action: "completeSet")) {
              Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .heavy)).foregroundColor(.black)
                .frame(width: 48).frame(maxHeight: .infinity)
                .background(T.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }.buttonStyle(.plain)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  // Horizontal stepper: [ − ] [ label / value ] [ + ], filling its row height.
  private func hstepper(
    label: String,
    value: String,
    down: some AppIntent,
    up: some AppIntent,
    liveDown: LiveMutationIntent,
    liveUp: LiveMutationIntent
  ) -> some View {
    HStack(spacing: 6) {
      SurfaceIntentButton(isLiveActivity: isLiveActivity, widgetIntent: down, liveIntent: liveDown) {
        hstepIcon("minus")
      }.buttonStyle(.plain)
      VStack(spacing: 0) {
        Text(label).font(.system(size: 9, weight: .semibold)).foregroundColor(T.textTertiary)
        Text(value).font(.system(size: 20, weight: .heavy, design: .rounded))
          .foregroundColor(T.textPrimary).lineLimit(1).minimumScaleFactor(0.6)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      SurfaceIntentButton(isLiveActivity: isLiveActivity, widgetIntent: up, liveIntent: liveUp) {
        hstepIcon("plus")
      }.buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, 6).padding(.vertical, 4)
    .background(T.surface)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func hstepIcon(_ icon: String) -> some View {
    Image(systemName: icon)
      .font(.system(size: 15, weight: .bold)).foregroundColor(T.textPrimary)
      .frame(width: 34).frame(maxHeight: .infinity)
      .background(T.surfaceHigh)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

private struct RestView: View {
  var entry: GymmerEntry
  var isLiveActivity: Bool
  var body: some View {
    let s = entry.session
    // Clamp so the range is always valid even if the end is (just) in the past.
    let end = max(restEndDate(s) ?? Date(), Date().addingTimeInterval(1))
    let allDone = sessionComplete(s)
    VStack(alignment: .leading, spacing: 9) {
      Header(title: "พัก", subtitle: allDone ? "ครบทุกท่าแล้ว" : "หลังบันทึกเซ็ต")
      // Self-ticking countdown — reliable across repeated rests (no timeline budget).
      Text(timerInterval: Date()...end, countsDown: true)
        .font(.system(size: 40, weight: .heavy, design: .rounded))
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .foregroundColor(T.accent)
        .frame(maxWidth: .infinity, alignment: .center)
      HStack(spacing: 6) {
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: RestAdjustIntent(-15), liveIntent: LiveMutationIntent(action: "restAdjust", delta: -15)) {
          Pill(label: "−15", bg: T.surfaceHigh, fg: T.textPrimary)
        }
          .buttonStyle(.plain)
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: RestAdjustIntent(15), liveIntent: LiveMutationIntent(action: "restAdjust", delta: 15)) {
          Pill(label: "+15", bg: T.surfaceHigh, fg: T.textPrimary)
        }
          .buttonStyle(.plain)
        if allDone {
          SurfaceIntentButton(isLiveActivity: isLiveActivity,
                              widgetIntent: FinishSessionIntent(), liveIntent: LiveMutationIntent(action: "finish")) {
            Pill(label: "จบ session", bg: T.accent, fg: .black)
          }
            .buttonStyle(.plain)
        } else {
          SurfaceIntentButton(isLiveActivity: isLiveActivity,
                              widgetIntent: SkipRestIntent(), liveIntent: LiveMutationIntent(action: "skipRest")) {
            Pill(label: "ข้าม", bg: T.accent, fg: .black)
          }
            .buttonStyle(.plain)
        }
      }
      Spacer(minLength: 0)
    }
  }
}

private struct AddView: View {
  var entry: GymmerEntry
  var isLiveActivity: Bool
  private let perPage = 4
  var body: some View {
    let s = entry.session
    let filtered = entry.catalog.filter { item in
      (s.ui.muscleFilter == nil || item.muscle == s.ui.muscleFilter) &&
      (s.ui.equipFilter == nil || item.equipment == s.ui.equipFilter)
    }
    let page = s.ui.listPage
    let slice = Array(filtered.dropFirst(page * perPage).prefix(perPage))
    let hasMore = filtered.count > (page + 1) * perPage

    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: WidgetNavIntent("fmuscle"), liveIntent: NavIntent("fmuscle")) {
          filterBtn(s.ui.muscleFilter ?? "Muscle")
        }.buttonStyle(.plain)
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: WidgetNavIntent("fequip"), liveIntent: NavIntent("fequip")) {
          filterBtn(s.ui.equipFilter ?? "Equip")
        }.buttonStyle(.plain)
        Spacer(minLength: 0)
        // Single right-pager that wraps back to page 0 past the last page.
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: ListPageIntent(hasMore ? 1 : -page),
                            liveIntent: LiveMutationIntent(action: "listPage", delta: Double(hasMore ? 1 : -page))) {
          chevron("chevron.right")
        }.buttonStyle(.plain)
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: WidgetNavIntent("log"), liveIntent: NavIntent("log")) {
          Text("Done").font(.system(size: 12, weight: .bold)).foregroundColor(.black)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(T.accent).clipShape(Capsule())
        }.buttonStyle(.plain)
      }
      // Pad to a full page of cells so the grid height stays fixed no matter
      // how many exercises the last page has.
      let cells: [CatalogItem?] = slice.map { Optional($0) }
        + Array<CatalogItem?>(repeating: nil, count: max(0, perPage - slice.count))
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
        ForEach(Array(cells.enumerated()), id: \.offset) { _, item in
          if let item {
            if let qi = s.exercises.firstIndex(where: { $0.name == item.name }) {
              // Already queued: split into two tap zones sharing one background.
              // Left circle = −1 set (removes the exercise at 1 set); right = +1 set.
              HStack(spacing: 5) {
                SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                    widgetIntent: PickerRemoveSetIntent(item.name),
                                    liveIntent: LiveMutationIntent(action: "pickerRemoveSet", value: item.name)) {
                  queueBadge(order: qi + 1, sets: s.exercises[qi].sets.count)
                }.buttonStyle(.plain)
                SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                    widgetIntent: PickerAddSetIntent(item.name),
                                    liveIntent: LiveMutationIntent(action: "pickerAddSet", value: item.name)) {
                  cellText(item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
              }
              .padding(.horizontal, 7).padding(.vertical, 7)
              .frame(maxWidth: .infinity)
              .background(T.surfaceHigh)
              .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
              // Not queued: tap anywhere on the cell to add it (1 set).
              SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                  widgetIntent: AddExerciseIntent(item.name),
                                  liveIntent: LiveMutationIntent(action: "addExercise", value: item.name)) {
                HStack(spacing: 5) {
                  plusBadge()
                  cellText(item)
                  Spacer(minLength: 0)
                }
                .padding(.horizontal, 7).padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(T.surface)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
              }.buttonStyle(.plain)
            }
          } else {
            Color.clear.frame(height: 34) // placeholder keeps the row height
          }
        }
      }
      Spacer(minLength: 0)
    }
  }

  private func filterBtn(_ label: String) -> some View {
    HStack(spacing: 3) {
      Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(T.textPrimary).lineLimit(1)
      Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundColor(T.textTertiary)
    }
    .padding(.horizontal, 9).padding(.vertical, 6)
    .background(T.surfaceHigh).clipShape(Capsule())
  }

  private func cellText(_ item: CatalogItem) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(item.name).font(.system(size: 11, weight: .semibold))
        .foregroundColor(T.textPrimary).lineLimit(1)
      Text(item.muscle).font(.system(size: 9))
        .foregroundColor(T.textTertiary).lineLimit(1)
    }
  }

  private func plusBadge() -> some View {
    ZStack {
      Circle().fill(T.surfaceHigh).frame(width: 20, height: 20)
      Image(systemName: "plus").font(.system(size: 10, weight: .bold)).foregroundColor(T.textSecondary)
    }
  }

  // Queued exercise badge: "order x sets" (e.g. 1x3). Tapping it removes a set.
  private func queueBadge(order: Int, sets: Int) -> some View {
    ZStack {
      Circle().fill(T.accent).frame(width: 24, height: 24)
      Text("\(order)x\(sets)")
        .font(.system(size: 9, weight: .heavy)).foregroundColor(.black)
        .lineLimit(1).minimumScaleFactor(0.6)
    }
  }
}

private enum FilterCell { case all, value(String), empty }

private struct FilterView: View {
  var entry: GymmerEntry
  var isMuscle: Bool
  var isLiveActivity: Bool
  private let perPage = 8 // + the "All" cell = 9 cells (3×3), fixed each page
  var body: some View {
    let s = entry.session
    let values = distinctValues()
    let selected = isMuscle ? s.ui.muscleFilter : s.ui.equipFilter
    let page = s.ui.filterPage
    let slice = Array(values.dropFirst(page * perPage).prefix(perPage))
    let hasMore = values.count > (page + 1) * perPage
    let kind = isMuscle ? "muscle" : "equip"
    // First page leads with All; every page is padded to 9 cells so the grid
    // height (and the nav row) never shifts between pages. Built in a helper so
    // the ViewBuilder body stays free of control-flow statements.
    let cells = paddedCells(leadWithAll: page == 0, values: slice)

    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 6) {
        Header(title: isMuscle ? "Filter · Muscle" : "Filter · Equip", subtitle: nil)
        // Single right-pager that wraps back to page 0 past the last page.
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: FilterPageIntent(hasMore ? 1 : -page),
                            liveIntent: LiveMutationIntent(action: "filterPage", delta: Double(hasMore ? 1 : -page))) {
          chevron("chevron.right")
        }.buttonStyle(.plain)
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: WidgetNavIntent("add"), liveIntent: NavIntent("add")) {
          Text("BACK").font(.system(size: 11, weight: .bold)).foregroundColor(T.textSecondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(T.surfaceHigh).clipShape(Capsule())
        }.buttonStyle(.plain)
      }
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)], spacing: 5) {
        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
          switch cell {
          case .all:
            SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                widgetIntent: SelectFilterIntent(kind: kind, value: ""),
                                liveIntent: LiveMutationIntent(action: "selectFilter", value: kind)) {
              chip("All", on: selected == nil)
            }.buttonStyle(.plain)
          case .value(let v):
            SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                widgetIntent: SelectFilterIntent(kind: kind, value: v),
                                liveIntent: LiveMutationIntent(action: "selectFilter", value: kind, extra: v)) {
              chip(v, on: selected == v)
            }.buttonStyle(.plain)
          case .empty:
            Color.clear.frame(height: 27)
          }
        }
      }
      Spacer(minLength: 0)
    }
  }

  // Fixed 9-cell page: optional leading All, the page's values, empty padding.
  // Uses Array(repeating:count:) instead of a while-loop so this can't sit in
  // (and break) the ViewBuilder body.
  private func paddedCells(leadWithAll: Bool, values: [String]) -> [FilterCell] {
    var cells: [FilterCell] = leadWithAll ? [.all] : []
    cells += values.map { FilterCell.value($0) }
    cells += Array(repeating: FilterCell.empty, count: max(0, 9 - cells.count))
    return cells
  }

  private func distinctValues() -> [String] {
    var seen: [String] = []
    for item in entry.catalog {
      let v = isMuscle ? item.muscle : item.equipment
      if !v.isEmpty && !seen.contains(v) { seen.append(v) }
    }
    return seen
  }

  private func chip(_ label: String, on: Bool) -> some View {
    Text(label)
      .font(.system(size: 11, weight: .semibold))
      .foregroundColor(on ? .black : T.textPrimary)
      .lineLimit(1)
      .frame(maxWidth: .infinity).padding(.vertical, 6)
      .background(on ? T.accent : T.surfaceHigh)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

private struct ManageView: View {
  var entry: GymmerEntry
  var isLiveActivity: Bool
  var body: some View {
    let s = entry.session
    let exName = s.currentExercise?.name ?? "—"
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Header(title: "Manage", subtitle: exName)
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: WidgetNavIntent("log"), liveIntent: NavIntent("log")) {
          Text("BACK").font(.system(size: 11, weight: .bold)).foregroundColor(T.textSecondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(T.surfaceHigh).clipShape(Capsule())
        }.buttonStyle(.plain)
      }
      manageRow(title: "เซ็ต",
                add: AnyView(SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                                 widgetIntent: AddSetIntent(), liveIntent: LiveMutationIntent(action: "addSet")) {
                  miniPill("+ เพิ่ม", T.surfaceHigh, T.textPrimary)
                }.buttonStyle(.plain)),
                remove: AnyView(SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                                    widgetIntent: RemoveSetIntent(), liveIntent: LiveMutationIntent(action: "removeSet")) {
                  miniPill("− ลบ", T.surfaceHigh, T.textPrimary)
                }.buttonStyle(.plain)))
      manageRow(title: "ท่า",
                add: AnyView(SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                                 widgetIntent: WidgetNavIntent("add"), liveIntent: NavIntent("add")) {
                  miniPill("+ เพิ่ม", T.surfaceHigh, T.textPrimary)
                }.buttonStyle(.plain)),
                remove: AnyView(SurfaceIntentButton(isLiveActivity: isLiveActivity,
                                                    widgetIntent: RemoveExerciseIntent(), liveIntent: LiveMutationIntent(action: "removeExercise")) {
                  miniPill("− ลบ", T.surfaceHigh, T.textPrimary)
                }.buttonStyle(.plain)))
      HStack(spacing: 6) {
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: FinishSessionIntent(), liveIntent: LiveMutationIntent(action: "finish")) {
          Pill(label: "จบ session", bg: T.accent, fg: .black)
        }.buttonStyle(.plain)
        SurfaceIntentButton(isLiveActivity: isLiveActivity,
                            widgetIntent: DiscardIntent(), liveIntent: LiveMutationIntent(action: "discard")) {
          Pill(label: "Discard", bg: T.surfaceHigh, fg: T.danger)
        }.buttonStyle(.plain)
      }
      Spacer(minLength: 0)
    }
  }

  private func manageRow(title: String, add: AnyView, remove: AnyView) -> some View {
    HStack(spacing: 6) {
      Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(T.textSecondary)
        .frame(width: 44, alignment: .leading)
      add
      remove
    }
  }

  private func miniPill(_ label: String, _ bg: Color, _ fg: Color) -> some View {
    Text(label).font(.system(size: 12, weight: .bold)).foregroundColor(fg)
      .frame(maxWidth: .infinity).padding(.vertical, 6)
      .background(bg).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

// MARK: - Router / entry view

struct GymmerWidgetEntryView: View {
  var entry: GymmerEntry
  var body: some View {
    GymmerSessionPagesView(entry: entry, showStart: true, isLiveActivity: false)
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .containerBackground(T.bg, for: .widget)
  }
}

private struct GymmerSessionPagesView: View {
  var entry: GymmerEntry
  var showStart: Bool
  var isLiveActivity: Bool

  @ViewBuilder var body: some View {
    let s = entry.session
    if !s.active {
      if showStart {
        StartView(entry: entry)
      } else {
        Color.clear
      }
    } else {
      switch s.ui.page {
      case "add": AddView(entry: entry, isLiveActivity: isLiveActivity)
      case "fmuscle": FilterView(entry: entry, isMuscle: true, isLiveActivity: isLiveActivity)
      case "fequip": FilterView(entry: entry, isMuscle: false, isLiveActivity: isLiveActivity)
      case "manage": ManageView(entry: entry, isLiveActivity: isLiveActivity)
      default: LogView(entry: entry, isLiveActivity: isLiveActivity)
      }
    }
  }
}

// MARK: - Widget

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

@main
struct GymmerBundle: WidgetBundle {
  var body: some Widget {
    GymmerWidget()
    GymmerLiveActivity()
    if #available(iOS 18.0, *) {
      GymmerWorkoutActionControl()
    }
  }
}

// MARK: - System controls (Control Center / Lock Screen / Action button)

@available(iOS 18.0, *)
struct GymmerWorkoutActionControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    AppIntentControlConfiguration(
      kind: "com.gymmer.workout-action",
      intent: GymmerWorkoutControlIntent.self
    ) { configuration in
      ControlWidgetButton(action: configuration) {
        Label {
          Text(configuration.selectedAction.label)
        } icon: {
          Image(systemName: configuration.selectedAction.systemImage)
        }
      }
    }
    .displayName("Workout Action")
    .description("Choose a workout action for Control Center, the Lock Screen, or Action button.")
    .promptsForUserConfiguration()
  }
}

// MARK: - Live Activity (same pages as the widget, without Start)

// The Lock Screen and expanded Dynamic Island use the same Add/Filter/Log/Manage
// views and App Intents as the home widget; only the Start page is omitted.
struct GymmerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: GymmerActivityAttributes.self) { context in
      LiveActivityEntryView(state: context.state, title: context.attributes.title)
        .environment(\.gymmerActivityID, context.activityID)
        .activityBackgroundTint(T.bg)
        .activitySystemActionForegroundColor(T.textPrimary)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
          LiveActivityEntryView(state: context.state, title: context.attributes.title)
            .environment(\.gymmerActivityID, context.activityID)
        }
      } compactLeading: {
        Image(systemName: "dumbbell.fill").foregroundColor(T.accent)
      } compactTrailing: {
        Text(context.state.setLabel).font(.system(size: 11, weight: .semibold))
      } minimal: {
        Image(systemName: "dumbbell.fill").foregroundColor(T.accent)
      }
    }
  }
}

private struct LiveActivityEntryView: View {
  let state: GymmerActivityAttributes.ContentState
  let title: String

  private var entry: GymmerEntry {
    let stored = WStore.loadSession()
    var session = stored
    session.active = true
    session.sessionName = session.sessionName ?? title
    session.ui.page = state.page ?? "log"
    return GymmerEntry(
      date: Date(),
      session: session,
      catalog: WStore.catalog(),
      routines: []
    )
  }

  var body: some View {
    GymmerSessionPagesView(entry: entry, showStart: false, isLiveActivity: true)
      .padding(12)
      .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
      .background(T.bg)
  }
}
#endif
