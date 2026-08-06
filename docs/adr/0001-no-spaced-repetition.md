> **Copied from the Android repo** — `guillermo-rebolledo/argo-flashcards`, `docs/adr/0001-no-spaced-repetition.md`.
> The decision was made there and still binds here.
>
> Copied rather than linked: a cross-repo link is a broken link waiting to happen, and a
> copy makes a future divergence visible as an edit to one side rather than a silent change
> to both. **The body below is unchanged from the original.**

# No spaced repetition

Essentially every flashcard app schedules Cards by due date — Anki, Quizlet, SuperMemo and their descendants all compute intervals and show you what is overdue. We are deliberately not doing that. A Card carries a **Mastery streak** and nothing else: no interval, no ease factor, no due date, no next-review timestamp. Sessions are composed from what the user knows least well, not from what a scheduler says is due today, and nothing accumulates while the app is closed.

The reason is that the target user is someone whose attention is unreliable. Due-date scheduling turns a missed week into a two-hundred-Card backlog, and it presents that backlog at exactly the moment motivation is lowest. The behaviour that spaced repetition optimises for — daily, uninterrupted practice — is the behaviour this user cannot reliably produce, so the algorithm's failure mode is aimed squarely at them. "Nothing is waiting for you tomorrow if you skip it" is the product's central promise, and a scheduler cannot make that promise honestly.

## Considered Options

- **SM-2 or FSRS, fully visible.** Best retention per minute studied, and a solved problem with reference implementations. Rejected because the backlog is not an implementation detail we could hide — it is the thing that makes people quit.
- **Spaced repetition hidden under the UI.** Compute real intervals, but never show due dates or overdue counts; just quietly pick the most-due Cards each Session. Tempting, and it keeps the promise *technically* true, but the scheduler still accumulates debt silently. A user returning after a month would find every Session composed entirely of stale material with no way to see or clear it — the same punishment, less legible. Rejected.
- **No mastery state at all.** Cards are just Cards; only per-Session results exist. Genuinely simpler and honest, but it deletes the progress framing the product is built around — deck mastery counts, filter chips, and the Progress tab all go with it. Rejected as too much.

## Consequences

- Long-term retention will be worse than a scheduled app for a user who *would* have studied daily. This is an accepted trade: we are optimising for the user who returns after two weeks, not the user who never left.
- **Mastered** would decay into a meaningless label if Mastered Cards never resurfaced, so Session composition reserves every fifth slot for a Mastered Card, oldest-seen first. That is the entire retention mechanism, and it works without dates.
- The schema has nowhere to put an interval. Adding spaced repetition later is a migration plus a rewrite of Session composition, not a feature flag — which is the intended cost, since this is a product identity decision and not a tuning knob.
- No background scheduling, no notification of overdue counts, no daily recompute job. The daily reminder is a fixed-time nudge that carries no numbers.
