@echo off
setlocal

set USER=
set HOST=
set BOOK=deploy-entry-straight-ubuntu2404.sh
set SUDO_PASS=

call deploy.bat %USER% %HOST% %BOOK% %SUDO_PASS%

endlocal
