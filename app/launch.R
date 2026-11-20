# Started by "Run AutoG.bat". Uses only the bundled library -- never the
# internet, never packages from the user's own R installation.

app_dir <- dirname(normalizePath(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)))
.libPaths(.Library)
options(repos = NULL)

# First launch: install the pinned GGIR from the bundled source tarball.
# GGIR is pure R, so this needs no compiler and no internet.
tgz <- list.files(file.path(dirname(app_dir), "packages"), "^GGIR_.*\\.tar\\.gz$", full.names = TRUE)
want <- package_version(sub("^GGIR_(.*)\\.tar\\.gz$", "\\1", basename(tgz)))
have <- tryCatch(packageVersion("GGIR", lib.loc = .Library), error = function(e) NULL)
if (is.null(have) || have != want) {
  cat("First launch: installing GGIR", as.character(want), "(about a minute) ...\n")
  install.packages(tgz, lib = .Library, repos = NULL, type = "source", quiet = TRUE)
  stopifnot(packageVersion("GGIR", lib.loc = .Library) == want)
}

# Port 8765 so the address is always the same; another free port if taken.
port <- tryCatch({ s <- httpuv::startServer("127.0.0.1", 8765, list()); httpuv::stopServer(s); 8765L },
                 error = function(e) httpuv::randomPort())
cat(sprintf("Starting the app at http://127.0.0.1:%d - it opens in your browser.\n", port))
cat("Keep this window open while you work. To quit: close the browser tab, then this window.\n\n")
shiny::runApp(app_dir, host = "127.0.0.1", port = port, launch.browser = TRUE)
