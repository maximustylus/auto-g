# Builds PLAYBOOK.md as a light and a dark PDF -- run on the build machine:
#     TZ=UTC Rscript tools/make_playbook.R
# Writes docs/AutoG-playbook-light.pdf (for printing) and -dark.pdf. The text is
# PLAYBOOK.md itself, so edit that file and rebuild; never edit the PDFs.
# Needs Google Chrome and the R package commonmark.

root <- normalizePath(file.path(dirname(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)), ".."))
version <- trimws(readLines(file.path(root, "VERSION"))[1])
chrome <- "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; stopifnot(file.exists(chrome))

md <- readLines(file.path(root, "PLAYBOOK.md"), encoding = "UTF-8")
title <- sub("^# +", "", md[grep("^# ", md)[1]]); md <- md[-grep("^# ", md)[1]]     # the title goes on the cover
body <- commonmark::markdown_html(paste(md, collapse = "\n"), extensions = TRUE)
# Links to repository files are text in a PDF: keep the words, drop the link
body <- gsub('<a href="(?!https?://)[^"]*">(.*?)</a>', "\\1", body, perl = TRUE)

# The loop diagram is ASCII art in the Markdown (fine on GitHub); box-drawing
# characters do not line up in print, so the PDF gets a drawn version instead.
step <- function(n, t) sprintf('<div class="ls"><b>%d</b><span>%s</span></div>', n, t)
loop <- paste0('<div class="loop"><div class="lcol"><div class="lh">Build machine (internet)</div>',
  step(1, "Change, through <code>maintain-app</code>"), step(2, "<code>run_tests</code>, parity, golden test"), step(3, "Mockup agreed for new screens"),
  step(4, "<code>release-bundle</code>: version, changelog, PDFs, build"), step(5, "<code>session-handover</code>: write state"),
  '</div><div class="larr"><span>bundle &rarr;</span><span class="d">encrypted drive</span><span>&larr; handover</span></div><div class="lcol"><div class="lh">Managed laptop (offline)</div>',
  step(6, "<code>load-app</code>: install, verify version and fingerprint"), step(7, "Golden test (<code>qc-steward</code>)"), step(8, "<code>run-study</code>, <code>interpret-participant</code>"),
  step(9, "<code>session-handover</code>: write state and \u201cChanged on Windows\u201d"), '</div></div>')
body <- sub("(?s)<pre><code>[^<]*build machine \\(internet\\).*?</code></pre>", loop, body, perl = TRUE)
if (!grepl('class="loop"', body, fixed = TRUE)) stop("loop diagram not found in PLAYBOOK.md")

cover <- paste0('<div class="cover"><svg viewBox="0 0 128 128" width="64" height="64"><path d="M101 64 A37 37 0 1 1 64 27" fill="none" stroke="#F3EFE4" stroke-width="18"/>',
  '<path d="M64 9 L82 27 L64 45 Z" fill="#F3EFE4"/><path d="M110 55 H78 V46 L60 64 L78 82 V73 H110 Z" fill="#2F6BFF"/></svg>',
  '<div><h1>', title, '</h1><p>AutoG ', version, ' &middot; how it was designed, built, tested and released</p><p>Apache License 2.0 &middot; research use only</p></div></div>')

css <- '
@page { size: A4; margin: 0; }
* { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
html { --page:#ffffff; --card:#F2F5FB; --text:#18203A; --muted:#566079; --line:#D9DFEC; --accent:#2456D6; --soft:#E9EFFF; background: var(--page); }
html.dark { --page:#0A0F1E; --card:#131A2E; --text:#E9ECF5; --muted:#A3ADC4; --line:#2A3553; --accent:#8FB1FF; --soft:#1B2747; }
body { margin: 0; font-family: "Segoe UI", "Helvetica Neue", Arial, sans-serif; color: var(--text); background: var(--page); font-size: 10pt; line-height: 1.5; }
table.frame { width: 100%; border: 0; margin: 0; } table.frame > thead > tr > td, table.frame > tfoot > tr > td { height: 14mm; border: 0; padding: 0; }
table.frame > tbody > tr > td { border: 0; padding: 0 17mm; } table.frame > tbody > tr { break-inside: auto; }
.cover { background: linear-gradient(120deg, #0B1636 0%, #10204A 45%, #2A3FA6 100%); color: #F3EFE4; border-radius: 5mm; padding: 9mm 10mm; display: flex; gap: 7mm; align-items: center; margin-bottom: 4mm; }
.cover h1 { margin: 0 0 1mm; font-size: 23pt; color: #F3EFE4; } .cover p { margin: 0; color: #C3CDEB; font-size: 9.6pt; }
h2 { font-size: 13.5pt; margin: 7mm 0 2.5mm; padding-bottom: 1mm; border-bottom: 2px solid var(--accent); break-after: avoid; }
h3 { font-size: 11pt; margin: 4mm 0 1.5mm; break-after: avoid; }
p { margin: 0 0 2.4mm; } ul, ol { margin: 0 0 2.4mm; padding-left: 6mm; } li { margin-bottom: 1.2mm; }
hr { border: 0; border-top: 1px solid var(--line); margin: 5mm 0; }
strong { color: var(--text); }
code { background: var(--soft); color: var(--accent); border-radius: 3px; padding: 0 3px; font-family: Consolas, Menlo, monospace; font-size: 8.8pt; }
pre { background: var(--card); border: 1px solid var(--line); border-radius: 3mm; padding: 3mm 4mm; break-inside: avoid; overflow: hidden; }
pre code { background: transparent; color: var(--text); padding: 0; font-size: 7.6pt; line-height: 1.3; white-space: pre; }
table { width: 100%; border-collapse: collapse; margin: 1mm 0 3.5mm; font-size: 9pt; }
th { text-align: left; background: var(--card); font-size: 8pt; letter-spacing: .6px; text-transform: uppercase; color: var(--muted); }
th, td { border: 1px solid var(--line); padding: 1.6mm 2.2mm; vertical-align: top; } tr { break-inside: avoid; }
a { color: var(--accent); text-decoration: none; }
.loop { display: grid; grid-template-columns: 1fr 26mm 1fr; gap: 3mm; align-items: center; margin: 2mm 0 4mm; break-inside: avoid; }
.lcol { background: var(--card); border: 1px solid var(--line); border-radius: 4mm; padding: 3mm 3.5mm; }
.lh { font-size: 8pt; letter-spacing: .8px; text-transform: uppercase; color: var(--muted); font-weight: 700; margin-bottom: 2mm; }
.ls { display: flex; gap: 2.5mm; align-items: baseline; font-size: 9pt; margin: 1.6mm 0; }
.ls b { flex: none; width: 5.5mm; height: 5.5mm; border-radius: 50%; background: linear-gradient(135deg, #2F6BFF, #6A5CFF); color: #fff; font-size: 8pt; display: inline-flex; align-items: center; justify-content: center; }
.larr { display: flex; flex-direction: column; align-items: center; gap: 2mm; font-size: 8.4pt; color: var(--muted); text-align: center; }
.larr .d { border: 1px solid var(--line); border-radius: 99px; padding: 1mm 2.5mm; color: var(--text); background: var(--soft); }
'
out <- file.path(root, "docs"); tmp <- tempfile("playbook_"); dir.create(tmp)
for (theme in c("light", "dark")) {
  html <- file.path(tmp, paste0(theme, ".html"))
  writeLines(sprintf('<!doctype html><html class="%s"><head><meta charset="utf-8"><title>AutoG playbook</title><style>%s</style></head><body><table class="frame"><thead><tr><td></td></tr></thead><tfoot><tr><td></td></tr></tfoot><tbody><tr><td>%s%s</td></tr></tbody></table></body></html>',
                     theme, css, cover, body), html, useBytes = TRUE)
  pdf <- file.path(out, sprintf("AutoG-playbook-%s.pdf", theme))
  system2(chrome, c("--headless=new", "--disable-gpu", "--no-pdf-header-footer", shQuote(paste0("--print-to-pdf=", pdf)), shQuote(paste0("file://", html))), stdout = FALSE, stderr = FALSE)
  stopifnot(file.exists(pdf))
  cat(sprintf("%s  %d pages  %.0f KB\n", basename(pdf), pdftools::pdf_info(pdf)$pages, file.info(pdf)$size / 1024))
}
