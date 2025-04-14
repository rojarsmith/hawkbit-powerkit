@echo off
setlocal

echo ===============================
echo SSH Auto Deploy Public Key Tool
echo Login without Password
echo ===============================

set /p USER="VPS account: "
set /p HOST="VPS IP or host name: "

set PUBKEY=%USERPROFILE%\.ssh\id_rsa.pub
set SSHEXE=ssh
set SCP=scp

echo %USER%@%HOST%

echo.
echo [STEP 1] Build .ssh for VPS
%SSHEXE% %USER%@%HOST% "mkdir -p ~/.ssh && chmod 700 ~/.ssh"

echo.
echo [STEP 2] Send PUB key to VPS
%SCP% "%PUBKEY%" %USER%@%HOST%:~/.ssh/temp_key.pub

echo.
echo [STEP 3] Add PUB key to authorized_keys
%SSHEXE% %USER%@%HOST% "cat ~/.ssh/temp_key.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && rm ~/.ssh/temp_key.pub"

echo.
echo [COMPLETE] Login VPS without password
echo ssh %USER%@%HOST%
echo ssh -i "%PRVKEY%" %USER%@%HOST%

echo.
pause
endlocal
