# SwiftData over a SQL library, and Progress figures as folds

Persistence is SwiftData: `@Model` types for Deck, Card, and the Session log, behind repository protocols. There is no SQL in the app and no third-party persistence library.

The consequence worth recording is downstream of that choice. The Android spec says *every Progress figure is a query over the Session log table*. **Here, every Progress figure is a Swift fold over fetched rows.** SwiftData's `#Predicate` does not express aggregates — no `GROUP BY`, no `COUNT(DISTINCT …)`, no date bucketing — so the day streak, the seven-day grid, the Cards/minutes/Decks tiles, and Decks-touched-this-week cannot be written as the queries the Android app uses. They are computed in Swift over the rows the screen fetches.

That is affordable because of what the data actually is: the Session log gets one row per sitting. A heavy user studying three times a day for two years produces a couple of thousand rows. Fetching those and folding them is faster than the round trips a naïve query-per-tile version would make, and it is more readable than the predicate gymnastics the alternative would require.

## Containing the divergence

A fold is easier to get subtly wrong than a query, and this is a second implementation of figures the Android app already computes — the two can disagree invisibly. Two things contain that:

- **Every Progress computation lives in a single type.** They are not spread across views or screen models. One file is the whole surface where this divergence lives, so a reader comparing platforms has one place to look.
- **The Progress tests are translated from the Android suite** — same inputs, same expected numbers. This converts "the two apps should agree" from an intention into a failing test when they do not.

## Considered Options

- **GRDB, with the Android schema and queries carried across nearly verbatim.** Genuinely tempting: the Progress figures would be the *same SQL*, which is the strongest possible alignment between the two apps, and GRDB is excellent. Rejected because it gives up SwiftData in the layer where the platform's integration is worth most — `@Model` change tracking, the in-memory container that makes the test suite fast and simulator-free, and migrations — in exchange for parity on a few hundred lines that translated tests already pin.
- **Core Data directly.** Same storage engine, aggregates available through `NSExpression`. Rejected: the aggregate support is real but the API is the part of Core Data that ages worst, and it would be an odd thing to choose new in 2026 for a greenfield app with no Core Data history to honour.
- **SwiftData with aggregates pushed into `#Predicate` wherever possible.** Rejected as the worst outcome: some figures expressible, some not, and the reader left to work out which is which. If the folds are the rule, they should be the rule everywhere.
- **CloudKit-backed SwiftData.** Rejected on separate grounds, recorded here because the flag is one line away and looks free: it is cross-device sync, which ADR 0002 rules out, and it constrains the model (all properties optional or defaulted, no unique constraints) in exactly the layer being kept pinned to the Android schema. Revisitable in v2 with its own ADR.

## Consequences

- **`@Query` is not used in views.** Almost every rule worth protecting — mastery, Session composition, "Up next" selection — lives in the layer `@Query` would dissolve into the view. Keeping it out is what makes those rules testable synchronously rather than through a simulator.
- Tests run against an in-memory `ModelContainer` with the real models and real repositories. A test exercising Session composition therefore runs against the real schema and catches schema and fetch bugs a fake repository would hide. This is a deliberate choice against a repository seam.
  - The repository *protocols* still exist — they are the architecture the spec asks for. What this rules out is faking them in tests. The one standing exception is a failing implementation used to cover the branch where a screen reports an unreadable store: an in-memory container cannot be made to fail on demand, and without it that branch would be the only unexercised path on the screen. A fake that stands in for the store in a *behavioural* test is still ruled out.
- If the Session log ever stops being one-row-per-sitting — per-Card rows, say — the fold assumption stops holding and this ADR needs revisiting rather than the folds quietly being optimised.
- Migrations are `VersionedSchema` and `SchemaMigrationPlan`. There is nothing to test until a second schema version exists; migration tests arrive with it.
