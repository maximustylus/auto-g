# R port of compose_reports.py (no Python / poppler needed).
#
# For every old_report_*.pdf in <studydir>/ggir/output_raw/results/file summary reports/
# put page 2 (per-day panels) on the left and page 1 (summary bars) on the
# right, and write <studydir>/reports/<ID>_GGIR_report.jpg.

compose_reports <- function(studydir) {
  src <- file.path(studydir, "ggir", "output_raw", "results", "file summary reports")
  dst <- file.path(studydir, "reports")
  dir.create(dst, showWarnings = FALSE, recursive = TRUE)

  pdfs <- sort(list.files(src, "^old_report_.*\\.pdf$", full.names = TRUE))
  if (!length(pdfs)) { cat("no old_report_*.pdf in", src, "\n"); return(invisible(character())) }

  out <- character()
  for (pdf in pdfs) {
    pid <- gsub("^old_report_|\\.csv\\.pdf$|\\.gt3x\\.pdf$|_\\d{4}-\\d{2}-\\d{2}", "", basename(pdf))
    pages <- tryCatch(pdftools::pdf_info(pdf)$pages, error = function(e) 0)      # a report GGIR could not finish is not a valid PDF
    if (pages < 2) { cat(basename(pdf), ": no usable report pages, skipped\n"); next }
    page <- function(i) magick::image_read(pdftools::pdf_render_page(pdf, page = i, dpi = 200))
    pp <- tryCatch(list(page(1), page(2)), error = function(e) NULL)              # one bad file must not stop the others
    if (is.null(pp)) { cat(basename(pdf), ": could not be rendered, skipped\n"); next }
    bars <- pp[[1]]; days <- pp[[2]]
    h <- max(magick::image_info(days)$height, magick::image_info(bars)$height)
    fit <- function(im) magick::image_scale(im, paste0("x", h))
    img <- magick::image_append(c(fit(days), fit(bars)))
    img <- magick::image_flatten(magick::image_background(img, "white"))
    f <- file.path(dst, paste0(pid, "_GGIR_report.jpg"))
    magick::image_write(img, f, format = "jpeg", quality = 92)
    cat(pid, ":", f, "\n")
    out <- c(out, f)
  }
  invisible(out)
}
