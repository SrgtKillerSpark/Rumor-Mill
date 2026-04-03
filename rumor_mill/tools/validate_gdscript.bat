@echo off
REM validate_gdscript.bat — headless GDScript validation for Rumor Mill (Windows)
REM
REM Usage:
REM   validate_gdscript.bat [--godot "C:\path\to\godot.exe"] [--project "C:\path\to\rumor_mill"]
REM
REM Exit codes:
REM   0 — no errors found
REM   1 — GDScript errors detected
REM   2 — Godot binary not found or project path invalid

setlocal EnableDelayedExpansion

REM ── Defaults ─────────────────────────────────────────────────────────────────
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%.."
set "GODOT_BIN="

REM ── Argument parsing ──────────────────────────────────────────────────────────
:parse_args
if "%~1"=="" goto find_godot
if /i "%~1"=="--godot"   ( set "GODOT_BIN=%~2" & shift & shift & goto parse_args )
if /i "%~1"=="--project" ( set "PROJECT_DIR=%~2" & shift & shift & goto parse_args )
if /i "%~1"=="-h"        ( goto usage )
if /i "%~1"=="--help"    ( goto usage )
echo Unknown option: %~1 1>&2
exit /b 2

:usage
echo Usage: %~n0 [--godot ^<path^>] [--project ^<path^>]
exit /b 0

REM ── Locate Godot binary ───────────────────────────────────────────────────────
:find_godot
if not "%GODOT_BIN%"=="" goto validate_godot

REM Try common install locations
for %%G in (
  "godot4.exe"
  "godot.exe"
  "%LOCALAPPDATA%\Programs\Godot\Godot_v4\Godot_v4_win64.exe"
  "C:\Program Files\Godot\Godot_v4\Godot_v4_win64.exe"
  "C:\Godot\Godot_v4\Godot_v4_win64.exe"
) do (
  if exist "%%~G" (
    set "GODOT_BIN=%%~G"
    goto validate_godot
  )
  where "%%~G" >nul 2>&1 && (
    set "GODOT_BIN=%%~G"
    goto validate_godot
  )
)

echo ERROR: Godot binary not found. 1>&2
echo   Set GODOT_BIN env var or pass --godot ^<path^> 1>&2
echo   e.g.: set GODOT_BIN=C:\path\to\godot4.exe ^& validate_gdscript.bat 1>&2
exit /b 2

:validate_godot
if not exist "%GODOT_BIN%" (
  echo ERROR: Godot binary not found at: %GODOT_BIN% 1>&2
  exit /b 2
)

REM ── Validate project path ─────────────────────────────────────────────────────
if not exist "%PROJECT_DIR%\project.godot" (
  echo ERROR: No project.godot found in: %PROJECT_DIR% 1>&2
  exit /b 2
)

echo ================================================
echo   GDScript Validation -- Rumor Mill
echo   Godot:   %GODOT_BIN%
echo   Project: %PROJECT_DIR%
echo ================================================

REM ── Run Godot headless validation ─────────────────────────────────────────────
set "TMPLOG=%TEMP%\godot_validate_%RANDOM%.log"

"%GODOT_BIN%" --headless --check-only --path "%PROJECT_DIR%" > "%TMPLOG%" 2>&1
set GODOT_EXIT=%ERRORLEVEL%

REM ── Parse and report ──────────────────────────────────────────────────────────
set ERROR_COUNT=0
set WARNING_COUNT=0

echo.
for /f "tokens=*" %%L in ('findstr /R "^ERROR: ^SCRIPT ERROR: ^Parse error:" "%TMPLOG%" 2^>nul') do (
  echo   %%L
  set /a ERROR_COUNT+=1
)

for /f "tokens=*" %%L in ('findstr /R "^WARNING:" "%TMPLOG%" 2^>nul') do (
  echo   [WARN] %%L
  set /a WARNING_COUNT+=1
)

if %GODOT_EXIT% neq 0 if %ERROR_COUNT%==0 (
  echo   Godot exited with code %GODOT_EXIT%. Raw output:
  type "%TMPLOG%"
)

del /f /q "%TMPLOG%" 2>nul

echo.
if %GODOT_EXIT%==0 if %ERROR_COUNT%==0 (
  echo [PASS] Validation passed -- no GDScript errors found.
  exit /b 0
) else (
  echo [FAIL] Validation FAILED -- %ERROR_COUNT% error(s) found.
  exit /b 1
)
