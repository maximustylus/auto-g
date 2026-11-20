#!/usr/bin/env bash
# AutoG launcher for Linux. Needs R and a one-time "Rscript setup.R".
cd "$(dirname "$0")" || exit 1
exec Rscript app/launch.R
