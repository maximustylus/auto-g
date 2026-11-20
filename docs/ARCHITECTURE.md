# Architecture

## The four workers (plain R processes, no AI)

| Worker | File | Started by | Job | Lives |
|---|---|---|---|---|
| Launcher | `app/launch.R` | `Run AutoG.bat` | First launch: installs GGIR 3.3-8 from `packages/` into `R/library`. Picks port 8765 (or a free one). Starts the UI. | Whole session (the black window) |
| UI server | `app/app.R` | Launcher | Shiny app on `127.0.0.1`. Collects folder, study, age group, cores, overwrite. Starts and stops the GGIR worker. Tails its log. Shows report images. | Whole session |
| GGIR worker | `app/ggir_run.R` | UI server, as a **separate** `Rscript` process | Runs `GGIR()` Parts 1–6, writes `run_settings.txt`, then calls the composer. | One run |
| Result reader | `app/results.R` | UI server (sourced) | Read-only functions over GGIR's CSVs, milestone files and log for the Quality check, Progress and Summary tabs. Writes only `<study>/ggir/QC_notes.md` (the user's verdicts). No GGIR call, no setting. |
| Report composer | `app/compose_reports.R` | GGIR worker (sourced) | Page 2 (day panels) + page 1 (summary bars) of each `old_report_*.pdf` → one JPEG. | End of a run |

`app/settings.R` is shared by the UI server and the GGIR worker: study list, age-group cut-points,
`check_root()`.

The worker is a separate process so the UI stays responsive during a 10–20 minute Part 1, and so
**Stop** can kill it (`taskkill /T /F /PID`) without killing the app.

## Contract between UI server and GGIR worker

Environment variables set by `app.R` before it starts the worker:

| Variable | Meaning |
|---|---|
| `GGIR_ROOT` | data root, forward slashes, no spaces, e.g. `D:/GGIR` |
| `GGIR_STUDY` | `ADULT` or `CHILD` |
| `GGIR_AGE_GROUP` | `paediatric`, `adolescent`, `adult` or `senior` |
| `GGIR_CORES` | parallel workers for Part 1–2 |
| `GGIR_OVERWRITE` | `TRUE` / `FALSE` |
| `GGIR_STATUS` | temp file; the worker writes `done` or `failed: <message>`; the UI writes `running` at start |
| `GGIR_PIDFILE` | temp file; the worker writes its PID (used by Stop) |

The worker's stdout and stderr go to `<root>/<study>/ggir/app_log_<timestamp>.txt`. The UI polls the
status file and the log every 2 s.

## Data folder contract

```
<root>\                       e.g. D:\GGIR  (no spaces anywhere in the path)
  <study>\                    ADULT or CHILD
    raw\ID_date.csv           ActiLife raw CSV or .gt3x; ID = text before the first "_"
    sleeplog_<study>.csv      optional filled diary (GGIR "advanced" format)
    ggir\                     written by the app
      run_settings.txt        who/when/which cut-points/GGIR version
      app_log_*.txt
      output_raw\             GGIR output; config.csv, meta\ (milestones), results\
    reports\<ID>_GGIR_report.jpg
```

GGIR names its output folder after the data folder, so `raw` gives `output_raw`.

Per study folder the app keeps `autog_study.txt` (the fixed age group), `ggir/QC_notes.md` (verdicts),
`ggir/autog_run.txt` and `ggir/autog_run_status.txt` (the current or last run: worker process id,
start time, log file, files; and running / done / failed), `ggir/nodiary_nights.md` (accept or dismiss decisions for nights without a diary entry),
`ggir/study_log.txt` (runs, age-group changes, night decisions) and `datasheet/` (saved datasheets).
The list of user initials is kept per PC in `%APPDATA%\AutoG-users.txt`. Who has been through the
welcome is in `%APPDATA%\AutoG-welcomed.txt`. `app/help.R` holds the welcome and Help content (static).
The UI remembers the last data root in `%APPDATA%\AutoG-app.txt`.

## Resumability

GGIR saves a milestone file per participant per part under `output_raw\meta\`. With overwrite off,
finished files are skipped, so adding a new raw file and rerunning only processes the new one.
Part 1 saves only at the end of a file: a disconnect or sleep mid-file loses that file's progress.

## What differs from the Mac pipeline

| | Mac | Windows app |
|---|---|---|
| Entry | `reference_pipeline.R` (prompts in RStudio) | `app.R` menus → `ggir_run.R` |
| GGIR call | in `reference_pipeline.R` | duplicated in `ggir_run.R` — must match (`tools/check_parity.R`) |
| Cut-point table | in `reference_pipeline.R` | `settings.R` — must match |
| Composer | `compose_reports.py` (pdftoppm + Pillow) | `compose_reports.R` (pdftools + magick) |
| Data root | `~/ggir-data` symlink to the external drive | chosen in the app |

## Build (Mac only)

`Rscript build_bundle.R` → `~/AutoG-build/AutoG/`. It unpacks the official Windows R installer
with `innoextract`, downloads the dependency closure of GGIR + shiny/pdftools/magick as CRAN Windows
binaries, adds the GGIR source tarball, the app and this handover pack. Needs internet and
`brew install innoextract`. It cannot be run on the laptop.
