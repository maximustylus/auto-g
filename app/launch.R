# Starts AutoG. Two ways it is installed:
#  - The offline Windows bundle ("Run AutoG.bat"): uses only the bundled R
#    library, never the internet, and installs GGIR from packages/ on first start.
#  - A normal R installation on Windows, macOS or Linux ("Run AutoG.command",
#    "run-autog.sh", or Rscript app/launch.R) after running setup.R once.

app_dir <- dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)))
GGIR_PIN <- package_version("3.3.8")
tgz <- list.files(file.path(dirname(app_dir), "packages"), "^GGIR_.*\\.tar\\.gz$", full.names = TRUE)
bundled <- length(tgz) > 0 && file.exists(file.path(dirname(app_dir), "R", "bin"))

if (bundled) {
  .libPaths(.Library)
  options(repos = NULL)
  # First launch: install the pinned GGIR from the bundled source tarball.
  # GGIR is pure R, so this needs no compiler and no internet.
  want <- package_version(sub("^GGIR_(.*)\\.tar\\.gz$", "\\1", basename(tgz)))
  have <- tryCatch(packageVersion("GGIR", lib.loc = .Library), error = function(e) NULL)
  if (is.null(have) || have != want) {
    cat("First launch: installing GGIR", as.character(want), "(about a minute) ...\n")
    install.packages(tgz, lib = .Library, repos = NULL, type = "source", quiet = TRUE)
    stopifnot(packageVersion("GGIR", lib.loc = .Library) == want)
  }
} else {
  options(repos = NULL)                      # never install anything while running
  have <- tryCatch(packageVersion("GGIR"), error = function(e) NULL)
  missing <- c("shiny", "pdftools", "magick")[!vapply(c("shiny", "pdftools", "magick"), requireNamespace, TRUE, quietly = TRUE)]
  if (is.null(have) || have != GGIR_PIN || length(missing)) {
    cat("AutoG is not set up in this R yet.\n",
        if (is.null(have)) "  GGIR is not installed.\n" else if (have != GGIR_PIN) sprintf("  GGIR %s is installed; AutoG needs %s.\n", have, GGIR_PIN),
        if (length(missing)) sprintf("  Missing: %s.\n", paste(missing, collapse = ", ")),
        "Run this once, from the AutoG folder, with internet:\n    Rscript setup.R\n", sep = "")
    quit(status = 1)
  }
}

# Port 8765 so the address is always the same; another free port if taken.
port <- tryCatch({ s <- httpuv::startServer("127.0.0.1", 8765, list()); httpuv::stopServer(s); 8765L },
                 error = function(e) httpuv::randomPort())
cat(sprintf("Starting the app at http://127.0.0.1:%d - it opens in your browser.\n", port))
cat("Keep this window open while you work. To quit: close the browser tab, then this window.\n\n")
shiny::runApp(app_dir, host = "127.0.0.1", port = port, launch.browser = TRUE)
