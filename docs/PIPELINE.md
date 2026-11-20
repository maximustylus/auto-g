# The pipeline: settings, outputs, reading the results

## Studies and devices

Fill this in for your own studies. The examples match `STUDIES` in `app/settings.R`.

| Study | Population | Device and wear |
|---|---|---|
| ADULT | Example: adults, free-living | Example: ActiGraph wGT3X-BT, non-dominant wrist, 7 days |
| CHILD | Example: children 7–11 y | Same device, non-dominant wrist, 8 days |

AutoG was developed with ActiLife 6.13 raw CSV exports (`.gt3x` also works), Filter Normal (LFE off).

## Decisions that are settled (change only with the user)

| Setting | Value | Why |
|---|---|---|
| GGIR version | 3.3-8 | Results differ between versions; build machine and laptop must match |
| Acceleration metric | ENMO, 5 s epochs | Cut-points were derived at 5 s; epoch length changes MVPA |
| Timezone | `TIMEZONE` in `app/settings.R` | Check it against a recording's own timestamps |
| Non-wear | GGIR default (60-min window, 15-min steps) | |
| First and last day | excluded (`excludefirstlast = TRUE`) | Recordings start and end part-way through a day |
| Valid day | ≥16 h (Part 2), ≥2/3 of the window (Part 5) | |
| Sleep | HDCZA; diary guides if present (`relyonguider = FALSE`) | Diary guides the search, sensor decides exact times |
| Time windows | `MM` (midnight–midnight) and `WW` (waking–waking) | |
| MVPA bouts | 1, 5, 10 min, 80% criterion | |
| Reports | new timeline report **and** legacy report | The legacy one feeds the composite image |

## Age group → cut-points (ENMO, mg, ActiGraph, non-dominant wrist)

| Age group | Light | Moderate | Vigorous | Source and caveat |
|---|---|---|---|---|
| Paediatric 7–11 y | 35.6 | 201.4 | 707.0 | Hildebrand 2014/2016 |
| Adolescent 12–17 y | 44.8 | 100.6 | 428.8 | **Adult values applied.** No validated ActiGraph wrist ENMO set exists. Say so in methods. |
| Adult 18–64 y | 44.8 | 100.6 | 428.8 | Hildebrand 2014/2016 |
| Senior 65+ y | 18 | 60 | 428.8 | Migueles 2021 (≥70 y). No vigorous cut-point published; the adult value is carried over so Part 5 runs. |

Values are from GGIR's own "Published cut-points" vignette and are **device-specific**. Do not use
the GENEActiv children's set (56.3/191.6/695.8) on ActiGraph data. Verify against the papers before
publishing: Hildebrand 2014 doi:10.1249/mss.0000000000000289, Hildebrand 2016
doi:10.1111/sms.12795, Migueles 2021 doi:10.3390/s21103326.

Defaults: ADULT → adult, CHILD → paediatric.

## What GGIR produces (under `ggir\output_raw\results\`)

| File | One row per | Use it for |
|---|---|---|
| `QC\data_quality_report.csv` | file | calibration error, file health |
| `part2_summary.csv`, `part2_daysummary.csv` | person, day | valid days, mean ENMO, M120/M60/M10/M5, intensity gradient |
| `part4_nightsummary_sleep_cleaned.csv` | night | onset, wake, sleep period (SPT), sleep in SPT, WASO |
| `part5_daysummary_WW_L…M…V…_T5A5.csv` | waking day | minutes inactive/light/moderate/vigorous, bouted MVPA, mean mg |
| `part5_personsummary_…csv` | person | averages of the above |
| `part6_summary.csv` | person | interdaily stability (IS), intradaily variability (IV), cosinor, L5 |
| `file summary reports\*.pdf` | file | visual reports |

The file-name suffix encodes the cut-points, so a different age group writes new files rather than
overwriting.

**Numbers come from the CSVs. The image is for looking.** The legacy report averages over days that
Part 5 excludes, so its headline figures differ slightly from the CSVs.

## Checks after every run (in this order)

1. `data_quality_report.csv`: `cal.error.end` < 0.01 g. Higher, or calibration not done → flag or
   exclude the file.
2. Report image: are the nights grey (sleep) and the days coloured? Long green (non-wear) stretches
   at night, or a whole day shaded as sleep, mean the sleep numbers for that day are not usable.
3. `part2_summary.csv`: number of valid days.
4. `run_settings.txt`: right study, age group, GGIR version.

Worth a look (not pass/fail; the app's Quality check tab lists these per file): a night's sleep
period shorter than 5 h or longer than 11 h; more than 2 h awake within the sleep period (WASO);
a sleep period that starts between 08:00 and 18:00 (a nap, or a still wrist read as sleep; the
younger children take longer afternoon naps).

**Nights without a diary entry.** When `sleeplog_<study>.csv` exists, GGIR's cleaned night table
keeps only nights with a diary entry (`only.use.sleeplog` is switched on inside GGIR whenever a
diary is supplied). The other nights remain in `QC\part4_nightsummary_sleep_full.csv`. AutoG
shows those with cleaning code 0 or 1 and asks the user, per participant, to accept them as the
accelerometer found them or dismiss them.
There is no documented pass threshold for the number of valid days; it is shown as a count.
The verdict per file (usable / usable for activity only / exclude) is always the user's.

## Known traps

- **Idle Sleep Mode** (ActiGraph) back-fills identical values while the device is still, which can
  be a large share of a recording. Untick it when devices are initialised.
- **Mixed sample rates** (60 Hz and 30 Hz). GGIR handles it; standardise for the study.
- **People confined to bed:** a still wrist looks like sleep to HDCZA. Without a diary or ward log,
  daytime rest and disturbed nights cannot be told apart from sleep. "Sleep efficiency" without a
  diary is sleep ÷ SPT, not sleep ÷ time in bed.
- **MVPA is often zero for people confined to bed.** Use mean mg, M60/M5, intensity gradient, IS/IV and
  sleep timing as the outcomes that can show change.
- The 30-minute MVPA line on the legacy report is a generic reference, not a study criterion.

## The interpretation paragraph

One paragraph per participant, in this order, numbers taken from the CSVs:

1. **Who and what:** age group, setting, device, wrist, days recorded.
2. **Data quality:** wear per day, removals, calibration error.
3. **Activity volume:** mean mg per day with range; MVPA with the cut-point named; whether zero
   MVPA is real (compare M5 with the moderate threshold).
4. **Time use:** share of the waking day inactive, minutes of light activity, M60, intensity gradient.
5. **Sleep:** onset and wake ranges, SPT, WASO, efficiency — typical nights first, then each
   deviating night with what the trace shows and what is unknown.
6. **Rhythm:** IS, IV, cosinor fit.
7. **Caveats and what needs the log.**
8. **One-sentence overall reading**, without claiming cause.

State what the data show. Do not diagnose, and do not explain a deviating night without the log.

## Reference results (the golden test)

Pick one real recording per age group whose results you have checked by hand, and keep its values
(`cal.error.end`, still windows used, nights after cleaning, sleep period hours in order, IS / IV,
bouted MVPA per day) in `private/reference_results.md`. That folder is ignored by git: the values
are study data. The `qc-steward` compares every new installation against them
(`docs/VERSIONING_QC.md`).

**IS and IV depend on the light cut-point** in GGIR 3.3-8 (Part 6). Changing the light cut-point changes both, by
a few percent in development testing. So IS and IV are not comparable between age groups, and
reference values must be recorded with the cut-points currently in use.
