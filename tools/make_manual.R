# Builds the AutoG technical manual as a light and a dark PDF -- run on the Mac:
#     R_LIBS_USER=~/AutoG-build/maclib Rscript tools/make_manual.R
# Writes app/www/AutoG-technical-manual-light.pdf and -dark.pdf (linked from Help).
# Readers: the investigator, IT / information security, ethics, journal reviewers.
# The settings, cut-points, datasheet columns, package list and fingerprint are
# READ from the app's own files, so those parts cannot drift. The prose must be
# kept in step with docs/*.md by hand. Contains no participant data.

root <- normalizePath(file.path(dirname(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)), ".."))
version <- trimws(readLines(file.path(root, "VERSION"))[1])
source(file.path(root, "app", "settings.R")); source(file.path(root, "app", "results.R"))
chrome <- "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; stopifnot(file.exists(chrome))

esc <- function(x) gsub(">", "&gt;", gsub("<", "&lt;", gsub("&", "&amp;", as.character(x))))
tab <- function(d, widths = NULL) paste0('<table>', if (!is.null(widths)) paste0('<colgroup>', paste(sprintf('<col style="width:%s">', widths), collapse = ""), '</colgroup>'),
  '<tr>', paste(sprintf('<th>%s</th>', names(d)), collapse = ""), '</tr>',
  paste(apply(d, 1, function(r) paste0('<tr>', paste(sprintf('<td>%s</td>', r), collapse = ""), '</tr>')), collapse = ""), '</table>')
df <- function(...) { x <- list(...); n <- x[[1]]; m <- matrix(unlist(x[-1]), ncol = length(n), byrow = TRUE); d <- as.data.frame(m, stringsAsFactors = FALSE); names(d) <- n; d }

# read from the app itself
parity <- system2(file.path(R.home("bin"), "Rscript"), shQuote(file.path(root, "tools", "check_parity.R")), stdout = TRUE)
fingerprint <- sub(".*FINGERPRINT +", "", grep("FINGERPRINT", parity, value = TRUE))
find_call <- function(e) { if (is.call(e) && identical(e[[1]], as.name("GGIR"))) return(e)
  if (is.call(e) || is.expression(e)) for (i in seq_along(e)) { if (identical(e[[i]], quote(expr = ))) next; r <- find_call(e[[i]]); if (!is.null(r)) return(r) }; NULL }
a <- as.list(find_call(parse(file.path(root, "app", "ggir_run.R"), keep.source = FALSE)))[-1]
ggir_args <- data.frame(Argument = names(a), Value = vapply(a, function(x) paste(deparse(x, width.cutoff = 500), collapse = " "), ""), stringsAsFactors = FALSE)
lock <- grep("^#", readLines(file.path(root, "packages.lock")), invert = TRUE, value = TRUE); lock <- lock[nzchar(lock)]
cuts <- data.frame(`Age group` = sub(" - .*$", "", sapply(AGE_GROUPS, `[[`, "label")), `Light (mg)` = sapply(AGE_GROUPS, `[[`, "lig"), `Moderate (mg)` = sapply(AGE_GROUPS, `[[`, "mod"),
                   `Vigorous (mg)` = sapply(AGE_GROUPS, `[[`, "vig"), Source = unname(CUTPOINT_SOURCE[names(AGE_GROUPS)]), check.names = FALSE, stringsAsFactors = FALSE)

body <- paste0(
'<div class="cover"><svg viewBox="0 0 128 128" width="64" height="64"><path d="M101 64 A37 37 0 1 1 64 27" fill="none" stroke="#F3EFE4" stroke-width="18"/><path d="M64 9 L82 27 L64 45 Z" fill="#F3EFE4"/><path d="M110 55 H78 V46 L60 64 L78 82 V73 H110 Z" fill="#2F6BFF"/></svg>',
'<div><h1>AutoG technical manual</h1><p>Version ', version, ' &middot; GGIR 3.3.8 &middot; settings fingerprint <code>', fingerprint, '</code></p><p>', format(Sys.Date(), "%e %B %Y"), ' &middot; Research use only</p></div></div>',

'<h2>1. What AutoG is</h2>',
'<p>AutoG is an offline desktop application that processes raw wrist-accelerometer recordings with the open-source R package GGIR and, for each participant, produces a report image, a draft written summary and a row in a study datasheet. It was built so that people who do not use R can process recordings the same way every time, on a locked-down corporate Windows laptop, without any data leaving the machine.</p>',
'<p class="note"><b>Intended use.</b> Research use only. AutoG is not a medical device. Its outputs describe a recording; they are not for diagnosis, monitoring or decisions about an individual. The written summary and the methods paragraph are drafts that a researcher completes and edits.</p>',

'<h2>2. System requirements and installation</h2>',
tab(df(c("Item", "Requirement"),
  "Operating system", "Windows 10 or 11, 64-bit", "Rights", "Standard user. No administrator rights, no installer, no registry changes",
  "Network", "None. The app never contacts the internet", "Browser", "Microsoft Edge (or any modern browser) to display the interface",
  "Disk", "About 600 MB for the AutoG folder, plus study data (a 7-day raw CSV export is about 1.5 GB)", "Memory and processor", "8 GB or more recommended; the app uses up to 4 processor cores by default"), c("28%", "72%")),
'<p>Installation is copying the <code>AutoG</code> folder to a local path such as <code>C:\\AutoG</code> and double-clicking <code>Run AutoG.bat</code>. The first start installs GGIR from a source file inside the folder (GGIR is pure R, so no compiler is needed). Updating is replacing the folder. Study data is not stored in the AutoG folder. The step-by-step version is page 1 of the infographic.</p>',

'<h2>3. Architecture</h2>',
'<p>The AutoG folder contains a portable copy of R 4.5.3 for Windows, ', length(lock), ' R packages at locked versions, the GGIR 3.3-8 source package, and the application code. Four plain R processes do the work. There is no AI, no database and no server beyond the local one.</p>',
tab(df(c("Process", "File", "What it does"),
  "Launcher", "<code>Run AutoG.bat</code>, <code>app/launch.R</code>", "Uses only the bundled R library; installs GGIR on first start; opens the interface on <code>127.0.0.1</code>, port 8765 or another free port",
  "Interface", "<code>app/app.R</code>, <code>app/help.R</code>", "The screens. Runs in the browser, served by the local R process only to this computer",
  "Result reader", "<code>app/results.R</code>", "Reads GGIR&rsquo;s result files for the quality check, progress, summary, datasheet and methods text. Writes only the verdict notes, study log and files the user saves",
  "GGIR worker", "<code>app/ggir_run.R</code>, <code>app/settings.R</code>", "A separate R process that runs GGIR with the fixed settings in section 5, so the interface stays responsive",
  "Report composer", "<code>app/compose_reports.R</code>", "Joins the two pages of GGIR&rsquo;s per-file PDF report into one image"), c("17%", "30%", "53%")),

'<h2>4. Data flow and privacy</h2>',
'<p>AutoG reads raw recordings from <code>&lt;data folder&gt;\\&lt;study&gt;\\raw\\</code> and never modifies them. Everything it produces is written inside the same study folder. Nothing is sent anywhere.</p>',
tab(df(c("Location", "Contents", "Written by"),
  "<code>&lt;study&gt;\\raw\\</code>", "Raw recordings, named <code>ID_date.csv</code> (or <code>.gt3x</code>). Read-only to AutoG", "The user",
  "<code>&lt;study&gt;\\ggir\\output_raw\\</code>", "GGIR&rsquo;s milestone files, result CSVs and PDF reports", "GGIR",
  "<code>&lt;study&gt;\\ggir\\</code>", "<code>run_settings.txt</code>, run logs, <code>QC_notes.md</code> (verdicts), <code>study_log.txt</code>", "AutoG",
  "<code>&lt;study&gt;\\reports\\</code>", "Report images and saved draft summaries", "AutoG",
  "<code>&lt;study&gt;\\datasheet\\</code>", "Study datasheets with column guide, README and draft methods text", "AutoG",
  "<code>&lt;study&gt;\\autog_study.txt</code>", "The age group fixed for the study", "AutoG",
  "<code>%APPDATA%\\AutoG-*.txt</code>", "Three small text files: last data folder, list of user initials, who has seen the welcome", "AutoG"), c("30%", "50%", "20%")),
'<ul><li><b>Identifiers.</b> AutoG uses the coded participant ID taken from the file name (the text before the first underscore). It has no field for names, dates of birth or clinical details, and tells users not to type them.</li>',
'<li><b>Users.</b> Each user picks their initials at start. They are self-declared, not verified, and are written beside verdicts and study-log entries. They are not exported in the datasheet or summaries. This is a record of who did what, not access control.</li>',
'<li><b>Access control</b> is provided by Windows sign-in, folder permissions and disk encryption, not by AutoG.</li>',
'<li><b>Theme preference</b> (light, dark or auto) is stored in the browser&rsquo;s local storage for the address <code>127.0.0.1</code>.</li></ul>',

'<h2>5. Processing pipeline</h2>',
'<p>AutoG runs GGIR parts 1 to 6 with one fixed set of arguments. The only choice that changes results is the age group, which selects the cut-points and is fixed once per study. The decisions and their reasons:</p>',
tab(df(c("Setting", "Value", "Reason"),
  "GGIR version", "3.3-8, pinned", "Results differ between GGIR versions; every installation must match",
  "Metric and epoch", "ENMO in 5-second epochs", "The cut-points used were derived at 5 seconds; epoch length changes time in each intensity",
  "Calibration", "Auto-calibration on; accepted when the error after calibration is under 0.01 g", "Standard GGIR practice",
  "Time zone", paste0("<code>", TIMEZONE, "</code>"), "Set in <code>app/settings.R</code>; check it against a recording&rsquo;s timestamps",
  "Non-wear", "GGIR default (60-minute window, 15-minute steps), imputed", "",
  "Valid day", "At least 16 hours of wear (Part 2); at least two-thirds of the window (Part 5)", "",
  "Sleep", "HDCZA for the sleep period window; sustained inactivity of 5 minutes within 5 degrees; a diary guides the search if one is supplied", "The sensor decides the exact times; the diary only guides",
  "First and last night", "Excluded", "Recordings start and end part-way through a day",
  "Time windows", "Midnight to midnight, and waking to waking", "",
  "Bouts", "1, 5 and 10 minutes; 80% of the bout above threshold (90% for inactivity)", "",
  "Rhythm", "Interdaily stability, intradaily variability, cosinor (Part 6)", ""), c("20%", "45%", "35%")),
'<h3>Cut-points (ENMO, ActiGraph, non-dominant wrist)</h3>', tab(cuts, c("19%", "10%", "12%", "12%", "47%")),
'<p class="note">These values are device-specific. They are taken from GGIR&rsquo;s published cut-points vignette and should be verified against the original papers before publication. Interdaily stability and intradaily variability depend on the light cut-point in GGIR 3.3-8, so they are not comparable between age groups.</p>',
'<h3>Every argument passed to GGIR</h3><p>Read from <code>app/ggir_run.R</code> when this manual was built. <code>cp_lig</code>, <code>cp_mod</code> and <code>cp_vig</code> are the cut-points for the chosen age group; <code>sleeplog</code> is the diary file if present.</p>',
tab(setNames(data.frame(Argument = paste0("<code>", esc(ggir_args$Argument), "</code>"), Value = paste0("<code>", esc(ggir_args$Value), "</code>")), c("Argument", "Value")), c("34%", "66%")),

'<h2>6. Outputs</h2>',
tab(df(c("Output", "Where", "What it is"),
  "Report image", "<code>reports\\&lt;ID&gt;_GGIR_report.jpg</code>", "GGIR&rsquo;s legacy visual report: one row per day, with summary bars. For looking, not for numbers",
  "Result tables", "<code>ggir\\output_raw\\results\\</code>", "GGIR&rsquo;s CSVs per person, day and night. All numbers AutoG shows come from these",
  "Draft summary", "Summary tab; <code>reports\\&lt;ID&gt;_interpretation_DRAFT.txt</code>", "Eight sections with every number read from a CSV and listed with its file and column; blanks for what the files cannot tell",
  "Study datasheet", "<code>datasheet\\</code>", "One row per recording, with a column guide, a README and a draft methods paragraph",
  "Records", "<code>ggir\\QC_notes.md</code>, <code>ggir\\study_log.txt</code>, <code>ggir\\run_settings.txt</code>", "Verdicts with reasons, processing starts and age-group changes, and the settings of the last run"), c("17%", "35%", "48%")),
'<h3>Datasheet columns</h3><p>Every value is copied from a GGIR person-level file; nothing is recalculated.</p>',
tab(setNames(data.frame(DS_COLS$group, paste0("<code>", DS_COLS$name, "</code>"), esc(DS_COLS$meaning), DS_COLS$unit, paste0("<code>", DS_COLS$col, "</code>")), c("Group", "Column", "Meaning", "Unit", "GGIR column")), c("11%", "21%", "35%", "11%", "22%")),

'<h2>7. Quality control</h2>',
'<h3>Per recording</h3><p>After processing, a user looks at the report image and records one of three verdicts with a one-line reason. AutoG never sets the verdict.</p>',
tab(df(c("Verdict", "Effect"),
  "Usable", "Summary and all datasheet groups available",
  "Usable for activity only", "Sleep and rhythm are left blank in the summary and datasheet",
  "Exclude", "No summary is drafted and the recording cannot enter the datasheet"), c("28%", "72%")),
sprintf('<p>To help the user, AutoG marks calibration as Pass when the error is under %g g (the only documented pass limit) and lists as &ldquo;worth a look&rdquo; any night with a sleep period under %g hours or over %g hours, or more than %g hours awake within it, and any sleep period that starts between 08:00 and 18:00 (a nap, or a still wrist read as sleep). When a study has a sleep diary, GGIR keeps only nights with a diary entry; AutoG lists the other nights GGIR found and the user accepts or dismisses them for each participant. A verdict applies to the results it judged: if the recording is processed again, AutoG asks for the verdict again. New users go through a short lesson with practice questions on reading the report image before their first check.</p>', QC_CAL_MAX, NIGHT_MIN_H, NIGHT_MAX_H, WASO_MAX_H),
'<h3>Of the software</h3><ul><li><b>Golden test.</b> A recording with known results is reprocessed after every installation and after any change to the worker or settings, and compared value by value (calibration error, nights, sleep period lengths, rhythm values, bouted activity). The reference values are held by the investigator and are not printed here because they are study data.</li>',
'<li><b>Settings fingerprint.</b> A hash of every GGIR argument, the cut-point table, the age-group defaults and the time zone. Two installations with the same fingerprint process data identically. This build: <code>', fingerprint, '</code>.</li>',
'<li><b>Parity check.</b> On the build machine the worker&rsquo;s settings are compared automatically with the investigator&rsquo;s reference R script.</li></ul>',

'<h2>8. Versioning and reproducibility</h2>',
'<p>Version numbers are MAJOR.MINOR.PATCH. A MAJOR change is one that can change results (GGIR version, any GGIR argument, cut-points, time zone) and requires reprocessing. MINOR changes alter screens or behaviour but not results. Every release is recorded in <code>CHANGELOG.md</code> with its fingerprint.</p>',
tab(df(c("Component", "Pinned at"), "AutoG", version, "R for Windows", "4.5.3", "GGIR", "3.3-8 (CRAN has since released 3.3-9; staying on 3.3-8 is deliberate)", "Other R packages", paste(length(lock), "packages at the versions listed in the appendix"), "Settings", paste0("fingerprint <code>", fingerprint, "</code>")), c("28%", "72%")),

'<h2>9. Notes for IT and information security</h2>',
'<ul><li><b>Executables run:</b> <code>R\\bin\\Rscript.exe</code> and <code>R\\bin\\x64\\Rterm.exe</code> inside the AutoG folder, started by <code>Run AutoG.bat</code>. Where application control blocks programs outside approved locations, these two need to be allowed.</li>',
'<li><b>Network:</b> the interface listens on the loopback address <code>127.0.0.1</code> only (port 8765, or another free port). It is not reachable from other computers. The app makes no outbound connections, has no update check and sends no telemetry. R&rsquo;s package repositories are disabled at launch.</li>',
'<li><b>Writes outside the study folder:</b> three small text files in the user&rsquo;s <code>%APPDATA%</code> folder, GGIR installed into the AutoG folder&rsquo;s own library on first start, and temporary files in the user&rsquo;s temp folder.</li>',
'<li><b>No installer, services, drivers, registry changes or scheduled tasks.</b> Removing AutoG is deleting the folder.</li>',
'<li><b>Antivirus:</b> real-time scanning of 1.5 GB raw files slows processing considerably. Excluding the data folder from real-time scanning is a performance request, not a requirement.</li>',
'<li><b>Third-party software:</b> R and the packages in the appendix are open source. GGIR is distributed under the Apache License 2.0. Each package&rsquo;s licence is in its <code>DESCRIPTION</code> file under <code>R\\library\\</code>.</li></ul>',
'<p class="note"><b>Governance still to be confirmed by the investigator.</b> Whether ethics approval covers processing on this laptop and transfer on the encrypted drive; whether IT has approved the bundle; where raw files and outputs may be stored and for how long; who may use the app and what training they need. AutoG does not include a backup function: copying raw recordings to a second location needs written approval of that location first.</p>',

'<h2>10. Known limitations</h2>',
'<ul><li><b>Windows testing.</b> Development and testing are done on macOS with the same GGIR version. Each release must pass the golden test on the Windows laptop before it is used for new recordings.</li>',
'<li><b>Sleep without a diary</b> rests on the accelerometer alone. Sleep efficiency is then sleep divided by the sleep period, not by time in bed.</li>',
'<li><b>Inpatients and people confined to bed.</b> A still wrist is read as sleep. Daytime rest and disturbed nights cannot be told apart from sleep without a ward log. Moderate-to-vigorous activity will often be zero; mean acceleration, M60, M5, the intensity gradient and rhythm measures are more informative.</li>',
'<li><b>Adolescents and older adults.</b> No validated ActiGraph wrist ENMO cut-points exist for adolescents (adult values are applied), and no vigorous cut-point is published for older adults (the adult value is carried over).</li>',
'<li><b>Idle Sleep Mode</b> on ActiGraph devices back-fills identical values during stillness. It did not prevent calibration or non-wear detection in the recordings tested, but should be turned off and the sample rate standardised when devices are initialised.</li>',
'<li><b>One age group per study folder.</b> Participants needing different cut-points belong in different study folders.</li>',
'<li><b>The report image</b> averages over days that the day-and-night analysis excludes, so its headline figures can differ slightly from the tables. Numbers come from the tables.</li>',
'<li><b>Initials are not authentication,</b> and a run in progress is not shown again if the black AutoG window is closed and reopened (the run itself continues).</li></ul>',

'<h2>11. Reporting in publications</h2>',
'<p>The Datasheet tab writes a draft methods paragraph from the settings actually used for the study, and saves it with each datasheet. Complete its blanks: device model and firmware, wrist, days worn, whether Idle Sleep Mode was on, and how many recordings were excluded and why. State the AutoG version, the GGIR version and the cut-points with their source. Check each reference against the original paper.</p>',
'<ul class="refs">', paste(sprintf('<li>%s</li>', esc(METHODS_REFERENCES)), collapse = ""), '</ul>',

'<h2>Appendix. R packages in the bundle</h2><p class="small">', paste(esc(lock), collapse = " &middot; "), '</p>')

css <- '
@page { size: A4; margin: 0; }   /* margins come from table.frame so the dark page colour reaches the paper edge */
table.frame { width: 100%; border: 0; margin: 0; font-size: inherit; } table.frame > thead > tr > td, table.frame > tfoot > tr > td { height: 14mm; border: 0; padding: 0; } table.frame > tbody > tr > td { border: 0; padding: 0 15mm; } table.frame > tbody > tr { break-inside: auto; }
* { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
html { --page:#ffffff; --card:#F2F5FB; --text:#18203A; --muted:#566079; --line:#D9DFEC; --accent:#2456D6; --soft:#E9EFFF; --notebg:#FFF2D6; --notefg:#5E4000; background: var(--page); }
html.dark { --page:#0A0F1E; --card:#131A2E; --text:#E9ECF5; --muted:#A3ADC4; --line:#2A3553; --accent:#8FB1FF; --soft:#1B2747; --notebg:#3F320F; --notefg:#FFDB8E; }
body { margin: 0; font-family: "Segoe UI", "Helvetica Neue", Arial, sans-serif; color: var(--text); background: var(--page); font-size: 9.6pt; line-height: 1.45; }
.cover { background: linear-gradient(120deg, #0B1636 0%, #10204A 45%, #2A3FA6 100%); color: #F3EFE4; border-radius: 5mm; padding: 9mm 10mm; display: flex; gap: 7mm; align-items: center; margin-bottom: 5mm; }
.cover h1 { margin: 0 0 1mm; font-size: 22pt; } .cover p { margin: 0; color: #C3CDEB; font-size: 9.6pt; } .cover code { background: rgba(255,255,255,.14); color: #F3EFE4; }
h2 { font-size: 13pt; margin: 6mm 0 2mm; padding-bottom: 1mm; border-bottom: 2px solid var(--accent); break-after: avoid; }
h3 { font-size: 10.5pt; margin: 4mm 0 1.5mm; break-after: avoid; } p { margin: 0 0 2mm; } ul { margin: 0 0 2mm; padding-left: 5mm; } li { margin-bottom: 1mm; }
code { background: var(--soft); color: var(--accent); border-radius: 3px; padding: 0 3px; font-family: Consolas, Menlo, monospace; font-size: 8.4pt; overflow-wrap: anywhere; }
table { width: 100%; border-collapse: collapse; margin: 1mm 0 3mm; table-layout: fixed; font-size: 8.9pt; }
th { text-align: left; background: var(--card); font-size: 8pt; letter-spacing: .6px; text-transform: uppercase; color: var(--muted); }
th, td { border: 1px solid var(--line); padding: 1.4mm 2mm; vertical-align: top; overflow-wrap: anywhere; } tr { break-inside: avoid; }
.note { background: var(--notebg); color: var(--notefg); border-radius: 3mm; padding: 2.5mm 3.5mm; break-inside: avoid; } .note code { background: transparent; color: inherit; }
.small, .refs { font-size: 8.4pt; color: var(--muted); } .refs li { margin-bottom: .6mm; }
'
out <- file.path(root, "app", "www"); tmp <- tempfile("manual_"); dir.create(tmp)
for (theme in c("light", "dark")) {
  html <- file.path(tmp, paste0(theme, ".html"))
  writeLines(sprintf('<!doctype html><html class="%s"><head><meta charset="utf-8"><title>AutoG technical manual</title><style>%s</style></head><body><table class="frame"><thead><tr><td></td></tr></thead><tfoot><tr><td></td></tr></tfoot><tbody><tr><td>%s</td></tr></tbody></table></body></html>', theme, css, body), html, useBytes = TRUE)
  pdf <- file.path(out, sprintf("AutoG-technical-manual-%s.pdf", theme))
  system2(chrome, c("--headless=new", "--disable-gpu", "--no-pdf-header-footer", shQuote(paste0("--print-to-pdf=", pdf)), shQuote(paste0("file://", html))), stdout = FALSE, stderr = FALSE)
  stopifnot(file.exists(pdf))
  cat(sprintf("%s  %d pages  %.0f KB\n", basename(pdf), pdftools::pdf_info(pdf)$pages, file.info(pdf)$size / 1024))
}
