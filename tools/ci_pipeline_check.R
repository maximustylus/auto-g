# End-to-end check used by the GitHub workflow (and runnable by hand):
# makes a short FULLY SYNTHETIC recording, processes it with AutoG's real GGIR
# worker, and checks that the outputs AutoG promises are there and sensible.
#     Rscript tools/ci_pipeline_check.R [work folder]
here <- normalizePath(file.path(dirname(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)), ".."))
a <- commandArgs(TRUE); root <- if (length(a)) a[1] else file.path(tempdir(), "autog-ci")
root <- normalizePath(root, winslash = "/", mustWork = FALSE); unlink(root, recursive = TRUE)
raw <- file.path(root, "CHILD", "raw"); dir.create(raw, recursive = TRUE)
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
ok <- function(what, cond) { cat(if (isTRUE(cond)) "  ok   " else "  FAIL ", what, "\n", sep = ""); if (!isTRUE(cond)) quit(status = 1) }

cat("1. synthetic recording (4 days, child)\n")
stopifnot(system2(rscript, c(shQuote(file.path(here, "dev", "make_synthetic_recording.R")), shQuote(file.path(raw, "K001_2026-01-15.csv")), "3", "4", "child")) == 0)

cat("2. AutoG worker (GGIR parts 1-6, reports)\n")
status <- file.path(root, "status.txt")
Sys.setenv(GGIR_ROOT = root, GGIR_STUDY = "CHILD", GGIR_AGE_GROUP = "paediatric", GGIR_CORES = "1", GGIR_OVERWRITE = "TRUE", GGIR_STATUS = status)
log <- file.path(root, "worker_log.txt")
system2(rscript, c("--vanilla", shQuote(file.path(here, "app", "ggir_run.R"))), stdout = log, stderr = log)
st <- if (file.exists(status)) readLines(status)[1] else "no status"
if (st != "done") cat(tail(readLines(log), 40), sep = "\n")
ok(paste("worker finished:", st), st == "done")

cat("3. outputs\n")
source(file.path(here, "app", "settings.R")); source(file.path(here, "app", "results.R"))
sd <- file.path(root, "CHILD"); f <- "K001_2026-01-15.csv"
q <- qc_table(sd)[[1]]
ok("calibration error under 0.01 g", isTRUE(q$cal_error < 0.01))
ok("at least one night of sleep found", isTRUE(q$nights >= 1))
ok("report picture made", file.exists(file.path(sd, "reports", "K001_GGIR_report.jpg")))
ok("run settings recorded with GGIR 3.3.8", identical(read_run_settings(sd)[["GGIR version"]], "3.3.8"))
add_qc_note(sd, f, "usable", "ci", "ci", "CI")
d <- draft_summary(sd, f, "ci"); ok("summary drafted with traced numbers", d$ok && nrow(d$sources) >= 15)
x <- build_datasheet(sd, f)$data; ok("datasheet row built", nrow(x) == 1 && !is.na(x$mean_accel_waking_mg))
ok("methods paragraph drafted", grepl("GGIR version 3.3.8", methods_paragraph(sd, "ci")$text))
cat("pipeline check passed\n")
