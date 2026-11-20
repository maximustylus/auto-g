# Contributing to AutoG

Thank you for helping. AutoG exists so that people who don't code can process wrist-accelerometer
recordings correctly, offline. Contributions that make it more correct, easier or more portable
are very welcome: bug reports, testing on your own devices and operating system, documentation,
translations of the guides, and code.

## Three rules first

1. **Never share participant data.** Not in issues, pull requests, screenshots, logs or examples.
   No raw files, no result tables, no report images of real people, no IDs. Reproduce problems
   with a synthetic recording (`dev/make_synthetic_recording.R`) or the demo study
   (`dev/make_demo_study.R`). Logs may contain file names and dates: remove them before posting.
2. **Science changes are discussed before they are coded.** Anything that can change a result
   (a `GGIR()` argument, cut-points, epoch, time zone, the GGIR version, how nights or days are
   counted) starts as an issue using the *Scientific change* template, with references. These
   changes are MAJOR versions and mean reprocessing for every user.
3. **Every number traces to its source.** AutoG reads GGIR's own result files and never
   recalculates. A feature that needs a new number should read it from a GGIR output, or explain
   in the issue why it cannot.

## Getting set up

```bash
git clone https://github.com/maximustylus/auto-g.git
cd auto-g
Rscript setup.R            # once: packages, and GGIR pinned at 3.3-8
Rscript tools/run_tests.R  # the automated checks; all must pass
Rscript app/launch.R       # start the app
```

`dev/make_demo_study.R` gives you an invented study to click through in seconds;
`dev/make_synthetic_recording.R` gives you a synthetic week to run through GGIR end to end.

## Making a change

- Read [PLAYBOOK.md](PLAYBOOK.md): it explains how AutoG is built and why.
- Keep the change small and focused. One pull request, one idea.
- Changed `app/results.R`? Add or update checks in `tools/run_tests.R`.
- Changed the worker or settings? Run `Rscript tools/ci_pipeline_check.R` and say so in the PR.
- New or changed screens work in light and dark mode, on a laptop screen, with keyboard only.
- Wording follows `docs/UI_UX.md`: plain words, cause then action, units always shown.
- Record the change in `CHANGELOG.md` under a new version heading.

The GitHub workflow runs the automated checks on Windows, macOS and Linux, and a synthetic week
through GGIR on Windows and Linux, for every pull request.

## Testing on your own setup

Some of the most useful contributions need no code: install AutoG on your operating system or a
managed computer, process a synthetic week, and report what happened (template: *Bug report*).
The Windows behaviour around stopping runs and application control is the least tested part.

## Conduct

Be kind and constructive. Assume good intent, critique ideas and not people, and remember many
users here are clinicians and researchers, not programmers. Harassment of any kind is not
tolerated; maintainers may remove comments or contributors that break this.
