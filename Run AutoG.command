#!/bin/bash
# AutoG launcher for macOS. Double-click it (first time: right-click > Open).
# Needs R and a one-time "Rscript setup.R". The Terminal window is AutoG running: keep it open.
cd "$(dirname "$0")" || exit 1
Rscript app/launch.R
