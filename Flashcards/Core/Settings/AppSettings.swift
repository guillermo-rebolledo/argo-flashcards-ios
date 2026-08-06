import Foundation
import Observation
import SwiftUI

/// How many Cards a Session contains.
///
/// Three values and no free number: the point of the setting is to match a sitting to the
/// attention the learner actually has, and a stepper up to 50 would quietly reintroduce the
/// backlog this app exists not to have. Raw values are the count, so there is one place the
/// numbers live and no table mapping a case to a size.
enum SessionLength: Int, CaseIterable, Identifiable, Sendable {
  case three = 3
  case five = 5
  case ten = 10

  var id: Int { rawValue }

  /// How many Cards a Session of this length draws.
  var cardCount: Int { rawValue }

  /// What the picker calls it — the number alone. "3 Cards" would repeat the row's own label.
  var title: String { "\(rawValue)" }
}

/// Which appearance the app is drawn in.
enum ThemePreference: String, CaseIterable, Identifiable, Sendable {
  /// Whatever the device is doing. The default, and what most people should stay on.
  case system

  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }

  /// What to hand `preferredColorScheme`. `nil` is not "no theme" — it is the absence of an
  /// override, which is how SwiftUI spells "follow the system".
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

/// Whether Cards move during Review.
///
/// **Three states rather than a `Bool`**, because "follow the device" is not the same fact as "on".
/// A learner who has Reduce Motion on system-wide and has never opened this setting should get
/// still Cards without configuring it twice — and if they turn Reduce Motion off next month, the
/// Cards should start moving again rather than staying frozen because the app copied the value once.
enum CardAnimations: Equatable, Sendable {
  /// Untouched: the device's Reduce Motion setting answers.
  case followDevice

  /// The learner disagreed with the device, in one direction or the other.
  case on
  case off

  /// Whether Review should take the reduced-motion path: the Card cross-fades where it was let go
  /// rather than flying, and the tilt is zeroed.
  ///
  /// **Haptics are not motion and are not covered by this.** Losing the confirmation that a Grade
  /// landed is not part of what a learner asks for when they turn animations off.
  func reducesMotion(whenDeviceReducesMotion deviceReducesMotion: Bool) -> Bool {
    switch self {
    case .followDevice: deviceReducesMotion
    case .on: false
    case .off: true
    }
  }

  /// The same fact the other way up, for the toggle in Settings, which has only two positions to
  /// draw and must show the device's answer until the learner gives their own.
  func areOn(whenDeviceReducesMotion deviceReducesMotion: Bool) -> Bool {
    !reducesMotion(whenDeviceReducesMotion: deviceReducesMotion)
  }
}

/// The learner's settings: the values themselves, and the only place they are read from or written
/// to the store.
///
/// One observable object shared by the whole app rather than a screen model of its own, because
/// these values are read in three places at once — the shell draws the theme, Review draws the
/// animations, and a Session is composed from the length — and a per-screen copy would be three
/// copies to keep in step. It is still what the Settings screen binds to, and what the tests drive.
///
/// `UserDefaults` rather than the SwiftData store: three scalars a learner chooses about the app
/// are not content, they never need to be queried or related to a Deck, and they must be readable
/// before the container is open.
@MainActor
@Observable
final class AppSettings {

  /// How many Cards the **next** Session draws. Changing it mid-Session leaves that sitting alone,
  /// because a Session's Cards are drawn once — see `SessionModel`.
  var sessionLength: SessionLength {
    didSet { defaults.set(sessionLength.rawValue, forKey: Key.sessionLength) }
  }

  var theme: ThemePreference {
    didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
  }

  /// Stored as an absent key for `followDevice` and a `Bool` otherwise, so "never chosen" and
  /// "chose off" stay different facts in the plist as well as in memory.
  var cardAnimations: CardAnimations {
    didSet {
      switch cardAnimations {
      case .followDevice: defaults.removeObject(forKey: Key.cardAnimations)
      case .on: defaults.set(true, forKey: Key.cardAnimations)
      case .off: defaults.set(false, forKey: Key.cardAnimations)
      }
    }
  }

  private let defaults: UserDefaults

  /// - Parameter defaults: Where the settings live. A suite of its own in tests, so a test can
  ///   neither read nor leave behind a real learner's choices.
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults

    // A value this build cannot read — an older one's, or a hand-edited plist — is the default
    // rather than a crash or a Session of seven Cards.
    sessionLength =
      SessionLength(rawValue: defaults.integer(forKey: Key.sessionLength)) ?? .five
    theme = defaults.string(forKey: Key.theme).flatMap(ThemePreference.init(rawValue:)) ?? .system
    cardAnimations =
      defaults.object(forKey: Key.cardAnimations) == nil
      ? .followDevice
      : (defaults.bool(forKey: Key.cardAnimations) ? .on : .off)
  }

  /// Namespaced, so a later setting cannot collide with a key some framework wrote into the same
  /// suite.
  private enum Key {
    static let sessionLength = "settings.sessionLength"
    static let theme = "settings.theme"
    static let cardAnimations = "settings.cardAnimations"
  }
}

extension EnvironmentValues {
  /// How the setting reaches Review.
  ///
  /// The environment rather than an initialiser parameter because the Card is drawn several views
  /// down from the shell, and because the answer can change while a Session is up. It defaults to
  /// `followDevice`, so a preview — or any view drawn outside the app's shell — still honours
  /// Reduce Motion without being handed the settings.
  @Entry var cardAnimations: CardAnimations = .followDevice
}
