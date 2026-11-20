# One-time setup of AutoG in a normal R installation (Windows, macOS or Linux).
#     Rscript setup.R
# Needs R 4.3 or later and internet. Installs AutoG's R packages into your user
# library and GGIR at the pinned version 3.3-8 (results differ between GGIR
# versions), then runs AutoG's automated checks.
#
# The offline Windows bundle does NOT need this: it is built by build_bundle.R
# and carries everything it needs.
#
# Linux needs these system libraries first (Debian/Ubuntu names):
#     sudo apt-get install libpoppler-cpp-dev libmagick++-dev libcurl4-openssl-dev libssl-dev
GGIR_PIN <- "3.3-8"
if (getRversion() < "4.3") stop("AutoG needs R 4.3 or later; this is R ", getRversion())
here <- dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)))
if (!length(here) || !file.exists(file.path(here, "app", "app.R"))) stop("Run setup.R from the AutoG folder: Rscript setup.R")

lib <- Sys.getenv("R_LIBS_USER"); if (nzchar(lib)) { dir.create(lib, recursive = TRUE, showWarnings = FALSE); .libPaths(c(lib, .libPaths())) }
repo <- getOption("repos"); if (is.null(repo) || identical(unname(repo["CRAN"]), "@CRAN@")) options(repos = c(CRAN = "https://cloud.r-project.org"))

# GGIR's own dependencies (from its DESCRIPTION) and what AutoG adds
ggir_deps <- c("data.table", "foreach", "doParallel", "signal", "zoo", "unisensR", "ineq", "psych", "irr", "lubridate",
               "GGIRread", "ActCR", "read.gt3x", "arrow")
autog_deps <- c("shiny", "pdftools", "magick", "jsonlite")
need <- setdiff(c(ggir_deps, autog_deps), rownames(installed.packages()))
if (length(need)) { cat("Installing:", paste(need, collapse = ", "), "\n"); install.packages(need) }

have <- tryCatch(as.character(packageVersion("GGIR")), error = function(e) "")
if (!identical(have, gsub("-", ".", GGIR_PIN))) {
  cat("Installing GGIR", GGIR_PIN, "(pinned) ...\n")
  url <- sprintf("https://cran.r-project.org/src/contrib/Archive/GGIR/GGIR_%s.tar.gz", GGIR_PIN)
  tgz <- file.path(tempdir(), basename(url)); download.file(url, tgz, mode = "wb", quiet = TRUE)
  install.packages(tgz, repos = NULL, type = "source")
}
stopifnot(identical(as.character(packageVersion("GGIR")), gsub("-", ".", GGIR_PIN)))
for (p in c(ggir_deps, autog_deps)) if (!requireNamespace(p, quietly = TRUE)) stop("Package ", p, " did not install. See the messages above.")

cat("\nRunning AutoG's automated checks ...\n")
st <- system2(file.path(R.home("bin"), "Rscript"), shQuote(file.path(here, "tools", "run_tests.R")), stdout = TRUE)
cat(tail(st, 1), "\n")
cat("\nAutoG is set up. Start it with",
    switch(Sys.info()[["sysname"]], Darwin = "a double-click on 'Run AutoG.command'", Windows = "Rscript app/launch.R", "./run-autog.sh"),
    "\n(or, on any system: Rscript app/launch.R)\n")
