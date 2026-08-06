# Domain Docs

How the engineering skills should consume this repo's domain documentation when
exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — the glossary and domain overview.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their
absence; don't suggest creating them upfront. The `/domain-modeling` skill
(reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates
them lazily when terms or decisions actually get resolved.

## File structure

This is a **single-context** repo:

```
/
├── CONTEXT.md
├── docs/
│   ├── adr/
│   │   ├── 0001-....md
│   │   └── 0002-....md
│   └── agents/          ← this directory: skill configuration, not domain docs
└── ...Swift sources
```

## Relationship to the Android app

Flashcards for iOS is an independent Swift/SwiftUI implementation of the same
product as the Android app at `guillermo-rebolledo/argo-flashcards`. **No code
is shared.** The two implementations are kept aligned by a shared glossary,
mirrored ADRs, and translated tests rather than by the compiler.

Practical consequences when writing docs here:

- Domain terms in `CONTEXT.md` (Deck, Card, Session, …) should match the Android
  app's vocabulary. If you need to diverge, say so explicitly in the glossary
  entry and record why.
- A decision that applies to both platforms gets an ADR in **each** repo, each
  linking to its counterpart. An iOS-only decision (Liquid Glass, SwiftData,
  Apple platform constraints) gets an ADR here only, and should say it is
  iOS-specific.
- Don't assume an Android implementation detail carries over. The visual
  language is deliberately Apple-native, not a port of Material You.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal,
a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift
to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either
you're inventing language the project doesn't use (reconsider) or there's a real
gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than
silently overriding:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…_
