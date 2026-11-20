#==============================================================================
# Build the offline Windows bundle of the AutoG app -- run on the Mac:
#     Rscript build_bundle.R
#
# Produces  ~/AutoG-build/AutoG/   (copy that folder to the Windows PC)
#     R\                portable Windows R + every package as Windows binaries
#     app\              Shiny app, GGIR worker, report composer
#     packages\         GGIR source tarball (pure R) -- installed on first launch
#     docs\ .claude\ tools\ templates\ CLAUDE.md HANDOVER.md   handover pack
#     Run AutoG.bat      double-click to start
#
# Needs internet (here, on the Mac only) and `brew install innoextract`.
# The Windows PC never needs internet.
#==============================================================================

R_WIN_VERSION <- "4.5.3"          # same minor series as the Mac (4.5.x)
GGIR_VERSION  <- "3.3-8"          # pinned: same as the Mac pipeline
EXTRA_PKGS    <- c("shiny", "pdftools", "magick")

cran   <- "https://cran.r-project.org"
src    <- normalizePath(dirname(gsub("~+~", " ", sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)), fixed = TRUE)))
build  <- path.expand("~/AutoG-build")
bundle <- file.path(build, "AutoG")
dl     <- file.path(build, "downloads")
dir.create(dl, recursive = TRUE, showWarnings = FALSE)
options(timeout = 3600)

fetch <- function(url, dest) {
  if (!file.exists(dest)) { message("downloading ", basename(dest)); download.file(url, dest, mode = "wb", quiet = TRUE) }
  dest
}

#--- 1. Windows R, unpacked from the official installer ----------------------
unlink(bundle, recursive = TRUE)
dir.create(bundle)
exe <- fetch(sprintf("%s/bin/windows/base/old/%s/R-%s-win.exe", cran, R_WIN_VERSION, R_WIN_VERSION),
             file.path(dl, sprintf("R-%s-win.exe", R_WIN_VERSION)))
tmp <- file.path(build, "inno"); unlink(tmp, recursive = TRUE)
stopifnot(system2("innoextract", c("-s", "-d", shQuote(tmp), shQuote(exe))) == 0)
file.rename(file.path(tmp, "app"), file.path(bundle, "R"))
unlink(tmp, recursive = TRUE)
winlib <- file.path(bundle, "R", "library")
stopifnot(file.exists(file.path(bundle, "R", "bin", "Rscript.exe")))

#--- 2. GGIR source + dependency closure as Windows binaries -----------------
ggir_tgz <- fetch(sprintf("%s/src/contrib/Archive/GGIR/GGIR_%s.tar.gz", cran, GGIR_VERSION),
                  file.path(dl, sprintf("GGIR_%s.tar.gz", GGIR_VERSION)))
td <- tempfile(); untar(ggir_tgz, files = "GGIR/DESCRIPTION", exdir = td)
desc <- read.dcf(file.path(td, "GGIR", "DESCRIPTION"))
ggir_deps <- unlist(tools:::.extract_dependency_package_names(paste(desc[, intersect(c("Depends", "Imports"), colnames(desc))], collapse = ",")))

rminor  <- sub("\\.[0-9]+$", "", R_WIN_VERSION)
contrib <- sprintf("%s/bin/windows/contrib/%s", cran, rminor)
db      <- available.packages(contriburl = contrib, type = "win.binary")
shipped <- list.files(winlib)                                   # base + recommended
need    <- unique(c(ggir_deps, EXTRA_PKGS))
need    <- unique(c(need, unlist(tools::package_dependencies(need, db = db, recursive = TRUE,
                                                             which = c("Depends", "Imports", "LinkingTo")))))
need    <- setdiff(need, c(shipped, "R", "GGIR"))
missing <- setdiff(need, rownames(db))
if (length(missing)) stop("no Windows binary on CRAN for: ", paste(missing, collapse = ", "))

message(length(need), " packages to bundle")
# Package versions are locked (packages.lock) so that a rebuild ships the same
# binaries as the last tested bundle. CRAN keeps only the current Windows
# binary, so a locked version must still be in the download cache; if it is
# not, the current one is taken and reported as drift.
lockfile <- file.path(src, "packages.lock")
lock <- if (file.exists(lockfile)) { l <- read.table(lockfile, comment.char = "#", col.names = c("pkg", "ver"), colClasses = "character"); setNames(l$ver, l$pkg) } else character()
cached <- function(p) if (p %in% names(lock)) file.path(dl, sprintf("%s_%s.zip", p, lock[[p]])) else NA_character_
zipfor <- vapply(need, cached, "")
todo   <- need[is.na(zipfor) | !file.exists(zipfor)]
if (length(todo)) {
  got <- download.packages(todo, destdir = dl, contriburl = contrib, type = "win.binary", available = db, quiet = TRUE)
  zipfor[got[, 1]] <- got[, 2]
  message("NOT from the lock (new or drifted): ", paste(basename(got[, 2]), collapse = ", "))
}
for (z in zipfor) unzip(z, exdir = winlib)
stopifnot(all(need %in% list.files(winlib)))
shipped_ver <- vapply(need, function(p) read.dcf(file.path(winlib, p, "DESCRIPTION"), "Version")[1], "")
writeLines(c("# Windows binary package versions shipped in the bundle (name version).",
             "# build_bundle.R uses these from its download cache; delete a line to take CRAN's current version.",
             paste(sort(need), shipped_ver[sort(need)])), lockfile)

#--- 3. App files -------------------------------------------------------------
dir.create(file.path(bundle, "packages"))
file.copy(ggir_tgz, file.path(bundle, "packages"))
file.copy(file.path(src, "app"), bundle, recursive = TRUE)
for (f in c("Run AutoG.bat", "README.txt")) file.copy(file.path(src, f), bundle)

# Handover pack for the session working on the Windows laptop: manuals,
# sub-agents and skills (.claude), the parity tool, templates. build_bundle.R
# itself goes along for reference only -- it cannot run on the laptop.
# HANDOVER.md is git-ignored (it holds the state of real studies); a fresh
# checkout ships the empty template instead.
if (!file.exists(file.path(src, "HANDOVER.md"))) file.copy(file.path(src, "HANDOVER.template.md"), file.path(src, "HANDOVER.md"))
for (f in c("CLAUDE.md", "HANDOVER.md", "CHANGELOG.md", "VERSION", "build_bundle.R", "LICENSE", "NOTICE"))
  stopifnot(file.copy(file.path(src, f), bundle))
for (d in c("docs", "tools", "templates", ".claude"))
  stopifnot(file.copy(file.path(src, d), bundle, recursive = TRUE))

# Windows wants CRLF in .bat / .txt
for (f in file.path(bundle, c("Run AutoG.bat", "README.txt"))) {
  x <- readLines(f); con <- file(f, "wb"); writeLines(x, con, sep = "\r\n"); close(con)
}

writeLines(c(sprintf("app        %s", readLines(file.path(src, "VERSION"))[1]),
             sprintf("built      %s on %s", format(Sys.time(), "%Y-%m-%d %H:%M"), Sys.info()[["nodename"]]),
             sprintf("R          %s (Windows x64)", R_WIN_VERSION),
             sprintf("GGIR       %s (installed from packages/ on first launch)", GGIR_VERSION),
             sprintf("packages   %s", paste(sort(need), shipped_ver[sort(need)], collapse = ", "))),
           file.path(bundle, "BUILD_INFO.txt"))

sz <- sum(file.info(list.files(bundle, recursive = TRUE, full.names = TRUE))$size) / 1e6
message(sprintf("done: %s  (%.0f MB)", bundle, sz))
