# Fixed-time breaks

A fixed-time break interrupts you at a set clock time on chosen weekdays, instead of on a repeating
interval. Use it to break task inertia at a known transition, such as lunch.

## Configure

Settings › Schedules › **Fixed-Time Breaks**. Press **+** and set:

- **Name**: a label, e.g. "Lunch".
- **Time**: the local clock time.
- **Active Days**: weekdays, weekends, every day, or custom.
- **Break duration**: how long the break lasts.
- **Discipline Level**: defaults to Strict. The usual Strict permissions and the fallback to Firm apply.

Each break has an on/off switch. You can add as many as you like. Edits take effect immediately and
are saved across restarts.

## Behaviour

- The break starts when the local clock reaches the time on an enabled day. It does not depend on
  when StandLock launched or when the last break ended, and it uses your current timezone.
- It reuses the normal break machinery: overlay, Strict input locking, idle detection (an idle
  break counts as taken), and deferral for calls, screen sharing and calendar events.
- Repeating schedules are unaffected. Whichever of a repeating break and a fixed-time break comes
  first fires first.

## Developer notes

Fixed-time breaks are a separate model (`FixedTimeBreak`, in its own `fixedTimeBreaks` UserDefaults
key) that is projected into a `Schedule` with the same `id` before it reaches `BreakCoordinator`.
`FixedTimeSchedulingEngine` wraps `ScheduleEvaluator`: it answers for fixed ids and delegates
everything else. `Schedule`, `ScheduleEvaluator` and `BreakCoordinator` are unchanged.

**Missed slots are skipped, never fired late.** `nextOccurrence` returns a time strictly after the
reference date and has no grace period. `BreakCoordinator` re-arms from the current time on launch,
wake, screen unlock, resume from pause and after every break, so a slot that passed in the meantime
is dropped. Consequences:

- Launching or waking up at or after the slot skips today's break; one second before still fires it.
- A fixed slot that passes while another break is on screen is dropped, not queued.
- Two fixed breaks at the same minute produce one break; the later one is not fired afterwards.
- Because the next slot is always strictly later, a slot cannot fire twice, including across a DST
  fall-back (the repeated hour counts once). A time inside a spring-forward gap fires at the first
  valid instant after it.

**Clock changes.** `FixedTimeBreakStore` listens for system clock and timezone changes and rebuilds
the coordinator, because an armed slot is an absolute date computed in the old zone. A running break
is left alone.

**Edits.** A rebuilt coordinator normally re-arms the slot it inherited. For fixed breaks that slot
is discarded (`discardingFixedSlot`) and recomputed, so moving a break's time takes effect at once.

**Known limits.**

- With the default "reset interval on skip", "Skip Next Break" in the menu bar does not skip a
  fixed-time slot; the slot is recomputed to the same time. Skipping from the break screen works as the discipline level allows.
- If a fixed break is deferred (call, screen sharing, calendar event) it starts when the deferral
  clears, which can be well after its time. This is the existing deferral behaviour.
- The new UI strings are English only; the string catalog is not extended.
