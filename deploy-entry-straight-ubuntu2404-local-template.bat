@echo off
setlocal

set USER=
set HOST=
set BOOK=
set SUDO_PASS=

call deploy.bat %USER% %HOST% %BOOK% %SUDO_PASS%

endlocal
