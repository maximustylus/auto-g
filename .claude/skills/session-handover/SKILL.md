---
name: session-handover
description: Start a session from HANDOVER.md, and end one by updating it so the next session - on the Mac or the Windows laptop - can continue without this conversation. Use at the start and end of every working session on this app.
---

# Session handover

The two machines never talk to each other. `HANDOVER.md` travels with the bundle on the encrypted
drive and is the only shared memory. Treat it as the first thing read and the last thing written.

## Starting a session
1. Read `HANDOVER.md` fully, then `CLAUDE.md`.
2. Check the claims that matter instead of trusting them: installed version, fingerprint, whether
   the golden test has passed here (`version-steward`).
3. Tell the user in a few lines: what state you found, what the note says is next, anything that
   does not match the note.

## Ending a session
Rewrite the top sections of `HANDOVER.md` so they are true now:

- **State:** bundle version and fingerprint on each machine; golden test result and date.
- **Done this session:** outcomes, not a diary.
- **Changed on Windows** (laptop only): every edited file, why, and the new fingerprint if settings
  moved. The Mac applies these and clears the list.
- **Data processed:** per study, which IDs are processed, their QC verdicts, which have
  interpretations. Coded IDs only.
- **Open items:** each with an owner (user / Mac session / laptop session) and what unblocks it.
- **Next step:** the single most useful thing the next session should do first.

Rules
- Write for a reader with none of this conversation. No "as discussed", no labels invented here.
- No patient-identifying detail: coded IDs and aggregate numbers only.
- If something was not verified, say "not verified" rather than leaving it out.
- Keep it under two screens. Move anything durable into the manuals in `docs/`.
- Add a dated line to the log at the bottom; do not delete earlier lines.
