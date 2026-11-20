# UI and UX

## Who uses it

| User | Context | What they need |
|---|---|---|
| The investigator (primary) | Clinician-researcher, corporate laptop, knows the study, not an R user | Process new files correctly without remembering settings; a picture and numbers to interpret |
| A research assistant (expected) | Batch-processing downloads after device return | A procedure that cannot be done wrong quietly |
| A reviewer or collaborator | Sees only the outputs | Report image, CSVs, `run_settings.txt` |

Sessions are infrequent (a device comes back every week or two), so the app must be usable from
cold each time. Runs are long, so the user will walk away.

## Principles

1. **One screen, one decision path:** folder → study → age group → Run. Nothing else is required.
2. **The risky choice is visible.** Age group sets the cut-points, so the three numbers are shown
   under the menu before anything runs.
3. **Check before, not after.** Folder problems (space in path, missing folder, no files, no diary)
   are stated in the side panel before Run is pressed.
4. **Never trap the user.** No native dialogs (they open behind the browser). Stop always works.
   A closed tab can be reopened at `http://127.0.0.1:8765`.
5. **Say what happened and what to do.** Messages name the cause and the next action in plain words.
6. **Leave a record.** Every run writes `run_settings.txt` and a log next to the output.
7. **Little decoration.** System font, standard Bootstrap controls, one brand header and one accent
   colour (`docs/BRAND.md`). This is a lab instrument.

## Screen inventory (app 0.2.0+)

Side panel
- Data folder (text box, remembered between sessions) and **Browse…** (in-page picker: drive
  buttons, Up one level, folder list, a hint when `ADULT/raw` or `CHILD/raw` is found, a warning on spaces)
- Study; the locked age group with its cut-points; Advanced (Change age group, processor cores,
  Reprocess files already done)
- Live checks: number of raw files, diary found or not
- **Start processing**, **Stop**, and the reminder about power, sleep and the drive

Main panel (app 0.4.0+)
- **Home** (0.9.0+, first tab): study bar (study, locked age group, cut-points), four step cards
  with the current step highlighted, participant list with a workflow status and next action
- **Progress**: headline (Ready / Running – step k of 6 – elapsed / Finished / Finished, but n files
  did not complete / Stopped – reason), six step rows with a bar and "n of N files", a box naming
  any file that did not get through, and the full log under "Show details"
- **Quality check**: one row per processed file (calibration error with Pass/Flag, valid days as a
  count, nights with "worth a look", image ready or not, the user's verdict), then the form:
  what to look at, View report image, the "I have looked" tick box, verdict, one-line reason
- **Reports**: open-folder buttons, report picker, the composite image at full width
- **Datasheet** (0.6.0+): who goes in (checked, not excluded), what goes in (four groups),
  a scrolling preview, warnings for mixed cut-points, Save datasheet, Open datasheet folder
- **Summary**: participant picker, draft banner, the eight-section draft with yellow `[FILL IN]`
  blanks, Copy text, Save draft, and "Where each number came from"
- **Help** (0.11.0+): six fold-out cards and "Show the welcome again". Content lives in
  `app/help.R`; the datasheet column list is generated from `DS_COLS`, so it cannot drift.
- **Welcome** (0.11.0+): four screens in a dialog, once per set of initials; screen 3 teaches the
  report picture and has three practice questions.

Rules these screens keep (from the biodesign review)
- A mark belongs to one check, never to the file. Only calibration has a documented pass limit.
- The app never sets a verdict and never drafts without a current one.
- The draft uses numbers read from the CSVs only, one recording per draft, no comparison between
  recordings of the same participant, no cause, no overall reading.
- The draft label is part of the text that is copied or saved.

## States to handle

| State | What the user sees |
|---|---|
| No folder chosen | "Choose the data folder first." |
| Space in path | Warning with an example of a valid path |
| Folder missing | "Folder not found … is the drive plugged in?" |
| No raw files | Warning naming the folder that was searched |
| Running | State "Running…", log scrolling, second Run refused |
| Stopped by user | "Stopped. Files already finished are kept; rerun to continue." |
| Worker error | "Stopped – <R error message>" |
| Finished | "Finished. See the Reports tab." |

## Wording rules

- Name things by what the user sees: "data folder", "age group", "report image".
- Buttons are verbs: Start processing, Stop, Browse, Use this folder.
- Errors: cause, then action. No R jargon unless it is the literal error from the log.
- Units always shown (mg, minutes, hours).

## Known gaps (backlog, most valuable first)

1. ~~QC is not surfaced.~~ Built in 0.4.0 (Quality check tab).
2. ~~No per-file progress.~~ Built in 0.4.0 as progress by step: GGIR works step by step across
   all files, so "file 2 of 5" does not exist.
3. ~~No interpretation draft.~~ Built in 0.4.0 (Summary tab).
4. **File naming is manual.** Offer to copy `C003 (2026-01-15)RAW.csv` to `raw\C003_2026-01-15.csv`.
5. ~~Overwrite is easy to forget after changing age group.~~ Built in 0.7.0 as a side-panel warning.
6. ~~Version is invisible.~~ Built in 0.5.0: app and GGIR version in the header (the settings
   fingerprint is still not shown).
7. **Sleep is not prevented.** The laptop can sleep mid-run; Windows has no `caffeinate`. Options
   need testing under corporate policy.
8. **The legacy report shows a generic 30-minute MVPA line** that does not apply to people confined
   to bed; annotate or hide it for such studies.
9. Accessibility: check keyboard-only use of the folder picker and colour contrast of `.muted` text.
10. ~~A run is lost to the app if the app is restarted mid-run.~~ Fixed in 0.16.0: the run state is
    kept in the study folder.
11. **A file GGIR skips never appears in the Quality check table** (it is named on the Progress tab
    only). List raw files with no results as "not processed".
12. **The remembered data folder is saved only when Run is pressed.** Save it when it is chosen.
13. **No search or filter in the participant list.** Fine at 50 participants; needed well before 200.

Each backlog item is MINOR (no result change). Item 3 must never write numbers that are not read
directly from the CSVs.
