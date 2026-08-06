import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import Flashcards

/// Driven the way the Settings screen drives it — set a value, read what the app would read — over
/// a defaults suite that belongs to the test. Relaunch is modelled by building a second `AppSettings`
/// over the same suite, which is the only thing "persists across relaunch" can mean here.
@MainActor
@Suite("App settings")
struct AppSettingsTests {

  @Test("Out of the box a Session is five Cards, the theme follows the system, and Cards animate")
  func defaultsAreTheUnconfiguredOnes() {
    let store = TemporaryDefaults()

    let settings = AppSettings(defaults: store.defaults)

    #expect(settings.sessionLength == .five)
    #expect(settings.theme == .system)
    #expect(settings.cardAnimations == .followDevice)
  }

  @Test("A chosen Session length survives relaunch")
  func sessionLengthPersists() {
    let store = TemporaryDefaults()
    AppSettings(defaults: store.defaults).sessionLength = .ten

    #expect(AppSettings(defaults: store.defaults).sessionLength == .ten)
  }

  @Test("A chosen theme survives relaunch")
  func themePersists() {
    let store = TemporaryDefaults()
    AppSettings(defaults: store.defaults).theme = .dark

    #expect(AppSettings(defaults: store.defaults).theme == .dark)
  }

  @Test("A Card animation choice survives relaunch")
  func cardAnimationsPersist() {
    let store = TemporaryDefaults()
    AppSettings(defaults: store.defaults).cardAnimations = .off

    #expect(AppSettings(defaults: store.defaults).cardAnimations == .off)
  }

  /// The setting is a choice the user made, not a value copied off the device once: clearing it
  /// hands the answer back to Reduce Motion rather than freezing whatever it said at the time.
  @Test("Following the device is a state of its own, not a copy of what it said at the time")
  func followingTheDeviceIsItsOwnState() {
    let store = TemporaryDefaults()
    let settings = AppSettings(defaults: store.defaults)
    settings.cardAnimations = .off

    settings.cardAnimations = .followDevice

    #expect(AppSettings(defaults: store.defaults).cardAnimations == .followDevice)
  }

  /// The whole point of the default: a learner who has already turned Reduce Motion on system-wide
  /// does not have to turn Cards off here as well.
  @Test("Following the device means what Reduce Motion says")
  func followingTheDeviceMeansReduceMotion() {
    #expect(CardAnimations.followDevice.reducesMotion(whenDeviceReducesMotion: true))
    #expect(!CardAnimations.followDevice.reducesMotion(whenDeviceReducesMotion: false))
  }

  /// And the other half of it: the learner can still disagree with the device in either direction.
  @Test("An explicit choice overrides the device in either direction")
  func anExplicitChoiceOverridesTheDevice() {
    #expect(CardAnimations.off.reducesMotion(whenDeviceReducesMotion: false))
    #expect(!CardAnimations.on.reducesMotion(whenDeviceReducesMotion: true))
  }

  /// What the toggle in Settings shows before it has ever been touched.
  @Test("The toggle reads as off on a device already reducing motion")
  func theToggleFollowsTheDeviceUntilItIsTouched() {
    #expect(!CardAnimations.followDevice.areOn(whenDeviceReducesMotion: true))
    #expect(CardAnimations.followDevice.areOn(whenDeviceReducesMotion: false))
  }

  @Test("The theme override names a colour scheme, and following the system names none")
  func themesNameAColourScheme() {
    #expect(ThemePreference.system.colorScheme == nil)
    #expect(ThemePreference.light.colorScheme == .light)
    #expect(ThemePreference.dark.colorScheme == .dark)
  }

  /// A stored value the app no longer understands — an older build's, or a hand-edited plist — is
  /// not a reason to launch into a broken Session length.
  @Test("A stored value this build does not understand falls back to the default")
  func anUnreadableStoredValueFallsBack() {
    let store = TemporaryDefaults()
    store.defaults.set(7, forKey: "settings.sessionLength")
    store.defaults.set("sepia", forKey: "settings.theme")

    let settings = AppSettings(defaults: store.defaults)

    #expect(settings.sessionLength == .five)
    #expect(settings.theme == .system)
  }

  /// The acceptance criterion the rest of the settings only support: the number the learner picked
  /// is the number of Cards the next Session runs. Driven through the composition root, because
  /// wiring the setting to `SessionModel` is the part that can silently not happen.
  @Test("The chosen Session length is how many Cards the next Session contains")
  func sessionLengthReachesTheNextSession() throws {
    let store = TemporaryDefaults()
    let settings = AppSettings(defaults: store.defaults)
    let dependencies = AppDependencies(
      modelContainer: try ModelContainer.makeInMemoryContainer(),
      dateProvider: FixedDateProvider(now: .at(2026, 3, 1, 9, 30)),
      settings: settings)
    let deck = try SwiftDataDeckRepository(
      context: dependencies.mainContext, dateProvider: dependencies.dateProvider
    ).createDeck(named: "Spanish verbs")
    let cards = SwiftDataCardRepository(
      context: dependencies.mainContext, dateProvider: dependencies.dateProvider)
    for index in 0..<10 {
      try cards.addCard(toDeckWithID: deck.id, front: "Front \(index)", back: "Back \(index)")
    }

    settings.sessionLength = .three
    let short = dependencies.makeSessionModel(forDeckWithID: deck.id)
    short.start()

    #expect(short.state.reviewing?.total == 3)

    // The same store and the same Deck: only the setting changed, and the Session that follows it
    // is the one that changed with it.
    settings.sessionLength = .ten
    let long = dependencies.makeSessionModel(forDeckWithID: deck.id)
    long.start()

    #expect(long.state.reviewing?.total == 10)
  }
}
