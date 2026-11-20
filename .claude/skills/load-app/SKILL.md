---
name: load-app
description: Install, update, start and verify the AutoG offline app on the Windows laptop. Use when the bundle has just arrived on the transfer drive, when the app will not start, or at the start of a session to confirm what is installed.
---

# Load the app

1. **Find what is there.** Look for `Run AutoG.bat` in `C:\AutoG` and anywhere else the user
   mentions. More than one copy: ask which to keep, and remove the others only with the user's yes.
2. **Install or update.** With the app closed, copy the whole `AutoG` folder from the transfer
   drive to `C:\AutoG` (a local path without spaces), replacing the old folder entirely.
   Do not merge folders and do not run from the transfer drive.
3. **Start.** Double-click `Run AutoG.bat`. First start installs GGIR (about a minute), then the
   browser opens at `http://127.0.0.1:8765`. The black window must stay open.
4. **Verify.** Delegate to `version-steward`, or do its checks yourself:
   - `type VERSION` and `type BUILD_INFO.txt`
   - `R\bin\Rscript.exe --vanilla -e "cat(as.character(packageVersion('GGIR')))"` → `3.3.8`
   - `R\bin\Rscript.exe --vanilla tools\check_parity.R` → fingerprint equals the newest
     `CHANGELOG.md` entry
5. **Prove it computes correctly.** If the golden test has never passed on this laptop with this
   bundle version (see `HANDOVER.md`), run it now: skill `run-study` with ADULT, adult, overwrite on,
   then `qc-steward`.
6. **Record** the version, fingerprint and golden-test result in `HANDOVER.md`.

If it will not start, use the troubleshooting table in `docs/RUNBOOK.md`. If `Rscript.exe` is
blocked by policy, stop: give the user the wording for an IT request (what it is: portable R,
runs locally, no network; which files: `R\bin\Rscript.exe`, `R\bin\x64\Rterm.exe`). Do not look for
a way round the control.
