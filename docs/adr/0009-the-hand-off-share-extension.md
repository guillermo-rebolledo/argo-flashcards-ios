# The Share Extension hands off; it does not generate

Sharing text or a link into the app goes through a Share Extension that does as little as possible: it captures the shared **Source**, writes it into an App Group container, and opens the host app via a custom URL scheme, which routes into the Generation flow with the Source pre-filled. If the open fails, the app reads the pending Source on next foreground and clears it.

**Generation deliberately does not run inside the extension.**

The Android app needs none of this — an intent filter delivers the payload to the activity synchronously, and the app is simply *running* with the Source in hand. The App Group, the URL scheme, and the pending-Source concept exist only because iOS extensions are separate processes with their own lifetime and their own sandbox. They are platform tax, not product, and this ADR exists so a reader does not go looking for the feature they represent.

## Why generation stays in the host app

Running the Generation in-extension is the shape that looks better on paper — the user never leaves the app they were reading in. It is rejected on three counts, any one of which would be enough:

- **It puts the store and the API key into shared scope.** The Keychain item is `ThisDeviceOnly` and app-scoped; sharing it means a Keychain access group, and the SwiftData store would have to move into the App Group container so both processes could write it. That widens the blast radius of the app's one credential for a convenience feature.
- **It duplicates the entire Generation UI.** Progress, the Kept-selection list with its tick boxes and count, the Deck-name field, and all seven typed failures with their user actions — including the one whose action is *"open Settings"*, which an extension cannot usefully offer. Every later change to that flow would have to land twice.
- **It runs a multi-second network call under an extension's memory budget.** Share extensions are killed aggressively. The failure mode is a kill partway through exactly the large-page case the feature exists for — and the user's key has already been billed for the tokens.

Handing off costs one app switch. That is a visible cost, and it is smaller than any of the three above.

## Considered Options

- **Generate in-extension.** Rejected, as above.
- **`NSExtensionContext` + `openURL` with no App Group.** The URL carries the Source as a query parameter, so there is no shared container at all. Genuinely simpler, and it was close. Rejected because a pasted article is routinely tens of kilobytes and a URL is not a transport for it — long URLs are truncated by the system in practice, and the failure would be silent and length-dependent, which is the worst way for this to break. The App Group holds the payload; the URL carries only a signal that one is waiting.
- **App Group only, no URL scheme** — the app notices the pending Source the next time it is foregrounded. Rejected as the primary path: the user shared *now* and expects something to happen now, and a hand-off that waits for them to switch apps themselves reads as a failure. It is kept as the **fallback**, which is exactly what it is good for.
- **A Shortcuts / App Intents entry point instead.** Rejected as out of scope for v1, and it is not the same affordance — the share sheet is where the user already is.

## Consequences

- **Three things exist solely for this**: the App Group container, the custom URL scheme, and the pending-Source concept with its read-and-clear on foreground. None has an Android counterpart.
- The pending Source must be **cleared once consumed**, or the same Source is re-offered on a later launch. Read-and-clear is one operation, and it is the bug this ADR most expects: the clear is easy to lose in a refactor and its absence only shows up on a second launch.
- The extension's own UI is minimal — capture and dismiss. It has no key entry, no failure states, and nothing to configure.
- **The user may share in with no API key set.** The hand-off still works and routes to the Generation flow, which surfaces the no-key outcome and offers Settings, per ADR 0002. The extension does not check for a key; checking there would mean giving it Keychain access, which is the thing being avoided.
- A Source shared while the app is already open in the Generation flow replaces the pending one rather than queueing. There is no Source queue, and one should not be added without revisiting this.
