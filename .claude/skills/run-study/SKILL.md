---
name: run-study
description: Process raw accelerometer files for a study through the app, end to end - file naming, age group, running GGIR, and the post-run quality checks. Use when new raw files arrive or a study needs reprocessing.
---

# Run a study

**Before**
1. Raw files are in `<root>\<study>\raw\` and named `ID_date.csv` (or `.gt3x`): no spaces, no
   brackets, ID before the first underscore. If a file arrives as `C003 (2026-01-15)RAW.csv`,
   **copy** it to `raw\C003_2026-01-15.csv`; leave the original untouched.
2. Read the first 10 lines of each new CSV (the ActiLife header) and note: serial number, sample
   rate, start date and time, "Filter Normal". Tell the user if the sample rate differs from earlier
   files or the filter is not Normal.
3. Diary: a filled `<root>\<study>\sleeplog_<study>.csv` with a row for each ID, or none at all.
   An empty template there is worse than no file.
4. Confirm the age group with the user if it is not the study default (ADULT adult, CHILD paediatric).
   This sets the cut-points.
5. Laptop plugged in, sleep disabled for the session if the user can, data drive connected.

**Run**
6. In the app: data folder, study, age group, **Start processing**. Tick **overwrite** only when
   reprocessing on purpose (new diary, different age group, new bundle with a MAJOR change).
7. Allow 10–20 minutes per file. Progress is in the Progress tab and in `ggir\app_log_*.txt`.

**After**
8. State is "Finished". If "Stopped – …", read the end of the log; see `docs/RUNBOOK.md`.
9. Hand to `qc-steward` for the per-file verdicts (written to `ggir\QC_notes.md`).
10. Tell the user, per file: verdict, calibration error, valid days, nights, and where the report
    image is. Offer the interpretation (skill `interpret-participant`) for files that passed.

Do not delete `ggir\output_raw\meta\` to "clean up"; it holds the slow Part 1 results.
