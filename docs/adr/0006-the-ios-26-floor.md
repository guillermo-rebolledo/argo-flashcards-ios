# The iOS 26 floor, and no fallback visual language

The deployment target is iOS 26. Liquid Glass is used unconditionally — the glass tab bar and its scroll-edge behaviours, glass toolbars and buttons, and glass effect containers — and **there are no `if #available` fences anywhere in the app**. A device that stopped at iOS 18 does not run this app.

The reason is that Liquid Glass is an API surface, not a style that can be approximated. Its refraction, its scroll-edge response, and the way controls morph inside a glass effect container are things the system draws; they are not a corner radius and a blur that older code paths could stand in for. Supporting iOS 18 alongside would therefore mean designing, building, and maintaining two visual systems — and the newer one, which is the entire point of building a second app rather than shipping the Android one to more people, would be the branch seen least during development. Every screen would be built twice and reviewed once.

The cost is named rather than discovered: devices below iOS 26 are unsupported. There is no existing iOS user base to strand, and the bring-your-own-key design (ADR 0002) means there is no acquisition funnel to protect — nobody's growth number moves because the floor is high.

## Considered Options

- **iOS 18 floor with `if #available` fences around glass.** The widest reach, and the ordinary thing to do. Rejected: it doubles the visual system at exactly the layer this app exists to get right, and it makes the fallback the default a developer sees on an older simulator. A fence around a tab bar is not a small fence — the shell is the thing every screen sits inside.
- **iOS 18 floor with a single non-glass design, glass added later.** One visual system, ship sooner, adopt Liquid Glass when the floor rises naturally. Coherent, and genuinely cheaper. Rejected because the visual language is the product decision here: a native-feeling iOS app is why this repo exists rather than a wider Android rollout, and "later" would arrive with eight screens already built against the other design.
- **iOS 26 floor, glass adopted incrementally per screen.** Rejected as the worst of both — the floor's cost with none of its benefit, and a half-glass app reads as an unfinished one.

## Consequences

- **No availability fences.** This is checkable: `if #available` appearing in a diff is a signal the floor is being eroded, and should be challenged in review rather than merged.
- The app cannot be tested on a device or simulator below iOS 26, which sets the CI runner's floor too.
- Glass is a control-layer material only — tab bar, toolbars, sheets, pickers, and the Grade hint chips. Content sits *under* it. That boundary is not this ADR's decision, but it is the reason the floor buys anything: glass over glass has nothing to refract, and stacking it would degrade the Card face, which carries the most important text in the app.
- No custom tint and no brand colour anywhere, per Apple's guidance that glass surfaces stay neutral and let content show through. The Android app's teal Material You seed is not carried across.
- Raising the floor later is free; lowering it is not. Dropping to iOS 18 after the fact means retrofitting a second design system across every screen, which is the work this ADR declines to start.
