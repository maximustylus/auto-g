# Reads GGIR's output for the app's Quality check, Progress and Summary tabs.
# Pure functions, no Shiny, no GGIR: everything here only READS result files
# (the one exception is add_qc_note, which appends the user's verdict).
# Thresholds and wording rules: docs/PIPELINE.md. Nothing here changes a result.

QC_CAL_MAX  <- 0.01   # g, documented pass limit for cal.error.end
NIGHT_MIN_H <- 5      # "worth a look" limits, not pass/fail
NIGHT_MAX_H <- 11
WASO_MAX_H  <- 2
DAY_SLEEP_FROM <- 8   # a sleep period that STARTS between these clock hours is
DAY_SLEEP_TO   <- 18  # pointed out as possible daytime sleep (a nap, or a still wrist)
VERDICTS    <- c("usable", "usable for activity only", "exclude")
BLANK       <- function(what) paste0("[FILL IN: ", what, "]")

results_dir <- function(studydir) file.path(studydir, "ggir", "output_raw", "results")
file_id     <- function(filename) sub("_.*$", "", basename(filename))        # idloc = 2
read_csv    <- function(f) if (file.exists(f)) tryCatch(utils::read.csv(f, stringsAsFactors = FALSE), error = function(e) NULL)
fmt         <- function(x, d = 1) formatC(round(as.numeric(x), d), format = "f", digits = d)
nice_date   <- function(x) trimws(format(as.Date(x), "%e %b %Y"))
rng         <- function(x, d = 1) if (length(unique(fmt(x, d))) == 1) fmt(x[1], d) else paste(fmt(min(x), d), "to", fmt(max(x), d))

# run_settings.txt is written by ggir_run.R as "key<padding to 14>value"
read_run_settings <- function(studydir) {
  f <- file.path(studydir, "ggir", "run_settings.txt")
  if (!file.exists(f)) return(NULL)
  l <- readLines(f, warn = FALSE); l <- l[nzchar(l)]
  out <- as.list(setNames(trimws(substring(l, 15)), trimws(substr(l, 1, 14))))
  cp <- regmatches(out[["cut-points"]], gregexpr("[0-9]+\\.?[0-9]*", out[["cut-points"]]))[[1]]
  if (length(cp) >= 3) out$cp <- setNames(cp[1:3], c("lig", "mod", "vig"))
  out
}

# The Part 5 file-name suffix encodes the cut-points; pick the one this run wrote.
part5_file <- function(studydir, kind = "personsummary", window = "WW") {
  rs <- read_run_settings(studydir); if (is.null(rs$cp)) return(NULL)
  f <- file.path(results_dir(studydir), sprintf("part5_%s_%s_L%sM%sV%s_T5A5.csv", kind, window, rs$cp[["lig"]], rs$cp[["mod"]], rs$cp[["vig"]]))
  if (file.exists(f)) f else NULL
}

#--- QC notes: one line per file per verdict, newest last ---------------------
qc_notes_path <- function(studydir) file.path(studydir, "ggir", "QC_notes.md")
read_qc_notes <- function(studydir) {
  empty <- data.frame(date = character(), version = character(), file = character(), verdict = character(), reason = character(), by = character())
  f <- qc_notes_path(studydir); if (!file.exists(f)) return(empty)
  l <- grep("^- ", readLines(f, warn = FALSE), value = TRUE)
  p <- strsplit(sub("^- ", "", l), " | ", fixed = TRUE); p <- p[lengths(p) >= 4]
  if (!length(p)) return(empty)
  # optional trailing field "by XX" (initials, self-declared); lines written before 0.10.0 have none
  by <- sapply(p, function(x) if (length(x) > 5 && grepl("^by [A-Z]{2,4}$", x[length(x)])) sub("^by ", "", x[length(x)]) else "")
  data.frame(date = sapply(p, `[`, 1), version = sapply(p, `[`, 2), file = sapply(p, `[`, 3), verdict = sapply(p, `[`, 4),
             reason = mapply(function(x, b) paste(x[if (nzchar(b)) -c(1:4, length(x)) else -(1:4)], collapse = " | "), p, by), by = by, stringsAsFactors = FALSE)
}
add_qc_note <- function(studydir, file, verdict, reason, version, by = "") {
  stopifnot(verdict %in% VERDICTS)
  f <- qc_notes_path(studydir)
  if (!file.exists(f)) writeLines(c("# QC notes", "", "One line per file per verdict: date | app version | file | verdict | reason | by initials. The newest line for a file counts.",
                                    "Initials are self-declared in AutoG, not verified.", ""), f)
  reason <- gsub("[\r\n|]+", " ", trimws(reason))
  cat(sprintf("- %s | app %s | %s | %s | %s%s\n", format(Sys.time(), "%Y-%m-%d %H:%M"), version, file, verdict, reason, if (nzchar(by)) paste0(" | by ", by) else ""), file = f, append = TRUE)
}
# stale = the verdict is older than THIS file's results. Judged per file, from
# the time GGIR last wrote the file's own milestone: a run that only adds new
# participants (overwrite off) leaves earlier files, and their verdicts, alone.
results_time <- function(studydir, file) {
  ms <- c(milestone(studydir, 5, file), milestone(studydir, 4, file), milestone(studydir, 2, file))
  ms <- ms[!is.na(ms)]
  if (length(ms)) format(max(file.mtime(ms)), "%Y-%m-%d %H:%M") else read_run_settings(studydir)[["run date"]]
}
latest_verdict <- function(studydir, file) {
  n <- read_qc_notes(studydir); n <- n[n$file == file, , drop = FALSE]
  if (!nrow(n)) return(NULL)
  v <- as.list(n[nrow(n), ]); made <- results_time(studydir, file)
  v$stale <- !is.null(made) && isTRUE(v$date < made)
  v
}

#--- Quality check: one row per processed file --------------------------------
#--- Nights, and nights without a diary entry ----------------------------------
# When a study has a sleep diary file, GGIR's CLEANED night table keeps only the
# nights that have a diary entry; the others stay in the FULL table. AutoG shows
# those nights and lets the user accept them as GGIR found them, or dismiss them
# (a decision of the original deployment). The choice is per file, recorded with initials, and
# asked again if the file is processed again.
nodiary_path <- function(studydir) file.path(studydir, "ggir", "nodiary_nights.md")
set_nodiary_decision <- function(studydir, file, decision, by = "") {
  stopifnot(decision %in% c("accept", "dismiss")); f <- nodiary_path(studydir)
  if (!file.exists(f)) writeLines(c("# Nights without a diary entry", "", "date | file | accept or dismiss | by initials (self-declared). The newest line for a file counts.", ""), f)
  cat(sprintf("- %s | %s | %s%s\n", format(Sys.time(), "%Y-%m-%d %H:%M"), file, decision, if (nzchar(by)) paste0(" | by ", by) else ""), file = f, append = TRUE)
}
nodiary_decision <- function(studydir, file) {
  f <- nodiary_path(studydir); if (!file.exists(f)) return("")
  p <- strsplit(sub("^- ", "", grep("^- ", readLines(f, warn = FALSE), value = TRUE)), " | ", fixed = TRUE)
  p <- Filter(function(x) length(x) >= 3 && x[2] == file, p); if (!length(p)) return("")
  last <- p[[length(p)]]; made <- results_time(studydir, file)
  if (!is.null(made) && isTRUE(last[1] < made)) "" else last[3]          # decided before the file was reprocessed: ask again
}
# Returns list(used, extra, decision): `used` = the nights AutoG reports for this
# file; `extra` = nights GGIR found that have no diary entry (only in a diary study).
participant_nights <- function(studydir, file) {
  res <- results_dir(studydir); id <- file_id(file)
  clean <- read_csv(file.path(res, "part4_nightsummary_sleep_cleaned.csv")); full <- read_csv(file.path(res, "QC", "part4_nightsummary_sleep_full.csv"))
  mine <- function(d) if (is.null(d)) NULL else d[d$ID == id, , drop = FALSE]
  used <- mine(clean); extra <- NULL; decision <- ""
  diary_study <- !is.null(full) && any(full$sleeplog_used %in% c(TRUE, "TRUE", 1))
  if (diary_study) {
    fm <- mine(full)
    extra <- fm[!(fm$sleeplog_used %in% c(TRUE, "TRUE", 1)) & fm$cleaningcode <= 1 & fm$acc_available %in% c(1, "1", TRUE) &
                !(fm$night %in% if (is.null(used)) integer() else used$night), , drop = FALSE]     # same cut GGIR applies when there is no diary
    if (nrow(extra)) { decision <- nodiary_decision(studydir, file)
      if (decision == "accept") { used <- rbind(used, extra[, names(used), drop = FALSE]); used <- used[order(used$night), , drop = FALSE] } }
  }
  list(used = used, extra = if (is.null(extra)) used[0, , drop = FALSE] else extra, decision = decision)
}

night_looks <- function(nights) {
  if (is.null(nights) || !nrow(nights)) return(character())
  out <- character()
  for (i in seq_len(nrow(nights))) {
    n <- nights[i, ]; d <- nice_date(n$calendar_date)
    if (n$SptDuration < NIGHT_MIN_H) out <- c(out, sprintf("Night of %s: sleep period %s hours (shorter than %g hours).", d, fmt(n$SptDuration), NIGHT_MIN_H))
    if (n$SptDuration > NIGHT_MAX_H) out <- c(out, sprintf("Night of %s: sleep period %s hours (longer than %g hours).", d, fmt(n$SptDuration), NIGHT_MAX_H))
    if (n$WASO > WASO_MAX_H)         out <- c(out, sprintf("Night of %s: %s hours awake within the sleep period (more than %g hours).", d, fmt(n$WASO), WASO_MAX_H))
    h <- suppressWarnings(as.numeric(substr(n$sleeponset_ts, 1, 2)))
    if (!is.na(h) && h >= DAY_SLEEP_FROM && h < DAY_SLEEP_TO) out <- c(out, sprintf("%s: a sleep period starting at %s, in the daytime. It may be a nap, or a still wrist read as sleep.", d, substr(n$sleeponset_ts, 1, 5)))
  }
  out
}

qc_table <- function(studydir) {
  res <- results_dir(studydir)
  q <- read_csv(file.path(res, "QC", "data_quality_report.csv"))
  if (is.null(q) || !nrow(q)) return(NULL)
  p2 <- read_csv(file.path(res, "part2_summary.csv"))
  p4 <- read_csv(file.path(res, "part4_nightsummary_sleep_cleaned.csv"))
  rows <- lapply(seq_len(nrow(q)), function(i) {
    f <- q$filename[i]; id <- file_id(f)
    d2 <- if (!is.null(p2)) p2[p2$filename == f, , drop = FALSE]
    pn <- participant_nights(studydir, f); n4 <- pn$used
    img <- file.path(studydir, "reports", paste0(id, "_GGIR_report.jpg"))
    v <- latest_verdict(studydir, f)
    looks <- c(if (isTRUE(q$file.corrupt[i])) "GGIR marked this file as corrupt.",
               if (isTRUE(q$file.too.short[i])) "GGIR marked this file as too short.",
               if (is.na(q$cal.error.end[i])) "Calibration could not be done.",
               if (is.null(d2) || !nrow(d2)) "No Part 2 summary for this file.",
               if (nrow(pn$extra) && pn$decision == "") sprintf("%d night(s) have no diary entry. Decide below whether to accept them as GGIR found them, or dismiss them.", nrow(pn$extra)),
               night_looks(n4))
    list(file = f, id = id, cal_error = q$cal.error.end[i],
         recorded_days = if (!is.null(d2) && nrow(d2)) d2$meas_dur_dys[1] else NA,
         valid_days = if (!is.null(d2) && nrow(d2)) d2$N.valid.weekdays..WD.[1] + d2$N.valid.weekend.days..WE.[1] else NA,
         nights = if (!is.null(n4)) nrow(n4) else NA, looks = looks, nodiary = pn$extra, nodiary_decision = pn$decision,
         image = if (file.exists(img)) img else NA,
         verdict = if (is.null(v)) NA else v$verdict, reason = if (is.null(v)) "" else v$reason, verdict_date = if (is.null(v)) NA else v$date, by = if (is.null(v)) "" else v$by,
         stale = !is.null(v) && v$stale)
  })
  rows
}

#--- Progress: GGIR works part by part across all files -----------------------
PARTS <- c("Read files and calibrate", "Wear time and daily activity", "Rest periods",
           "Sleep", "Day and night combined", "Daily rhythm")

# Milestone file GGIR writes when `part` is finished for raw file `f` (NA if not there yet)
milestone <- function(studydir, part, f) {
  meta <- file.path(studydir, "ggir", "output_raw", "meta")
  if (part == 1) p <- file.path(meta, "basic", paste0("meta_", f, ".RData"))
  else if (part <= 5) p <- file.path(meta, paste0("ms", part, ".out"), paste0(f, ".RData"))
  else {
    hit <- list.files(file.path(meta, "ms6.out"), full.names = TRUE)
    hit <- hit[startsWith(basename(hit), paste0(tools::file_path_sans_ext(f), "_"))]
    p <- if (length(hit)) hit[1] else NA_character_
  }
  if (!is.na(p) && file.exists(p)) p else NA_character_
}

# Counts only milestones belonging to THIS run's raw files. A milestone older
# than the run start is "already done" (kept when overwrite is off).
run_progress <- function(studydir, rawfiles, start, overwrite) {
  lapply(seq_along(PARTS), function(k) {
    ms <- vapply(rawfiles, function(f) milestone(studydir, k, f), "")
    fresh <- !is.na(ms) & file.mtime(ms) >= start
    old   <- !is.na(ms) & !fresh & !overwrite
    list(part = k, label = PARTS[k], done = sum(fresh), already = sum(old), total = length(rawfiles),
         missing = rawfiles[!(fresh | old)])
  })
}

#--- Summary: draft interpretation, numbers read from the CSVs ----------------
# Returns list(ok, message) or list(ok = TRUE, sections, sources, text).
# Every number passes through num(), which records file and column.
draft_summary <- function(studydir, file, version) {
  id <- file_id(file); res <- results_dir(studydir)
  v <- latest_verdict(studydir, file)
  if (is.null(v)) return(list(ok = FALSE, message = "No verdict recorded for this file yet. Look at the report image and record a verdict in the Quality check tab first."))
  if (v$verdict == "exclude") return(list(ok = FALSE, message = paste0("This file's verdict is \"exclude\" (", v$date, "), so no summary is drafted.")))
  if (v$stale) return(list(ok = FALSE, message = paste0("The verdict for this file (", v$verdict, ", ", v$date, ") was recorded before this file was last processed. Look at the new report image and record the verdict again in the Quality check tab.")))
  activity_only <- v$verdict == "usable for activity only"

  rs <- read_run_settings(studydir)
  q  <- read_csv(file.path(res, "QC", "data_quality_report.csv")); q <- q[q$filename == file, , drop = FALSE]
  p2 <- read_csv(file.path(res, "part2_summary.csv"));             p2 <- p2[p2$filename == file, , drop = FALSE]
  pn <- participant_nights(studydir, file); p4 <- pn$used; n_nd <- nrow(pn$extra)
  f5p <- part5_file(studydir, "personsummary"); f5d <- part5_file(studydir, "daysummary")
  p5 <- if (!is.null(f5p)) read_csv(f5p); if (!is.null(p5)) p5 <- p5[p5$ID == id, , drop = FALSE]
  d5 <- if (!is.null(f5d)) read_csv(f5d); if (!is.null(d5)) d5 <- d5[d5$ID == id, , drop = FALSE]
  p6 <- read_csv(file.path(res, "part6_summary.csv")); if (!is.null(p6)) p6 <- p6[p6$ID == id, , drop = FALSE]
  if (is.null(rs) || !nrow(q) || !nrow(p2)) return(list(ok = FALSE, message = "Results for this file are incomplete. Start processing for it first."))
  have <- function(d) !is.null(d) && nrow(d) > 0

  src <- list()
  num <- function(text, file, column) { src[[length(src) + 1]] <<- c(number = text, file = file, column = column); text }
  F2 <- "part2_summary.csv"; F4 <- "part4_nightsummary_sleep_cleaned.csv"; F6 <- "part6_summary.csv"; FQ <- "QC/data_quality_report.csv"
  F5P <- if (!is.null(f5p)) basename(f5p) else NA; F5D <- if (!is.null(f5d)) basename(f5d) else NA
  mod <- rs$cp[["mod"]]; lig <- rs$cp[["lig"]]
  not_reportable <- "Not reportable: this file's verdict is \"usable for activity only\"."

  who <- sprintf("Age group: %s. Setting: %s. Device: %s, sampled at %s Hz, worn on the %s. Recording started %s and lasted %s days.",
                 rs[["age group"]], BLANK("setting, e.g. community or ward"),
                 num(p2$device[1], F2, "device"), num(as.character(p2$samplefreq[1]), F2, "samplefreq"), BLANK("which wrist"),
                 num(nice_date(substr(p2$start_time[1], 1, 10)), F2, "start_time"), num(as.character(p2$meas_dur_dys[1]), F2, "meas_dur_dys"))

  quality <- sprintf("Calibration error after correction was %s g. Valid days: %s weekdays and %s weekend days.",
                     num(fmt(q$cal.error.end[1], 3), FQ, "cal.error.end"),
                     num(as.character(p2$N.valid.weekdays..WD.[1]), F2, "N.valid.weekdays..WD."), num(as.character(p2$N.valid.weekend.days..WE.[1]), F2, "N.valid.weekend.days..WE."))
  if (have(p5)) quality <- paste(quality, sprintf("%s waking days were kept for the day and night analysis.", num(as.character(p5$Nvaliddays[1]), F5P, "Nvaliddays")))
  if (have(d5)) quality <- paste(quality, sprintf("Non-wear during the waking day was %s percent.", num(rng(d5$nonwear_perc_day, 1), F5D, "nonwear_perc_day (lowest to highest day)")))

  activity <- if (!have(p5) || !have(d5)) "Day and night results (Part 5) were not found for this file." else {
    bouts <- d5$dur_day_MVPA_bts_10_min
    a <- sprintf("Mean acceleration over the waking day was %s mg (days ranged %s mg). Moderate-to-vigorous activity in bouts of 10 minutes or more (moderate threshold %s mg) was %s minutes on the %d waking days, in date order. Averaged over days, the acceleration reached during the most active 5 minutes of the day (M5) was %s mg.",
                 num(fmt(p5$ACC_day_mg_pla[1]), F5P, "ACC_day_mg_pla"), num(rng(d5$ACC_day_mg), F5D, "ACC_day_mg (lowest to highest day)"), mod,
                 num(paste(fmt(bouts), collapse = ", "), F5D, "dur_day_MVPA_bts_10_min"), nrow(d5),
                 num(fmt(p2$AD_M5_ENMO_mg_0.24hr[1]), F2, "AD_M5_ENMO_mg_0.24hr"))
    if (all(bouts == 0)) a <- paste(a, sprintf("No bout of 10 minutes or more was recorded; compare M5 with the moderate threshold of %s mg before reading this as no moderate activity.", mod))
    a
  }

  timeuse <- if (!have(p5)) "Day and night results (Part 5) were not found for this file." else
    sprintf("On an average waking day of %s minutes, %s minutes were inactive and %s minutes were light activity. The most active 60 minutes of the day averaged %s mg (M60). The intensity gradient was %s.",
            num(fmt(p5$dur_day_min_pla[1], 0), F5P, "dur_day_min_pla"), num(fmt(p5$dur_day_total_IN_min_pla[1], 0), F5P, "dur_day_total_IN_min_pla"),
            num(fmt(p5$dur_day_total_LIG_min_pla[1], 0), F5P, "dur_day_total_LIG_min_pla"),
            num(fmt(p5$quantile_mostactive60min_mg_pla[1]), F5P, "quantile_mostactive60min_mg_pla"),
            num(fmt(p2$AD_ig_gradient_ENMO_0.24hr[1], 2), F2, "AD_ig_gradient_ENMO_0.24hr"))

  sleep <- if (activity_only) not_reportable
    else if (n_nd && pn$decision == "") sprintf("Not reportable yet: %d night(s) have no diary entry. Accept or dismiss them in the Quality check tab.", n_nd)
    else if (n_nd && pn$decision == "dismiss" && !have(p4)) sprintf("Sleep is not reported: the %d night(s) GGIR found had no diary entry and were dismissed.", n_nd)
    else if (!have(p4)) "No nights remained after cleaning." else {
    o <- p4[order(p4$sleeponset), ]; w <- p4[order(p4$wakeup), ]; hm <- function(x) substr(x, 1, 5)
    diary <- any(p4$sleeplog_used %in% c(TRUE, "TRUE", 1))
    s <- sprintf("%s nights remained after cleaning. Sleep onset ranged from %s to %s and waking from %s to %s. The sleep period lasted %s hours, with %s hours awake within it.",
                 num(as.character(nrow(p4)), F4, "number of rows"),
                 num(hm(o$sleeponset_ts[1]), F4, "sleeponset_ts (earliest)"), num(hm(o$sleeponset_ts[nrow(o)]), F4, "sleeponset_ts (latest)"),
                 num(hm(w$wakeup_ts[1]), F4, "wakeup_ts (earliest)"), num(hm(w$wakeup_ts[nrow(w)]), F4, "wakeup_ts (latest)"),
                 num(rng(p4$SptDuration), F4, "SptDuration (shortest to longest night)"), num(rng(p4$WASO), F4, "WASO (lowest to highest night)"))
    if (have(p5) && !is.null(p5$sleep_efficiency_after_onset_pla))
      s <- paste(s, sprintf("Sleep efficiency after onset averaged %s.", num(fmt(p5$sleep_efficiency_after_onset_pla[1], 2), F5P, "sleep_efficiency_after_onset_pla")))
    s <- paste(s, if (diary) "A sleep diary guided the sleep window." else "No sleep diary was available: sleep timing comes from the accelerometer alone, and efficiency is sleep divided by the sleep period, not by time in bed.")
    if (n_nd && pn$decision == "accept") s <- paste(s, sprintf("%d of these nights had no diary entry and were accepted as the accelerometer found them.", n_nd))
    if (n_nd && pn$decision == "dismiss") s <- paste(s, sprintf("%d further night(s) had no diary entry and were dismissed.", n_nd))
    looks <- night_looks(p4)
    if (length(looks)) s <- paste0(s, "\nNights that deviate:\n", paste0("- ", looks, " ", BLANK("what the diary or ward log says about this night"), collapse = "\n"))
    s
  }

  rhythm <- if (activity_only) not_reportable else if (!have(p6)) "Rhythm results (Part 6) were not found for this file." else
    sprintf("Interdaily stability was %s and intradaily variability %s. The cosinor fit explained %s of the variance (R squared). Interdaily stability and intradaily variability depend on the light cut-point (%s mg here), so they are not comparable with values from another age group.",
            num(fmt(p6$IS[1], 3), F6, "IS"), num(fmt(p6$IV[1], 3), F6, "IV"), num(fmt(p6$cosinor_R2[1], 2), F6, "cosinor_R2"), lig)

  sections <- list(
    "1. Who and what" = who, "2. Data quality" = quality, "3. Activity volume" = activity, "4. Time use" = timeuse,
    "5. Sleep" = sleep, "6. Rhythm" = rhythm,
    "7. Caveats" = BLANK("caveats, and what needs the diary or ward log"),
    "8. Overall reading" = BLANK("one sentence, stating what the data show without claiming cause"))

  header <- c("DRAFT - research use only - not for clinical decisions.",
              sprintf("Participant %s, one recording (%s). Verdict in QC notes: %s (%s).", id, file, v$verdict, v$date),
              sprintf("Drafted by AutoG app %s on %s from GGIR %s output, %s cut-points (%s).", version, format(Sys.Date()), rs[["GGIR version"]], rs[["age group"]], rs[["cut-points"]]),
              "Numbers are read from the result files. Complete every [FILL IN] and edit the wording before use.")
  text <- paste(c(header, "", unlist(lapply(names(sections), function(n) c(n, sections[[n]], "")))), collapse = "\n")
  list(ok = TRUE, id = id, header = header, sections = sections, sources = as.data.frame(do.call(rbind, src), stringsAsFactors = FALSE), text = text)
}

# Which step GGIR has reached, from the " Part k " headers it prints:
# 1-6 = that part, 7 = writing reports, 0 = not started yet.
log_step <- function(logfile) {
  if (is.null(logfile) || !file.exists(logfile)) return(0L)
  l <- readLines(logfile, warn = FALSE)
  if (any(grepl("^ *(Report part [0-9]|Generate visual reports)", l))) return(7L)
  k <- regmatches(l, regexpr("^ *Part [1-6] *$", l))
  if (length(k)) as.integer(gsub("\\D", "", k[length(k)])) else 0L
}

#--- Study datasheet: one row per participant recording -----------------------
# Every value is copied from a GGIR person-level CSV (src = which file,
# col = which column); nothing is recalculated. Groups are what the user ticks.
DS_COLS <- read.csv(text = '
group,name,meaning,unit,src,col
Data quality,calibration_error_g,Calibration error after correction (under 0.01 is the pass limit),g,qc,cal.error.end
Data quality,days_recorded,Length of the recording,days,p2,meas_dur_dys
Data quality,valid_weekdays,Weekdays with enough wear time,days,p2,N.valid.weekdays..WD.
Data quality,valid_weekend_days,Weekend days with enough wear time,days,p2,N.valid.weekend.days..WE.
Data quality,waking_days_analysed,Waking days kept for the day and night analysis,days,p5,Nvaliddays
Activity,mean_accel_24h_mg,Mean acceleration over the whole day and night,mg,p2,AD_mean_ENMO_mg_0.24hr
Activity,mean_accel_waking_mg,Mean acceleration over the waking day,mg,p5,ACC_day_mg_pla
Activity,waking_day_min,Length of the waking day,minutes per day,p5,dur_day_min_pla
Activity,inactive_min,Time inactive in the waking day,minutes per day,p5,dur_day_total_IN_min_pla
Activity,light_min,Time in light activity,minutes per day,p5,dur_day_total_LIG_min_pla
Activity,moderate_min,Time in moderate activity,minutes per day,p5,dur_day_total_MOD_min_pla
Activity,vigorous_min,Time in vigorous activity,minutes per day,p5,dur_day_total_VIG_min_pla
Activity,mvpa_bouts10_min,Moderate-to-vigorous activity in bouts of 10 minutes or more,minutes per day,p5,dur_day_MVPA_bts_10_min_pla
Activity,m60_mg,Mean acceleration of the most active 60 minutes of the day (M60),mg,p5,quantile_mostactive60min_mg_pla
Activity,m5_mg,Acceleration reached during the most active 5 minutes of the day (M5),mg,p2,AD_M5_ENMO_mg_0.24hr
Activity,intensity_gradient,Intensity gradient (more negative = less time at higher intensities),none,p2,AD_ig_gradient_ENMO_0.24hr
Sleep,sleep_period_min,Length of the sleep period (onset to waking),minutes per night,p5,dur_spt_min_pla
Sleep,sleep_in_period_min,Sleep within the sleep period,minutes per night,p5,dur_spt_sleep_min_pla
Sleep,sleep_efficiency,Sleep divided by the sleep period (not by time in bed unless a diary was used),proportion,p5,sleep_efficiency_after_onset_pla
Sleep,sleep_onset_clock_h,Average sleep onset as hours on the clock (22.5 = 22:30),hours,p5,sleeponset_pla
Sleep,wake_clock_h,Average waking as hours on the clock (values above 24 are the next morning: 30.2 = 06:12),hours,p5,wakeup_pla
Daily rhythm,interdaily_stability,Interdaily stability IS (depends on the light cut-point),0 to 1,p6,IS
Daily rhythm,intradaily_variability,Intradaily variability IV (depends on the light cut-point),none,p6,IV
Daily rhythm,cosinor_r2,Share of variance explained by the cosinor fit,proportion,p6,cosinor_R2
', stringsAsFactors = FALSE, strip.white = TRUE)
DS_GROUPS <- unique(DS_COLS$group)
DS_ID_COLS <- data.frame(stringsAsFactors = FALSE,
  name = c("participant", "file", "study", "recording_start", "age_group_last_run", "cutpoint_light_mg", "cutpoint_moderate_mg", "cutpoint_vigorous_mg",
           "ggir_version", "verdict", "verdict_date", "sleep_diary_used", "notes"),
  meaning = c("Coded participant ID", "Raw file the row comes from", "Study folder", "Date the recording started",
              "Age group chosen for the last run of this study folder", "Light cut-point this row was processed with (adolescents use the adult values: no validated wrist set exists)", "Moderate cut-point this row was processed with",
              "Vigorous cut-point this row was processed with (for seniors the adult value is carried over: none is published)", "GGIR version that produced the row", "Quality verdict recorded in AutoG", "When the verdict was recorded",
              "Whether a sleep diary guided the sleep window", "Why any cell in the row is blank"))

# Part 5 person files are named by cut-points; a participant processed under
# another age group sits in a different file. Returns one row per (file, cut-points).
part5_index <- function(studydir) {
  fs <- list.files(results_dir(studydir), "^part5_personsummary_WW_L.*_T5A5\\.csv$", full.names = TRUE)
  do.call(rbind, lapply(fs, function(f) {
    d <- read_csv(f); if (is.null(d) || !nrow(d)) return(NULL)
    cp <- regmatches(basename(f), regexec("_L([0-9.]+)M([0-9.]+)V([0-9.]+)_", basename(f)))[[1]]
    data.frame(filename = d$filename, path = f, lig = cp[2], mod = cp[3], vig = cp[4], stringsAsFactors = FALSE)
  }))
}

# Which processed files may go into a datasheet, and why not.
datasheet_candidates <- function(studydir) {
  rows <- qc_table(studydir); if (is.null(rows)) return(NULL)
  do.call(rbind, lapply(rows, function(r) {
    why <- if (is.na(r$verdict)) "not checked yet" else if (r$stale) "processed again since it was checked - check again" else if (r$verdict == "exclude") "excluded" else ""
    data.frame(file = r$file, id = r$id, verdict = if (is.na(r$verdict)) "" else r$verdict, eligible = !nzchar(why), why = why, stringsAsFactors = FALSE)
  }))
}

# Returns list(data, guide, warnings).
build_datasheet <- function(studydir, files, groups = DS_GROUPS) {
  res <- results_dir(studydir); rs <- read_run_settings(studydir); idx <- part5_index(studydir)
  qc <- read_csv(file.path(res, "QC", "data_quality_report.csv")); p2 <- read_csv(file.path(res, "part2_summary.csv"))
  p4 <- read_csv(file.path(res, "part4_nightsummary_sleep_cleaned.csv")); p6 <- read_csv(file.path(res, "part6_summary.csv"))
  cols <- DS_COLS[DS_COLS$group %in% groups, ]
  warn <- character()
  pick <- function(d, key, value, col) { if (is.null(d) || !col %in% names(d)) return(NA); v <- d[d[[key]] == value, col]; if (length(v)) v[1] else NA }

  rows <- lapply(files, function(f) {
    id <- file_id(f); v <- latest_verdict(studydir, f); notes <- character()
    mine <- if (!is.null(idx)) idx[idx$filename == f, , drop = FALSE]
    if (is.null(mine) || !nrow(mine)) { p5 <- NULL; cp <- c(NA, NA, NA); notes <- c(notes, "no day and night results (Part 5) for this file")
    } else {
      if (nrow(mine) > 1) {   # processed under more than one age group: take the last run's
        cur <- mine[mine$lig == rs$cp[["lig"]] & mine$mod == rs$cp[["mod"]] & mine$vig == rs$cp[["vig"]], , drop = FALSE]
        mine <- if (nrow(cur)) cur[1, ] else mine[1, ]
        notes <- c(notes, "processed with more than one set of cut-points; the row uses the set shown")
      }
      p5 <- read_csv(mine$path); cp <- c(mine$lig, mine$mod, mine$vig)
    }
    same_as_last <- !anyNA(cp) && !is.null(rs$cp) && all(cp == rs$cp)
    activity_only <- v$verdict == "usable for activity only"
    if (activity_only) notes <- c(notes, "sleep and rhythm blank: verdict is usable for activity only")
    pn <- participant_nights(studydir, f); n_nd <- nrow(pn$extra)
    sleep_blank <- n_nd > 0 && pn$decision != "accept"
    if (n_nd && !activity_only && "Sleep" %in% groups) notes <- c(notes, switch(if (nzchar(pn$decision)) pn$decision else "pending",
      pending = sprintf("sleep blank: %d night(s) without a diary entry not yet accepted or dismissed", n_nd),
      dismiss = sprintf("sleep blank: %d night(s) without a diary entry were dismissed", n_nd),
      accept  = sprintf("sleep includes %d night(s) without a diary entry, accepted by the user", n_nd)))
    if (!same_as_last && "Daily rhythm" %in% groups) notes <- c(notes, "rhythm blank: cut-points differ from the last run, so IS and IV may not match them")
    val <- function(src, col) switch(src,
      qc = pick(qc, "filename", f, col), p2 = pick(p2, "filename", f, col),
      p5 = pick(p5, "filename", f, col), p6 = pick(p6, "ID", id, col))
    out <- list(participant = id, file = f, study = basename(studydir),
                recording_start = substr(as.character(pick(p2, "filename", f, "start_time")), 1, 10),
                age_group_last_run = rs[["age group"]], cutpoint_light_mg = cp[1], cutpoint_moderate_mg = cp[2], cutpoint_vigorous_mg = cp[3],
                ggir_version = as.character(pick(p5, "filename", f, "GGIRversion")), verdict = v$verdict, verdict_date = v$date,
                sleep_diary_used = if (!is.null(p4) && any(p4$ID == id)) any(p4$sleeplog_used[p4$ID == id] %in% c(TRUE, "TRUE", 1)) else NA)
    for (i in seq_len(nrow(cols))) {
      g <- cols$group[i]
      blank <- (activity_only && g %in% c("Sleep", "Daily rhythm")) || (g == "Daily rhythm" && !same_as_last) || (g == "Sleep" && sleep_blank)
      out[[cols$name[i]]] <- if (blank) NA else val(cols$src[i], cols$col[i])
    }
    out$notes <- paste(notes, collapse = "; ")
    as.data.frame(out, stringsAsFactors = FALSE)
  })
  data <- do.call(rbind, rows)
  data <- data[, c(setdiff(names(data), "notes"), "notes")]
  cps <- unique(paste(data$cutpoint_light_mg, data$cutpoint_moderate_mg, data$cutpoint_vigorous_mg, sep = " / "))
  if (length(cps) > 1) warn <- c(warn, paste0("These participants were processed with different cut-points (", paste(cps, collapse = "; "), " mg). Activity minutes are not comparable between them."))
  if (length(unique(stats::na.omit(data$ggir_version))) > 1) warn <- c(warn, "These participants were processed with different GGIR versions. Reprocess before combining.")
  src_file <- c(qc = "QC/data_quality_report.csv", p2 = "part2_summary.csv", p5 = "part5_personsummary_WW_L..M..V.._T5A5.csv", p6 = "part6_summary.csv")
  about <- c("Research use only. Not for decisions about an individual. Coded IDs only.",
             "One row per recording. Every value is copied from a GGIR result file; nothing is recalculated.",
             "Interdaily stability and intradaily variability depend on the light cut-point: do not compare them between age groups.",
             "Without a sleep diary, sleep efficiency is sleep divided by the sleep period, not by time in bed.")
  guide <- rbind(
    data.frame(column = "(read first)", meaning = about, unit = "", group = "About", source_file = "", source_column = "", stringsAsFactors = FALSE),
    data.frame(column = DS_ID_COLS$name, meaning = DS_ID_COLS$meaning, unit = "", group = "Identity", source_file = "AutoG", source_column = "", stringsAsFactors = FALSE),
    data.frame(column = cols$name, meaning = cols$meaning, unit = cols$unit, group = cols$group, source_file = unname(src_file[cols$src]), source_column = cols$col, stringsAsFactors = FALSE))
  list(data = data, guide = guide, warnings = warn)
}

# Writes the datasheet and its column guide into <study>/datasheet/. Never overwrites.
save_datasheet <- function(studydir, ds, version, methods = NULL) {
  dir <- file.path(studydir, "datasheet"); dir.create(dir, showWarnings = FALSE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M")
  base <- file.path(dir, paste0(basename(studydir), "_study_datasheet_", stamp))
  if (file.exists(paste0(base, ".csv"))) base <- paste0(base, format(Sys.time(), "%S"))
  utils::write.csv(ds$data, paste0(base, ".csv"), row.names = FALSE, na = "")
  utils::write.csv(ds$guide, paste0(base, "_column_guide.csv"), row.names = FALSE, na = "")
  writeLines(c(sprintf("Study datasheet for %s, made %s with AutoG %s.", basename(studydir), format(Sys.time(), "%Y-%m-%d %H:%M"), version),
               sprintf("%d participant row(s). Research use only. Coded IDs only.", nrow(ds$data)),
               "Every value is copied from GGIR's result files; the column guide says which file and column.",
               "A blank cell is explained in the row's notes column.", if (length(ds$warnings)) c("", "Warnings when it was made:", paste("-", ds$warnings))),
             paste0(base, "_README.txt"))
  if (!is.null(methods)) writeLines(c("DRAFT methods paragraph - complete every [FILL IN], check the references, edit before use.", "", methods$text, "", "References", paste("-", methods$references)),
                                    paste0(base, "_methods_DRAFT.txt"))
  paste0(base, ".csv")
}

#--- Study settings and log ---------------------------------------------------
# The age group sets the cut-points, so it is fixed once per study folder in
# <study>/autog_study.txt and changed only on purpose (app: Advanced).
study_file <- function(studydir) file.path(studydir, "autog_study.txt")
study_age <- function(studydir, default) {
  f <- study_file(studydir)
  if (file.exists(f)) { a <- sub("^age_group=", "", grep("^age_group=", readLines(f, warn = FALSE), value = TRUE)); if (length(a)) return(a[1]) }
  rs <- read_run_settings(studydir)
  if (!is.null(rs[["age group"]])) rs[["age group"]] else default
}
study_age_is_set <- function(studydir) file.exists(study_file(studydir)) || !is.null(read_run_settings(studydir))
set_study_age <- function(studydir, age) writeLines(c("# AutoG study settings. Change the age group inside AutoG (Advanced), not here.", paste0("age_group=", age)), study_file(studydir))
study_log <- function(studydir, event, by = "") {
  d <- file.path(studydir, "ggir"); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  cat(sprintf("%s | %s%s\n", format(Sys.time(), "%Y-%m-%d %H:%M"), event, if (nzchar(by)) paste0(" | by ", by) else ""), file = file.path(d, "study_log.txt"), append = TRUE)
}

#--- Home: where each raw file is in the workflow ------------------------------
# A workflow status, never a judgement of the participant. `failed` = files the
# last run in this session could not get through.
participant_status <- function(studydir, rawfiles, running = character(), failed = character()) {
  lapply(rawfiles, function(f) {
    done <- !is.na(milestone(studydir, 5, f)); v <- if (done) latest_verdict(studydir, f)
    img <- file.path(studydir, "reports", paste0(file_id(f), "_GGIR_report.jpg"))
    # "short": GGIR read the file (step 2 done) but could not make day-and-night
    # results from it - too little data. It will not get further by trying again.
    short <- !done && !is.na(milestone(studydir, 2, f)); if (short) v <- latest_verdict(studydir, f)
    status <- if (f %in% running) "processing" else if (short && !is.null(v) && v$verdict == "exclude") "excluded" else if (short) "short"
              else if (!done && f %in% failed) "unreadable" else if (!done) "new"
              else if (is.null(v) || v$stale) "check" else if (v$verdict == "exclude") "excluded" else "checked"
    list(file = f, id = file_id(f), status = status, verdict = if (is.null(v)) NA else v$verdict, image = file.exists(img))
  })
}

#--- Methods paragraph for a paper, from this study's own settings -------------
# Wording follows app/ggir_run.R. If a GGIR() argument changes there, change
# the sentence here too (docs/PIPELINE.md lists the settled decisions).
CUTPOINT_SOURCE <- c(
  paediatric = "Hildebrand et al., 2014, 2017; children aged 7 to 11 years, ActiGraph, non-dominant wrist",
  adult      = "Hildebrand et al., 2014, 2017; adults, ActiGraph, non-dominant wrist",
  adolescent = "the adult values of Hildebrand et al., 2014, 2017, applied because no validated ActiGraph wrist ENMO cut-points exist for adolescents",
  senior     = "Migueles et al., 2021, for light and moderate; no vigorous cut-point is published for older adults, so the adult value was carried over and vigorous time is not interpreted")
METHODS_REFERENCES <- c(
  "Hildebrand M, et al. (2014). Age group comparability of raw accelerometer output from wrist- and hip-worn monitors. Med Sci Sports Exerc. doi:10.1249/mss.0000000000000289",
  "Hildebrand M, et al. (2017). Evaluation of raw acceleration sedentary thresholds in children and adults. Scand J Med Sci Sports. doi:10.1111/sms.12795",
  "Migueles JH, et al. (2019). GGIR: a research community-driven open source R package for generating physical activity and sleep outcomes from multi-day raw accelerometer data. J Meas Phys Behav.",
  "Migueles JH, et al. (2021). Calibration and cross-validation of accelerometer cut-points to classify sedentary time and physical activity from hip and non-dominant and dominant wrists in older adults. Sensors. doi:10.3390/s21103326",
  "Rowlands AV, et al. (2018). Beyond cut points: accelerometer metrics that capture the physical activity profile. Med Sci Sports Exerc.",
  "van Hees VT, et al. (2013). Separating movement and gravity components in an acceleration signal and implications for the assessment of human daily physical activity. PLoS ONE.",
  "van Hees VT, et al. (2014). Autocalibration of accelerometer data for free-living physical activity assessment using local gravity and temperature. J Appl Physiol.",
  "van Hees VT, et al. (2015). A novel, open access method to assess sleep duration using a wrist-worn accelerometer. PLoS ONE.",
  "van Hees VT, et al. (2018). Estimating sleep parameters using an accelerometer without sleep diary. Sci Rep.",
  "GGIR itself: cite the version used, doi:10.5281/zenodo.1051064")

methods_paragraph <- function(studydir, version) {
  rs <- read_run_settings(studydir); if (is.null(rs) || is.null(rs$cp)) return(NULL)
  p2 <- read_csv(file.path(results_dir(studydir), "part2_summary.csv")); p4 <- read_csv(file.path(results_dir(studydir), "part4_nightsummary_sleep_cleaned.csv"))
  hz <- if (!is.null(p2)) sort(unique(p2$samplefreq)) else NULL
  rate <- if (!length(hz)) BLANK("sample rate") else if (length(hz) == 1) paste(hz, "Hz") else paste0(paste(hz, collapse = " or "), " Hz (devices were not all set to the same rate)")
  diary <- !is.null(p4) && any(p4$sleeplog_used %in% c(TRUE, "TRUE", 1))
  ag <- rs[["age group"]]; src <- if (ag %in% names(CUTPOINT_SOURCE)) CUTPOINT_SOURCE[[ag]] else BLANK("source of the cut-points")
  text <- paste0(
    "Participants wore a ", BLANK("device model, e.g. ActiGraph wGT3X-BT"), " on the ", BLANK("which wrist"), " for ", BLANK("number of days"),
    " days, recording raw tri-axial acceleration at ", rate, ". ", BLANK("Idle Sleep Mode was on / was off"), ". ",
    "Raw files were processed offline with AutoG ", version, ", which runs the R package GGIR version ", rs[["GGIR version"]], " (Migueles et al., 2019). ",
    "The signal was auto-calibrated against local gravity (van Hees et al., 2014) and summarised as the Euclidean norm minus one g (ENMO; van Hees et al., 2013) in 5-second epochs. ",
    "Non-wear was detected with GGIR's default method (60-minute windows moving in 15-minute steps) and replaced using GGIR's default imputation. Days with at least 16 hours of wear were treated as valid. ",
    "Sleep was identified as sustained inactivity (no change in arm angle of more than 5 degrees for at least 5 minutes; van Hees et al., 2015) within the sleep period time window estimated by the HDCZA algorithm (van Hees et al., 2018)",
    if (diary) ", with a sleep diary guiding the search for that window" else "; no sleep diary was used, so sleep efficiency is sleep divided by the sleep period and not by time in bed", ". ",
    "The first and last nights of each recording were excluded. ",
    "Time spent inactive and in light, moderate and vigorous activity during the waking day was classified with ENMO cut-points of ", rs$cp[["lig"]], ", ", rs$cp[["mod"]], " and ", rs$cp[["vig"]], " mg (", src, "). ",
    "Moderate-to-vigorous activity was also summarised in bouts of at least 1, 5 and 10 minutes, in which at least 80% of the time was above the moderate cut-point. ",
    "Outcomes that do not depend on cut-points were mean acceleration, the acceleration of the most active 60 and 5 minutes of the day (M60, M5) and the intensity gradient (Rowlands et al., 2018). ",
    "The rest-activity rhythm was described with interdaily stability, intradaily variability and a cosinor model; interdaily stability and intradaily variability depend on the light cut-point and were not compared between age groups. ",
    "Times were interpreted in the ", TIMEZONE, " time zone. ",
    "Before inclusion, each recording was checked against its report image and its calibration error (accepted under ", QC_CAL_MAX, " g) by a trained user, who recorded it as usable, usable for activity only, or excluded. ",
    BLANK("number of recordings excluded and why"), ".")
  list(text = text, references = METHODS_REFERENCES,
       note = "Draft generated from this study's settings. Complete every [FILL IN], check each reference against the paper, and edit before use.")
}

#--- A run's state lives in the study folder, not in the app's memory -----------
# <study>/ggir/autog_run.txt (what was started) and autog_run_status.txt
# (running / done / failed: ...). So a restarted app, a second browser tab or a
# second copy of AutoG pointed at the same study all see the same run, and a
# worker that died (laptop slept, was switched off) is noticed.
run_state_file  <- function(studydir) file.path(studydir, "ggir", "autog_run.txt")
run_status_file <- function(studydir) file.path(studydir, "ggir", "autog_run_status.txt")
write_run_state <- function(studydir, st) writeLines(c(
  paste0("pid=", st$pid), paste0("start=", format(st$start, "%Y-%m-%d %H:%M:%S")), paste0("log=", st$log),
  paste0("overwrite=", st$overwrite), paste0("label=", st$label), paste0("by=", st$by), paste0("files=", paste(st$files, collapse = ";"))), run_state_file(studydir))
read_run_state <- function(studydir) {
  f <- run_state_file(studydir); if (!file.exists(f) || !file.exists(run_status_file(studydir))) return(NULL)
  l <- readLines(f, warn = FALSE); v <- as.list(setNames(sub("^[^=]*=", "", l), sub("=.*$", "", l)))
  list(pid = v$pid, start = as.POSIXct(v$start), log = v$log, overwrite = identical(v$overwrite, "TRUE"), label = v$label, by = v$by,
       files = if (nzchar(v$files)) strsplit(v$files, ";", fixed = TRUE)[[1]] else character(), status = run_status_file(studydir), studydir = studydir)
}
pid_alive <- function(pid) {
  if (is.null(pid) || !nzchar(pid) || !grepl("^[0-9]+$", pid)) return(FALSE)
  if (.Platform$OS.type == "windows") any(grepl(paste0("\\b", pid, "\\b"), suppressWarnings(system2("tasklist", c("/FI", shQuote(paste("PID eq", pid)), "/NH"), stdout = TRUE, stderr = FALSE))))
  else suppressWarnings(system2("kill", c("-0", pid), stdout = FALSE, stderr = FALSE)) == 0
}
