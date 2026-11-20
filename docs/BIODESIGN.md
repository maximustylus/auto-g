# Biodesign brief

Written in the Biodesign order: identify the need, define what a solution must do, then how it is
implemented and governed. It is the reference for judging whether a proposed change is worth
making (the `biodesign-reviewer` agent uses it). Adapt the stakeholders, risks and governance to
your own site before relying on it.

## 1. Identify

### Need statement
A way for **clinician-researchers** to turn **raw wrist-accelerometer recordings** from adult and
paediatric participants into **a trustworthy picture and written summary of activity, sleep and
rest–activity rhythm**, on **locked-down institutional computers**, without specialist
programming and without participant data leaving the device.

### The problem AutoG was built for
- Device software (for example ActiLife) produces counts and its own sleep scores, not the open
  raw-acceleration metrics (ENMO, intensity gradient, IS/IV) that current research uses, and it is
  driven by hand.
- GGIR produces those metrics but is an R package with more than 300 arguments. Scripts passed
  between people drift: cut-points meant for another age group or device, a missing time zone.
- Corporate and clinical laptops often have no internet and no admin rights, so R and its packages
  cannot be installed the usual way.
- Participant data, especially from children and patients, must not go to a cloud service or a
  personal computer.

### Stakeholders
| Stakeholder | Interest | What would make them reject it |
|---|---|---|
| Investigator | Correct, reproducible results with little effort | Silent wrong settings; results that change between runs |
| Research staff | A procedure they can follow | Needing R knowledge; unclear errors |
| Participants and parents | Privacy; no added burden | Data leaving the institution |
| Clinical staff (if participants are patients) | Minimal extra work | A long diary; a device interfering with care |
| IT and information security | No unapproved software risk, no data egress | Installers, network listeners, admin prompts |
| Ethics board, data protection officer | Data handled as approved | Copies of raw data in unapproved places |
| Journal reviewers | Methods that can be reproduced | Unreported software versions or cut-points |

### What to expect from different populations
- For free-living adults, the standard outcomes (bouted MVPA, sleep timing) are usually informative.
- For people confined to bed, moderate-to-vigorous activity is often zero and most of the waking
  day is inactive. Volume (mean acceleration, M60), rhythm (IS/IV) and sleep timing are then the
  informative outcomes, and a still wrist is easily read as sleep. A diary or ward log is needed to
  tell rest from sleep.

## 2. Requirements a solution must meet

| # | Requirement | How AutoG meets it |
|---|---|---|
| R1 | Runs with no internet, no admin, no installer | Portable R and locked packages in one folder |
| R2 | No data egress | Binds to 127.0.0.1; no network calls; package repositories disabled |
| R3 | Correct settings without expertise | Age group fixed per study sets the cut-points; everything else fixed |
| R4 | Reproducible | Pinned GGIR, locked packages, settings fingerprint, `run_settings.txt` |
| R5 | Same results as a reference pipeline | Parity check against an optional reference script; golden test |
| R6 | Output a clinician can read | Composite report image |
| R7 | Written interpretation | Summary tab: eight-section draft, numbers read from the result files |
| R8 | Data quality judged before results are used | Quality check tab: prompts, then a verdict by a person |
| R9 | Sleep anchored to a diary where there is one | Diary picked up automatically; nights without a diary entry accepted or dismissed by a person |
| R10 | Usable after weeks away, by non-technical staff | Home screen with four steps, welcome with practice, Help, infographic |

## 3. Implement

### Intended use and limits
Research use only: processing and summarising accelerometer recordings for research studies.
AutoG is **not** a medical device. Its output must not be used to diagnose, monitor or make
treatment decisions for an individual. If the intended use ever moves towards clinical
decision-making, the regulatory position must be reassessed first.

### Risks
| Risk | Consequence | Control |
|---|---|---|
| Wrong age group chosen | MVPA wrong by a large factor | Age group fixed per study, always shown; changing it needs confirmation and is logged |
| Settings drift between machines | Results not comparable | Fingerprint; parity check; pinned GGIR; golden test |
| Daytime rest read as sleep | False sleep durations | Daytime-sleep prompt; image check; "usable for activity only" verdict; diary |
| Idle Sleep Mode on (ActiGraph) | Possible non-wear and sleep artefacts | Untick at initialisation; image check |
| Interpretation over-reaches | Causal or clinical claims from movement data | Draft only; blanks for what the files cannot tell; "state, do not explain" rule |
| Automation bias | A green mark taken as the verdict | Marks apply to one check, never to a file; the verdict is always a person's |
| Raw data copied to an unapproved place | Privacy breach | No backup feature until a location is approved in writing; coded IDs only |
| Unsigned program on a managed device | Blocked, or a policy breach | Tell IT what it is (portable R, local only) and ask for approval; do not work around controls |
| Single maintainer | App cannot be updated | Handover file, playbook, changelog, automated checks |

### Governance to confirm locally before use
- Ethics approval covers processing on the chosen computer and any transfer of the bundle.
- IT or information security knows the bundle exists and has approved or accepted it.
- Where raw files, outputs and any backups may live, and for how long.
- Who may use the app, and what training they need (the welcome teaches reading the report image).

### Product decisions taken in the original deployment
These were the original investigator's choices. Make your own and record them here.
- Several non-technical users share one laptop; they need the image, the summary and the datasheet.
- Anyone using AutoG may record the quality verdict (a reviewer advised investigator confirmation;
  the investigator chose otherwise and required onboarding to teach the image check).
- In a study with a diary, nights without a diary entry are shown and a person accepts or
  dismisses them per participant.
- Sleep periods starting 08:00–18:00 are pointed out (younger children nap in the afternoon).
- One study folder per datasheet, one row per recording; no pooling across age groups.
- Users identify themselves by initials only; this is a record, not a login.

### Protocol recommendations
1. Untick Idle Sleep Mode; use one sample rate for all devices.
2. Start recordings at 00:00 on the day of issue and run 8 days, so 7 full days survive exclusion.
3. A sleep diary (free-living) or ward log (patients) for every participant: in bed, lights out,
   wake, out of bed, naps, device removals, plus free-text events for patients.
4. Report: device, firmware, sample rate, wrist, epoch, metric, cut-points with citation, non-wear
   method, valid-day rule, GGIR version, and whether Idle Sleep Mode was on.

### What would show it works
- The golden test passes on every installation.
- A second person processes a file correctly from the Help tab and infographic alone.
- Diary-guided sleep agrees with the diary within 30 minutes on most nights.
