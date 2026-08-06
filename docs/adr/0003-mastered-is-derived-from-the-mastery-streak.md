> **Copied from the Android repo** — `guillermo-rebolledo/argo-flashcards`, `docs/adr/0003-mastered-is-derived-from-the-mastery-streak.md`.
> The decision was made there and still binds here.
>
> Copied rather than linked: a cross-repo link is a broken link waiting to happen, and a
> copy makes a future divergence visible as an edit to one side rather than a silent change
> to both. **The body below is unchanged from the original.**
>
> Where the body names Kotlin, Room, SQLite, or `CardDao`, that is the Android implementation's mechanics. Here the threshold is a Swift constant and the derivation is a computed property; the decision — never store what can be derived — is what binds.

# Mastered is derived from the Mastery streak, never stored

A Card row holds a `mastery_streak` integer and nothing else about its state. **Mastered** — the label the Deck detail chips filter by, the summary counts, and the Progress tab reports — is computed at read time as `mastery_streak >= 3`. There is no `mastered` column, and the threshold lives in one place in Kotlin (`Card.MASTERY_THRESHOLD`) rather than in the schema.

The reason is that two records of the same fact eventually disagree. A stored boolean has to be recomputed on every write that touches the streak, and every one of those writes is a chance to forget: grading a Card `Again` in a Session, a bulk insert from a Generation, a migration that backfills. When they diverge there is no way to tell which one is right, and the symptom — a Card that says Mastered while showing a streak of 1 — is invisible until a user reports it. Deriving it makes the disagreement unrepresentable.

## Considered Options

- **A `mastered` boolean column updated alongside the streak.** Cheaper to query (`WHERE mastered = 1` beats a comparison over the whole table) and it survives a change to the threshold: Cards already Mastered stay Mastered. Rejected because the cost it buys off is imaginary at this scale — a Deck is tens of Cards, not millions — and the correctness risk is not.
- **A stored `mastered` column as a SQLite generated column.** Gets the query benefit with no divergence risk, since SQLite computes it. Rejected because it puts the threshold in the schema, so changing it becomes a migration, and Room's support for generated columns would leak into the entity for no gain we currently need.
- **Store the threshold per Deck.** Would let a hard Deck demand more consecutive `Knew it`s than an easy one. Rejected as a setting nobody asked for; the ADR can be reopened if Session results suggest 3 is wrong for some material.

## Consequences

- Filtering by Mastered happens in Kotlin over the Deck's Cards, not in SQL. That is fine for a Deck — it is already loaded to be listed — and it is where the filter chips read from.
- Changing the threshold changes the past: every Card is re-labelled the moment the constant moves, with no migration and no way to grandfather Cards in. That is the intended behaviour of a derived value, but it means the constant is a product decision, not a tuning knob to fiddle with between releases.
- Editing a Card cannot touch its Mastery state, because there is no Mastery state to touch — only the streak, which the `UPDATE` that writes a Front and a Back has no access to. See `CardDao.updateContent`.
- Deck-wide counts (`8 of 12 Mastered`) are computed from the same list the screen already holds, so the summary and the list can never disagree either.
