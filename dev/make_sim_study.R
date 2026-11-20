# Mac-only development tool (dev/ is NOT copied into the bundle).
# Builds a SIMULATED study from one real recording, to exercise cases the app
# has not met: short recordings, device off at night, a day of stillness, very
# short and very long nights, a 30 Hz device, a cut-off file, a sleep diary.
#
#     Rscript dev/make_sim_study.R [source.csv] [out_root]
#
# The output is DERIVED FROM A REAL RECORDING: keep it where that recording may be
# kept, never commit or share it. It is test material, never study data. The code
# reads an ActiLife raw CSV (60 Hz, at least 7 days); times of day below are
# relative to the hours the source recording covers.
suppressPackageStartupMessages(library(data.table))
a   <- commandArgs(TRUE)
if (length(a) < 2) stop("usage: Rscript dev/make_sim_study.R <one real raw CSV, 60 Hz, at least 7 days> <output folder>")
src <- a[1]; out <- a[2]
raw <- file.path(out, "ADULT", "raw"); dir.create(raw, recursive = TRUE, showWarnings = FALSE)

hdr <- readLines(src, n = 10); hdr <- sub("\r$", "", hdr)
cat("reading", src, "...\n")
x <- fread(src, skip = 11, header = FALSE, select = 2:4, col.names = c("X", "Y", "Z"), showProgress = FALSE)
HZ <- 60; H <- 3600 * HZ
H0 <- as.numeric(substr(sub("^Start Time +", "", hdr[3]), 1, 2))             # the source recording's start hour, from its header
tt <- function(day, hour) as.integer(((day - 1) * 24 + hour - H0) * H)       # rows before day/hour of the source recording
rows <- function(d1, h1, d2, h2) (tt(d1, h1) + 1L):tt(d2, h2)
N5 <- tt(6, 6)

write_sim <- function(id, d, hz = 60, start = "15/01/2026", cut_bytes = 0) {     # simulated files get made-up dates
  f <- file.path(raw, sprintf("%s_2026-01-15.csv", id))
  h <- hdr; h[1] <- sub("at [0-9]+ Hz", sprintf("at %d Hz", hz), h[1]); h[4] <- paste("Start Date", start)
  con <- file(f, "wb"); writeLines(c(h, "Accelerometer X,Accelerometer Y,Accelerometer Z"), con, sep = "\r\n"); close(con)
  fwrite(d, f, append = TRUE, col.names = FALSE, eol = "\r\n", showProgress = FALSE)
  if (cut_bytes) { s <- file.info(f)$size; system2("truncate", c("-s", s - cut_bytes, shQuote(f))) }
  cat(sprintf("%-6s %8.1f h  %3d Hz  %6.0f MB\n", id, nrow(d) / hz / 3600, hz, file.info(f)$size / 1e6)); invisible(gc())
}

write_sim("SIM01", x[1:N5])                                              # a normal 5 days
write_sim("SIM02", x[1:tt(3, 6)])                                        # only 2 days recorded

d <- x[1:N5]                                                             # device off the wrist on three nights
for (n in 2:4) set(d, rows(n, 22.5, n + 1, 6.5), c("X", "Y", "Z"), list(0.012, -0.031, -0.998))
write_sim("SIM03", d)

d <- x[1:N5]; night <- x[rows(2, 23, 3, 5)]                              # a day of sleep-like stillness (night data in the day)
set(d, rows(3, 8, 3, 20), c("X", "Y", "Z"), rbind(night, night))
write_sim("SIM04", d)

d <- x[1:N5]                                                             # one very short night, one very long night
set(d, rows(2, 21.5, 3, 3), c("X", "Y", "Z"), x[rows(2, 13, 2, 18.5)])   #   awake until 03:00
set(d, rows(3, 18, 3, 22.5), c("X", "Y", "Z"), x[rows(1, 23.5, 2, 4)])   #   asleep from 18:00 ...
set(d, rows(4, 6.5, 4, 10.5), c("X", "Y", "Z"), x[rows(2, 0, 2, 4)])     #   ... until 10:30
write_sim("SIM05", d)

write_sim("SIM06", x[seq(1L, N5, by = 2L)], hz = 30)                     # a device set to 30 Hz
write_sim("SIM07", x[1:tt(2, 13)], cut_bytes = 9)                        # a file cut off part-way through a line
write_sim("SIM08", x[seq(tt(2, 6) + 1L, tt(7, 6), by = 2L)], hz = 30, start = "16/01/2026")   # 5 days from day 2, with a diary

# Sleep diary for SIM08 only (GGIR "advanced" format; times a participant might plausibly write)
days <- sprintf("2026-01-%02d", 16:21)
wake <- c("", "06:15:00", "05:45:00", "06:15:00", "05:30:00", "07:15:00"); outb <- c("", "06:30:00", "06:00:00", "06:30:00", "05:45:00", "07:30:00")
inb  <- c("21:30:00", "22:15:00", "22:15:00", "23:00:00", "22:30:00", ""); ons  <- c("22:00:00", "22:30:00", "22:30:00", "23:15:00", "23:00:00", "")
cols <- unlist(lapply(seq_along(days), function(i) paste0(c("date_", "wakeup_", "outbed_", "inbed_", "onset_"), i)))
vals <- unlist(lapply(seq_along(days), function(i) c(days[i], wake[i], outb[i], inb[i], ons[i])))
writeLines(c(paste(c("ID", cols), collapse = ","), paste(c("SIM08", vals), collapse = ",")), file.path(out, "ADULT", "sleeplog_ADULT.csv"))
cat("diary written for SIM08\ndone:", raw, "\n")
