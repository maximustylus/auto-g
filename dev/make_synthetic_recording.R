# Writes a FULLY SYNTHETIC wrist-accelerometer recording in ActiLife raw-CSV
# format: no real recording is read or copied. Use it to try AutoG end to end,
# make screenshots, or teach, without participant data.
#
#   Rscript dev/make_synthetic_recording.R <out.csv> [seed] [days] [profile]
#     profile: "adult" (default) or "child" (shorter, burstier activity, an
#     afternoon nap most days)
#
# The day is built minute by minute from a simple schedule (sleep, sitting,
# light, moderate and vigorous activity, one device-off period), then turned
# into 30 Hz tri-axial acceleration: gravity along a slowly changing wrist
# orientation, plus movement whose size depends on the activity. It is
# plausible enough for GGIR to calibrate, find non-wear, sleep and activity; it
# is NOT a model of any real person and its numbers mean nothing clinically.
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(TRUE); if (!length(a)) stop("usage: Rscript dev/make_synthetic_recording.R <out.csv> [seed] [days] [adult|child]")
out <- a[1]; seed <- if (length(a) > 1) as.integer(a[2]) else 1L; days <- if (length(a) > 2) as.integer(a[3]) else 8L
profile <- if (length(a) > 3) a[4] else "adult"; child <- profile == "child"
set.seed(seed); FS <- 30L; start <- as.POSIXct("2026-01-15 00:00:00", tz = "UTC")

hdr <- c(sprintf("------------ Data File Created By ActiGraph GT3X+ ActiLife v6.13.4 Firmware v1.9.2 date format dd/MM/yyyy at %d Hz  Filter Normal -----------", FS),
         "Serial Number: SYNTHETIC0001", "Start Time 00:00:00", paste("Start Date", format(start, "%d/%m/%Y")), "Epoch Period (hh:mm:ss) 00:00:00",
         "Download Time 09:00:00", paste("Download Date", format(start + days * 86400, "%d/%m/%Y")), "Current Memory Address: 0",
         "Current Battery Voltage: 4.10     Mode = 12", "--------------------------------------------------", "Accelerometer X,Accelerometer Y,Accelerometer Z")
con <- file(out, "wb"); writeLines(hdr, con, sep = "\r\n"); close(con)

unit <- function(v) v / sqrt(sum(v^2))
lying   <- function() unit(c(rnorm(1, 0, .5), rnorm(1, 0, .5), sample(c(-1, 1), 1) * runif(1, .4, 1)))
sitting <- function() unit(c(rnorm(1, -.2, .35), rnorm(1, -.6, .3), rnorm(1, .4, .35)))
cal_scale <- c(1.012, .991, 1.006); cal_off <- c(.011, -.008, .006)          # a slightly miscalibrated device, as real ones are

for (d in seq_len(days)) {
  # ---- the day's schedule, one state per minute: 0 non-wear, 1 sleep, 2 inactive, 3 light, 4 moderate, 5 vigorous
  st <- rep(2L, 1440)
  wake  <- round(if (child) rnorm(1, 6.75 * 60, 20) else rnorm(1, 6.6 * 60, 25))
  onset <- round(if (child) rnorm(1, 20.75 * 60, 25) else rnorm(1, 22.6 * 60, 30))
  if (d == 3 && !child) onset <- onset + 75                                    # one late night
  onset <- min(onset, 1435)
  st[1:max(1, wake)] <- 1L; st[min(1440, onset):1440] <- 1L
  day <- (wake + 1):(onset - 1)
  n_bursts <- if (child) 70 else 18
  for (b in seq_len(n_bursts)) {                                               # activity: many short bursts for a child, fewer longer ones for an adult
    len <- if (child) sample(1:6, 1) else sample(c(5:20, 30:45), 1)
    s0 <- sample(day, 1); idx <- s0:min(onset - 1, s0 + len - 1)
    st[idx] <- sample(3:5, 1, prob = if (child) c(.5, .35, .15) else c(.6, .3, .1))
  }
  if (!child && d %in% c(2, 4, 6)) { s0 <- 18 * 60 + sample(0:60, 1); st[s0:(s0 + 40)] <- 5L }   # evening exercise
  if (child && d %in% 2:days) { s0 <- 13 * 60 + sample(0:45, 1); st[s0:(s0 + sample(60:100, 1))] <- 1L }   # afternoon nap
  if (!child && d == 5) { s0 <- 13 * 60 + 30; st[s0:(s0 + 75)] <- 1L }        # one daytime nap
  if (d == 4) st[(10 * 60):(12 * 60 + 30)] <- 0L                              # the device taken off for 2.5 hours

  # ---- per second: wrist orientation (gravity direction), changing with posture
  sec <- rep(st, each = 60); n <- length(sec); g <- matrix(0, n, 3)
  i <- 1L
  while (i <= n) {
    s <- sec[i]; seg <- if (s == 1) sample(300:2400, 1) else if (s == 0) n else if (s == 2) sample(60:400, 1) else sample(20:90, 1)
    j <- min(n, i + seg - 1L); j <- min(j, i - 1L + match(TRUE, sec[i:j] != s, nomatch = j - i + 2L) - 1L)
    v <- if (s == 1) lying() else if (s == 0) c(0, 0, 1) else sitting()
    g[i:j, ] <- matrix(v, j - i + 1L, 3, byrow = TRUE); i <- j + 1L
  }
  # Awake wrists never stay still: add a continuous small wobble while awake (none in sleep or off the wrist)
  awake <- sec >= 2; jit <- matrix(rnorm(n * 3, 0, .22), n, 3) * awake
  k10 <- rep(1 / 10, 10); for (c3 in 1:3) { f <- stats::filter(jit[, c3], k10, sides = 2); f[is.na(f)] <- 0; g[, c3] <- g[, c3] + f }
  k <- rep(1 / 5, 5); for (c3 in 1:3) { f <- stats::filter(g[, c3], k, sides = 2); f[is.na(f)] <- g[is.na(f), c3]; g[, c3] <- f }   # smooth the turns
  g <- g / sqrt(rowSums(g^2))

  # ---- 30 Hz signal: gravity + movement + sensor noise
  N <- n * FS; t <- (0:(N - 1)) / FS; s30 <- rep(sec, each = FS); G <- g[rep(seq_len(n), each = FS), ]
  amp <- c(0, .004, .03, .22, .55, 1.25)[s30 + 1L]; hz <- c(0, .3, 1, 1.8, 2.2, 2.8)[s30 + 1L]
  if (child) amp <- amp * c(1, 1, 1.2, 1.35, 1.45, 1.3)[s30 + 1L]
  tw <- rep(sec == 1 & runif(n) < .015, each = FS); amp[tw] <- .06; hz[tw] <- 1.5      # small movements in sleep
  ph <- runif(3, 0, 2 * pi)
  mv <- sapply(1:3, function(ax) amp * sin(2 * pi * hz * t + ph[ax]) * c(1, .7, .5)[ax])
  noise <- matrix(rnorm(N * 3, 0, ifelse(s30 == 0, .0025, .006 + amp * .15)), N, 3)
  A <- (G + mv + noise) * matrix(cal_scale, N, 3, byrow = TRUE) + matrix(cal_off, N, 3, byrow = TRUE)
  fwrite(data.table(round(A[, 1], 3), round(A[, 2], 3), round(A[, 3], 3)), out, append = TRUE, col.names = FALSE, eol = "\r\n", showProgress = FALSE)
  rm(A, G, mv, noise, t, s30, amp, hz); invisible(gc())
  cat(sprintf("day %d: wake %02d:%02d, sleep %02d:%02d\n", d, wake %/% 60, wake %% 60, onset %/% 60, onset %% 60))
}
cat("written", out, sprintf("(%.0f MB)\n", file.info(out)$size / 1e6))
