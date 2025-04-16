@echo off
setlocal

echo ===============================
echo SSH Auto Deploy Public Key Tool
echo Login without Password
echo ===============================

:: User name for remote server
if "%~1"=="" (
    set /p USER="VPS account: "
) else (
    set USER=%~1
)
:: Host name for remote server
if "%~2"=="" (
    set /p HOST="VPS IP or host name: "
) else (
    set HOST=%~2
)
:: Password for remote server
if "%~3"=="" (
    set /p PASS="VPS password: "
) else (
    setlocal EnableDelayedExpansion
    set ARG3=%~3
    set "PASS=!ARG3!"
    endlocal & set "PASS=%PASS%"
)

set PUBKEY=%USERPROFILE%\.ssh\id_rsa.pub
set SSHEXE=ssh
set SSHPASSEXE=%~dp0tool\sshpass.exe
set SCP=scp

echo Server=%USER%@%HOST%

echo.
echo [STEP 1] Build .ssh for VPS
%SSHPASSEXE% -p "%PASS%" %SSHEXE% -o StrictHostKeyChecking=no %USER%@%HOST% "mkdir -p ~/.ssh && chmod 700 ~/.ssh"

echo.
echo [STEP 2] Send PUB key to VPS
%SSHPASSEXE% -p "%PASS%" %SCP% "%PUBKEY%" %USER%@%HOST%:~/.ssh/temp_key.pub

echo.
echo [STEP 3] Add PUB key to authorized_keys
%SSHPASSEXE% -p "%PASS%" %SSHEXE% %USER%@%HOST% "cat ~/.ssh/temp_key.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && rm ~/.ssh/temp_key.pub"

echo.
echo [COMPLETE] Login VPS without password
echo ssh %USER%@%HOST%
echo ssh -i "PRIVATE_KEY" %USER%@%HOST%

echo.
pause
endlocal
