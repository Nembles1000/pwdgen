@echo off
:: pwdgen installer for Windows
:: Usage: install.bat
::        install.bat --version v1.2.0   (pin a specific version)
setlocal EnableDelayedExpansion

set "REPO=Nembles1000/pwdgen"
set "GITHUB_API=https://api.github.com/repos/%REPO%"
set "RAW_BASE=https://raw.githubusercontent.com/%REPO%"
set "BINARY_NAME=pwdgen.exe"
set "PINNED_VERSION="

:: ── argument parsing ──────────────────────────────────────────────────────────
:parse_args
if "%~1"=="" goto args_done
if "%~1"=="--version" (
    set "PINNED_VERSION=%~2"
    shift & shift
    goto parse_args
)
if "%~1"=="-v" (
    set "PINNED_VERSION=%~2"
    shift & shift
    goto parse_args
)
echo [fail] Unknown argument: %~1
exit /b 1
:args_done

:: ── dependency check ──────────────────────────────────────────────────────────
where curl >nul 2>&1
if errorlevel 1 (
    echo [fail] 'curl' is required but not found. Please install it first.
    exit /b 1
)

where powershell >nul 2>&1
if errorlevel 1 (
    echo [fail] 'powershell' is required but not found.
    exit /b 1
)

:: ── resolve version ───────────────────────────────────────────────────────────
if not "!PINNED_VERSION!"=="" (
    set "VERSION=!PINNED_VERSION!"
    echo [pwdgen] Using pinned version: !VERSION!
    goto version_done
)

echo [pwdgen] Fetching latest version from GitHub...

:: Pull tag_name from the releases API using PowerShell JSON parsing
for /f "delims=" %%V in ('powershell -NoProfile -Command "try { (Invoke-RestMethod -Uri '%GITHUB_API%/releases/latest').tag_name } catch { '' }"') do (
    set "VERSION=%%V"
)

if "!VERSION!"=="" (
    echo [ warn ] No GitHub release found, checking tags...
    for /f "delims=" %%V in ('powershell -NoProfile -Command "try { (Invoke-RestMethod -Uri '%GITHUB_API%/tags')[0].name } catch { '' }"') do (
        set "VERSION=%%V"
    )
)

if "!VERSION!"=="" (
    echo [ warn ] Could not determine version from GitHub, falling back to v1.0.0
    set "VERSION=v1.0.0"
)

echo [pwdgen] Latest version: !VERSION!
:version_done

:: ── resolve install path ──────────────────────────────────────────────────────
set "INSTALL_DIR=%LOCALAPPDATA%\Programs\pwdgen"
set "INSTALL_PATH=%INSTALL_DIR%\pwdgen.exe"

if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%"
    if errorlevel 1 (
        echo [fail] Could not create install directory: %INSTALL_DIR%
        exit /b 1
    )
)

set "DOWNLOAD_URL=%RAW_BASE%/main/bin/!VERSION!/%BINARY_NAME%"

:: ── download ──────────────────────────────────────────────────────────────────
set "TMPFILE=%TEMP%\pwdgen_download.exe"

echo [pwdgen] Downloading %BINARY_NAME% !VERSION!...
echo [pwdgen] Source: !DOWNLOAD_URL!

curl -fsSL -o "%TMPFILE%" "!DOWNLOAD_URL!"
if errorlevel 1 (
    echo [fail] Download failed. Check that version !VERSION! exists in the repo.
    if exist "%TMPFILE%" del "%TMPFILE%"
    exit /b 1
)

echo [  ok  ] Download complete.

:: ── install ───────────────────────────────────────────────────────────────────
copy /Y "%TMPFILE%" "%INSTALL_PATH%" >nul
if errorlevel 1 (
    echo [fail] Could not copy binary to %INSTALL_PATH%
    del "%TMPFILE%"
    exit /b 1
)

del "%TMPFILE%"
echo [  ok  ] Installed to %INSTALL_PATH%

:: ── PATH check ────────────────────────────────────────────────────────────────
echo %PATH% | findstr /I /C:"%INSTALL_DIR%" >nul 2>&1
if errorlevel 1 (
    echo [ warn ] %INSTALL_DIR% is not on your PATH.
    echo [ warn ] Add it via: Windows Settings - Environment Variables - PATH
    echo [ warn ]   Add: %INSTALL_DIR%
)

:: ── verify ────────────────────────────────────────────────────────────────────
where pwdgen >nul 2>&1
if errorlevel 1 (
    echo [ warn ] pwdgen installed but not found in PATH yet.
    echo [ warn ] Restart your terminal or add %INSTALL_DIR% to PATH.
) else (
    echo [  ok  ] pwdgen is ready. Try: pwdgen 16
)

echo.
echo Done. pwdgen !VERSION! installed.
echo.
endlocal
