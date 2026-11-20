---
name: maintain-app
description: Make a change to the AutoG app safely - classify it, route it to the right specialist, keep Mac and Windows in step, verify, and record it. Use for any bug fix, new feature, new study or age group, or settings change.
---

# Maintain the app

**1. Classify the change**

| Kind | Examples | Version bump | Owner |
|---|---|---|---|
| SCIENCE | Any `GGIR()` argument, cut-points, timezone, GGIR version, new age group | MAJOR | `pipeline-scientist` |
| Behaviour | New panel, progress display, file-rename helper, messages | MINOR | `shiny-ui-engineer` |
| Packaging | Launcher, `.bat`, bundle contents, new package | MINOR/PATCH | `windows-packager` |
| Docs | Manuals, README | PATCH | lead agent |

Not sure it is worth doing? Ask `biodesign-reviewer` first.
A SCIENCE change needs the user's explicit agreement before any edit.

**2. Know which files move together**

- `app/ggir_run.R` ↔ Mac `reference_pipeline.R` — same `GGIR()` arguments.
- `app/settings.R` ↔ Mac `reference_pipeline.R` — same cut-point table and defaults.
- `app/compose_reports.R` ↔ Mac `compose_reports.py` — same layout.
- A new study: `STUDIES` and `AGE_DEFAULT` in `settings.R`, the same in `reference_pipeline.R`, a row in
  `docs/PIPELINE.md`, and the folder `<root>\<study>\raw\`.

**3. Make the change** through the owning sub-agent, in the smallest edit that does it.

**4. Verify**
- `tools/check_parity.R`: fingerprint unchanged for non-SCIENCE changes; new and recorded for
  SCIENCE changes.
- Run the app and exercise the change, including the failure path.
- Worker or settings touched: golden test via `qc-steward`.
- Then `version-steward` for the consistency report.

**5. Record**
- `VERSION` bumped; `CHANGELOG.md` entry with date, what, fingerprint, can-results-change.
- On the laptop: add the file to "Changed on Windows" in `HANDOVER.md`. The Mac copy is the source
  of truth and the next bundle will overwrite an unrecorded edit.
- On the Mac: rebuild with skill `release-bundle`.

**Where each side can work**

| | Mac | Laptop |
|---|---|---|
| Edit `app/*.R`, docs | yes (source of truth) | yes, as a recorded hot-fix |
| Add or upgrade a package, R or GGIR | yes, via `build_bundle.R` | **no** |
| Rebuild the bundle | yes | **no** |
| Process real study data | only where approved | yes |
