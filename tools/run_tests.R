#==============================================================================
# Automated checks of app/results.R against a made-up study.
#
#   Rscript tools/run_tests.R          (Windows: R\bin\Rscript.exe --vanilla tools\run_tests.R)
#
# Builds a small fake GGIR output folder in a temp directory (invented numbers,
# no participant data), then checks what the Quality check, Progress, Summary,
# Datasheet, Home and Methods code make of it. Base R only; takes seconds.
# Exit status 0 = all passed, 1 = at least one failed. Run after every change
# to app/results.R. It does NOT run GGIR: the golden test does that.
#==============================================================================
root <- normalizePath(file.path(dirname(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)), ".."))
source(file.path(root, "app", "settings.R")); source(file.path(root, "app", "results.R"))

fails <- character(); n <- 0
check <- function(what, ok) { n <<- n + 1; ok <- isTRUE(tryCatch(ok, error = function(e) FALSE)); if (!ok) fails <<- c(fails, what); cat(if (ok) "  ok   " else "  FAIL ", what, "\n", sep = "") }
section <- function(x) cat("\n", x, "\n", sep = "")

#--- the made-up study --------------------------------------------------------
sd <- file.path(tempfile("autog_test_"), "ADULT"); res <- file.path(sd, "ggir", "output_raw", "results")
dir.create(file.path(res, "QC"), recursive = TRUE); dir.create(file.path(sd, "raw")); dir.create(file.path(sd, "reports"))
ids <- c("A001", "B002", "C003", "D004", "E005"); f <- paste0(ids, "_2026-01-01.csv")
for (x in f) writeLines("raw", file.path(sd, "raw", x))
writeLines("raw", file.path(sd, "raw", "F006_2026-01-01.csv"))          # never processed
w <- function(d, name) utils::write.csv(d, file.path(res, name), row.names = FALSE)
w(data.frame(filename = f, file.corrupt = FALSE, file.too.short = FALSE, cal.error.end = c(0.004, 0.006, 0.008, 0.014, 0.005)), "QC/data_quality_report.csv")
w(data.frame(ID = ids, filename = f, start_time = "2026-01-01T06:00:00+0000", samplefreq = c(60, 60, 30, 60, 60), device = "actigraph", meas_dur_dys = 7,
             N.valid.weekend.days..WE. = c(2, 2, 2, 0, 2), N.valid.weekdays..WD. = c(5, 4, 5, 1, 5), AD_M5_ENMO_mg_0.24hr = c(80.5, 60, 70, 20, 90),
             AD_mean_ENMO_mg_0.24hr = c(29.85, 25, 28, 9, 33), AD_ig_gradient_ENMO_0.24hr = c(-2.31, -2.5, -2.4, -3, -2.2)), "part2_summary.csv")
nights <- rbind(
  data.frame(ID = "A001", night = 2:4, sleeponset = c(22.5, 23, 22.75), wakeup = c(30, 30.5, 30.25), SptDuration = c(7.5, 7.5, 7.5), WASO = c(1, .8, 1.2),
             sleeponset_ts = c("22:30:00", "23:00:00", "22:45:00"), wakeup_ts = c("06:00:00", "06:30:00", "06:15:00"), calendar_date = c("2026-01-02", "2026-01-03", "2026-01-04"), sleeplog_used = 0),
  data.frame(ID = "B002", night = 2, sleeponset = 22, wakeup = 30, SptDuration = 8, WASO = 1, sleeponset_ts = "22:00:00", wakeup_ts = "06:00:00", calendar_date = "2026-01-02", sleeplog_used = 0),
  data.frame(ID = "C003", night = 2:4, sleeponset = c(26, 19, 22), wakeup = c(30.2, 30.5, 30), SptDuration = c(4.2, 11.5, 8), WASO = c(.5, 1, 2.4),
             sleeponset_ts = c("02:00:00", "19:00:00", "22:00:00"), wakeup_ts = c("06:12:00", "06:30:00", "06:00:00"), calendar_date = c("2026-01-02", "2026-01-03", "2026-01-04"), sleeplog_used = 1))
nights$filename <- paste0(nights$ID, "_2026-01-01.csv"); nights$cleaningcode <- 0; nights$acc_available <- 1; w(nights, "part4_nightsummary_sleep_cleaned.csv")
p5 <- function(i) data.frame(ID = ids[i], filename = f[i], Nvaliddays = c(5, 4, 5, 1, 5)[i], ACC_day_mg_pla = c(48.2, 40, 44, 12, 50)[i], dur_day_min_pla = 990,
  dur_day_total_IN_min_pla = c(731.6, 760, 750, 950, 700)[i], dur_day_total_LIG_min_pla = 160, dur_day_total_MOD_min_pla = 70, dur_day_total_VIG_min_pla = 15,
  dur_day_MVPA_bts_10_min_pla = c(22.7, 10, 0, 0, 30)[i], quantile_mostactive60min_mg_pla = 130, dur_spt_min_pla = 465, dur_spt_sleep_min_pla = 392,
  sleep_efficiency_after_onset_pla = .84, sleeponset_pla = 22.9, wakeup_pla = 30.4, GGIRversion = "3.3.8")
w(p5(1:4), "part5_personsummary_WW_L44.8M100.6V428.8_T5A5.csv"); w(p5(5), "part5_personsummary_WW_L18M60V428.8_T5A5.csv")
w(data.frame(ID = rep(ids[1:4], each = 2), calendar_date = c("2026-01-02", "2026-01-03"), nonwear_perc_day = c(0, 1.5, 0, 0, 0, 0, 40, 60),
             ACC_day_mg = c(40, 52.8, 38, 42, 44, 44, 10, 14), dur_day_MVPA_bts_10_min = c(47.5, 0, 20, 0, 0, 0, 0, 0)), "part5_daysummary_WW_L44.8M100.6V428.8_T5A5.csv")
w(data.frame(ID = ids, IS = c(.612, .5, .55, .2, .6), IV = c(1.071, 1.2, 1.1, 1.6, 1), cosinor_R2 = c(.19, .2, .2, .05, .2)), "part6_summary.csv")
run_date <- "2026-01-10 09:00"
cat(sprintf("run date      %s\nstudy         ADULT\nage group     adult\ncut-points    light 44.8 / moderate 100.6 / vigorous 428.8 mg (Adult (18-64 y) - Hildebrand 2014/2016)\nGGIR version  3.3.8\nsleep log     none (HDCZA only)\n", run_date),
    file = file.path(sd, "ggir", "run_settings.txt"))
meta <- file.path(sd, "ggir", "output_raw", "meta"); t0 <- as.POSIXct("2026-01-10 09:05:00")
for (k in 1:6) { d <- file.path(meta, c("basic", paste0("ms", 2:6, ".out"))[k]); dir.create(d, recursive = TRUE)
  for (x in f) { m <- file.path(d, if (k == 1) paste0("meta_", x, ".RData") else if (k == 6) paste0(tools::file_path_sans_ext(x), "_T5A5.RData") else paste0(x, ".RData")); writeLines("", m); Sys.setFileTime(m, t0) } }
writeLines("", file.path(sd, "reports", "A001_GGIR_report.jpg"))

#--- checks -------------------------------------------------------------------
section("Reading settings and the quality table")
rs <- read_run_settings(sd)
check("run_settings: age group and three cut-points are read", rs[["age group"]] == "adult" && identical(unname(rs$cp), c("44.8", "100.6", "428.8")))
q <- qc_table(sd); names(q) <- sapply(q, `[[`, "id")
check("quality table has one row per processed file", length(q) == 5)
check("calibration error is read exactly", q$A001$cal_error == 0.004 && q$D004$cal_error == 0.014)
check("valid days are weekdays plus weekend days", q$A001$valid_days == 7 && q$D004$valid_days == 1)
check("nights are counted per participant", q$A001$nights == 3 && q$B002$nights == 1 && q$D004$nights == 0)
check("a normal participant has nothing worth a look", length(q$A001$looks) == 0)
check("short night, long night and long wake are each listed", length(q$C003$looks) == 3 && any(grepl("shorter than 5", q$C003$looks)) && any(grepl("longer than 11", q$C003$looks)) && any(grepl("awake", q$C003$looks)))
check("report image found only where it exists", !is.na(q$A001$image) && is.na(q$B002$image))
check("no verdict before one is recorded", all(is.na(sapply(q, `[[`, "verdict"))))

section("Verdicts")
old <- "- 2026-01-10 10:00 | app 0.4.0 | A001_2026-01-01.csv | usable | looked fine"
dir.create(dirname(qc_notes_path(sd)), showWarnings = FALSE); writeLines(c("# QC notes", "", old), qc_notes_path(sd))
v <- latest_verdict(sd, f[1])
check("a line written before initials existed still reads", v$verdict == "usable" && v$reason == "looked fine" && v$by == "")
add_qc_note(sd, f[2], "usable for activity only", "nights | green", "9.9.9", "AB")
v <- latest_verdict(sd, f[2])
check("a new verdict carries initials, and a | in the reason cannot break the line", v$verdict == "usable for activity only" && v$by == "AB" && !grepl("|", v$reason, fixed = TRUE))
add_qc_note(sd, f[3], "usable", "ok", "9.9.9", "AB"); add_qc_note(sd, f[4], "exclude", "calibration flagged", "9.9.9", "CD"); add_qc_note(sd, f[5], "usable", "ok", "9.9.9", "CD")
check("the newest line for a file wins", { add_qc_note(sd, f[3], "exclude", "x", "9.9.9", "AB"); add_qc_note(sd, f[3], "usable", "ok again", "9.9.9", "AB"); latest_verdict(sd, f[3])$reason == "ok again" })
check("a verdict is current when the file has not been processed since", !latest_verdict(sd, f[1])$stale)
later <- Sys.time() + 3600; for (k in 2:5) Sys.setFileTime(file.path(meta, paste0("ms", k, ".out"), paste0(f[1], ".RData")), later)
check("a verdict goes stale when THAT file is processed again", latest_verdict(sd, f[1])$stale)
check("...and other files' verdicts do not", !latest_verdict(sd, f[2])$stale && !latest_verdict(sd, f[5])$stale)
for (k in 2:5) Sys.setFileTime(file.path(meta, paste0("ms", k, ".out"), paste0(f[1], ".RData")), t0)
check("an invalid verdict is refused", inherits(try(add_qc_note(sd, f[1], "fine", "x", "9"), silent = TRUE), "try-error"))

section("Summary draft")
d <- draft_summary(sd, f[1], "9.9.9")
check("a usable file gets a draft", d$ok)
check("the draft header says draft and research use only", grepl("DRAFT", d$header[1]) && grepl("research use only", d$header[1]))
check("every number in the draft is listed with a file and column", nrow(d$sources) >= 20 && all(nzchar(d$sources$file)) && all(nzchar(d$sources$column)))
check("numbers match the files (calibration, mean acceleration, IS, IV)", all(c("0.004", "48.2", "0.612", "1.071") %in% d$sources$number))
check("what the files cannot tell is left blank", length(gregexpr("[FILL IN:", d$text, fixed = TRUE)[[1]]) >= 4 && grepl("[FILL IN: one sentence", d$sections[["8. Overall reading"]], fixed = TRUE))
check("initials are not in the draft", !grepl("\\bAB\\b|\\bCD\\b", d$text))
d2 <- draft_summary(sd, f[2], "9.9.9")
check("activity only: sleep and rhythm are not reportable", d2$ok && grepl("Not reportable", d2$sections[["5. Sleep"]]) && grepl("Not reportable", d2$sections[["6. Rhythm"]]) && !any(c("0.5", "1.2") %in% d2$sources$number))
d3 <- draft_summary(sd, f[3], "9.9.9")
check("deviating nights are listed with a blank, not an explanation", grepl("Nights that deviate", d3$sections[["5. Sleep"]]) && grepl("FILL IN: what the diary or ward log says", d3$sections[["5. Sleep"]]))
check("zero bouted MVPA adds the compare-M5 sentence", grepl("compare M5", d3$sections[["3. Activity volume"]]))
check("a diary changes the sleep sentence", grepl("diary guided", d3$sections[["5. Sleep"]]) && grepl("No sleep diary", d$sections[["5. Sleep"]]))
check("an excluded file gets no draft", !draft_summary(sd, f[4], "9.9.9")$ok)
check("a file with no verdict gets no draft", { writeLines("raw", file.path(sd, "raw", "Z_1.csv")); !draft_summary(sd, "Z_1.csv", "9.9.9")$ok })
unlink(file.path(sd, "raw", "Z_1.csv"))

section("Datasheet")
cand <- datasheet_candidates(sd)
check("excluded files cannot go in; the others can", !cand$eligible[cand$id == "D004"] && all(cand$eligible[cand$id != "D004"]))
ds <- build_datasheet(sd, cand$file[cand$eligible]); x <- ds$data; rownames(x) <- x$participant
check("one row per chosen participant", nrow(x) == 4)
check("values are copied from the person-level files", x["A001", "calibration_error_g"] == 0.004 && x["A001", "mean_accel_waking_mg"] == 48.2 && x["A001", "inactive_min"] == 731.6 && x["A001", "m5_mg"] == 80.5 && x["A001", "interdaily_stability"] == .612)
check("activity only: sleep and rhythm cells are blank, activity is not", all(is.na(x["B002", c("sleep_period_min", "sleep_efficiency", "interdaily_stability", "cosinor_r2")])) && x["B002", "inactive_min"] == 760 && grepl("activity only", x["B002", "notes"]))
check("each row shows the cut-points it was processed with", x["A001", "cutpoint_light_mg"] == "44.8" && x["E005", "cutpoint_light_mg"] == "18" && x["E005", "cutpoint_moderate_mg"] == "60")
check("a row with other cut-points takes its values from its own Part 5 file", x["E005", "mean_accel_waking_mg"] == 50)
check("rhythm is blank when cut-points differ from the last run", is.na(x["E005", "interdaily_stability"]) && grepl("rhythm blank", x["E005", "notes"]))
check("mixed cut-points raise a warning", any(grepl("different cut-points", ds$warnings)))
check("no warning when everyone shares cut-points", length(build_datasheet(sd, f[1:3])$warnings) == 0)
check("the diary column is filled", isTRUE(as.logical(x["C003", "sleep_diary_used"])) && !isTRUE(as.logical(x["A001", "sleep_diary_used"])))
check("initials are not in the datasheet", !"by" %in% names(x) && !any(grepl("^(AB|CD)$", unlist(x))))
check("choosing groups limits the columns", !"sleep_period_min" %in% names(build_datasheet(sd, f[1], "Activity")$data))
check("the guide covers every column and starts with the research-use line", all(names(x) %in% ds$guide$column) && grepl("Research use only", ds$guide$meaning[1]))
p1 <- save_datasheet(sd, ds, "9.9.9", methods_paragraph(sd, "9.9.9")); p2 <- save_datasheet(sd, ds, "9.9.9")
check("saving writes the sheet, guide, README and methods draft", all(file.exists(p1, sub("\\.csv$", "_column_guide.csv", p1), sub("\\.csv$", "_README.txt", p1), sub("\\.csv$", "_methods_DRAFT.txt", p1))))
check("saving twice never overwrites", p1 != p2 && file.exists(p2))
check("the saved file reads back with blanks as empty cells", { y <- utils::read.csv(p1); nrow(y) == 4 && is.na(y$sleep_period_min[y$participant == "B002"]) })

section("Progress and Home")
pr <- run_progress(sd, c(f, "F006_2026-01-01.csv"), t0 - 60, TRUE)
check("each step counts only this run's files, and names the missing one", all(sapply(pr, `[[`, "done") == 5) && all(sapply(pr, function(p) identical(p$missing, "F006_2026-01-01.csv"))))
pr <- run_progress(sd, f, t0 + 60, FALSE)
check("with reprocess off, earlier files count as already done", all(sapply(pr, `[[`, "already") == 5) && all(sapply(pr, `[[`, "done") == 0))
pr <- run_progress(sd, f, t0 + 60, TRUE)
check("with reprocess on, earlier files count as not done yet", all(sapply(pr, `[[`, "done") == 0) && all(sapply(pr, `[[`, "already") == 0))
lg <- tempfile(); writeLines(c("x", " Part 1 ", "y", " Part 2 ", " Part 3 "), lg)
check("the current step is read from the log", log_step(lg) == 3 && log_step(tempfile()) == 0)
writeLines(c(" Part 6 ", " Report part 2 "), lg); check("writing reports is step 7", log_step(lg) == 7)
ps <- participant_status(sd, c(f, "F006_2026-01-01.csv"), failed = "F006_2026-01-01.csv"); st <- setNames(sapply(ps, `[[`, "status"), sapply(ps, `[[`, "id"))
check("Home statuses: checked, excluded, could not be read", st[["A001"]] == "checked" && st[["D004"]] == "excluded" && st[["F006"]] == "unreadable")
check("Home: a file not yet processed is new, and one being processed says so", participant_status(sd, "F006_2026-01-01.csv")[[1]]$status == "new" && participant_status(sd, f[1], running = f[1])[[1]]$status == "processing")

section("Study settings and methods")
check("age group falls back to the last run, then to the default", study_age(sd, "paediatric") == "adult" && study_age(file.path(tempdir(), "nowhere"), "paediatric") == "paediatric")
set_study_age(sd, "senior"); check("a fixed age group is remembered", study_age(sd, "adult") == "senior" && study_age_is_set(sd))
study_log(sd, "test event", "AB"); check("the study log gets a dated line with initials", grepl("^2[0-9-]+ [0-9:]+ \\| test event \\| by AB$", readLines(file.path(sd, "ggir", "study_log.txt"))))
m <- methods_paragraph(sd, "9.9.9")
check("methods text states the cut-points, GGIR version and mixed sample rates", grepl("44.8, 100.6 and 428.8 mg", m$text) && grepl("GGIR version 3.3.8", m$text) && grepl("30 or 60 Hz", m$text))
check("methods text has blanks for what the app cannot know", length(gregexpr("[FILL IN:", m$text, fixed = TRUE)[[1]]) == 5)
check("every age group has a cut-point source sentence", all(names(AGE_GROUPS) %in% names(CUTPOINT_SOURCE)))
check("every datasheet column has a name, meaning and source", !anyDuplicated(DS_COLS$name) && all(nzchar(DS_COLS$meaning)) && all(DS_COLS$src %in% c("qc", "p2", "p5", "p6")))

section("Nights without a diary entry, and daytime sleep")
check("before a full night table exists, nothing is treated as a diary study", nrow(participant_nights(sd, f[5])$extra) == 0)
extra <- data.frame(ID = "E005", night = c(2, 3, 4), sleeponset = c(22.5, 13, 23), wakeup = c(30, 15.5, 30.5), SptDuration = c(7.5, 2.5, 7.5), WASO = c(1, .2, 1),
                    sleeponset_ts = c("22:30:00", "13:00:00", "23:00:00"), wakeup_ts = c("06:00:00", "15:30:00", "06:30:00"), calendar_date = c("2026-01-02", "2026-01-03", "2026-01-04"),
                    sleeplog_used = 0, filename = f[5], cleaningcode = c(1, 1, 5), acc_available = 1)
w(rbind(nights, extra), "QC/part4_nightsummary_sleep_full.csv")
pn <- participant_nights(sd, f[5])
check("nights without a diary entry are found in the full table, minus those GGIR rejects", nrow(pn$extra) == 2 && pn$decision == "" && nrow(pn$used) == 0)
q5 <- Filter(function(r) r$id == "E005", qc_table(sd))[[1]]
check("until decided, they are not counted and the user is asked to decide", q5$nights == 0 && any(grepl("no diary entry", q5$looks)))
check("until decided, the summary says sleep is not reportable yet", grepl("Not reportable yet", draft_summary(sd, f[5], "9")$sections[["5. Sleep"]]))
xs <- build_datasheet(sd, f[5])$data
check("until decided, sleep is blank in the datasheet with the reason", is.na(xs$sleep_period_min) && grepl("not yet accepted or dismissed", xs$notes))
set_nodiary_decision(sd, f[5], "dismiss", "AB")
check("dismissed: sleep stays blank and the summary says so", is.na(build_datasheet(sd, f[5])$data$sleep_period_min) && grepl("were dismissed", draft_summary(sd, f[5], "9")$sections[["5. Sleep"]]))
set_nodiary_decision(sd, f[5], "accept", "AB")
q5 <- Filter(function(r) r$id == "E005", qc_table(sd))[[1]]
check("accepted: the nights count, and the decision note goes", q5$nights == 2 && !any(grepl("no diary entry", q5$looks)) && q5$nodiary_decision == "accept")
check("a sleep period starting in the daytime is pointed out as a possible nap", any(grepl("starting at 13:00, in the daytime", q5$looks)))
xs <- build_datasheet(sd, f[5])$data
check("accepted: sleep is filled in the datasheet and the note says nights had no diary", xs$sleep_period_min == 465 && grepl("accepted by the user", xs$notes))
check("accepted: the summary says how many nights had no diary entry", grepl("2 of these nights had no diary entry", draft_summary(sd, f[5], "9")$sections[["5. Sleep"]]))
check("participants whose nights are all in the diary are not asked", nrow(participant_nights(sd, f[3])$extra) == 0 && !any(grepl("no diary entry", Filter(function(r) r$id == "C003", qc_table(sd))[[1]]$looks)))
for (k in 2:5) Sys.setFileTime(file.path(meta, paste0("ms", k, ".out"), paste0(f[5], ".RData")), Sys.time() + 3600)
check("the decision is asked again if the file is processed again", participant_nights(sd, f[5])$decision == "")
check("an evening onset is not called daytime sleep", !any(grepl("daytime", night_looks(nights[nights$ID == "A001", ]))))

section("Run state")
check("no run recorded means nothing to pick up", is.null(read_run_state(sd)))
writeLines("running", run_status_file(sd))
write_run_state(sd, list(pid = as.character(Sys.getpid()), start = as.POSIXct("2026-01-10 09:00:00"), log = "x.txt", overwrite = TRUE, label = "Study ADULT", by = "AB", files = f[1:2]))
st <- read_run_state(sd)
check("a recorded run is read back whole", st$pid == as.character(Sys.getpid()) && st$overwrite && identical(st$files, f[1:2]) && format(st$start, "%H:%M") == "09:00" && st$label == "Study ADULT")
check("a live process is seen as alive, a made-up one is not", pid_alive(st$pid) && !pid_alive("999999") && !pid_alive("") && !pid_alive("abc"))

section("Short recordings")
p6_full <- utils::read.csv(file.path(res, "part6_summary.csv"))
w(data.frame(ID = ids), "part6_summary.csv")                        # GGIR writes no IS/IV for a recording that is too short
d6 <- draft_summary(sd, f[2 + 1], "9")
check("no rhythm measures: the summary says so instead of leaving a gap", grepl("did not compute rhythm", d6$sections[["6. Rhythm"]]) && !grepl("stability was  and", d6$text))
check("no rhythm measures: the datasheet leaves rhythm blank", is.na(build_datasheet(sd, f[3])$data$interdaily_stability))
w(p6_full, "part6_summary.csv")

cat(sprintf("\n%d checks, %d failed\n", n, length(fails)))
if (length(fails)) { cat("FAILED:\n", paste0("  - ", fails, "\n"), sep = ""); quit(status = 1) }
