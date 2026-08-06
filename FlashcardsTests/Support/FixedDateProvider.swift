import Foundation

@testable import Flashcards

/// A `DateProvider` that returns whatever the test tells it to.
///
/// **Hand-written, and living with the tests — there is no mocking library in this project.** This
/// is the first of the fakes, so it sets the pattern: a struct or final class conforming to the
/// production protocol, no recorded calls, no verification. Tests assert on what the code under
/// test *produced*, never on which methods a fake was asked for.
final class FixedDateProvider: DateProvider, @unchecked Sendable {
  private let lock = NSLock()
  private var _now: Date

  let calendar: Calendar

  /// - Parameters:
  ///   - now: The instant every read of `now` returns until `advance(by:)` or `set(to:)` moves it.
  ///   - calendar: Defaults to a fixed UTC Gregorian calendar so day-boundary tests do not depend
  ///     on the machine running them. A test covering the crossing-midnight case should pass its
  ///     own calendar with the time zone it means to exercise.
  init(now: Date, calendar: Calendar = .utcGregorian) {
    self._now = now
    self.calendar = calendar
  }

  var now: Date {
    lock.withLock { _now }
  }

  func advance(by interval: TimeInterval) {
    lock.withLock { _now += interval }
  }

  func set(to date: Date) {
    lock.withLock { _now = date }
  }
}

extension Calendar {
  /// A calendar that does not vary with the machine running the tests.
  ///
  /// `nonisolated` because the project defaults to `MainActor` isolation, and this is used as a
  /// default argument in a nonisolated initialiser.
  nonisolated static var utcGregorian: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }
}

extension Date {
  /// Builds a date from components in the given calendar, for readable fixtures.
  ///
  /// Traps rather than returning an optional: a test fixture that does not describe a real date is
  /// a broken test, and it should fail at the line that wrote it.
  nonisolated static func at(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 0,
    _ minute: Int = 0,
    calendar: Calendar = .utcGregorian
  ) -> Date {
    let components = DateComponents(
      year: year, month: month, day: day, hour: hour, minute: minute)
    guard let date = calendar.date(from: components) else {
      preconditionFailure("Not a real date: \(year)-\(month)-\(day) \(hour):\(minute)")
    }
    return date
  }
}
