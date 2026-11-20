# Changelog

Newest first. Every entry: version, what changed, the **settings fingerprint** (from
`tools/check_parity.R`), and whether results can change. Pipeline changes are marked **[SCIENCE]**.
Before 0.16.0 AutoG was developed privately; those versions are summarised.

## 0.17.0 — runs anywhere, open to contributors
- `setup.R` and launchers for macOS (`Run AutoG.command`) and Linux (`run-autog.sh`); the app
  launcher works both from the offline Windows bundle and from a normal R installation.
- GitHub workflow: automated checks on Windows, macOS and Linux; a synthetic week through GGIR
  on Windows and Linux (`tools/ci_pipeline_check.R`).
- Fixed: for a recording too short for rhythm measures, the summary printed an empty sentence; it
  now says GGIR did not compute them. 76 checks.
- `CONTRIBUTING.md`, issue and pull-request templates, `CITATION.cff`.
- Results cannot change.

## 0.16.0 — first public release
- Settings fingerprint of this public copy: `675c9fd3ac26f6918431d051e57efa29` (example studies
  ADULT and CHILD). Your fingerprint changes when you edit `app/settings.R`; record it here.
- Same processing as the private 0.16.0. Differences: study names and the time zone (now a placeholder, UTC, to be set) and the
  reference script are now settings or optional; study data, reference values and the handover
  state were removed.

## Private development, summarised

| Version | What arrived |
|---|---|
| 0.16 | Stress test: run state kept in the study folder; dead runs reported; Stop ends GGIR's helper processes |
| 0.15 | Nights without a diary entry, accepted or dismissed by a person; daytime-sleep prompt |
| 0.14 | Worker survives a file GGIR cannot draw; "Not enough data" status; automated checks |
| 0.13 | Technical manual (PDF, light and dark); methods paragraph drafted from the settings used |
| 0.12 | Two-page infographic (PDF, light and dark): install and set up; using AutoG |
| 0.11 | Welcome with practice on reading the report image; Help tab |
| 0.10 | "Who is using AutoG?" initials, stamped on verdicts and the study log |
| 0.9 | Home screen: four steps and a participant list; age group fixed per study; study log |
| 0.8 | New look: cards, pills, icons, gradients |
| 0.7 | Light, dark and auto mode; warning when existing results used another age group |
| 0.6 | Study datasheet with column guide |
| 0.5 | Renamed AutoG; logo, icon and branded header |
| 0.4 | Quality check tab, progress by step, Summary draft |
| 0.3 | Handover pack: manuals, agents, skills, settings parity tool, locked package list |
| 0.2 | In-page folder picker (the Windows dialog opened behind the browser) |
| 0.1 | First offline Windows bundle |

No version changed a `GGIR()` argument or a cut-point after 0.1; results are unchanged throughout.
