@echo off
setlocal

:: If the execution console leaves the focus, 
:: it may get stuck in the middle and require enter to continue execution.

:: User name for remote server
set USER=
:: Host name for remote server
set HOST=
:: Password for remote server
:: The % symbol needs to be used %% to escape the character
set PASS=

call ssh-rsa-login.bat %USER% %HOST% %PASS%

endlocal
