# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those
roles to the actual label strings used in this repo's issue tracker (Linear —
see `issue-tracker.md`).

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the
corresponding label string from this table.

All five exist as team labels on `Memoji inc` in Linear.

Linear specifics:

- Apply labels via `save_issue`'s `labels` array, which **replaces** the full
  set — always pass the labels you want to keep alongside the one you're adding.
- These are triage _labels_, independent of the team's workflow _states_
  (`Backlog`, `Todo`, `In Progress`, `In Review`, `Done`, `Canceled`).
  `wontfix` normally accompanies moving the issue to `Canceled`.

Edit the right-hand column to match whatever vocabulary you actually use.
