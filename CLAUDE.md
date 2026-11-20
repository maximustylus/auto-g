# AutoG — offline Windows app

You are working on AutoG, a point-and-click app that runs a wrist-accelerometry pipeline (GGIR) on a
**corporate Windows laptop with no internet and no admin rights**. Read `HANDOVER.md` first (made from
`HANDOVER.template.md`; it is git-ignored): it says what state things are in and what to do next.
`PLAYBOOK.md` explains the method behind all of this.

**End product, per participant:** (1) the report image `<ID>_GGIR_report.jpg` and (2) a written
interpretation paragraph. Everything else exists to make those two trustworthy.

## Hard rules

1. **Nothing leaves the machine.** Participants may be children or patients. No uploads, no pasting
   raw data or identifiable details into anything external. The app binds to `127.0.0.1` only.
2. **No internet, no admin, no installers.** Never call `install.packages()` with a repository, never
   suggest installing R, Rtools, Python or anything system-wide. Everything needed is in this folder.
3. **Never change a scientific setting casually.** Cut-points, epoch, timezone and every `GGIR()`
   argument are study decisions (see `docs/PIPELINE.md`). A change needs the user's say-so, a
   `CHANGELOG.md` entry, and a new settings fingerprint.
4. **GGIR is pinned to 3.3-8.** Results shift between GGIR versions. Do not upgrade it.
5. **Paths must not contain spaces** (GGIR's file reader treats them as shell commands). Data root is
   e.g. `D:/GGIR`, never `D:/My Data/GGIR`.
6. **The Mac is the source of truth.** The bundle is built on the user's Mac from `windows-app/`.
   Anything you change on this laptop must be listed in `HANDOVER.md` under "Changed on Windows" so
   it can be carried back, or the next bundle will silently undo it.
7. **Raw data is read-only.** Never edit, move or delete files in `<study>/raw/` without asking.

## Layout

```
AutoG\                    (on the Mac: windows-app/, without R\ and packages\)
  Run AutoG.bat               double-click launcher
  R\                         portable R 4.5.3 + all packages (Windows binaries)
  packages\GGIR_3.3-8.tar.gz installed into R\library on first launch
  app\                       launch.R, app.R, ggir_run.R, settings.R, results.R, help.R, compose_reports.R
  app\www\                   logo files (autog-mark.svg, autog-icon.svg); brand rules in docs\BRAND.md
  tools\check_parity.R       settings fingerprint / parity check
  templates\                 sleep-log template + instructions
  docs\                      the manuals below
  .claude\agents, skills     the team and its procedures
  VERSION, CHANGELOG.md, BUILD_INFO.txt, HANDOVER.md, README.txt
  build_bundle.R             reference only; the bundle is built on the Mac (with packages.lock)
```

Use the bundled R for everything: `R\bin\Rscript.exe --vanilla <script>`.

## Who does what

| Layer | What it is | Where defined |
|---|---|---|
| Lead agent | You, the main session. Talks to the user, decides, delegates, signs off. | this file |
| Sub-agents | Specialists you delegate one bounded job to. They report back; you decide. | `.claude/agents/` |
| Stewards | Sub-agents that only check and never edit: version steward, QC steward. | `.claude/agents/` |
| Workers | Plain R processes, no AI: launcher, UI server, GGIR worker, report composer. | `app/`, `docs/ARCHITECTURE.md` |
| Skills | Step-by-step procedures any of the above follow. | `.claude/skills/` |

Sub-agents: `pipeline-scientist`, `shiny-ui-engineer`, `windows-packager`, `report-interpreter`,
`biodesign-reviewer`, and the stewards `version-steward`, `qc-steward`.

Skills: `load-app`, `run-study`, `interpret-participant`, `maintain-app`, `release-bundle`,
`session-handover`.

## Manuals

- `docs/ARCHITECTURE.md` — processes, files, the contracts between them
- `docs/PIPELINE.md` — the science: settings, cut-points, outputs, how to read them
- `docs/RUNBOOK.md` — install, run, troubleshoot on Windows
- `docs/VERSIONING_QC.md` — pins, fingerprint, golden test, release checklist
- `docs/UI_UX.md` — users, screens, wording rules, backlog
- `docs/BIODESIGN.md` — the clinical need, stakeholders, risks, governance

## Before you say something is done

- Settings touched? Run `R\bin\Rscript.exe tools\check_parity.R` and record the fingerprint.
- `app/results.R` touched? Run `R\bin\Rscript.exe --vanilla tools\run_tests.R` (all checks must pass).
- App code touched? Start the app and exercise the change; the `qc-steward` golden test if the
  worker or settings changed.
- Then update `CHANGELOG.md` and `HANDOVER.md`.
