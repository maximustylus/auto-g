#==============================================================================
# Version/QC steward tool: are the pipeline settings what we think they are?
#
#   Rscript tools/check_parity.R [path/to/reference_pipeline.R]
#   (Windows bundle:  R\bin\Rscript.exe tools\check_parity.R)
#
# 1. Prints a SETTINGS FINGERPRINT of app/ggir_run.R + app/settings.R (every
#    GGIR() argument, the cut-points, the timezone). Two copies of the app with
#    the same fingerprint process data identically.
# 2. If a reference script is found (optional: your own R script that calls GGIR()
#    directly, kept next to this folder as reference_pipeline.R), compares the two
#    GGIR() calls and the cut-point tables, and fails on any difference that
#    is not on the allow-list below.
#
# Exit status 0 = OK, 1 = mismatch. Uses base R only.
#==============================================================================

args <- commandArgs(FALSE)
here <- dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", args, value = TRUE)), fixed = TRUE)))
root <- dirname(here)
ref  <- commandArgs(TRUE)
ref  <- if (length(ref)) ref[1] else file.path(dirname(root), "reference_pipeline.R")

# Arguments that legitimately differ between the Mac script and the app worker
ALLOWED <- c("overwrite", "do.parallel", "maxNcores", "studyname")

find_call <- function(e, fn = "GGIR") {          # first call to fn(), any depth
  if (is.call(e) && identical(e[[1]], as.name(fn))) return(e)
  if (is.call(e) || is.expression(e) || is.list(e)) {
    for (i in seq_along(e)) {
      if (identical(e[[i]], quote(expr = ))) next    # empty argument, e.g. x[, 1]
      r <- find_call(e[[i]], fn); if (!is.null(r)) return(r)
    }
  }
  NULL
}
ggir_args <- function(file) {
  cl <- find_call(parse(file, keep.source = FALSE))
  if (is.null(cl)) stop("no GGIR() call in ", file)
  a <- as.list(cl)[-1]
  a <- vapply(a, function(x) paste(deparse(x, width.cutoff = 500), collapse = " "), "")
  a[order(names(a))]
}
top_value <- function(file, name) {              # evaluate `name <- <literal>` at top level
  for (e in parse(file, keep.source = FALSE))
    if (is.call(e) && as.character(e[[1]]) %in% c("<-", "=") && identical(e[[2]], as.name(name)))
      return(eval(e[[3]], baseenv()))
  NULL
}
tz_of <- function(file) { m <- regmatches(x <- readLines(file, warn = FALSE), regexpr('tz +<- +"[^"]+"', x)); sub('.*"([^"]+)"', "\\1", m[1]) }
cuts  <- function(ag) vapply(ag, function(g) sprintf("%g/%g/%g", g$lig, g$mod, g$vig), "")

run_f <- file.path(root, "app", "ggir_run.R"); set_f <- file.path(root, "app", "settings.R")
app   <- ggir_args(run_f)
app_cuts <- cuts(top_value(set_f, "AGE_GROUPS")); app_def <- top_value(set_f, "AGE_DEFAULT"); app_tz <- top_value(set_f, "TIMEZONE")

canon <- c(paste(names(app), app, sep = " = "), paste("cut", names(app_cuts), app_cuts), paste("default", names(app_def), app_def), paste("tz", app_tz))
tf <- tempfile(); writeLines(canon, tf, sep = "\n")
cat("SETTINGS FINGERPRINT  ", unname(tools::md5sum(tf)), "\n", sep = "")
cat("  GGIR() arguments: ", length(app), " | timezone: ", app_tz, "\n", sep = "")
for (n in names(app_cuts)) cat(sprintf("  %-11s light/moderate/vigorous = %s mg\n", n, app_cuts[[n]]))
have <- tryCatch(as.character(packageVersion("GGIR")), error = function(e) "not installed in this R")
cat("  GGIR in this R: ", have, "\n\n", sep = "")

if (!file.exists(ref)) {
  cat("Reference reference_pipeline.R not found (", ref, ") - fingerprint only.\n",
      "Compare the fingerprint with the one in CHANGELOG.md for this release.\n", sep = "")
  quit(status = 0)
}

mac <- ggir_args(ref); bad <- character()
for (n in setdiff(union(names(app), names(mac)), ALLOWED)) {
  a <- if (n %in% names(app)) app[[n]] else "<absent>"; m <- if (n %in% names(mac)) mac[[n]] else "<absent>"
  if (!identical(a, m)) bad <- c(bad, sprintf("  %-22s app: %s\n  %-22s mac: %s", n, a, "", m))
}
mac_cuts <- cuts(top_value(ref, "AGE_GROUPS"))
if (!identical(app_cuts, mac_cuts)) bad <- c(bad, "  cut-point tables differ (settings.R AGE_GROUPS vs reference_pipeline.R AGE_GROUPS)")
if (!identical(app_def, top_value(ref, "AGE_DEFAULT"))) bad <- c(bad, "  AGE_DEFAULT differs")
if (!identical(app_tz, tz_of(ref))) bad <- c(bad, sprintf("  timezone differs: app %s vs mac %s", app_tz, tz_of(ref)))

if (length(bad)) { cat("MISMATCH between app/ggir_run.R and", ref, "\n"); cat(bad, sep = "\n"); cat("\n"); quit(status = 1) }
cat("PARITY OK: app/ggir_run.R matches ", basename(ref), " (ignoring ", paste(ALLOWED, collapse = ", "), ").\n", sep = "")
