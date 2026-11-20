# Writes a small, entirely INVENTED study (the same one tools/run_tests.R checks)
# into a data folder, so the screens can be shown or demonstrated without any
# participant data. GGIR is not run; there are no report images.
#     Rscript dev/make_demo_study.R <data folder>      e.g. /tmp/AutoG-demo
# WARNING: it deletes and rewrites <data folder>/ADULT. Never point it at real study data.
a <- commandArgs(TRUE); if (!length(a)) stop("usage: Rscript dev/make_demo_study.R <data folder>")
root <- normalizePath(file.path(dirname(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)), ".."))
source(file.path(root, "app", "settings.R")); source(file.path(root, "app", "results.R"))
#--- the made-up study --------------------------------------------------------
sd <- file.path(path.expand(a[1]), "ADULT"); unlink(sd, recursive = TRUE); res <- file.path(sd, "ggir", "output_raw", "results")
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
run_date <- format(Sys.time() - 7200, "%Y-%m-%d %H:%M")
cat(sprintf("run date      %s\nstudy         ADULT\nage group     adult\ncut-points    light 44.8 / moderate 100.6 / vigorous 428.8 mg (Adult (18-64 y) - Hildebrand 2014/2016)\nGGIR version  3.3.8\nsleep log     none (HDCZA only)\n", run_date),
    file = file.path(sd, "ggir", "run_settings.txt"))
meta <- file.path(sd, "ggir", "output_raw", "meta"); t0 <- Sys.time() - 3600
for (k in 1:6) { d <- file.path(meta, c("basic", paste0("ms", 2:6, ".out"))[k]); dir.create(d, recursive = TRUE)
  for (x in f) { m <- file.path(d, if (k == 1) paste0("meta_", x, ".RData") else if (k == 6) paste0(tools::file_path_sans_ext(x), "_T5A5.RData") else paste0(x, ".RData")); writeLines("", m); Sys.setFileTime(m, t0) } }
set_study_age(sd, "adult")
add_qc_note(sd, f[1], "usable", "nights grey, days coloured", "demo", "AB")
add_qc_note(sd, f[2], "usable for activity only", "green at night on two nights", "demo", "AB")
add_qc_note(sd, f[4], "exclude", "calibration flagged, one valid day", "demo", "CD")
cat("demo study written to", sd, "\n")
