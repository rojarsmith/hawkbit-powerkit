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

set REMAINING_PARAMS=
set INDEX=5
:loop
call set ARG=%%%INDEX%%%
if defined ARG (
    set REMAINING_PARAMS=!REMAINING_PARAMS! !ARG!
    set /a INDEX+=1
    goto loop
)

echo SUDO_PASS=%SUDO_PASS%
echo REMAINING_PARAMS=!REMAINING_PARAMS!

echo Send to VPS
scp %BOOK% %USER%@%HOST%:/tmp/%BOOK%

echo Run .sh
ssh %USER%@%HOST% "bash /tmp/%BOOK% !SUDO_PASS! !REMAINING_PARAMS!"

echo.
pause
endlocal
