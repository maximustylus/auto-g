---
name: interpret-participant
description: Produce the two end products for one participant - the report image and the written interpretation paragraph - from a finished GGIR run. Use when the user asks for the visuals, the interpretation, or "the write-up" for a participant.
---

# Visuals and interpretation for one participant

1. **Check it is ready.** `<study>\ggir\QC_notes.md` has a verdict for this file. "Exclude": stop
   and tell the user why. No verdict: run `qc-steward` first.
2. **Visual.** `<study>\reports\<ID>_GGIR_report.jpg` (left: one panel per day; right: summary
   bars). If it is missing but `old_report_<file>.pdf` exists under
   `ggir\output_raw\results\file summary reports\`, rebuild it:
   `R\bin\Rscript.exe --vanilla -e "source('app/compose_reports.R'); compose_reports('D:/GGIR/CHILD')"`
   (substitute the study folder). Look at the image yourself before describing it.
3. **Interpretation.** Delegate to `report-interpreter`, giving it the study folder and the ID.
   It returns the paragraph plus a table of every number and the CSV column it came from.
4. **Review before showing.** Spot-check three numbers against the CSVs. Confirm the paragraph
   follows the eight-element template in `docs/PIPELINE.md`, names the cut-points, and makes no
   causal or clinical claim.
5. **Deliver.** Save as `<study>\reports\<ID>_interpretation.md` (paragraph, then the source table,
   then: study, age group, cut-points, GGIR version, app version, date, "draft for investigator
   review; research use only"). Show the user the paragraph and the image path.

Reading the image
- Top trace per day: wrist angle. Bottom trace: movement.
- Grey = sleep window, turquoise = awake within it, blue = inactive, yellow = light, orange/red =
  moderate/vigorous, green = not worn.
- Hatched bars are weekend days. Dashed lines are GGIR's generic reference values, not study criteria.
- Headline numbers on the image can differ slightly from the CSVs. Report the CSV values.
