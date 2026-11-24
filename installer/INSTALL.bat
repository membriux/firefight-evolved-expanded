@echo off
REM ============================================================================
REM  INSTALL.bat - Firefight Reinforcements
REM
REM  Double-click this file. It runs install.ps1 beside it, with the execution
REM  policy relaxed for this one process only, so nothing about your machine's
REM  PowerShell settings is changed. No administrator rights are needed.
REM
REM  Optional: to overwrite the stock .map files in the game folder instead of
REM  using MCC's mod manifest, run this from a command prompt as:
REM      INSTALL.bat -DirectCopy
REM  It backs every original up first and asks before replacing anything.
REM ============================================================================
setlocal
cd /d "%~dp0"
echo.
echo Running the installer from "%~dp0"
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set RC=%ERRORLEVEL%
echo.
if not "%RC%"=="0" (
  echo The installer reported a problem. Nothing further was changed.
) else (
  echo Installer finished.
)
echo.
pause
endlocal
exit /b %RC%
