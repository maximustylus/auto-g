# Builds the AutoG infographic (2 x A4) as a light and a dark PDF -- run on the Mac:
#     Rscript tools/make_infographic.R
# Writes app/www/AutoG-infographic-light.pdf and -dark.pdf (the Help tab links to
# them, and they travel in the bundle). One source, two themes (docs/BRAND.md).
# Needs Google Chrome on the Mac for the HTML -> PDF step. Nothing here runs on
# the laptop. Text must stay in step with app/help.R and docs/RUNBOOK.md.

root <- normalizePath(file.path(dirname(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)), ".."))
version <- trimws(readLines(file.path(root, "VERSION"))[1])
source(file.path(root, "app", "results.R")); library(shiny); source(file.path(root, "app", "help.R"))   # thresholds, report colours
chrome <- "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
stopifnot(file.exists(chrome))

ic <- function(name) as.character(fontawesome::fa(name, fill = "currentColor"))
mark_svg <- function(ring) sprintf('<svg viewBox="0 0 128 128" width="46" height="46"><path d="M101 64 A37 37 0 1 1 64 27" fill="none" stroke="%s" stroke-width="18"/><path d="M64 9 L82 27 L64 45 Z" fill="%s"/><path d="M110 55 H78 V46 L60 64 L78 82 V73 H110 Z" fill="#2F6BFF"/></svg>', ring, ring)
strip <- function(segs) paste0('<div class="strip">', paste(sapply(segs, function(s) sprintf('<i style="flex:%s;background:%s"></i>', s[2], REPORT_COLOURS[[s[1]]])), collapse = ""), '</div>')
key <- paste(sapply(names(REPORT_KEY), function(k) sprintf('<span><i style="background:%s"></i>%s</span>', REPORT_COLOURS[[k]], REPORT_KEY[[k]])), collapse = "")
step <- function(n, icon, title, body) sprintf('<div class="card step"><div class="n">%s</div><div class="ico">%s</div><h3>%s</h3><p>%s</p></div>', n, ic(icon), title, body)
head <- function(title, sub) sprintf('<header>%s<div><h1>%s</h1><p>%s</p></div><span class="pill">AutoG %s</span></header>', mark_svg("#F3EFE4"), title, sub, version)
foot <- function(n) sprintf('<footer><span>AutoG %s &middot; GGIR 3.3.8 &middot; Research use only. Not for decisions about an individual.</span><span>%d of 2</span></footer>', version, n)

page1 <- paste0('<section class="page">', head("Install and set up AutoG", "On the corporate laptop. No internet, no admin rights, nothing to install."),
  '<div class="row needs">',
    sprintf('<span class="chip">%s Windows 10 or 11</span><span class="chip">%s Microsoft Edge</span><span class="chip">%s The AutoG folder</span><span class="chip">%s About 1 GB free on C:</span><span class="chip">%s 10 minutes</span>',
            ic("laptop"), ic("globe"), ic("folder-open"), ic("hard-drive"), ic("clock")), '</div>',
  '<h2>Six steps, once per laptop</h2><div class="grid3">',
  step(1, "folder-open", "Copy the folder", "Copy the <b>whole</b> AutoG folder from the (encrypted) transfer drive to <code>C:\\AutoG</code>. Never run it from the drive or from a network drive."),
  step(2, "trash-can", "Remove old copies", "Delete any earlier copy, or one on a shared drive. Only one AutoG should exist on the laptop."),
  step(3, "play", "Start AutoG", "Open <code>C:\\AutoG</code> and double-click <b>Run AutoG.bat</b>. A black window opens. Keep it open: it is AutoG running."),
  step(4, "hourglass-half", "Wait a minute", "The first start sets itself up from the folder, with no internet. Then AutoG opens in Edge on its own."),
  step(5, "user", "Choose your initials", "Add your initials (2 to 4 letters) and go through the short welcome. It teaches you to read the report picture."),
  step(6, "flask", "Choose the study folder", "Press <b>Browse</b> and pick the data folder, for example <code>D:\\GGIR</code>. It holds a study folder such as <code>ADULT</code> with a <code>raw</code> folder inside."),
  '</div>',
  '<div class="grid2">',
  sprintf('<div class="card warn"><h3>%s If Windows stops you</h3><p><b>"Windows protected your PC"</b>: choose More info, then Run anyway.</p><p><b>Blocked by your organisation</b>: AutoG cannot fix this. Ask IT to allow <code>C:\\AutoG\\R\\bin\\Rscript.exe</code> and <code>C:\\AutoG\\R\\bin\\x64\\Rterm.exe</code>.</p><p><b>Edge does not open</b>: type <code>http://127.0.0.1:8765</code> into Edge.</p></div>', ic("triangle-exclamation")),
  sprintf('<div class="card"><h3>%s Folder rules</h3><p>No spaces anywhere in the data folder path: <code>D:\\GGIR</code> works, <code>D:\\My Data\\GGIR</code> does not.</p><p>Inside it: <code>ADULT\\raw\\P001_2026-01-15.csv</code>. The name is the coded ID, an underscore, the date.</p><p>AutoG writes its results next to <code>raw</code>. It never changes the raw files.</p></div>', ic("folder-tree")),
  '</div>',
  '<h2>Every day after that</h2><div class="grid3">',
  sprintf('<div class="card mini"><h3>%s Start</h3><p>Double-click <b>Run AutoG.bat</b>, then choose your initials.</p></div>', ic("play")),
  sprintf('<div class="card mini"><h3>%s Close</h3><p>Close the Edge tab, then the black window. Not while files are processing.</p></div>', ic("power-off")),
  sprintf('<div class="card mini"><h3>%s Update</h3><p>Delete <code>C:\\AutoG</code> and copy the new folder in. Study data is not inside it, so nothing is lost.</p></div>', ic("rotate")),
  '</div>',
  sprintf('<div class="check">%s <b>It is working when</b> the top of the screen shows the version, GGIR 3.3.8 and Offline, and your initials. The investigator then runs the reference file once to confirm the results match.</div>', ic("circle-check")),
  foot(1), '</section>')

page2 <- paste0('<section class="page">', head("Using AutoG", "From a week on the wrist to your study datasheet."),
  '<div class="flow">',
  paste(mapply(function(n, icon, t, d) sprintf('<div class="f"><div class="ico">%s</div><b>%d &middot; %s</b><span>%s</span></div>', ic(icon), n, t, d),
               1:5, c("clock", "folder-open", "play", "eye", "table"), c("Wear", "Save", "Process", "Check", "Collect"),
               c("7 to 8 days on the wrist", "File into the study's raw folder", "Press Start processing, about 15 minutes a file", "Look at the picture, record a verdict", "Reports, summaries, datasheet")), collapse = ""),
  '</div>',
  '<h2>What you get for each participant</h2><div class="grid3">',
  sprintf('<div class="card mini"><h3>%s Report picture</h3><p>Every day and night on one page.</p></div>', ic("image")),
  sprintf('<div class="card mini"><h3>%s Written summary</h3><p>A draft you complete and edit.</p></div>', ic("file-lines")),
  sprintf('<div class="card mini"><h3>%s A row in the datasheet</h3><p>Activity, sleep and rhythm numbers, with a guide to every column.</p></div>', ic("table")),
  '</div>',
  '<h2>Reading the report picture</h2><div class="card pic">',
  '<div class="key">', key, '</div>',
  sprintf('<div class="ex"><span class="tag ok">%s Usable</span> Nights are grey, days are coloured.%s</div>', ic("check"), strip(DAY_GOOD)),
  sprintf('<div class="ex"><span class="tag no">%s Not usable for sleep</span> Green at night: the device was not worn.%s</div>', ic("triangle-exclamation"), strip(DAY_NONWEAR)),
  sprintf('<div class="ex"><span class="tag no">%s Not usable for sleep</span> A whole day shaded as sleep: a still wrist was read as sleeping.%s</div>', ic("triangle-exclamation"), strip(DAY_ALLSLEEP)),
  '<div class="axis"><span>midnight</span><span>6am</span><span>noon</span><span>6pm</span><span>midnight</span></div>',
  '<p class="small">Simplified illustrations in the report\'s colours. A real picture shows each day as its own row.</p></div>',
  '<h2>Choosing a verdict</h2><div class="grid3">',
  '<div class="card mini"><h3>Usable</h3><p>Calibration passes and most days look right. Everything goes into the summary and datasheet.</p></div>',
  '<div class="card mini"><h3>Usable for activity only</h3><p>Days look right but nights cannot be trusted. Sleep and rhythm are left blank.</p></div>',
  '<div class="card mini"><h3>Exclude</h3><p>Calibration is flagged, very few valid days, or the picture makes no sense. Stays out of the datasheet.</p></div>',
  '</div>',
  sprintf('<p class="small">AutoG marks calibration Pass under %g g and points out nights under %g hours, over %g hours, or with more than %g hours awake. Those are prompts to look. The verdict is yours. Say what you see, not why.</p>', QC_CAL_MAX, NIGHT_MIN_H, NIGHT_MAX_H, WASO_MAX_H),
  '<div class="grid2">',
  sprintf('<div class="card warn"><h3>%s When something goes wrong</h3><p><b>Could not be read</b>: export the file again and replace it.</p><p><b>Laptop went to sleep</b>: press Start processing again. Finished files are kept.</p><p><b>Different age group warning</b>: stop and ask the investigator.</p></div>', ic("triangle-exclamation")),
  sprintf('<div class="card"><h3>%s Four rules</h3><p>%s Everything stays on this laptop.</p><p>%s Coded IDs only, never names.</p><p>%s Plugged in and awake while processing.</p><p>%s For research, not for an individual\'s care.</p></div>', ic("shield-halved"), ic("lock"), ic("id-card"), ic("plug"), ic("flask")),
  '</div>', foot(2), '</section>')

css <- '
@page { size: A4; margin: 0; }
* { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
html { --page:#ffffff; --card:#F2F5FB; --text:#18203A; --muted:#566079; --line:#DDE3EF; --accent:#2F6BFF; --soft:#E6EDFF; --warnbg:#FFF2D6; --warnfg:#6B4800; --okbg:#E3F6EC; --okfg:#126B45; --nobg:#FDE7E5; --nofg:#9A2019; }
html.dark { --page:#0A0F1E; --card:#131A2E; --text:#E9ECF5; --muted:#A3ADC4; --line:#26304B; --accent:#6C97FF; --soft:#1B2747; --warnbg:#3F320F; --warnfg:#FFDB8E; --okbg:#12382A; --okfg:#9BE8C0; --nobg:#47201E; --nofg:#FFB8B2; }
body { margin: 0; font-family: "Segoe UI", "Helvetica Neue", Arial, sans-serif; color: var(--text); font-size: 9.7pt; line-height: 1.38; }
.page { width: 210mm; height: 297mm; padding: 0 12mm 7mm; background: var(--page); display: flex; flex-direction: column; gap: 2.6mm; page-break-after: always; overflow: hidden; }
header svg { width: 15mm; height: 15mm; flex: none; }
header { margin: 0 -12mm; padding: 5.5mm 12mm; background: linear-gradient(120deg, #0B1636 0%, #10204A 45%, #2A3FA6 100%); color: #F3EFE4; display: flex; align-items: center; gap: 5mm; }
header h1 { margin: 0; font-size: 21pt; letter-spacing: .3px; } header p { margin: 1px 0 0; color: #C3CDEB; font-size: 10.5pt; }
.pill { margin-left: auto; border: 1px solid rgba(255,255,255,.3); border-radius: 99px; padding: 1.2mm 4mm; font-size: 9pt; white-space: nowrap; }
h2 { font-size: 9pt; letter-spacing: 1.3px; text-transform: uppercase; color: var(--muted); margin: 1.5mm 0 -1mm; }
h3 { font-size: 11pt; margin: 0 0 1mm; } p { margin: 0 0 1.2mm; } p:last-child { margin-bottom: 0; }
svg { height: 1em; width: 1.1em; vertical-align: -0.125em; }
code { background: var(--soft); color: var(--accent); border-radius: 4px; padding: 0 4px; font-family: Consolas, Menlo, monospace; font-size: 9pt; white-space: nowrap; }
.row { display: flex; flex-wrap: wrap; gap: 2.5mm; } .chip { background: var(--soft); border-radius: 99px; padding: 1mm 3mm; font-size: 8.6pt; font-weight: 600; white-space: nowrap; } .chip svg { color: var(--accent); margin-right: 1.2mm; }
.grid3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 3.2mm; } .grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 3.2mm; }
.card { background: var(--card); border: 1px solid var(--line); border-radius: 4mm; padding: 3mm 3.8mm; }
.card h3 svg { color: var(--accent); margin-right: 1.2mm; }
.step { position: relative; padding-top: 4mm; } .step .n { position: absolute; top: 3.2mm; right: 4mm; font-size: 22pt; font-weight: 800; color: var(--line); line-height: 1; }
.step .ico { width: 10mm; height: 10mm; border-radius: 3mm; background: linear-gradient(135deg, #2F6BFF, #6A5CFF); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 13pt; margin-bottom: 2.2mm; }
.card.warn { background: var(--warnbg); border-color: transparent; color: var(--warnfg); } .card.warn h3 svg { color: var(--warnfg); } .card.warn code { background: rgba(255,255,255,.35); color: inherit; }
html.dark .card.warn code { background: rgba(0,0,0,.3); }
.check { background: var(--okbg); color: var(--okfg); border-radius: 4mm; padding: 2.4mm 4mm; } .check svg { margin-right: 1mm; }
.flow { display: grid; grid-template-columns: repeat(5, 1fr); gap: 2.5mm; margin-top: 1mm; text-align: center; }
.flow .f { display: flex; flex-direction: column; align-items: center; gap: .8mm; } .flow b { font-size: 10.5pt; } .flow span { font-size: 8.8pt; color: var(--muted); }
.flow .ico { width: 12mm; height: 12mm; border-radius: 50%; background: linear-gradient(135deg, #2F6BFF, #6A5CFF); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 14pt; }
.pic { background: #ffffff; color: #18203A; border-color: #DDE3EF; }
.key { display: flex; flex-wrap: wrap; gap: 1mm 4.5mm; font-size: 9pt; margin-bottom: 2mm; } .key i { display: inline-block; width: 3.2mm; height: 3.2mm; border-radius: 1mm; border: 1px solid rgba(0,0,0,.3); margin-right: 1.4mm; vertical-align: -0.4mm; }
.ex { font-size: 9.4pt; margin-top: 2mm; } .strip { display: flex; height: 6.2mm; border-radius: 1.4mm; overflow: hidden; border: 1px solid #c3c7d3; margin-top: 1mm; } .strip i { display: block; }
.tag { border-radius: 99px; padding: .4mm 3mm; font-weight: 700; font-size: 8.6pt; margin-right: 1.5mm; } .tag.ok { background: #E3F6EC; color: #126B45; } .tag.no { background: #FDE7E5; color: #9A2019; }
.axis { display: flex; justify-content: space-between; font-size: 8pt; color: #566079; margin-top: .6mm; }
.small { font-size: 8.8pt; color: var(--muted); } .pic .small { color: #566079; margin-top: 1.5mm; }
footer { margin-top: auto; display: flex; justify-content: space-between; font-size: 8pt; color: var(--muted); border-top: 1px solid var(--line); padding-top: 1.8mm; }
'

out <- file.path(root, "app", "www"); tmp <- tempfile("infographic_"); dir.create(tmp)
for (theme in c("light", "dark")) {
  html <- file.path(tmp, paste0(theme, ".html"))
  writeLines(sprintf('<!doctype html><html class="%s"><head><meta charset="utf-8"><title>AutoG infographic</title><style>%s</style></head><body>%s%s</body></html>', theme, css, page1, page2), html, useBytes = TRUE)
  pdf <- file.path(out, sprintf("AutoG-infographic-%s.pdf", theme))
  system2(chrome, c("--headless=new", "--disable-gpu", "--no-pdf-header-footer", shQuote(paste0("--print-to-pdf=", pdf)), shQuote(paste0("file://", html))), stdout = FALSE, stderr = FALSE)
  stopifnot(file.exists(pdf))
  cat(sprintf("%s  %d pages  %.0f KB\n", basename(pdf), pdftools::pdf_info(pdf)$pages, file.info(pdf)$size / 1024))
}
