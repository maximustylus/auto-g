# Sleep & use log — how to fill `sleeplog_<study>.csv`

GGIR "advanced" sleep-log format. One row per participant. Columns come in
blocks, one block per calendar date, each starting with `date_N`.

For each date block (all times **24-h `hh:mm:ss`**, e.g. `22:45:00`; leave blank if not applicable):

| column | meaning |
|---|---|
| `date_N` | calendar date, `yyyy-mm-dd` (pre-filled — do not change) |
| `wakeup_N` | final wake-up **on the morning of** date N |
| `outbed_N` | got out of bed on the morning of date N |
| `inbed_N` | went to bed **on the evening of** date N |
| `onset_N` | tried to fall asleep / lights out, evening of date N |
| `nap1_start_N`, `nap1_end_N` | daytime nap on date N (nap2 for a second nap) |
| `nonwear1_start_N`, `nonwear1_end_N` | device taken off on date N (nonwear2 for a second episode) |

Notes
- A night that starts on date N and ends after midnight: `onset_N` = e.g. `23:30:00`,
  and the wake-up goes in the **next** block, `wakeup_{N+1}` = e.g. `06:15:00`.
  An onset after midnight (e.g. 00:40) still goes in block N as `00:40:00`.
- The last block (2026-01-22) only needs `wakeup_8` / `outbed_8`.
- Example: a recording started 2026-01-15 06:00 and ended 2026-01-22 06:00.
- Do not rename columns — GGIR matches them by keyword (`date`, `wakeup`, `onset`,
  `inbed`, `outbed`, `nap`, `nonwear`).
- Add one row per participant; `ID` must match the filename prefix (e.g. `P002`).

Once filled, save it as `<data folder>\<study>\sleeplog_<study>.csv`. AutoG picks it up on the
next run. Never put the empty template there.
