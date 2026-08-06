# No wallpaper-derived colour, and no palette picker in its place

The Android app seeds Material You from the user's wallpaper, and its spec carries a user story for it. **That story is deliberately not implemented here, and nothing is offered as a substitute.** The app uses system defaults throughout: no custom tint, no brand colour, no accent, and no theme picker beyond the light/dark override the system itself implies.

There are two separate reasons, and they need separating because only one of them is a platform limitation.

**The mechanism does not exist.** iOS exposes no wallpaper-derived palette to third-party apps. There is no `dynamicColor` equivalent to read. So the Android implementation cannot be ported; the question is only what, if anything, replaces it.

**And nothing needs to replace it.** The story that colour extraction was buying — *a surface that responds to its surroundings, so the app feels like it belongs on this particular phone* — is what Liquid Glass delivers, by refraction rather than by recolouring. Glass picks up what is behind and around it continuously, including the wallpaper, and does so as the user scrolls rather than once at install time. The user story is answered better by the material than it was by the palette. This is a supersession, not a gap.

## Why not a palette picker

The obvious consolation prize — let the user choose an accent colour in Settings — is rejected, and it is worth saying why, because it is the thing a future reader will propose.

It answers a different question. Wallpaper extraction is *automatic personalisation*: the phone already knows something about the user and the app reflects it, with nothing asked of them. A picker is a *configuration chore* that hands the work back and produces a worse result, since most users pick once, badly, or never open the setting at all.

It also fights the material. Apple's guidance is that glass surfaces stay neutral and let content show through; a saturated user-chosen tint on the tab bar is precisely the thing that makes a glass app look wrong. And it is out of scope on Android too, so adding it here would fork the product's feature set to substitute for a feature neither platform has.

## Considered Options

- **Extract a palette from a user-supplied image.** Technically possible — an image picker and a colour-quantisation pass. Rejected: it reproduces the *mechanism* while discarding the *point*, which was that the user did nothing. It is also a meaningful chunk of code to own for a cosmetic feature.
- **A fixed brand colour carried from Android's teal seed.** Rejected: it is not personalisation at all, it fights the neutral-glass guidance, and it would make the one place colour does real work — the drag hint — compete with chrome for attention.
- **A Settings accent picker.** Rejected, as above.
- **Do nothing and say nothing.** Rejected: the Android spec carries a user story for this, and an unexplained absence reads as an oversight to anyone comparing the two products.

## Consequences

- Story 68 of the Android spec is not implemented on iOS, and Out of Scope in this repo's spec names it explicitly so the gap is not rediscovered as a bug.
- Semantics are near-monochrome. Mastery indicators and streak dots are expressed through fill, weight, and SF Symbols rather than hue.
- **The one place colour does real work is the drag hint during Review**, read mid-gesture at the edge of attention: `.green` for `Knew it`, `.orange` for `Again`. Never red — "come back to this" is not "you got it wrong", and the Android implementation avoids its error colour here for the same reason. A neutral app everywhere else is what lets those two colours carry meaning.
- A future proposal to add a tint should be read against this ADR rather than treated as a small styling change, because the neutrality is load-bearing for both the glass and the drag hint.
