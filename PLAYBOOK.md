# The AutoG playbook

How AutoG was designed, built, tested and released, written so the method can be reused. AutoG
itself is one result of it: a GGIR front end for locked-down laptops. The same playbook fits any
research pipeline that must run where its maintainer cannot.

It was developed by a clinician-researcher working with an AI coding assistant (Claude Code). The
people decided; the assistant built, tested and wrote things down. Everything below is how that
division of labour was kept safe.

---

## 1. The situation it solves

- The analysis must run on a **managed computer with no internet and no admin rights**.
- The person maintaining it works on **a different machine** (here a Mac) that does have internet.
- The two machines **never talk to each other**. Files move on an encrypted transfer drive.
- The people running it day to day are **not programmers**.
- The data are **participant data** that must not leave the managed computer.

## 2. Principles

1. **One source of truth.** All code lives on the build machine. The managed laptop runs a built
   copy. A fix made on the laptop is written down so it can be carried back; otherwise the next
   release silently undoes it.
2. **Science is fixed; people decide.** Every analysis setting (cut-points, epoch, time zone, each
   `GGIR()` argument) is a study decision. Software never changes one on its own. The only choice
   left to users is the age group, fixed once per study, always visible, changeable only with
   confirmation and a log entry.
3. **Numbers come from the source.** Every number AutoG shows is read from GGIR's own result
   files and can be traced to a file and column. Nothing is recalculated. What the files cannot
   tell (setting, wrist, why a night looks odd) is left as a visible blank, never guessed.
4. **The machine points; a person judges.** AutoG marks what is worth a look. Quality verdicts,
   accepting nights without a diary, and the interpretation are always a person's, recorded with
   their initials.
5. **Prove it, don't assume it.** A pinned GGIR, a locked package list, a settings fingerprint, a
   parity check, a golden test, automated checks. Each release says which of them passed.
6. **Write for the next session.** A handover file carries the state between machines and between
   working sessions, because no one remembers the last conversation.
7. **Show before building.** Every new screen is shown as a mockup and agreed before code.

## 3. Roles

| Layer | Who | Does |
|---|---|---|
| Investigator | A person | Owns the science and the decisions. Approves every scientific change. |
| Lead agent | The main AI session | Talks to the investigator, plans, delegates, signs off. |
| Sub-agents | Specialists in `.claude/agents/` | One bounded job each, then report back: `pipeline-scientist`, `shiny-ui-engineer`, `windows-packager`, `report-interpreter`, `biodesign-reviewer`. |
| Stewards | Sub-agents that only check | `version-steward` (are we running what we think?), `qc-steward` (are the numbers right, is each file usable?). They never edit. |
| Workers | Plain R processes, no AI | Launcher, interface, GGIR worker, report composer (`docs/ARCHITECTURE.md`). |
| Skills | Procedures in `.claude/skills/` | `load-app`, `run-study`, `interpret-participant`, `maintain-app`, `release-bundle`, `session-handover`. |

The `biodesign-reviewer` is the gate for new features: it checks each proposal against the need,
stakeholders, risks and governance in `docs/BIODESIGN.md` and says build, build smaller, or don't.

## 4. The loop

```
         build machine (internet)                    managed laptop (offline)
  ┌──────────────────────────────────┐        ┌──────────────────────────────────┐
  │ 1. change, through maintain-app   │        │ 6. load-app: install, verify     │
  │ 2. run_tests, parity, golden test │        │    version and fingerprint       │
  │ 3. mockup agreed for new screens  │  drive │ 7. golden test (qc-steward)      │
  │ 4. release-bundle: version,       │ ─────► │ 8. run-study, interpret-         │
  │    changelog, PDFs, build         │        │    participant                   │
  │ 5. session-handover: write state  │ ◄───── │ 9. session-handover: write state │
  └──────────────────────────────────┘        │    and "Changed on Windows"      │
                                               └──────────────────────────────────┘
```

## 5. Classifying a change

| Kind | Examples | Version | Needs |
|---|---|---|---|
| Science | any `GGIR()` argument, cut-points, time zone, GGIR version | MAJOR | the investigator's explicit agreement; new fingerprint; golden test; reprocessing |
| Behaviour | a screen, a message, a helper | MINOR | mockup agreed; biodesign review for new features; run_tests; app exercised |
| Packaging | launcher, bundle contents | MINOR or PATCH | a test install |
| Docs | manuals | PATCH | none |

## 6. The checks, and what each one proves

| Check | Proves | When |
|---|---|---|
| `tools/run_tests.R` | The code that reads GGIR's results gives the right numbers, flags and blanks on a made-up study (74 checks, base R, seconds) | after every change to `app/results.R`, on both machines |
| `tools/check_parity.R` | The settings fingerprint; on the build machine, that the app's `GGIR()` call matches a reference script | every release; on the laptop after install |
| Golden test | A real recording processed now gives the same numbers as when it was checked by hand | after every install; after any worker or settings change |
| `dev/make_sim_study.R` | Whole runs survive awkward recordings: short, device off at night, a still day, very short and long nights, 30 Hz, cut-off file, with a diary | before a release that touches the worker or the night logic |
| Stress test | Stop and resume give identical results; a restarted app finds a running job; a dead job is reported; 50 participants stay fast | before a release that touches running jobs |
| `version-steward` | One copy installed, version and fingerprint as recorded, laptop edits listed | at the start of a laptop session |

The simulated study is what found the one crash that mattered: GGIR draws every report picture in
one loop at the end, and one recording with no complete night lost the pictures for every file
after it. The golden test alone would never have shown it.

## 7. Decisions worth copying

- **Freeze the age group per study.** The single choice that changes results should be hard to
  change by accident and impossible to change silently.
- **Verdicts go stale per file.** Reprocessing a file asks for its verdict again; adding new
  participants does not disturb earlier ones.
- **Run state lives with the data.** A run's state is written in the study folder, so a restarted
  app, a second tab or a second copy all agree, and a job that died is reported instead of showing
  "Running" for ever.
- **Initials, not logins.** A self-declared record of who did what, stated plainly as not being
  security. Access control is the operating system's job.
- **No backup feature until a location is approved in writing.** Copying participant data is a
  governance decision, not a feature request.
- **Light and dark for everything**, including the PDFs, generated from one source.

## 8. Starting your own

1. Read `docs/BIODESIGN.md` and rewrite it for your site, especially governance.
2. Edit `app/settings.R`: your studies, your time zone, and (with a methods person) your cut-points.
3. Record your choices in `docs/PIPELINE.md` and start `CHANGELOG.md` from the new fingerprint.
4. Copy `HANDOVER.template.md` to `HANDOVER.md` (git-ignored) and
   `private/reference_results.template.md` to `private/reference_results.md` (git-ignored).
5. Build on a machine with internet (`build_bundle.R`), install on the offline laptop
   (`docs/RUNBOOK.md`), process one recording by hand-checked reference, record it as your golden
   test, and only then process study data.
