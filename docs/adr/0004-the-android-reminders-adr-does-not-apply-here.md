# The Android reminders ADR does not apply here

> This number is deliberately not a copy. Android's `0004-reminders-are-inexact-work-not-exact-alarms.md`
> is the one still-live Android ADR that does **not** carry across, and the number is held here so a
> reader following a cross-repo reference to "ADR 0004" lands on the explanation rather than on a gap.

The daily Reminder is a `UNCalendarNotificationTrigger` with `repeats: true`, scheduled once at the chosen time. It fires daily, survives reboot with no code of ours, and needs no entitlement and no policy-reviewed permission.

The Android ADR exists to justify giving up minute accuracy. WorkManager was chosen over `AlarmManager` because exact alarms on Android cost either a Play-policy-reviewed permission (`USE_EXACT_ALARM`, reserved for alarm clocks and calendar events) or a second runtime prompt (`SCHEDULE_EXACT_ALARM`) in a flow that already has one. **None of that machinery exists on iOS.** A calendar-trigger notification is the ordinary way to do this, it is accurate, and the only permission involved is the notification authorisation the feature needs regardless.

So the constraint the Android ADR reasons about is absent, and its conclusion — accept approximate delivery — is not a conclusion this platform has to reach.

## The copy stays neutral anyway

The `Reminder time` glossary entry in `CONTEXT.md` reads "aimed at, not promised for", and the Settings copy stays neutral ("Remind me at 8:00 PM") even though iOS could honestly promise the minute.

This is the decision worth recording, because it is the one a future reader will want to overturn. `CONTEXT.md` is copied verbatim and must not fork; it is product language, shared by both apps. Tightening the promise here would mean either two definitions of one term, or an edit to a shared file to describe a guarantee only one platform makes. The accuracy is real but nobody asked for it, and it is not worth forking the glossary over.

## Considered Options

- **Copy the Android ADR with an "iOS: not applicable" note.** Rejected: it would import several paragraphs of Doze, WorkManager chaining, and `BOOT_COMPLETED` reasoning that describe machinery this repo does not have, and a reader would have to get to the end to learn none of it applies.
- **Say nothing and let the gap at 0004 speak.** Rejected: a gap is indistinguishable from an oversight, and the Android repo's ADR set is the thing this repo is deliberately kept legible against.
- **Promise the minute in the copy, and fork the glossary entry.** Rejected as above — a per-platform glossary is exactly the divergence the copied `CONTEXT.md` is meant to prevent.

## Consequences

- There is no reminders ADR to consult here for scheduling mechanics; the trigger is unremarkable and lives in `Core/Reminders`.
- Notification authorisation is requested at the moment the user enables Reminders, never at launch.
- The notification carries no counts and no streak numbers. That constraint is inherited from ADR 0001, not from anything about scheduling: there is no backlog, so a Reminder has nothing to count.
- If the copy is ever tightened to promise an exact time, `CONTEXT.md` forks — and that is a change to a shared artefact, so it belongs in the Android repo's review too, not just this one.
