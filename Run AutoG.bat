@echo off
title AutoG - keep this window open
cd /d "%~dp0"
if not exist "%~dp0R\bin\Rscript.exe" (
  echo Cannot find R\bin\Rscript.exe next to this file. Copy the whole AutoG folder, not just this file.
  pause
  exit /b 1
)
set "R_LIBS_USER=%~dp0R\library"
set "R_LIBS_SITE="
"%~dp0R\bin\Rscript.exe" --vanilla "%~dp0app\launch.R"
if errorlevel 1 (
  echo.
  echo Something went wrong - see the message above.
  pause
)
