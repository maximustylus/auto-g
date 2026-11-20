#==============================================================================
# AutoG -- GGIR worker (the GGIR call; keep in step with your reference script, if any)
#
# Started by the app as a separate Rscript process so the window stays
# responsive. All settings are fixed here and in settings.R; only the paths, the
# core count and the report composer are adapted. Keep the two in sync.
#
# Inputs (environment variables, set by app.R):
#   GGIR_ROOT       data root, e.g. D:/GGIR  -> <root>/<study>/{raw,ggir,reports}
#   GGIR_STUDY      a study code from STUDIES in settings.R
#   GGIR_AGE_GROUP  paediatric | adolescent | adult | senior
#   GGIR_CORES      worker processes for Part 1-2
#   GGIR_OVERWRITE  TRUE | FALSE
#   GGIR_STATUS     file this script writes "done" / "failed: ..." into
#   GGIR_PIDFILE    file this script writes its process id into (for Stop)
#==============================================================================

app_dir <- dirname(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE))
source(file.path(app_dir, "settings.R"))

status_file <- Sys.getenv("GGIR_STATUS")
set_status  <- function(x) if (nzchar(status_file)) writeLines(x, status_file)
if (nzchar(Sys.getenv("GGIR_PIDFILE"))) writeLines(as.character(Sys.getpid()), Sys.getenv("GGIR_PIDFILE"))

tryCatch({
  suppressPackageStartupMessages(library(GGIR))

  root      <- Sys.getenv("GGIR_ROOT")
  study     <- Sys.getenv("GGIR_STUDY", "ADULT")
  age_group <- Sys.getenv("GGIR_AGE_GROUP", AGE_DEFAULT[[study]])
  cores     <- as.integer(Sys.getenv("GGIR_CORES", "2"))
  overwrite <- as.logical(Sys.getenv("GGIR_OVERWRITE", "FALSE"))

  problem <- check_root(root)
  if (!is.null(problem)) stop(problem)
  stopifnot(study %in% names(STUDIES), age_group %in% names(AGE_GROUPS))

  datadir   <- file.path(root, study, "raw")
  outputdir <- file.path(root, study, "ggir")
  tz        <- TIMEZONE                    # app/settings.R

  sleeplog_path <- file.path(root, study, paste0("sleeplog_", study, ".csv"))
  sleeplog <- if (file.exists(sleeplog_path)) sleeplog_path else NULL

  cp <- AGE_GROUPS[[age_group]]
  cp_lig <- cp$lig; cp_mod <- cp$mod; cp_vig <- cp$vig

  cat(sprintf("GGIR %s | study %s | age group %s | cut-points (mg): light %g, moderate %g, vigorous %g\n",
              packageVersion("GGIR"), study, age_group, cp_lig, cp_mod, cp_vig))
  cat("files:", length(list.files(datadir, "\\.(csv|gt3x)$", ignore.case = TRUE)),
      "| sleep log:", if (is.null(sleeplog)) "NONE (HDCZA only)" else sleeplog,
      "| cores:", cores, "\n\n")

  dir.create(outputdir, showWarnings = FALSE, recursive = TRUE)
  cat(sprintf("run date      %s\nstudy         %s\nage group     %s\ncut-points    %s\nGGIR version  %s\nsleep log     %s\nrun from      Windows app (%s)\n",
              format(Sys.time(), "%Y-%m-%d %H:%M"), study, age_group,
              sprintf("light %g / moderate %g / vigorous %g mg (%s)", cp_lig, cp_mod, cp_vig, cp$label),
              as.character(packageVersion("GGIR")),
              if (is.null(sleeplog)) "none (HDCZA only)" else sleeplog,
              Sys.info()[["nodename"]]),
      file = file.path(outputdir, "run_settings.txt"))

  # GGIR draws every file's report picture in one loop at the very end. A file
  # it cannot draw (for example a recording with no complete night) stops that
  # loop, and with it the pictures for every file after it - although all the
  # result tables are already written. So an error here is caught, and the
  # pictures are then drawn one file at a time further down.
  run_started <- Sys.time()
  ggir_problem <- tryCatch({ GGIR(
    # General
    mode        = 1:6,
    datadir     = datadir,
    outputdir   = outputdir,
    studyname   = study,
    f0 = 1, f1 = 0,
    idloc       = 2,
    desiredtz   = tz,
    overwrite   = overwrite,
    do.parallel = cores > 1,
    maxNcores   = cores,

    # Part 1
    windowsizes = c(5, 900, 3600),
    do.enmo    = TRUE,
    do.anglez  = TRUE,
    acc.metric = "ENMO",
    do.cal     = TRUE,
    chunksize  = 1,
    printsummary = TRUE,

    # Part 2
    strategy      = 1,
    hrs.del.start = 0,
    hrs.del.end   = 0,
    maxdur        = 0,
    includedaycrit = 16,
    qwindow       = c(0, 24),
    mvpathreshold = cp_mod,
    qlevels  = c(1320/1440, 1380/1440, 1430/1440, 1435/1440),
    ilevels  = seq(0, 400, by = 50),
    iglevels = TRUE,

    # Part 3
    timethreshold  = 5,
    anglethreshold = 5,
    ignorenonwear  = TRUE,

    # Part 4
    HASPT.algo      = "HDCZA",
    loglocation     = sleeplog,
    colid           = 1,
    relyonguider    = FALSE,
    sleepwindowType = if (is.null(sleeplog)) "SPT" else "TimeInBed",
    do.visual       = !is.null(sleeplog),
    excludefirstlast = TRUE,
    includenightcrit = 16,
    def.noc.sleep   = 1,
    outliers.only   = FALSE,
    criterror       = 4,
    nnights         = 14,

    # Part 5
    threshold.lig = cp_lig,
    threshold.mod = cp_mod,
    threshold.vig = cp_vig,
    boutcriter      = 0.8,
    boutcriter.in   = 0.9,
    boutcriter.lig  = 0.8,
    boutcriter.mvpa = 0.8,
    boutdur.in   = c(1, 5, 10),
    boutdur.lig  = c(1, 5, 10),
    boutdur.mvpa = c(1, 5, 10),
    timewindow   = c("MM", "WW"),
    includedaycrit.part5    = 2/3,
    minimum_MM_length.part5 = 16,
    save_ms5rawlevels = TRUE,

    # Part 6
    part6CR = TRUE,

    # Reports
    do.report        = c(2, 4, 5, 6),
    visualreport     = TRUE,
    old_visualreport = TRUE,
    dofirstpage      = TRUE,
    viewingwindow    = 1
  ); NULL }, error = function(e) conditionMessage(e))

  if (!is.null(ggir_problem)) {
    p2 <- file.path(outputdir, "output_raw", "results", "part2_summary.csv")
    if (!file.exists(p2) || file.mtime(p2) < run_started) stop(ggir_problem)      # failed before the tables: a real failure
    cat("\nGGIR stopped while drawing the report pictures:", ggir_problem,
        "\nThe result tables are complete. Drawing the pictures one file at a time...\n")
    md <- file.path(outputdir, "output_raw"); files <- list.files(file.path(md, "meta", "ms2.out"))
    for (i in seq_along(files)) {                                                # same arguments GGIR() passes to g.plot5
      ok <- tryCatch({ g.plot5(metadatadir = md, dofirstpage = TRUE, viewingwindow = 1, f0 = i, f1 = i, overwrite = TRUE,
                               metric = "ENMO", desiredtz = tz, threshold.lig = cp_lig, threshold.mod = cp_mod, threshold.vig = cp_vig,
                               includedaycrit = 16, includenightcrit = 16, verbose = FALSE); TRUE }, error = function(e) FALSE)
      if (!ok) {
        try(grDevices::graphics.off(), silent = TRUE)
        unlink(file.path(md, "results", "file summary reports", paste0("old_report_", sub("\\.RData$", "", files[i]), ".pdf")))
        cat("No report picture for", sub("\\.RData$", "", files[i]), "- GGIR could not draw it (usually no complete night in the recording).\n")
      }
    }
  }

  cat("\n--- composing report images ---\n")
  source(file.path(app_dir, "compose_reports.R"))
  compose_reports(file.path(root, study))

  set_status("done")
}, error = function(e) {
  cat("\nERROR:", conditionMessage(e), "\n")
  set_status(paste("failed:", conditionMessage(e)))
  quit(status = 1)
})
