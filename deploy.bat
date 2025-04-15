@echo off
setlocal enabledelayedexpansion

echo ======
echo Deploy
echo ======

if "%~1"=="" (
    set /p USER="VPS account: "
) else (
    set USER=%~1
)
if "%~2"=="" (
    set /p HOST="VPS IP or host name: "
) else (
    set HOST=%~2
)
if "%~3"=="" (
    set /p BOOK=".sh file: "
) else (
    set BOOK=%~3
)
if "%~4"=="" (
    set /p SUDO_PASS="SUDO password: "
) else (
    set SUDO_PASS=%~4
)

echo SUDO_PASS=%SUDO_PASS%

echo Send to VPS
scp %BOOK% %USER%@%HOST%:/tmp/%BOOK%

echo Run .sh
ssh %USER%@%HOST% "bash /tmp/%BOOK% !SUDO_PASS!"

echo.
pause
endlocal
