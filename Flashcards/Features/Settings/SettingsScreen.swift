import SwiftUI

/// The Settings tab.
///
/// This is a tab rather than a gear in a toolbar because a failed Generation routes the user here
/// — a destination reached from an error path should be one tap away.
///
/// Three settings, and **no palette, accent, or theme colour, now or later** — see ADR 0008. The
/// light/dark override below is the only appearance control the app has, because it is the one the
/// system itself implies.
///
/// API key entry and Reminders arrive with their own tickets.
///
/// Unlike every other screen in the app this one is not split into a screen and a state-drawing
/// view. There is no state to draw: `AppSettings` is the model, every control binds straight to a
/// value on it, and there is no loading, empty, or failed case to preview.
struct SettingsScreen: View {
  /// Owned by the composition root and shared with the shell, not made here: the theme this screen
  /// writes is the theme the whole app is drawn in.
  let settings: AppSettings

  /// The device's own answer, which the Card animations toggle shows until the learner gives their
  /// own. Read here rather than inside `AppSettings` because it belongs to the environment the
  /// screen is drawn in, and it can change while the screen is open.
  @Environment(\.accessibilityReduceMotion) private var deviceReducesMotion

  var body: some View {
    List {
      Section {
        Picker("Session length", selection: sessionLength) {
          ForEach(SessionLength.allCases) { length in
            Text(length.title).tag(length)
          }
        }
        .pickerStyle(.segmented)
      } header: {
        Text("Session length")
      } footer: {
        // The glossary's own definition, said as a reason rather than as a description: the setting
        // exists so a sitting matches the attention the learner has.
        Text("How many Cards a Session contains. Pick the number you can finish in one sitting.")
      }

      Section {
        Picker("Theme", selection: theme) {
          ForEach(ThemePreference.allCases) { theme in
            Text(theme.title).tag(theme)
          }
        }
        .pickerStyle(.segmented)
      } header: {
        Text("Theme")
      } footer: {
        Text("Light or dark, whatever the device is set to.")
      }

      Section {
        Toggle("Card animations", isOn: cardAnimations)
      } footer: {
        // Says what turning it off does, rather than describing whichever way it currently sits.
        // The second sentence is there because a learner turning this off is entitled to know what
        // stays: the Grade still registers, and it still confirms itself in the hand.
        Text(
          "Turned off, Cards fade instead of flying. Grading still gives the same feedback in "
            + "your hand. This follows your device's Reduce Motion setting unless you set it "
            + "the other way."
        )
      }
    }
    .navigationTitle("Settings")
  }

  /// Bindings rather than `@Bindable`, because two of the three settings are not the type their
  /// control is: the toggle is a `Bool` over a three-state value that the device answers for.
  /// Writing all three the same way keeps that difference from reading as an inconsistency.
  private var sessionLength: Binding<SessionLength> {
    Binding(get: { settings.sessionLength }, set: { settings.sessionLength = $0 })
  }

  private var theme: Binding<ThemePreference> {
    Binding(get: { settings.theme }, set: { settings.theme = $0 })
  }

  /// What the toggle means in both directions is `CardAnimations`' to say, not this screen's —
  /// setting it to what the device already says is following the device again, and that rule is
  /// worth a test.
  private var cardAnimations: Binding<Bool> {
    Binding(
      get: { settings.cardAnimations.areOn(whenDeviceReducesMotion: deviceReducesMotion) },
      set: {
        settings.cardAnimations = .chosen(
          animating: $0, whenDeviceReducesMotion: deviceReducesMotion)
      })
  }
}

/// Over a suite of its own, so opening the preview cannot write into the settings of an app
/// installed on the same simulator.
#Preview {
  NavigationStack {
    SettingsScreen(settings: AppSettings(defaults: UserDefaults(suiteName: "preview.\(UUID())")!))
  }
}
