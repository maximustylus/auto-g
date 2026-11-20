# Onboarding (the welcome) and the Help tab. Static content only: no study
# data, no real recordings. The day strips are simplified ILLUSTRATIONS drawn in
# the colours GGIR uses in its report picture (sampled from a real report).
REPORT_COLOURS <- c(sleep = "#E0E0E0", wake = "#C8F0E8", inactive = "#D8D8F8", light = "#F8F8C8",
                    moderate = "#F8E0C8", vigorous = "#F8C8C8", nonwear = "#98E898")
REPORT_KEY <- c(sleep = "Sleep", wake = "Awake during the night", inactive = "Inactive", light = "Light activity",
                moderate = "Moderate activity", vigorous = "Vigorous activity", nonwear = "Device not worn")

# One day, midnight to midnight. segs = list(c(kind, hours), ...), hours summing to 24.
day_strip <- function(segs, label = NULL) {
  div(class = "strip-wrap", if (!is.null(label)) div(class = "strip-label", label),
    div(class = "strip", role = "img", `aria-label` = paste(sapply(segs, function(s) sprintf("%s for %s hours", REPORT_KEY[[s[1]]], s[2])), collapse = ", "),
        lapply(segs, function(s) div(style = sprintf("flex:%s; background:%s", s[2], REPORT_COLOURS[[s[1]]])))),
    div(class = "strip-axis", span("midnight"), span("6am"), span("noon"), span("6pm"), span("midnight")))
}
colour_key <- function() div(class = "key", lapply(names(REPORT_KEY), function(k)
  span(span(class = "sw", style = paste0("background:", REPORT_COLOURS[[k]])), REPORT_KEY[[k]])))

DAY_GOOD     <- list(c("sleep", 3), c("wake", .3), c("sleep", 3.2), c("inactive", 3), c("light", 1), c("inactive", 2.5), c("moderate", .7), c("inactive", 4), c("light", 1.3), c("inactive", 3.5), c("sleep", 1.5))
DAY_NONWEAR  <- list(c("nonwear", 5.5), c("sleep", 1), c("inactive", 4), c("light", 1.2), c("inactive", 5.3), c("moderate", .5), c("inactive", 5), c("sleep", 1.5))
DAY_ALLSLEEP <- list(c("sleep", 7), c("wake", .5), c("sleep", 6), c("inactive", 1), c("sleep", 5.5), c("wake", .4), c("sleep", 3.6))
DAY_GOOD2    <- list(c("sleep", 5.8), c("wake", .4), c("sleep", 1), c("inactive", 2.3), c("light", 1.5), c("inactive", 4), c("vigorous", .4), c("moderate", .6), c("inactive", 5), c("light", .8), c("sleep", 2.2))

practice <- function(n, segs, correct, why) div(class = "practice", `data-correct` = correct,
  day_strip(segs, sprintf("Practice %d", n)),
  div(class = "pr-q", "Could this day's sleep numbers be used?",
      tags$button(type = "button", class = "btn btn-default btn-sm pr-btn", `data-answer` = "yes", "Yes"),
      tags$button(type = "button", class = "btn btn-default btn-sm pr-btn", `data-answer` = "no", "No")),
  div(class = "pr-fb", `data-why` = why))

wstep <- function(k, ic, title, ...) div(class = "wstep", `data-step` = k, style = if (k > 1) "display:none",
  div(class = "wicon", icon(ic)), div(class = "wcount", sprintf("%d of 4", k)), h3(title), ...)

welcome_modal <- function(who) modalDialog(title = NULL, easyClose = FALSE, size = "l", class = "welcome",
  wstep(1, "wand-magic-sparkles", "Welcome to AutoG",
    p("AutoG turns a week of wrist recordings into three things for each participant:"),
    div(class = "trio", div(icon("image"), strong("A report picture"), span("every day and night on one page")),
        div(icon("file-lines"), strong("A written summary"), span("a draft that you complete and edit")),
        div(icon("table"), strong("A row in the study datasheet"), span("activity, sleep and rhythm numbers"))),
    p("You follow four steps on the Home screen: add files, process, check, collect. AutoG shows which step you are on.")),
  wstep(2, "folder-open", "Where files go",
    p("Each study has its own folder. Put each recording in the study's ", tags$code("raw"), " folder and name it with the participant's coded ID, an underscore and the date:"),
    p(tags$code("P001_2026-01-15.csv")),
    tags$ul(tags$li("Use the coded ID only. Never a name."), tags$li("Do not rename, edit or delete a file once it is in the raw folder."),
            tags$li("AutoG writes its results into the same study folder. It never changes the raw files."))),
  wstep(3, "eye", "Reading the report picture",
    p("After processing, you look at each participant's picture and say whether it can be used. This is the part that needs your judgement."),
    colour_key(),
    p(class = "muted", "Simplified illustrations in the report's colours, not real recordings. A real picture shows several days, one under another."),
    day_strip(DAY_GOOD, tagList(span(class = "mark pass", icon("check"), "Usable"), " Nights are grey, days are coloured.")),
    day_strip(DAY_NONWEAR, tagList(span(class = "mark flag", icon("triangle-exclamation"), "Not usable for sleep"), " Green at night: the device was not worn.")),
    day_strip(DAY_ALLSLEEP, tagList(span(class = "mark flag", icon("triangle-exclamation"), "Not usable for sleep"), " A whole day shaded as sleep: a still wrist was read as sleeping.")),
    h4("Try three"),
    practice(1, DAY_GOOD2, "yes", "Nights are grey and the day is coloured. A short wake in the night is normal."),
    practice(2, DAY_ALLSLEEP, "no", "Almost the whole day is shaded as sleep. Choose \"usable for activity only\" and say what you saw."),
    practice(3, DAY_NONWEAR, "no", "The night is green: the device was off the wrist, so there is no sleep to measure."),
    p(class = "muted", id = "pr-need", "Answer all three to continue.")),
  wstep(4, "shield-halved", "Four rules",
    div(class = "rules", div(icon("lock"), strong("Everything stays on this laptop."), span("Do not copy, email or upload study files.")),
        div(icon("id-card"), strong("Coded IDs only."), span("No names, ward or bed numbers anywhere, including in reasons you type.")),
        div(icon("plug"), strong("Keep the laptop plugged in and awake"), span("while files are processing.")),
        div(icon("flask"), strong("AutoG is for research."), span("It is not for decisions about an individual's care."))),
    p("You are recorded as ", strong(who), " on what you process and check. If you are unsure about a picture, choose nothing and ask the investigator.")),
  footer = tagList(tags$button(type = "button", class = "btn btn-default", id = "w_back", style = "visibility:hidden", icon("arrow-left"), "Back"),
                   tags$button(type = "button", class = "btn btn-primary", id = "w_next", "Next", icon("arrow-right"))))

help_card <- function(ic, title, ..., open = FALSE) tags$details(class = "help", open = if (open) NA, tags$summary(icon(ic), title), div(class = "help-body", ...))

help_ui <- function() tagList(
  div(class = "helpbar", h4("Help"), actionButton("welcome_again", "Show the welcome again", icon = icon("wand-magic-sparkles"), class = "btn-sm")),
  div(class = "docs",
    div(class = "doc", icon("map"), strong("Infographic"), span("Install and set up, and using AutoG, on two pages."),
        div(tags$a(class = "btn btn-default btn-sm", href = "AutoG-infographic-light.pdf", target = "_blank", icon("sun"), "Light, for printing"),
            tags$a(class = "btn btn-default btn-sm", href = "AutoG-infographic-dark.pdf", target = "_blank", icon("moon"), "Dark"))),
    div(class = "doc", icon("book"), strong("Technical manual"), span("Settings, data flow, quality control and notes for IT. For the investigator, IT, ethics and reviewers."),
        div(tags$a(class = "btn btn-default btn-sm", href = "AutoG-technical-manual-light.pdf", target = "_blank", icon("sun"), "Light, for printing"),
            tags$a(class = "btn btn-default btn-sm", href = "AutoG-technical-manual-dark.pdf", target = "_blank", icon("moon"), "Dark")))),
  help_card("list-check", "The four steps", open = TRUE,
    tags$ol(tags$li(strong("Add files."), " Put each recording in the study's raw folder, named ", tags$code("ID_date.csv"), "."),
            tags$li(strong("Process."), " Press Start processing. Allow about 15 minutes per file. Keep the laptop plugged in and awake. You can watch the Progress tab or walk away."),
            tags$li(strong("Check."), " For each participant, open the report picture, look at it, and record a verdict with a one-line reason."),
            tags$li(strong("Collect."), " Open the picture and the draft summary for each participant, and build the study datasheet when everyone is checked."))),
  help_card("image", "Reading the report picture",
    p("Each row of the picture is one day, midnight to midnight. The colours show what the wrist was doing."), colour_key(),
    p(class = "muted", "Simplified illustrations, not real recordings."),
    day_strip(DAY_GOOD, tagList(span(class = "mark pass", icon("check"), "Usable"), " Nights are grey, days are coloured.")),
    day_strip(DAY_NONWEAR, tagList(span(class = "mark flag", icon("triangle-exclamation"), "Not usable for sleep"), " Green at night: the device was not worn.")),
    day_strip(DAY_ALLSLEEP, tagList(span(class = "mark flag", icon("triangle-exclamation"), "Not usable for sleep"), " A whole day shaded as sleep.")),
    p("The bars on the right of the real picture are summaries. The dashed 30-minute line is a general reference, not a target for this study.")),
  help_card("clipboard-check", "Choosing a verdict",
    tags$table(class = "plain", tags$tr(tags$th("Verdict"), tags$th("Choose it when"), tags$th("What happens")),
      tags$tr(tags$td(strong("Usable")), tags$td("Calibration passes, nights are grey and days are coloured on most days."), tags$td("Everything goes into the summary and the datasheet.")),
      tags$tr(tags$td(strong("Usable for activity only")), tags$td("Activity looks right but the nights cannot be trusted: green at night, or days shaded as sleep."), tags$td("Sleep and rhythm are left blank.")),
      tags$tr(tags$td(strong("Exclude")), tags$td("Calibration is flagged, very few valid days, or the picture makes no sense."), tags$td("No summary, and the participant stays out of the datasheet."))),
    p(sprintf("AutoG marks calibration Pass when the error is under %g g, and lists as worth a look: nights shorter than %g hours or longer than %g hours, more than %g hours awake in the night, and any sleep period that starts between %02d:00 and %02d:00 (a nap, or a still wrist read as sleep). Those are prompts to look, not verdicts.", QC_CAL_MAX, NIGHT_MIN_H, NIGHT_MAX_H, WASO_MAX_H, DAY_SLEEP_FROM, DAY_SLEEP_TO)),
    p(strong("Nights without a diary entry."), " If the study has a sleep diary but some nights are not in it, AutoG lists those nights under the participant and asks you to accept them as the accelerometer found them, or dismiss them. Dismissing leaves sleep blank for that participant. Your choice is recorded with your initials."),
    p("Describe what you see. Do not explain why a night looks odd: that needs the diary or ward log. If the file is processed again, AutoG asks for the verdict again.")),
  help_card("table", "What the datasheet columns mean",
    p("The same list is saved next to every datasheet as the column guide."),
    div(class = "scroll", tags$table(class = "plain", tags$tr(tags$th("Group"), tags$th("Column"), tags$th("Meaning"), tags$th("Unit")),
      lapply(seq_len(nrow(DS_COLS)), function(i) tags$tr(tags$td(DS_COLS$group[i]), tags$td(tags$code(DS_COLS$name[i])), tags$td(DS_COLS$meaning[i]), tags$td(DS_COLS$unit[i])))))),
  help_card("triangle-exclamation", "When something goes wrong",
    tags$table(class = "plain", tags$tr(tags$th("What you see"), tags$th("What to do")),
      tags$tr(tags$td("Could not be read"), tags$td("The file is empty, cut short or not a recording. Export it again from the device software and replace it, then process again.")),
      tags$tr(tags$td("Finished, but a file did not complete"), tags$td("Open Progress. The box names the file and shows the message. The other files are fine.")),
      tags$tr(tags$td("Nothing happens for a long time"), tags$td("Step 1 is the slow one. If the elapsed time keeps counting, it is working. If the laptop went to sleep, press Start processing again: finished files are kept.")),
      tags$tr(tags$td("Folder not found"), tags$td("The drive is not connected, or the path has a space in it. Choose the folder again with Browse.")),
      tags$tr(tags$td("Different age group from the last run"), tags$td("Stop and ask the investigator. Every participant in a study must use the same age group.")),
      tags$tr(tags$td("The browser tab was closed"), tags$td("Open the address shown in the black AutoG window. A run that was going carries on.")))),
  help_card("shield-halved", "Rules and limits",
    tags$ul(tags$li("Everything stays on this laptop. Coded IDs only."), tags$li("AutoG is for research use. It is not a medical device and is not for decisions about an individual."),
            tags$li("The summary is a draft: complete the yellow blanks and edit the wording before it is used."),
            tags$li("Your initials are a record of who did what. They are not a password."))))
