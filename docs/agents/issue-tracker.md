# Issue tracker: Linear

Issues and specs (you may know a spec as a PRD) for this repo live in Linear,
not in GitHub Issues and not in the repo.

- **Workspace**: `memoji-inc`
- **Team**: `Memoji inc` (key `MEM`) — pass as `team: "Memoji inc"`
- **Project**: `flashcards-ios` — pass as `project: "flashcards-ios"`
- **Project URL**: https://linear.app/memoji-inc/project/flashcards-ios-e254fa47b01f

Every issue this repo's skills create MUST be scoped to that team _and_ that
project. An issue created without `project` lands in the team's general backlog
and is effectively lost to the iOS effort.

The Android app (`guillermo-rebolledo/argo-flashcards`) is a separate codebase
with no shared code. Cross-platform decisions are mirrored, not shared — see
`docs/agents/domain.md`.

## Access

All operations go through the Linear MCP tools (`mcp__claude_ai_Linear__*`).
They are deferred: load them with `ToolSearch` (a single `select:` query with a
comma-separated list) before the first call. There is no `gh`-style CLI in this
setup — never shell out for Linear.

## Conventions

- **Create an issue**: `save_issue` with `title`, `team: "Memoji inc"`,
  `project: "flashcards-ios"`, and `description` as literal Markdown (real
  newlines, not `\n` escapes). Omit `id` when creating.
- **Read an issue**: `get_issue` with the identifier (e.g. `MEM-42`), plus
  `includeRelations: true` when blockers matter. Comments come from
  `list_comments` with `issueId`.
- **List issues**: `list_issues` with `project: "flashcards-ios"` and
  `fields: ["identifier","title","description","status","labels","assignee","parentId"]`.
  Filter further with `label`, `state`, or `assignee`.
- **Comment on an issue**: `save_comment` with `issueId` and `body`.
- **Apply labels**: `save_issue` with `id` and `labels`. **`labels` replaces the
  whole set** — read the current labels first and pass the full intended list,
  or you will silently drop the others.
- **Close**: `save_issue` with `id` and `state: "Done"` (or `"Canceled"` for
  work that will not be actioned).

## Status vocabulary

Team workflow states: `Backlog`, `Todo`, `In Progress`, `In Review`, `Done`,
`Canceled`, `Duplicate`. Triage roles are carried by **labels**, not states —
see `docs/agents/triage-labels.md`.

## When a skill says "publish to the issue tracker"

Create a Linear issue in the `flashcards-ios` project.

## When a skill says "fetch the relevant ticket"

`get_issue` on the identifier the user gave (`MEM-123`), then `list_comments`
for the conversation history.

## Wayfinding operations

Used by `/wayfinder`. The **map** is an issue with **child** issues as tickets.

- **Map**: an issue labelled `wayfinder:map` holding the Notes /
  Decisions-so-far / Fog body.
- **Child ticket**: an issue with `parentId` set to the map, labelled
  `wayfinder:<type>` (`research` / `prototype` / `grilling` / `task`).
- **Blocking**: Linear's native relations — `save_issue` with `blockedBy`
  (append-only; use `removeBlockedBy` to clear). A ticket is unblocked when
  every blocker is `Done` or `Canceled`.
- **Frontier query**: `list_issues` with `parentId: <map>`, drop anything with
  an unfinished blocker or an assignee; first in map order wins.
- **Claim**: `save_issue` with `assignee: "me"` and `state: "In Progress"` —
  the session's first write.
- **Resolve**: `save_comment` with the answer, set `state: "Done"`, then append
  a context pointer (gist + link) to the map's Decisions-so-far using
  `save_issue`'s `patch` operations.
