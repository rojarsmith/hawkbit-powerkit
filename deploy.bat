@echo off
setlocal enabledelayedexpansion

echo ======
echo Deploy
echo ======

set /p USER="VPS account: "
set /p HOST="VPS IP or host name: "
set /p BOOK=".sh file: "
set /p SUDO_PASS="SUDO password: "

echo %SUDO_PASS%

echo Send to VPS
scp %BOOK% %USER%@%HOST%:/tmp/%BOOK%

echo Run .sh
ssh %USER%@%HOST% "bash /tmp/%BOOK% !SUDO_PASS!"

echo.
pause
endlocal
