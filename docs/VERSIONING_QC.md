# Versioning and quality control

Two stewards guard this. Neither edits code; both report to the lead agent.

- **Version steward:** are we running exactly what we think we are?
- **QC steward:** does it still produce the right numbers, and is each new file's data usable?

## What is pinned

| Component | Version | Where it is set | How to check |
|---|---|---|---|
| App | `VERSION` (currently 0.4.0) | `VERSION` | `BUILD_INFO.txt` |
| GGIR | 3.3-8 | `build_bundle.R` (`GGIR_VERSION`) | `packageVersion('GGIR')` prints 3.3.8 |
| R (Windows) | 4.5.3 | `build_bundle.R` (`R_WIN_VERSION`) | `BUILD_INFO.txt` |
| R (Mac reference) | 4.5.2 with GGIR 3.3.8 | the Mac | |
| Every other package (116) | locked in `packages.lock` | `packages.lock`; binaries kept in the Mac's `~/AutoG-build/downloads` | versions in `BUILD_INFO.txt` |
| Pipeline settings | fingerprint `ef97b8d3b3a4a62c27de294f8087b4bf` | `app/ggir_run.R`, `app/settings.R` | `tools/check_parity.R` |

**Package lock.** CRAN keeps only the newest Windows binary of each package, so an unpinned rebuild
quietly ships newer packages (in November 2026 nine had moved since October, including GGIRread).
`build_bundle.R` therefore takes the versions in `packages.lock` from its download cache and reports
anything it had to take fresh as "NOT from the lock". Do not delete `~/AutoG-build/downloads`:
it is the only copy of those binaries. Taking a newer package on purpose = delete its line, rebuild,
golden test, changelog entry. In development the Mac's own R had GGIRread 1.0.10 against the bundle's 1.0.11; ActiGraph CSV and
.gt3x files are not read through GGIRread, and results matched.

CRAN has moved on to GGIR 3.3-9. Staying on 3.3-8 is deliberate: an upgrade is a **[SCIENCE]**
change that needs every participant reprocessed.

## App version numbers

`MAJOR.MINOR.PATCH`
- **MAJOR**: results can change (GGIR version, any `GGIR()` argument, cut-points, timezone).
  Requires reprocessing and a note in every methods section written afterwards.
- **MINOR**: behaviour or screens change, results cannot.
- **PATCH**: fixes and documentation.

## The settings fingerprint

`tools/check_parity.R` hashes every `GGIR()` argument in `ggir_run.R`, the cut-point table, the
age-group defaults and the timezone. Same fingerprint means same processing.

- On the Mac it also compares against `reference_pipeline.R` and fails on any difference outside the
  allow-list (`overwrite`, `do.parallel`, `maxNcores`, `studyname`).
- On the laptop it prints the fingerprint only. Compare it with the newest `CHANGELOG.md` entry.
- A changed fingerprint without a **[SCIENCE]** changelog entry is a defect. Stop and tell the user.

## Automated checks

`tools/run_tests.R` builds a made-up study in a temp folder and checks what the quality table,
verdicts, summary draft, datasheet, progress, Home statuses and methods text make of it (58
checks, base R, a few seconds, no participant data). It does not run GGIR. Run it after any
change to `app/results.R`, on the Mac and on the laptop. All must pass.

`dev/make_sim_study.R` (Mac only, not in the bundle) builds eight simulated recordings from one
real one to exercise whole runs: normal, 2 days only, device off at night, a day of stillness,
very short and very long nights, 30 Hz, a cut-off file, and one with a sleep diary.

## Golden test (QC steward)

Reprocess a file whose results are known and compare.

1. Your reference recording (for example `P001_2026-01-15.csv` in study ADULT, age group adult),
   **Reprocess files already done** ticked.
2. Compare with `private/reference_results.md` (see "Reference results" in `docs/PIPELINE.md`): `cal.error.end`, nights, SPT hours,
   IS/IV, bouted MVPA.
3. Pass: identical to the printed precision, or within 1% on every value. Small last-digit
   differences between macOS and Windows are acceptable; a different number of nights or days is not.
4. Record the result in `HANDOVER.md` (date, bundle version, pass/fail, any differences).

Run it: after installing a new bundle, after any change to `ggir_run.R` or `settings.R`, and before
processing a new batch if it has never passed on this laptop. Keep a second reference recording
for the other age group.

## Per-file data QC (QC steward, every run)

The four checks in `docs/PIPELINE.md`. Outcome per file is one of: **usable**, **usable for activity
only** (sleep not trustworthy), **exclude** — each with the reason, written to
`<study>\ggir\QC_notes.md` (create if missing; one line per file per run).

## Release checklist (Mac)

1. Change made in `windows-app/` (and in `reference_pipeline.R` too if it is a pipeline setting).
2. `Rscript tools/check_parity.R` → PARITY OK. Note the fingerprint.
3. Bump `VERSION`; add the `CHANGELOG.md` entry with the fingerprint.
4. `Rscript tools/make_infographic.R` and `Rscript tools/make_manual.R` (the PDFs print the app version; needs Chrome and the Mac
   test library: `R_LIBS_USER=~/AutoG-build/maclib`). Look at both PDFs.
4b. `Rscript build_bundle.R`; read `BUILD_INFO.txt`. A "NOT from the lock" line means package
   versions changed: treat it as a change to verify (golden test) and record.
5. Smoke test on the Mac: `Rscript -e "shiny::runApp('app', launch.browser = TRUE)"` (do not use
   `launch.R` there; it is written for the bundled Windows R). Exercise the changed screen; run the
   golden test if the worker or settings changed.
6. Update `HANDOVER.md`: what changed, what the laptop must do.
7. Copy `~/AutoG-build/AutoG` to the encrypted drive, replacing the old folder.

## Change coming back from the laptop

Anything edited on the laptop is listed in `HANDOVER.md` → "Changed on Windows" with file, reason
and the new fingerprint. On the Mac it is applied to `windows-app/` (and `reference_pipeline.R` if relevant)
before the next build. An unlisted laptop edit is lost at the next update.
