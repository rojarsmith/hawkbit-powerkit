@echo off
setlocal

set USER=srv
set HOST=vmubu2404sv1
set BOOK=deploy-vmws.sh
set SUDO_PASS=123
set HOST_IP=

for /f "tokens=2 delims=[]" %%A in ('ping -4 -n 1 %HOST% ^| findstr /R /C:"Pinging .* \[.*\]"') do (
    set HOST_IP=%%A
)

if not defined HOST_IP (
    echo [ERROR] Cannot resolve IPv4 for %HOST%
    exit /b 1
)

echo HOST=%HOST%
echo HOST_IP=%HOST_IP%

rem Certificate output folder on Windows host
set CERT_DIR=%~dp0certs
if not exist "%CERT_DIR%" mkdir "%CERT_DIR%"

where mkcert >nul 2>nul
if errorlevel 1 (
  echo [ERROR] mkcert not found in PATH.
  exit /b 1
)

echo [INFO] Generating certificate for:
echo        127.0.0.1
echo        localhost
echo        %HOST%
echo        %HOST_IP%

mkcert ^
  -cert-file "%CERT_DIR%\server.crt" ^
  -key-file "%CERT_DIR%\server.key" ^
  127.0.0.1 localhost %HOST% %VM_IP%

if errorlevel 1 (
  echo [ERROR] mkcert certificate generation failed.
  exit /b 1
)

echo [INFO] Upload files to VM...

scp "%CERT_DIR%\server.crt" %USER%@%HOST%:/tmp/server.crt
if errorlevel 1 exit /b 1

scp "%CERT_DIR%\server.key" %USER%@%HOST%:/tmp/server.key
if errorlevel 1 exit /b 1

echo [OK] Deployment completed.

endlocal
