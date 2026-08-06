import Foundation

/// A `UserDefaults` suite that belongs to one test and is thrown away with it.
///
/// Settings are the one part of the app whose store is not SwiftData, so the isolation every other
/// suite gets from an in-memory container has to come from somewhere else: a suite named after a
/// fresh `UUID` cannot be seen by another test, and cannot leave anything behind for the next run
/// to read as a user's preference.
final class TemporaryDefaults {
  let defaults: UserDefaults

  private let name: String

  init() {
    name = "TemporaryDefaults.\(UUID().uuidString)"
    // Force-unwrapped deliberately: a suite name this app never uses elsewhere only fails to open
    // for a reason a test should stop on rather than route around.
    defaults = UserDefaults(suiteName: name)!
  }

  deinit {
    UserDefaults.standard.removePersistentDomain(forName: name)
  }
}
