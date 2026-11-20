AutoG - offline Windows app
==============================

Works with no internet and no admin rights. Nothing leaves the PC: the app
runs in your browser at 127.0.0.1 (this computer only).

INSTALL
  1. Copy the whole AutoG folder to the laptop, e.g. C:\AutoG
     (copy it, don't run it from the transfer drive).
  2. Double-click "Run AutoG.bat".
     The first start installs GGIR from the folder (about a minute).
     If Windows shows "Windows protected your PC", click More info > Run anyway.
     If it is blocked outright, ask IT to allow R (see BLOCKED below).

DATA FOLDER  (path must have NO SPACES, e.g. D:\GGIR - not "D:\My Data\GGIR")
  D:\GGIR\
    ADULT\raw\P001_2026-01-15.csv        raw ActiLife exports (or .gt3x), ID_date.csv
    ADULT\sleeplog_ADULT.csv                 filled sleep diary, optional
    CHILD\raw\...
  The app writes   <study>\ggir\     GGIR output (+ app_log_*.txt, run_settings.txt)
                   <study>\reports\  <ID>_GGIR_report.jpg

USE
  Choose your initials and the data folder, check the study and its locked age group,
  then click Start processing on the Home screen.
  Allow 10-20 min per file. Keep the laptop plugged in and awake, and keep
  the data drive connected until it says Finished. Files already finished
  are skipped on the next run unless you tick "overwrite".

  To quit: close the browser tab, then the black "AutoG" window.
  If you close the tab by accident, go to http://127.0.0.1:8765

AFTER EACH RUN (same checks as on the Mac)
  1. ggir\output_raw\results\QC\data_quality_report.csv - calibration error
     > 0.01 g or failed calibration: flag or exclude.
  2. The report images - long green (non-wear) stretches at night mean
     Idle Sleep Mode back-fill; don't report sleep from those files.
  3. part2_summary.csv - number of valid days per participant.

BLOCKED?
  Some corporate PCs only allow programs from C:\Program Files. If
  Rscript.exe is blocked, ask IT to allow  <this folder>\R\bin\Rscript.exe
  and <this folder>\R\bin\x64\Rterm.exe, or to whitelist the folder.
  If the antivirus scans every big CSV, processing is much slower - ask IT
  to exclude the data folder from real-time scanning.

  Port 8765 in use? Close other copies of the app (or restart the PC).

See BUILD_INFO.txt for the R / GGIR / package versions in this bundle.

See HANDOVER.md, CLAUDE.md and docs\ for the manuals (architecture, pipeline,
runbook, versioning and QC, UI, biodesign brief).
