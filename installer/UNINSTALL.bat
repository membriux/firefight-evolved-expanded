@echo off
REM ============================================================================
REM  UNINSTALL.bat - REVERT Firefight Reinforcements
REM
REM  Double-click this file: it shows you exactly what it would undo and
REM  CHANGES NOTHING. That is the dry run.
REM
REM  To actually revert, open a command prompt in this folder and run:
REM      UNINSTALL.bat -Apply
REM  then type REVERT when it asks.
REM
REM  It removes only the one manifest line the installer added and only the
REM  folders the installer created, restores your original "Firefight
REM  Evolved.bin" if the installer ever replaced it, and verifies the result.
REM  It never touches haloreach\maps and never touches your Workshop mod.
REM ============================================================================
setlocal
cd /d "%~dp0"
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
set RC=%ERRORLEVEL%
echo.
if not "%RC%"=="0" (
  echo The revert reported a problem - see the FAIL lines above.
)
echo.
pause
endlocal
exit /b %RC%
