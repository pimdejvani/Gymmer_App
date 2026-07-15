import Foundation
import ActivityKit

// Shared Live Activity type. MUST be compiled into BOTH the Runner (app) and the
// GymmerWidget (extension) targets — ActivityKit matches an ActivityConfiguration
// to a running Activity by this exact type, so a per-target duplicate (different
// module) would not match. See project.pbxproj: this file is a member of both
// Sources build phases.
//
// The app (foreground) starts the activity; the widget extension's App Intents
// update it while the app is backgrounded. The ContentState carries the current
// page plus compact fields used by Dynamic Island. Full page/session data stays
// in session.json so the Lock Screen can reuse the home widget's page views.
@available(iOS 16.1, *)
struct GymmerActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var phase: String          // "log" | "rest" | "done"
    var exName: String         // current exercise name
    var exIndex: Int           // 1-based position
    var exCount: Int           // total exercises
    var setLabel: String       // "เซ็ต 2/3" or "Done"
    var kg: String
    var reps: String
    var prev: String?          // "ครั้งก่อน 20kg x 10" style, optional
    var restEndsEpoch: Double? // rest end (epoch seconds); nil when not resting
    var page: String?          // "add" | "fmuscle" | "fequip" | "log" | "manage"

    var restEnds: Date? {
      guard let e = restEndsEpoch else { return nil }
      return Date(timeIntervalSince1970: e)
    }
  }

  var title: String            // routine / session name (static for the session)
}
