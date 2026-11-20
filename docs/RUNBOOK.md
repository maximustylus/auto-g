# Runbook (Windows laptop)

## Install or update

1. Close the app if it is running (browser tab, then the black window).
2. Copy the whole `AutoG` folder from the transfer drive to a local path without spaces, e.g.
   `C:\AutoG`. Copy it; do not run it from the transfer drive. When updating, replace the whole
   folder rather than merging, so no old file survives. Only one copy should exist on the laptop.
3. Double-click `Run AutoG.bat`. First start installs GGIR from the folder (about a minute).
4. Confirm the version: `BUILD_INFO.txt` and `VERSION` should show what `CHANGELOG.md` lists first.

## Run a study

1. Put raw files in `<root>\<study>\raw\`, named `ID_date.csv` (e.g. `C003_2026-01-15.csv`).
   The ID is everything before the first underscore. No spaces or brackets in the name.
2. If there is a filled diary, save it as `<root>\<study>\sleeplog_<study>.csv`
   (format: `templates\sleeplog_README.md`). Never put an empty template there.
3. In the app: data folder → study → age group → **Start processing**.
4. Keep the laptop plugged in and awake and the data drive connected until it says **Finished**.
   Allow 10–20 minutes per file.
5. Do the four post-run checks in `docs\PIPELINE.md`.

Files already finished are skipped next time unless **overwrite** is ticked. Tick it after changing
age group or adding a diary for files already processed.

## Command-line equivalents (bundled R only)

```
cd /d C:\AutoG
R\bin\Rscript.exe --vanilla tools\check_parity.R          settings fingerprint
R\bin\Rscript.exe --vanilla -e "packageVersion('GGIR')"   must print 3.3.8
```

Run the worker without the UI (for debugging), from `cmd`:

```
set GGIR_ROOT=D:/GGIR
set GGIR_STUDY=ADULT
set GGIR_AGE_GROUP=adult
set GGIR_CORES=2
set GGIR_OVERWRITE=FALSE
R\bin\Rscript.exe --vanilla app\ggir_run.R
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "Windows protected your PC" | SmartScreen on an unsigned `.bat` | More info → Run anyway |
| `Rscript.exe` blocked outright | Application control (only `C:\Program Files` allowed) | IT must allow `R\bin\Rscript.exe` and `R\bin\x64\Rterm.exe`, or the folder. There is no workaround. |
| Black window closes at once | Only the `.bat` was copied, or the folder is incomplete | Copy the whole folder again |
| Browser does not open | Default-browser policy | Open `http://127.0.0.1:8765` by hand |
| "Port in use" / a different port | Another copy is running | Close other black windows, or restart the PC |
| App frozen after **Browse** | Bundle 0.1.0: the folder dialog is hidden behind the browser | Alt+Tab to "Browse For Folder" and close it; update to ≥ 0.2.0 |
| "path contains a space" | GGIR cannot read such paths | Move or rename the data folder |
| "No .csv/.gt3x files" | Wrong folder level or wrong study | The data folder is the one that contains `ADULT\` and `CHILD\` |
| Participant ID wrong or `NA` in reports | File name has spaces/brackets or no underscore | Rename to `ID_date.csv` |
| Run fails at "Save .RData" / "cannot open the connection" | Drive disconnected or went to sleep | Reconnect, rerun; finished files are kept |
| Very slow | Antivirus scanning each large CSV; USB hard disk; laptop on battery | Ask IT to exclude the data folder; process from the internal disk; plug in |
| "Stopped - …" | The worker raised an error | Read the end of `ggir\app_log_*.txt`; the message is the R error |
| Report image missing | No `old_report_*.pdf` (the run failed before reports) | Fix the run error; rerun |
| Sleep diary ignored | Wrong file name or location, or IDs do not match file-name IDs | See `templates\sleeplog_README.md` |

When reporting a problem back to the Mac, send: `BUILD_INFO.txt`, the `app_log_*.txt`, and
`run_settings.txt`. None of these contain accelerometer data, but check for participant IDs before
sharing outside the team.

## Housekeeping

- `ggir\output_raw\meta\` holds the expensive Part 1 results. Keep it until a study is closed.
- A raw CSV is 0.9–1.6 GB per participant. `.gt3x` is about a tenth of that and is read directly.
- Back up `<study>\ggir\output_raw\results\`, `reports\`, `run_settings.txt` and `config.csv`.
  Together they are small and are the reproducible record of a run.
