@echo off
setlocal

:: User name for remote server
set USER=
:: Host name for remote server
set HOST=
:: Password for remote server
set PASS=

call ssh-rsa-login.bat %USER% %HOST% %PASS%

endlocal
