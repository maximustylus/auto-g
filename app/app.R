# AutoG -- offline desktop app. Runs on 127.0.0.1 only; nothing leaves the PC.
library(shiny)
source("settings.R", local = TRUE)
source("results.R", local = TRUE)
source("help.R", local = TRUE)

is_win  <- .Platform$OS.type == "windows"
rscript <- file.path(R.home("bin"), if (is_win) "Rscript.exe" else "Rscript")
cfg     <- file.path(Sys.getenv(if (is_win) "APPDATA" else "HOME"), "AutoG-app.txt")  # remembers the data folder
app_version <- tryCatch(trimws(readLines(file.path("..", "VERSION"), warn = FALSE)[1]), error = function(e) "dev")
ggir_version <- tryCatch(as.character(utils::packageVersion("GGIR")), error = function(e) "not installed")
# Who is using AutoG: initials only, self-declared, kept on this PC. A record, not a login.
users_file <- file.path(dirname(cfg), "AutoG-users.txt")
welcomed_file <- file.path(dirname(cfg), "AutoG-welcomed.txt")   # initials that have been through the welcome
welcomed <- function(u) file.exists(welcomed_file) && u %in% readLines(welcomed_file, warn = FALSE)
known_users <- function() if (file.exists(users_file)) unique(grep("^[A-Z]{2,4}$", readLines(users_file, warn = FALSE), value = TRUE)) else character()
default_cores <- max(1L, min(4L, parallel::detectCores() - 2L))

open_folder <- function(p) if (is_win) shell.exec(normalizePath(p)) else system2("open", shQuote(p))
# Stop the worker AND the helper processes GGIR starts for parallel work. If only
# the worker is killed, the helpers carry on with their current file for a while.
kill_tree   <- function(pid) if (is_win) system2("taskkill", c("/T", "/F", "/PID", pid), stdout = FALSE, stderr = FALSE) else {
  tab <- utils::read.table(text = system2("ps", c("-axo", "pid=,ppid="), stdout = TRUE))
  kids <- function(p) { k <- tab$V1[tab$V2 == p]; c(k, unlist(lapply(k, kids))) }
  tools::pskill(c(kids(as.integer(pid)), as.integer(pid)))
}
raw_files   <- function(d) list.files(d, "\\.(csv|gt3x)$", ignore.case = TRUE)
count_files <- function(d) length(raw_files(d))
elapsed     <- function(from, to = Sys.time()) { m <- as.numeric(difftime(to, from, units = "mins")); if (m < 1) "under a minute" else if (m < 90) sprintf("%.0f min", m) else sprintf("%.1f h", m / 60) }
mark        <- function(text, kind) span(class = paste("mark", kind), icon(c(pass = "check", flag = "triangle-exclamation", look = "eye")[[kind]]), text)
# Yellow highlight for every [FILL IN: ...] in a draft
with_blanks <- function(x) HTML(gsub("(\\[FILL IN:[^]]*\\])", "<mark>\\1</mark>", htmltools::htmlEscape(x)))

# The run belongs to the app, not to a browser tab: a reloaded or reopened
# tab must still see it.
run <- reactiveValues(pid = NULL, log = NULL, status = NULL, start = NULL, files = NULL, overwrite = FALSE, studydir = NULL, label = NULL)
# Drive letters for the in-app folder picker (A:/B: skipped - probing them can hang)
drives      <- function() if (is_win) { d <- paste0(LETTERS[-(1:2)], ":/"); d[dir.exists(d)] } else "/"
subdirs     <- function(p) sort(basename(list.dirs(p, full.names = TRUE, recursive = FALSE)))

ui <- fluidPage(
  tags$head(tags$script(src = "autog-theme.js"), tags$script(src = "autog-welcome.js"), tags$link(rel = "stylesheet", href = "autog.css")),
  tags$head(tags$title("AutoG"), tags$link(rel = "icon", type = "image/svg+xml", href = "autog-icon.svg")),
  div(class = "brand",
    tags$img(src = "autog-mark-on-dark.svg", alt = "", width = 38, height = 38),
    span(class = "name", "AutoG"), span(class = "tag", "Accelerometry, automated"),
    uiOutput("who_chip", inline = TRUE),
    div(class = "chips", style = "margin-left:0",
      span(class = "chip", sprintf("v%s", app_version)), span(class = "chip", sprintf("GGIR %s", ggir_version)),
      span(class = "chip", icon("lock"), "Offline")),
    div(class = "theme", role = "group", `aria-label` = "Colour mode",
      tags$button(type = "button", `data-theme-choice` = "light", title = "Light mode", icon("sun"), "Light"),
      tags$button(type = "button", `data-theme-choice` = "dark", title = "Dark mode", icon("moon"), "Dark"),
      tags$button(type = "button", `data-theme-choice` = "auto", title = "Follow this PC", icon("circle-half-stroke"), "Auto"))),
  sidebarLayout(
    sidebarPanel(width = 4,
      div(class = "sec", icon("folder-open"), "Data"),
      textInput("root", "Data folder (no spaces in path)",
                value = if (file.exists(cfg)) readLines(cfg, warn = FALSE)[1] else ""),
      actionButton("browse", "Browse", icon = icon("folder-open"), class = "btn-sm"),
      p(class = "muted", "Expected inside it:", tags$code("ADULT\\raw\\"), "and/or", tags$code("CHILD\\raw\\"),
        "with files named ", tags$code("ID_date.csv"), "."),
      div(class = "sec", icon("flask"), "Study"),
      selectInput("study", "Study", choices = setNames(names(STUDIES), STUDIES)),
      uiOutput("cutpoints"),
      tags$details(class = "adv", tags$summary(icon("sliders"), "Advanced"),
        actionButton("age_change", "Change age group", icon = icon("lock-open"), class = "btn-sm"),
        p(class = "muted", style = "margin:6px 0 12px", "The age group sets the cut-points. It is fixed for the study."),
        numericInput("cores", "Processor cores to use", default_cores, min = 1, max = parallel::detectCores()),
        checkboxInput("overwrite", "Reprocess files already done", FALSE)),
      div(class = "sec", icon("play"), "Run"),
      uiOutput("checks"),
      actionButton("run", "Start processing", icon = icon("play"), class = "btn-primary btn-lg"),
      actionButton("stop", "Stop", icon = icon("stop"), class = "btn-danger"),
      p(class = "muted", style = "margin-top:10px",
        "Takes roughly 10-20 min per file. Keep the laptop plugged in and stop it from sleeping, ",
        "and keep the drive connected until it says Finished.")
    ),
    mainPanel(width = 8,
      tabsetPanel(id = "tabs",
        tabPanel(title = tagList(icon("house"), "Home"), value = "Home", uiOutput("home")),
        tabPanel(title = tagList(icon("bars-progress"), "Progress"), value = "Progress", div(class = "status", textOutput("state")), uiOutput("run_label"), uiOutput("progress"), uiOutput("issues"),
          tags$details(tags$summary("Show details (full log)"), tags$pre(class = "log", textOutput("log")))),
        tabPanel(title = tagList(icon("clipboard-check"), "Quality check"), value = "Quality check", br(), uiOutput("qc"),
          conditionalPanel("output.qc_has_rows", div(class = "box",
            selectInput("qc_file", "File to judge", choices = NULL, width = "100%"),
            uiOutput("qc_detail")))),
        tabPanel(title = tagList(icon("image"), "Reports"), value = "Reports",
          br(),
          actionButton("open_reports", "Open reports folder", icon = icon("folder-open")),
          actionButton("open_results", "Open GGIR results folder", icon = icon("folder-open")),
          br(), br(),
          selectInput("report", "Report image", choices = NULL, width = "100%"),
          imageOutput("report_img", height = "auto")),
        tabPanel(title = tagList(icon("table"), "Datasheet"), value = "Datasheet", br(),
          p(strong("Build your study datasheet."), "One row per participant, ready to open in Excel. Only participants you have checked and not excluded can go in."),
          uiOutput("ds_who"),
          checkboxGroupInput("ds_groups", "What goes in", choices = DS_GROUPS, selected = DS_GROUPS, inline = TRUE),
          uiOutput("ds_preview"),
          actionButton("ds_save", "Save datasheet", icon = icon("download"), class = "btn-primary"), actionButton("ds_open", "Open datasheet folder", icon = icon("folder-open")),
          p(class = "muted", style = "margin-top:8px", "Saved in the study folder under datasheet/, with a column guide that explains every column and a draft methods paragraph. An earlier datasheet is never overwritten."),
          tags$details(class = "help", tags$summary(icon("pen-nib"), "Methods paragraph for your paper"), div(class = "help-body", uiOutput("methods")))),
        tabPanel(title = tagList(icon("file-lines"), "Summary"), value = "Summary", br(),
          selectInput("sum_file", "Participant file", choices = NULL, width = "100%"),
          uiOutput("summary"),
          tags$textarea(id = "sum_text", style = "position:absolute; left:-9999px;", readonly = NA),
          tags$script(HTML("Shiny.addCustomMessageHandler('copy_draft', function(text) {
            var t = document.getElementById('sum_text'); t.value = text;
            if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(text);
            else { t.select(); document.execCommand('copy'); }
          });"))),
        tabPanel(title = tagList(icon("circle-question"), "Help"), value = "Help", help_ui())
      )
    )
  )
)

server <- function(input, output, session) {
  # In-app folder picker. (utils::choose.dir opens behind the browser when
  # R runs from the .bat, and freezes the app until it is found and closed.)
  fb <- reactiveVal(NULL)
  observeEvent(input$browse, {
    start <- if (dir.exists(root()) && nzchar(root())) root() else drives()[1]
    fb(normalizePath(start, winslash = "/"))
    showModal(modalDialog(title = "Choose the data folder", size = "m", easyClose = TRUE,
      uiOutput("fb_drives"), br(), strong(textOutput("fb_path", inline = TRUE)), br(), br(),
      actionButton("fb_up", "Up one level", icon = icon("arrow-up"), class = "btn-sm"), br(), br(),
      selectInput("fb_sub", "Click a folder to open it:", choices = NULL, selectize = FALSE, size = 12, width = "100%"),
      uiOutput("fb_hint"),
      footer = tagList(modalButton("Cancel"), actionButton("fb_ok", "Use this folder", icon = icon("check"), class = "btn-primary"))))
  })
  output$fb_drives <- renderUI(tagList(lapply(seq_along(drives()), function(i)
    actionButton(paste0("fb_drive_", i), drives()[i], class = "btn-sm"))))
  observe(lapply(seq_along(drives()), function(i)
    observeEvent(input[[paste0("fb_drive_", i)]], fb(drives()[i]), ignoreInit = TRUE)))
  output$fb_path <- renderText(fb())
  observe({
    req(fb()); input$browse        # refill when the dialog reopens at the same folder
    updateSelectInput(session, "fb_sub", choices = c("", tryCatch(subdirs(fb()), error = function(e) character())), selected = "")
  })
  observeEvent(input$fb_sub, if (nzchar(input$fb_sub)) fb(file.path(sub("/$", "", fb()), input$fb_sub)))
  observeEvent(input$fb_up, fb(dirname(fb())))
  output$fb_hint <- renderUI({
    req(fb())
    found <- names(STUDIES)[dir.exists(file.path(fb(), names(STUDIES), "raw"))]
    tagList(
      if (grepl(" ", fb())) p(class = "warn", "This path contains a space - GGIR cannot use it."),
      p(class = "muted", if (length(found)) paste("Found:", paste0(found, "/raw", collapse = ", "), "- this looks right.")
                         else "No ADULT/raw or CHILD/raw in this folder yet."))
  })
  observeEvent(input$fb_ok, { updateTextInput(session, "root", value = sub("/$", "", fb())); removeModal() })

  root      <- reactive(sub("[/\\\\]+$", "", gsub("\\\\", "/", trimws(input$root))))
  studydir  <- reactive(file.path(root(), input$study))
  running   <- reactive({ invalidateLater(2000); !is.null(run$status) && file.exists(run$status) && readLines(run$status, warn = FALSE)[1] == "running" })

  # Who is using AutoG: asked at every start, because several people share the PC
  who <- reactiveVal("")
  who_modal <- function(msg = NULL) modalDialog(title = "Who is using AutoG?", easyClose = nzchar(isolate(who())), footer = NULL,
    p("Choose your initials. AutoG writes them next to what you process and check, so the study has a record of who did what."),
    div(class = "who-list", lapply(known_users(), function(u) tags$button(type = "button", class = "btn btn-default btn-lg",
      onclick = sprintf("Shiny.setInputValue('who_pick', '%s', {priority: 'event'})", u), u))),
    div(class = "who-add", textInput("who_new", "Not listed? Add your initials (2 to 4 letters)", width = "260px"),
        actionButton("who_add", "Add and continue", icon = icon("plus"), class = "btn-primary")),
    if (!is.null(msg)) p(class = "warn", msg),
    p(class = "muted", "Initials only, never full names. This is not a password and does not protect the data."))
  observe(if (!nzchar(isolate(who()))) showModal(who_modal()))
  observeEvent(input$who_pick, { req(input$who_pick %in% known_users()); who(input$who_pick); removeModal() })
  observeEvent(input$who_add, {
    u <- toupper(gsub("[^A-Za-z]", "", input$who_new))
    if (!grepl("^[A-Z]{2,4}$", u)) return(showModal(who_modal("Enter 2 to 4 letters, for example AB.")))
    if (!u %in% known_users()) cat(u, "\n", sep = "", file = users_file, append = TRUE)
    who(u); removeModal()
  })
  observeEvent(input$who_switch, showModal(who_modal()))
  # The welcome: once per person, right after they first choose their initials
  observeEvent(who(), if (nzchar(who()) && !welcomed(who())) showModal(welcome_modal(who())))
  observeEvent(input$welcome_done, { if (!welcomed(who())) cat(who(), "\n", sep = "", file = welcomed_file, append = TRUE); removeModal() })
  observeEvent(input$welcome_again, showModal(welcome_modal(who())))
  output$who_chip <- renderUI(if (nzchar(who())) tags$button(type = "button", class = "chip who", title = "Switch user",
    onclick = "Shiny.setInputValue('who_switch', Math.random(), {priority: 'event'})", icon("user"), who()))

  # Age group: fixed per study folder (autog_study.txt), shown everywhere,
  # changed only through Advanced with a confirmation.
  age <- reactiveVal(AGE_DEFAULT[[1]])
  observe({ sd <- studydir(); age(study_age(sd, AGE_DEFAULT[[input$study]])) })
  age_label <- function(a = age()) sub(" - .*$", "", AGE_GROUPS[[a]]$label)
  observeEvent(input$age_change, {
    showModal(modalDialog(title = "Change the age group for this study", easyClose = TRUE,
      p("The age group sets the cut-points that turn movement into inactive, light, moderate and vigorous time. Every participant in a study should use the same one."),
      selectInput("age_new", "Age group", choices = setNames(names(AGE_GROUPS), sapply(AGE_GROUPS, `[[`, "label")), selected = age(), width = "100%"),
      if (isTRUE(study_age_is_set(studydir()))) div(class = "box warn", strong("This study already has an age group."),
        p("After a change, tick Reprocess files already done so that every participant is redone with the new cut-points, then check each one again.")),
      footer = tagList(modalButton("Cancel"), actionButton("age_ok", "Change age group", icon = icon("check"), class = "btn-primary"))))
  })
  observeEvent(input$age_ok, {
    removeModal(); req(dir.exists(studydir()))
    if (!identical(input$age_new, age())) {
      study_log(studydir(), sprintf("age group changed from %s to %s", age(), input$age_new), who())
      set_study_age(studydir(), input$age_new); age(input$age_new)
      showNotification(paste("Age group for this study is now", age_label()), type = "warning", duration = 8)
    }
  })

  output$cutpoints <- renderUI({
    cp <- AGE_GROUPS[[age()]]
    return(div(class = "locked", div(icon("lock"), strong(age_label())),
               div(class = "muted", sprintf("Light %g - Moderate %g - Vigorous %g mg", cp$lig, cp$mod, cp$vig))))
    p(class = "muted", sprintf("Light %g  |  Moderate %g  |  Vigorous %g mg (ENMO, ActiGraph non-dominant wrist, 5 s)",
                               cp$lig, cp$mod, cp$vig))
  })

  # Results already in the folder were made with another age group: files
  # already processed are skipped unless "reprocess" is ticked, so the study
  # would silently hold two sets of cut-points.
  age_warning <- function() {
    rs <- read_run_settings(studydir())
    if (is.null(rs) || is.null(rs[["age group"]]) || identical(rs[["age group"]], age())) return(NULL)
    was <- rs[["age group"]]
    div(class = "box warn",
      strong("Different age group from the last run."),
      p(sprintf("The results in this study folder were made with the %s cut-points (%s). You have chosen %s.", was, rs[["cut-points"]] , age())),
      p(if (isTRUE(input$overwrite)) "Reprocess is ticked: every file will be redone with the new cut-points, and every participant needs checking again."
        else "Files already processed will keep the old cut-points; only new files get the new ones. To redo them all, tick Reprocess. To keep the study consistent, choose the earlier age group."))
  }

  output$checks <- renderUI({
    invalidateLater(5000)
    problem <- check_root(root())
    if (!is.null(problem)) return(p(class = "warn", problem))
    n  <- count_files(file.path(studydir(), "raw"))
    sl <- file.exists(file.path(studydir(), paste0("sleeplog_", input$study, ".csv")))
    tagList(
      p(if (n) sprintf("%d raw file(s) in %s/raw", n, input$study)
        else span(class = "warn", sprintf("No .csv/.gt3x files in %s/raw", studydir()))),
      p(if (sl) "Sleep diary found - sleep guided by the diary."
        else span(class = "muted", "No sleep diary - sleep from accelerometer (HDCZA) only.")),
      age_warning())
  })

  observeEvent(input$run, {
    problem <- check_root(root())
    if (!is.null(problem)) return(showNotification(problem, type = "error", duration = 10))
    if (isTRUE(running())) return(showNotification("A run is already in progress. Wait for it to finish, or stop it.", type = "warning"))
    other <- read_run_state(studydir())      # started by another copy of AutoG on the same study folder
    if (!is.null(other) && identical(readLines(other$status, warn = FALSE)[1], "running") && pid_alive(other$pid))
      return(showNotification("This study is already being processed. Wait for it to finish.", type = "warning"))
    if (!count_files(file.path(studydir(), "raw"))) return(showNotification("No raw files to process.", type = "error"))
    writeLines(root(), cfg)
    if (!file.exists(study_file(studydir()))) set_study_age(studydir(), age())
    study_log(studydir(), sprintf("processing started: %d file(s), age group %s, reprocess %s, AutoG %s", count_files(file.path(studydir(), "raw")), age(), isTRUE(input$overwrite), app_version), who())

    outdir <- file.path(studydir(), "ggir"); dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
    stamp  <- format(Sys.time(), "%Y%m%d_%H%M%S")
    run$start <- Sys.time(); run$files <- raw_files(file.path(studydir(), "raw")); run$overwrite <- isTRUE(input$overwrite)
    run$studydir <- studydir()
    run$label <- sprintf("Study %s - %s cut-points - %d file(s) - %s core(s)", input$study, age(), length(run$files), input$cores)
    run$log    <- file.path(outdir, paste0("app_log_", stamp, ".txt"))
    run$status <- run_status_file(studydir())
    pidfile    <- file.path(outdir, "autog_run_pid.txt"); unlink(pidfile)
    writeLines("running", run$status)

    Sys.setenv(GGIR_ROOT = root(), GGIR_STUDY = input$study, GGIR_AGE_GROUP = age(),
               GGIR_CORES = input$cores, GGIR_OVERWRITE = input$overwrite,
               GGIR_STATUS = run$status, GGIR_PIDFILE = pidfile)
    system2(rscript, c("--vanilla", shQuote(file.path(getwd(), "ggir_run.R"))),
            stdout = run$log, stderr = run$log, wait = FALSE)
    for (i in 1:50) { if (file.exists(pidfile)) break; Sys.sleep(0.1) }
    run$pid <- if (file.exists(pidfile)) readLines(pidfile)[1] else ""
    write_run_state(studydir(), list(pid = run$pid, start = run$start, log = run$log, overwrite = run$overwrite, label = run$label, by = who(), files = run$files))
    updateTabsetPanel(session, "tabs", "Progress")
  })

  observeEvent(input$stop, {
    if (!isTRUE(running()) || is.null(run$pid)) return(showNotification("Nothing is running."))
    kill_tree(run$pid)
    writeLines("failed: stopped by user", run$status)
    showNotification("Stopped. Files already finished are kept; rerun to continue.", type = "warning")
  })

  # Pick up a run recorded in the study folder (the app was restarted, or it was
  # started from another tab), unless a run is active in memory already.
  observe({
    sd <- studydir(); if (!is.null(check_root(root()))) return()
    active <- !is.null(isolate(run$status)) && file.exists(isolate(run$status)) && identical(readLines(isolate(run$status), warn = FALSE)[1], "running")
    if (active || identical(isolate(run$studydir), sd)) return()
    st <- read_run_state(sd); if (is.null(st)) return()
    for (k in c("pid", "start", "log", "overwrite", "label", "files", "status", "studydir")) run[[k]] <- st[[k]]
  })
  # A worker that is gone while the status still says running did not finish:
  # the laptop slept or was switched off, or the process was killed.
  last_alive_check <- 0
  status <- reactive({
    invalidateLater(2000); if (is.null(run$status) || !file.exists(run$status)) return(NULL)
    s <- readLines(run$status, warn = FALSE)[1]
    if (identical(s, "running") && as.numeric(Sys.time()) - last_alive_check > 8) {
      last_alive_check <<- as.numeric(Sys.time())
      if (!pid_alive(run$pid) && identical(readLines(run$status, warn = FALSE)[1], "running")) {
        s <- "failed: processing stopped unexpectedly (the laptop may have gone to sleep or been switched off). Press Start processing to carry on; finished files are kept."
        writeLines(s, run$status)
      }
    }
    s
  })
  progress <- reactive({
    req(run$start); status()
    run_progress(run$studydir, run$files, run$start, run$overwrite)
  })
  finished_at <- reactive(if (!is.null(run$status)) file.mtime(run$status))
  # The step GGIR is on comes from its log; a file that fails never completes
  # a step, so "first incomplete step" would stick there for the whole run.
  step <- reactive({ status(); k <- log_step(run$log); if (k == 0L) 1L else k })

  output$state <- renderText({
    s <- status()
    if (is.null(s)) return("Ready.")
    if (s == "running") {
      sprintf("Running - %s - %s elapsed", if (step() <= 6) sprintf("step %d of 6", step()) else "writing reports", elapsed(run$start))
    } else if (s == "done") {
      bad <- unique(unlist(lapply(progress(), `[[`, "missing")))
      if (length(bad)) sprintf("Finished in %s, but %d of %d file(s) did not complete. See below.", elapsed(run$start, finished_at()), length(bad), length(run$files))
      else sprintf("Finished in %s. Next: the Quality check tab.", elapsed(run$start, finished_at()))
    }
    else paste("Stopped -", sub("^failed: ", "", s))
  })
  output$run_label <- renderUI(if (!is.null(run$label)) p(class = "muted", run$label, "- started", format(run$start, "%H:%M")))

  output$progress <- renderUI({
    req(run$start); pr <- progress(); s <- status()
    current <- if (identical(s, "running")) step() else 99L
    rows <- lapply(pr, function(p) {
      n <- p$done + p$already; full <- n >= p$total
      count <- sprintf("%d of %d file(s)", n, p$total)
      if (p$already) count <- paste0(count, sprintf(" (%d already done)", p$already))
      tags$tr(tags$td(style = if (p$part == current) "font-weight:600", sprintf("%d. %s", p$part, p$label)),
              tags$td(div(class = paste("bar", if (full) "done"), div(style = sprintf("width:%.0f%%", 100 * n / max(1, p$total))))),
              tags$td(if (full) "done" else if (p$part == current) paste("working -", count)
                      else if (p$part < current) tagList(count, mark(sprintf("%d not completed", p$total - n), "flag")) else "waiting"))
    })
    tags$table(class = "plain", tags$tr(tags$th("Step"), tags$th(""), tags$th("Files")), rows,
      tags$tr(tags$td("Reports and report images"), tags$td(div(class = paste("bar", if (identical(s, "done")) "done"), div(style = sprintf("width:%d%%", if (identical(s, "done")) 100 else 0)))),
              tags$td(if (identical(s, "done")) "done" else if (current == 7L) "working" else "waiting")))
  })

  # After the run: which files did not get through, and the literal errors from the log
  output$issues <- renderUI({
    req(run$start); s <- status(); if (identical(s, "running")) return(NULL)
    pr <- progress(); seen <- character(); out <- list()
    for (p in pr) for (f in setdiff(p$missing, seen)) { seen <- c(seen, f)
      out <- c(out, list(tags$li(sprintf("%s did not finish step %d (%s).", f, p$part, tolower(p$label))))) }
    errs <- if (!is.null(run$log) && file.exists(run$log)) grep("error|skipping", readLines(run$log, warn = FALSE), value = TRUE, ignore.case = TRUE) else character()
    errs <- utils::head(unique(errs[!grepl("call?ibration error|cal.error", errs, ignore.case = TRUE)]), 5)
    if (!length(out) && !length(errs)) return(NULL)
    div(class = "box warn", strong("Not everything finished."), tags$ul(out),
        if (length(errs)) tagList(p("From the log:"), tags$pre(paste(errs, collapse = "\n"))),
        p("Files that finished are kept. Fix or remove the file named above, then run again."))
  })

  output$log <- renderText({
    if (is.null(run$log)) return("")
    status()
    if (!file.exists(run$log)) return("")
    x <- readLines(run$log, warn = FALSE)
    paste(utils::tail(x, 300), collapse = "\n")
  })

  reports <- reactive({
    invalidateLater(10000); running()
    rev(list.files(file.path(studydir(), "reports"), "\\.jpg$", full.names = TRUE))
  })
  observe(updateSelectInput(session, "report", choices = setNames(reports(), basename(reports()))))
  output$report_img <- renderImage({
    req(input$report, file.exists(input$report))
    list(src = input$report, width = "100%", alt = basename(input$report))
  }, deleteFile = FALSE)

  observeEvent(input$open_reports, { d <- file.path(studydir(), "reports"); if (dir.exists(d)) open_folder(d) })
  observeEvent(input$open_results, { d <- file.path(studydir(), "ggir"); if (dir.exists(d)) open_folder(d) })

  #--- Home: four steps and the participant list --------------------------------
  home <- reactive({
    status_changed(); qc_tick(); input$tabs; invalidateLater(15000)
    if (!is.null(check_root(root()))) return(NULL)
    files <- raw_files(file.path(studydir(), "raw"))
    is_running <- identical(status_changed(), "running")
    # "could not be read" only after a run that FINISHED without the file; after a stopped or interrupted run the file is simply not processed yet
    failed <- if (!is.null(run$start) && identical(status_changed(), "done") && identical(run$studydir, studydir())) unique(unlist(lapply(run_progress(run$studydir, run$files, run$start, run$overwrite), `[[`, "missing"))) else character()
    participant_status(studydir(), files, running = if (is_running) intersect(files, run$files) else character(), failed = failed)
  })
  STATUS <- list(new = c("clock", "Not processed yet"), processing = c("spinner", "Processing"), check = c("eye", "Needs quality check"),
                 checked = c("circle-check", "Checked"), excluded = c("circle-xmark", "Excluded"), unreadable = c("triangle-exclamation", "Could not be read"),
                 short = c("hourglass-end", "Not enough data"))
  go <- function(act, file, label, primary = FALSE) tags$button(type = "button", class = paste("btn btn-sm", if (primary) "btn-primary" else "btn-default"),
    onclick = sprintf("Shiny.setInputValue('home_go', {act: '%s', file: '%s', n: Math.random()}, {priority: 'event'})", act, file), label)

  output$home <- renderUI({
    problem <- check_root(root())
    if (!is.null(problem)) return(div(class = "empty", icon("folder-open"), h4("Choose your data folder to begin"),
      p(class = "muted", "Use Browse on the left. AutoG looks for a study folder such as ADULT or CHILD with a raw folder inside it."), p(class = "warn", if (nzchar(root())) problem)))
    rows <- home(); st <- vapply(rows, `[[`, "", "status"); n <- length(rows)
    n_new <- sum(st == "new"); n_bad <- sum(st == "unreadable"); n_check <- sum(st == "check"); n_done <- sum(st %in% c("checked", "excluded", "short")); n_in <- sum(st == "checked")
    is_running <- identical(status_changed(), "running")
    current <- if (n == 0) 1 else if (is_running || n_new > 0) 2 else if (n_check > 0) 3 else 4
    card <- function(k, title, text, ...) {
      state <- if (k < current) "done" else if (k == current) "now" else "later"
      div(class = paste("step", state), div(class = "k", if (state == "done") tagList(icon("check"), sprintf("Step %d - done", k)) else if (state == "now") sprintf("Step %d - do this now", k) else sprintf("Step %d", k)),
          div(class = "t", title), div(class = "d", text), ...)
    }
    cp <- AGE_GROUPS[[age()]]
    tagList(
      div(class = "studybar",
        span(span(class = "muted", "Study"), strong(STUDIES[[input$study]])),
        span(icon("lock"), span(class = "muted", "Age group"), strong(age_label())),
        span(class = "muted", sprintf("Light %g - Moderate %g - Vigorous %g mg", cp$lig, cp$mod, cp$vig))),
      age_warning(),
      div(class = "steps",
        card(1, "Add files", if (n) sprintf("%d file(s) in the study folder%s.", n, if (n_new) sprintf(", %d new", n_new) else "") else
               tagList("Put each recording in ", tags$code(paste0(input$study, "/raw")), " named ", tags$code("ID_date.csv"), ".")),
        card(2, "Process", if (is_running) "Processing now. You can leave this running." else if (n_new) sprintf("%d file(s) to process, roughly %d minutes.", n_new, 15 * n_new)
                          else if (n_bad) span(class = "warn", sprintf("%d file(s) could not be read. Replace or remove them, then process again.", n_bad)) else "Nothing waiting to be processed.",
             if (is_running) go("progress", "", "See progress") else if (n_new) tags$button(type = "button", class = "btn btn-primary", onclick = "document.getElementById('run').click()", icon("play"), "Start processing")),
        card(3, "Check", if (n_check) sprintf("%d participant(s) need a quality check.", n_check) else if (n_done) "Every processed participant is checked." else "Look at each report picture and say if it is usable."),
        card(4, "Collect", if (n_in) sprintf("%d participant(s) ready for the study datasheet.", n_in) else "Reports, summaries and the study datasheet.",
             if (n_in && current == 4) go("datasheet", "", "Build datasheet", primary = TRUE))),
      h4("Participants"),
      if (!n) p(class = "muted", "No recordings in this study folder yet.") else
      tags$table(class = "plain people",
        tags$tr(tags$th("Participant"), tags$th("Where it is"), tags$th("Next")),
        lapply(rows, function(r) { s0 <- STATUS[[r$status]]
          tags$tr(tags$td(strong(r$id)),
            tags$td(span(class = paste("where", r$status), icon(s0[1]), s0[2]), if (r$status == "checked") span(class = "muted", paste0(" - ", r$verdict))),
            tags$td(switch(r$status,
              new = span(class = "muted", "Included in step 2"), processing = go("progress", "", "See progress"),
              check = go("check", r$file, "Check now", primary = current == 3),
              checked = tagList(go("report", r$file, "Report"), go("summary", r$file, "Summary")),
              excluded = tagList(go("report", r$file, "Report"), go("check", r$file, "Change verdict")),
              unreadable = go("progress", "", "What happened"),
              short = tagList(span(class = "muted", "Too short for day and night results. "), go("check", r$file, "Record as excluded")))))
        })))
  })
  observeEvent(input$home_go, {
    g <- input$home_go
    if (g$act == "check")   { updateSelectInput(session, "qc_file", selected = g$file); updateTabsetPanel(session, "tabs", "Quality check") }
    if (g$act == "summary") { updateSelectInput(session, "sum_file", selected = g$file); updateTabsetPanel(session, "tabs", "Summary") }
    if (g$act == "report")  { updateSelectInput(session, "report", selected = file.path(studydir(), "reports", paste0(file_id(g$file), "_GGIR_report.jpg"))); updateTabsetPanel(session, "tabs", "Reports") }
    if (g$act == "progress")  updateTabsetPanel(session, "tabs", "Progress")
    if (g$act == "datasheet") updateTabsetPanel(session, "tabs", "Datasheet")
  })

  #--- Quality check ----------------------------------------------------------
  qc_tick <- reactiveVal(0)
  # status() re-fires every 2 s; the tables and the verdict form must only
  # redraw when something changed, or the form resets while it is being filled in
  status_changed <- reactiveVal(NULL)
  observe({ s <- status(); if (!identical(s, isolate(status_changed()))) status_changed(s) })
  qc <- reactive({ qc_tick(); status_changed(); input$tabs; qc_table(studydir()) })
  qc_files <- reactive({ rows <- qc(); if (is.null(rows)) character() else unname(sapply(rows, `[[`, "file")) })
  qc_row <- function() { hit <- Filter(function(r) r$file == input$qc_file, isolate(qc())); if (length(hit)) hit[[1]] }
  output$qc_has_rows <- reactive(length(qc_files()) > 0)
  outputOptions(output, "qc_has_rows", suspendWhenHidden = FALSE)
  observeEvent(qc_files(), updateSelectInput(session, "qc_file", choices = setNames(qc_files(), file_id(qc_files())),
                                             selected = if (isTRUE(input$qc_file %in% qc_files())) input$qc_file))

  output$qc <- renderUI({
    rows <- qc()
    if (is.null(rows)) return(p(class = "muted", "No results in this study folder yet. Start processing first."))
    rs <- read_run_settings(studydir())
    judged <- sum(sapply(rows, function(r) !is.na(r$verdict) && !r$stale))
    tagList(
      if (!is.null(rs)) p(class = "muted", sprintf("Last run %s - study %s - %s cut-points - GGIR %s", rs[["run date"]], rs[["study"]], rs[["age group"]], rs[["GGIR version"]])),
      tags$table(class = "plain",
        tags$tr(tags$th("File"), tags$th("Calibration error"), tags$th("Valid days"), tags$th("Nights"), tags$th("Report image"), tags$th("Your verdict")),
        lapply(rows, function(r) tags$tr(
          tags$td(strong(r$id)),
          tags$td(if (is.na(r$cal_error)) tagList("not done", mark("Flag", "flag"))
                  else tagList(sprintf("%.3f g", r$cal_error), if (r$cal_error < QC_CAL_MAX) mark("Pass", "pass") else mark("Flag", "flag"))),
          tags$td(if (is.na(r$valid_days)) "-" else sprintf("%s of %s recorded", r$valid_days, r$recorded_days)),
          tags$td(if (is.na(r$nights)) "-" else r$nights, if (length(r$looks)) mark(sprintf("%d worth a look", length(r$looks)), "look"),
                  if (nrow(r$nodiary) && nzchar(r$nodiary_decision)) div(class = "muted", sprintf("%d without diary: %s", nrow(r$nodiary), c(accept = "accepted", dismiss = "dismissed")[[r$nodiary_decision]]))),
          tags$td(if (is.na(r$image)) span(class = "warn", "not found") else "ready to view"),
          tags$td(if (is.na(r$verdict)) span(class = "muted", "Not yet judged") else tagList(r$verdict, br(), span(class = "muted", r$verdict_date, if (nzchar(r$by)) paste("by", r$by)), if (r$stale) tagList(br(), mark("processed again since - judge again", "look"))))))),
      p(class = "muted", sprintf("%d of %d file(s) judged. Pass means calibration error is under %g g; that mark is about calibration only. The app points out what to look at. The verdict is yours.", judged, length(rows), QC_CAL_MAX)))
  })

  # redrawn only when another file is chosen or a verdict is saved
  output$qc_detail <- renderUI({
    req(input$qc_file); qc_tick(); r <- qc_row(); req(r)
    tagList(
      if (length(r$looks)) tagList(strong("Worth a look"), tags$ul(lapply(r$looks, tags$li))) else p("Nothing unusual in the numbers."),
      if (nrow(r$nodiary)) div(class = "box",
        strong(sprintf("%d night(s) without a diary entry", nrow(r$nodiary))),
        p(class = "muted", "This study has a sleep diary, but these nights are not in it. GGIR found them from the accelerometer alone. Accept them as found, or dismiss them. If you dismiss them, sleep is left blank for this participant."),
        tags$table(class = "plain", tags$tr(tags$th("Night of"), tags$th("Sleep onset"), tags$th("Wake"), tags$th("Sleep period")),
          lapply(seq_len(nrow(r$nodiary)), function(i) tags$tr(tags$td(nice_date(r$nodiary$calendar_date[i])), tags$td(substr(r$nodiary$sleeponset_ts[i], 1, 5)),
                 tags$td(substr(r$nodiary$wakeup_ts[i], 1, 5)), tags$td(paste(fmt(r$nodiary$SptDuration[i]), "hours"))))),
        radioButtons("nd_choice", NULL, inline = TRUE, selected = if (nzchar(r$nodiary_decision)) r$nodiary_decision else character(0),
                     choices = c("Accept these nights" = "accept", "Dismiss these nights" = "dismiss")),
        actionButton("nd_save", "Save decision", icon = icon("check"), class = "btn-sm")),
      p("Open the image and check that nights are grey (sleep) and days are coloured. Long green stretches at night, or a whole day shaded as sleep, mean the sleep numbers are not usable."),
      actionButton("qc_view", "View report image", icon = icon("eye"), class = "btn-sm"), br(), br(),
      checkboxInput("qc_looked", "I have looked at the report image", FALSE),
      selectInput("qc_verdict", "Verdict", choices = c("Choose a verdict" = "", setNames(VERDICTS, c("Usable", "Usable for activity only (sleep not trustworthy)", "Exclude")))),
      textInput("qc_reason", "Reason, in one line", width = "100%", placeholder = "Image looked at; nights grey, days coloured"),
      p(class = "muted", "Coded IDs only: no names, ward or bed numbers. Saved to ggir/QC_notes.md in the study folder."),
      actionButton("qc_save", "Save verdict", icon = icon("check"), class = "btn-primary"))
  })

  observeEvent(input$qc_view, {
    r <- qc_row(); req(r)
    if (is.na(r$image)) return(showNotification("No report image for this file. Start processing again to make it.", type = "error"))
    updateSelectInput(session, "report", selected = r$image); updateTabsetPanel(session, "tabs", "Reports")
  })
  observeEvent(input$nd_save, {
    if (is.null(input$nd_choice) || !input$nd_choice %in% c("accept", "dismiss")) return(showNotification("Choose accept or dismiss first.", type = "error"))
    set_nodiary_decision(studydir(), input$qc_file, input$nd_choice, who())
    study_log(studydir(), sprintf("nights without a diary entry %s for %s", c(accept = "accepted", dismiss = "dismissed")[[input$nd_choice]], file_id(input$qc_file)), who())
    qc_tick(qc_tick() + 1)
    showNotification(sprintf("Decision saved for %s.", file_id(input$qc_file)), type = "message")
  })
  observeEvent(input$qc_save, {
    if (!isTRUE(input$qc_looked)) return(showNotification("Look at the report image first, then tick the box.", type = "error"))
    if (!nzchar(input$qc_verdict)) return(showNotification("Choose a verdict.", type = "error"))
    if (!nzchar(trimws(input$qc_reason))) return(showNotification("Enter a reason in one line.", type = "error"))
    add_qc_note(studydir(), input$qc_file, input$qc_verdict, input$qc_reason, app_version, who())
    qc_tick(qc_tick() + 1)
    showNotification(sprintf("Verdict saved for %s.", file_id(input$qc_file)), type = "message")
  })

  #--- Study datasheet ----------------------------------------------------------
  ds_cand <- reactive({ qc(); datasheet_candidates(studydir()) })
  output$ds_who <- renderUI({
    c0 <- ds_cand()
    if (is.null(c0)) return(p(class = "muted", "No results in this study folder yet. Start processing first."))
    ok <- c0[c0$eligible, , drop = FALSE]; no <- c0[!c0$eligible, , drop = FALSE]
    tagList(
      if (nrow(ok)) checkboxGroupInput("ds_files", "Who goes in", inline = TRUE, selected = ok$file,
                                       choiceNames = lapply(seq_len(nrow(ok)), function(i) span(strong(ok$id[i]), span(class = "muted", paste0(" ", ok$verdict[i])))),
                                       choiceValues = ok$file)
      else p(class = "warn", "No participant can go in yet. Check each one in the Quality check tab first."),
      if (nrow(no)) p(class = "muted", "Cannot go in: ", paste(sprintf("%s (%s)", no$id, no$why), collapse = ", "), "."))
  })
  ds <- reactive({
    req(length(input$ds_files) > 0, length(input$ds_groups) > 0); qc_tick()
    build_datasheet(studydir(), intersect(input$ds_files, ds_cand()$file[ds_cand()$eligible]), input$ds_groups)
  })
  output$ds_preview <- renderUI({
    if (!length(input$ds_files)) return(NULL)
    if (!length(input$ds_groups)) return(p(class = "warn", "Tick at least one group under What goes in."))
    d <- ds(); x <- d$data
    tagList(
      lapply(d$warnings, function(w) div(class = "banner", w)),
      strong(sprintf("Preview: %d participant(s), %d columns", nrow(x), ncol(x))),
      div(class = "scroll",
        tags$table(class = "plain", style = "font-size:12px; white-space:nowrap",
          tags$tr(lapply(names(x), tags$th)),
          lapply(seq_len(nrow(x)), function(i) tags$tr(lapply(x[i, ], function(v) tags$td(if (is.na(v)) "" else as.character(v))))))))
  })
  observeEvent(input$ds_save, {
    if (!length(input$ds_files)) return(showNotification("Tick at least one participant.", type = "error"))
    if (!length(input$ds_groups)) return(showNotification("Tick at least one group.", type = "error"))
    f <- save_datasheet(studydir(), ds(), app_version, methods_paragraph(studydir(), app_version))
    showNotification(paste("Saved", basename(f), "and its column guide in the datasheet folder."), type = "message", duration = 8)
  })
  output$methods <- renderUI({
    status_changed(); m <- methods_paragraph(studydir(), app_version)
    if (is.null(m)) return(p(class = "muted", "Process a study first. The paragraph is written from the settings that were actually used."))
    tagList(div(class = "banner", strong("Draft to edit."), m$note),
            div(class = "box draft", div(class = "txt", .noWS = c("after-begin", "before-end"), with_blanks(m$text))),
            actionButton("methods_copy", "Copy text", icon = icon("copy")),
            tags$details(tags$summary("References to check and cite"), tags$ul(lapply(m$references, tags$li))))
  })
  observeEvent(input$methods_copy, { m <- methods_paragraph(studydir(), app_version); req(m); session$sendCustomMessage("copy_draft", m$text); showNotification("Methods paragraph copied.") })
  observeEvent(input$ds_open, { d <- file.path(studydir(), "datasheet"); if (dir.exists(d)) open_folder(d) else showNotification("No datasheet saved yet.") })

  #--- Summary (draft interpretation) -----------------------------------------
  observeEvent(qc_files(), updateSelectInput(session, "sum_file", choices = setNames(qc_files(), file_id(qc_files())),
                                             selected = if (isTRUE(input$sum_file %in% qc_files())) input$sum_file))
  draft <- reactive({ req(input$sum_file); qc_tick(); draft_summary(studydir(), input$sum_file, app_version) })

  output$summary <- renderUI({
    d <- draft()
    if (!d$ok) return(div(class = "box", d$message))
    tagList(
      div(class = "banner", strong("Draft to edit. Research use only."), "Numbers are read from the result files. The wording and the yellow blanks are yours to complete."),
      div(class = "box draft", lapply(d$header, function(h) div(class = "muted", h)),
          lapply(names(d$sections), function(n) tagList(tags$h5(n), div(class = "txt", .noWS = c("after-begin", "before-end"), with_blanks(d$sections[[n]]))))),
      actionButton("sum_copy", "Copy text", icon = icon("copy")), actionButton("sum_save", "Save draft to reports folder", icon = icon("download")),
      tags$details(tags$summary("Where each number came from"),
        tags$table(class = "plain", tags$tr(tags$th("Number"), tags$th("File"), tags$th("Column")),
          lapply(seq_len(nrow(d$sources)), function(i) tags$tr(tags$td(d$sources$number[i]), tags$td(tags$code(d$sources$file[i])), tags$td(tags$code(d$sources$column[i])))))))
  })
  observeEvent(input$sum_copy, { d <- draft(); req(d$ok); session$sendCustomMessage("copy_draft", d$text); showNotification("Draft copied.") })
  observeEvent(input$sum_save, {
    d <- draft(); req(d$ok)
    dir.create(file.path(studydir(), "reports"), showWarnings = FALSE)
    f <- file.path(studydir(), "reports", paste0(d$id, "_interpretation_DRAFT.txt"))
    # never overwrite: an earlier draft may have been edited by hand
    if (file.exists(f)) f <- sub("\\.txt$", format(Sys.time(), "_%Y%m%d_%H%M%S.txt"), f)
    writeLines(d$text, f)
    showNotification(paste("Saved", basename(f), "in the reports folder."), type = "message", duration = 8)
  })
}

shinyApp(ui, server)
