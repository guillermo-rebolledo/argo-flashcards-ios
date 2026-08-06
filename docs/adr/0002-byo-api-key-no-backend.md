> **Copied from the Android repo** — `guillermo-rebolledo/argo-flashcards`, `docs/adr/0002-byo-api-key-no-backend.md`.
> The decision was made there and still binds here.
>
> Copied rather than linked: a cross-repo link is a broken link waiting to happen, and a
> copy makes a future divergence visible as an edit to one side rather than a silent change
> to both. **The body below is unchanged from the original.**
>
> Where the body names Android Auto Backup or the Play Store, that is the Android implementation's mechanics. On iOS the same consequence is met by storing the key in the Keychain with `ThisDeviceOnly` accessibility; the decision — the user's own key, called direct from the device, no backend — is what binds.

# Bring-your-own API key, no backend

AI Card generation calls the Anthropic API directly from the device, using an API key the user pastes into Settings and which is stored in encrypted storage on the device. There is no server, no account system, and no sync. Card content goes from the device to Anthropic and nowhere else.

The alternative shapes all cost more than they are worth at this stage. A key baked into the APK is extractable, so it would work for a personal sideload and then have to be torn out the moment anyone else installed it. A proxy backend is the only way to serve users on our key, but it means an additional deployable, a spend ceiling to enforce, and abuse protection — real infrastructure in service of a user base that does not exist. Bring-your-own-key is the one option that is both correct for a single user today and safe to publish tomorrow: if the app ever ships, the same Settings screen is already the right design, and the decision can be revisited on evidence rather than speculation.

## Consequences

- **The first-launch experience has a hole in it.** A new install cannot generate anything until a key is entered, so "no key set" is a first-class outcome of generation with its own message and a direct route to Settings — not a generic error.
- The key must be excluded from Android Auto Backup. Cards and Decks are backed up; the credential is not.
- Publishing to the Play Store would inherit a narrow audience — a bring-your-own-key app asks users to hold an Anthropic account. That is a known limitation of this path, and switching to a proxy later is additive rather than a rewrite, because `CardGenerator` already isolates the call.
- Per-generation cost falls on the user, which removes cost as a design constraint. Model choice is made on Card quality rather than price.
- No accounts means no cross-device sync. Decks live on one phone, and Android Auto Backup is the only continuity story.
