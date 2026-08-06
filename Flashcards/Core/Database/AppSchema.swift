import Foundation
import SwiftData

/// The app's persisted models, in one place.
///
/// Every `ModelContainer` in the app and in the tests is built from this list, so a model that is
/// added here is available everywhere and a model that is missing fails everywhere at once rather
/// than in whichever screen happened to fetch it.
enum AppSchema {
  static let models: [any PersistentModel.Type] = [
    Deck.self,
    Card.self,
    SessionRecord.self,
  ]

  static var schema: Schema { Schema(models) }
}

extension ModelContainer {
  /// The production container: the app's schema, persisted to disk.
  ///
  /// Persistence is the default rather than a configured option because the store being on disk
  /// is what makes it part of the standard device/iCloud backup, which is the app's entire
  /// continuity story. The API key is deliberately not in here — it lives in the Keychain with
  /// `ThisDeviceOnly` accessibility, so it is excluded from that backup. See ADR 0002.
  ///
  /// **CloudKit is not enabled**, and the one-line flag that would enable it should not be added
  /// without revisiting ADR 0002 — it is cross-device sync, which that ADR rules out.
  static func makeApplicationContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: false)
    return try ModelContainer(for: AppSchema.schema, configurations: configuration)
  }

  /// An in-memory container over the real schema, for tests.
  ///
  /// Tests run against the real models and real repositories rather than fakes, so a test
  /// exercising Session composition runs against the real schema and catches schema and fetch
  /// bugs a fake repository would hide. This is the deliberate choice against a repository seam
  /// described in the spec's Testing Decisions.
  static func makeInMemoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: AppSchema.schema, configurations: configuration)
  }
}
