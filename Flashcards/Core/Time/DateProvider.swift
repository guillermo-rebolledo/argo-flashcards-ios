import Foundation

/// The seam for everything that asks what time it is.
///
/// Day streaks, Session durations, and last-seen ordering are all time-dependent, and none of
/// them is testable against a real clock. Every read of wall-clock time in the app goes through
/// this protocol so a test can supply its own answer.
///
/// This is the Android app's `Clock` seam under a different name. Swift's `Clock` protocol is
/// about measuring elapsed durations, not about what day it is, so reusing that name here would
/// mean the wrong thing. The one place that genuinely wants elapsed time — Session duration —
/// uses `ContinuousClock` instead.
protocol DateProvider: Sendable {
  /// The current instant.
  var now: Date { get }

  /// The calendar day boundaries are measured against.
  ///
  /// Part of the seam rather than a global, because "did the user study yesterday" depends on the
  /// calendar and the time zone as much as on the instant, and a test that cannot control those
  /// cannot cover the crossing-midnight case.
  var calendar: Calendar { get }
}

/// The production implementation: the system clock, in the user's current calendar and time zone.
struct SystemDateProvider: DateProvider {
  var now: Date { Date() }

  /// Autoupdating, so a time-zone change while the app is running is picked up without relaunch.
  var calendar: Calendar { Calendar.autoupdatingCurrent }
}
