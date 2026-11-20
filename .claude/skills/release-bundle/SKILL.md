---
name: release-bundle
description: Build and ship a new version of the offline Windows bundle from the Mac - parity check, version bump, build, smoke test, copy to the encrypted drive. Mac only. Use after any change in windows-app/ that the laptop needs.
---

# Release a bundle (Mac only)

Needs internet and `brew install innoextract`. Cannot be done on the laptop.

1. **Collect laptop changes.** Read "Changed on Windows" in the `HANDOVER.md` that came back on the
   drive. Apply each to `windows-app/` (and to `reference_pipeline.R` if it is a pipeline setting). Clear the
   list once applied.
2. **Parity.** `Rscript tools/check_parity.R` → must print `PARITY OK`. Note the fingerprint.
3. **Version.** Edit `VERSION`; add the `CHANGELOG.md` entry (date, changes, fingerprint, whether
   results can change; `[SCIENCE]` if they can).
4. **Build.** `Rscript build_bundle.R` → `~/AutoG-build/AutoG/`. Downloads are cached in
   `~/AutoG-build/downloads`. Read `BUILD_INFO.txt`: app version, R 4.5.3, GGIR 3.3-8.
   If the build prints "NOT from the lock", package versions changed: golden test and changelog.
5. **Smoke test.** `Rscript -e "shiny::runApp('app', launch.browser = TRUE)"` from `windows-app/`;
   exercise what changed. If the worker or settings changed, run the golden test (your reference recording, `qc-steward`) and compare with `private/reference_results.md`.
6. **Handover note.** Update `HANDOVER.md`: what is new, what the laptop session must do first,
   open items. Rebuild if you edited it after step 4, or copy it into the bundle by hand.
7. **Ship.** With the encrypted drive mounted and unlocked, replace `GGIR/AutoG` on it with the
   new folder. Confirm with a file count or `diff -rq`. Eject properly.
8. **Tell the user** exactly what to do on the laptop: close the app, replace `C:\AutoG` with the
   folder from the drive, start it, run skill `load-app`.

Changing the GGIR or R version is a `[SCIENCE]`/MAJOR release: agree it with the user, change the
pin in `build_bundle.R`, install the same GGIR on the Mac, and plan to reprocess every participant.
