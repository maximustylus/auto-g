# Shared by app.R (menus) and ggir_run.R (the run). These are STUDY DECISIONS:
# read docs/PIPELINE.md before changing anything here, and record any change in
# CHANGELOG.md (the settings fingerprint will change).

# One entry per study folder. Replace these examples with your own studies.
STUDIES <- c(ADULT = "ADULT - example adult study", CHILD = "CHILD - example paediatric study")

# Time zone the devices were worn in (an Olson name, e.g. "Europe/London",
# "America/New_York"). SET THIS before processing study data, and check it against a
# recording's own timestamps. UTC is only a placeholder.
TIMEZONE <- "UTC"

AGE_GROUPS <- list(
  paediatric = list(label = "Paediatric (7-11 y) - Hildebrand 2014/2016",
                    lig = 35.6, mod = 201.4, vig = 707.0),
  adolescent = list(label = "Adolescent (12-17 y) - adult values, no validated wrist set",
                    lig = 44.8, mod = 100.6, vig = 428.8),
  adult      = list(label = "Adult (18-64 y) - Hildebrand 2014/2016",
                    lig = 44.8, mod = 100.6, vig = 428.8),
  senior     = list(label = "Senior (65+ y) - Migueles 2021, no vigorous cut-point",
                    lig = 18.0, mod = 60.0,  vig = 428.8)
)
AGE_DEFAULT <- c(ADULT = "adult", CHILD = "paediatric")

# Returns NULL if the data root is usable, otherwise a message.
check_root <- function(root) {
  if (!nzchar(root)) return("Choose the data folder first.")
  if (grepl(" ", root))
    return(paste0("The data folder path contains a space: ", root, "\n",
                  "GGIR's file reader cannot handle that. Use a path without spaces, e.g. D:/GGIR"))
  if (!dir.exists(root)) return(paste("Folder not found:", root, "- is the drive plugged in?"))
  NULL
}
