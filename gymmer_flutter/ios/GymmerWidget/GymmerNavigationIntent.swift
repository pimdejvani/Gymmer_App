import AppIntents

/// Navigation runs in the containing app for Live Activities. The Activity ID
/// comes from ActivityViewContext so this tap updates only the surface that was
/// actually used, while still persisting the shared widget session snapshot.
@available(iOS 17.0, *)
struct NavIntent: LiveActivityIntent, TargetedLiveActivityIntent {
  static var title: LocalizedStringResource = "Navigate"
  static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

  @Parameter(title: "page") var page: String
  @Parameter(title: "activityID") var activityID: String

  init() {}
  init(_ page: String, activityID: String = "") {
    self.page = page
    self.activityID = activityID
  }

  func targeting(activityID: String) -> Self {
    var copy = self
    copy.activityID = activityID
    return copy
  }

  func perform() async throws -> some IntentResult {
    var session = WStore.loadSession()
    session.ui.page = page
    await WStore.saveAndSync(session, activityID: activityID)
    return .result()
  }
}
