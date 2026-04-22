@echo off
setlocal EnableDelayedExpansion

REM =====================
REM VMware template clone
REM =====================

REM ---------- Default values ----------
set "templateDir="
set "outputRoot="
set "vmName="

REM template login
set "templateLoginUser=srv"
set "templateLoginPass=123"

REM tool paths (adjust if needed)
set "VMRUN=C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
set "VDISKMANAGER=C:\Program Files (x86)\VMware\VMware Workstation\vmware-vdiskmanager.exe"
set "SSH=ssh"
set "SSHPASS=%~dp0tool\sshpass.exe"

REM ---------- Parse args as name/value pairs ----------
call :parseArgs %*
if errorlevel 1 exit /b 1


REM ---------- Validate ----------
call :require templateDir
call :require outputRoot
call :require vmName
if errorlevel 1 exit /b 1

if not exist "!templateDir!" (
    echo [ERROR] templateDir not found: !templateDir!
    exit /b 1
)

for %%F in ("%templateDir%\*.vmx") do (
    set "templateVMX=%%~fF"
    goto :vmxFound
)

echo [ERROR] .vmx not found
exit /b 1

:vmxFound
echo templateVMX=%templateVMX%

if not exist "!VMRUN!" (
    echo [ERROR] vmrun.exe not found: !VMRUN!
    exit /b 1
)

if not exist "!VDISKMANAGER!" (
    echo [ERROR] vmware-vdiskmanager.exe not found: !VDISKMANAGER!
    exit /b 1
)

where "%SSH%" >nul 2>nul
if errorlevel 1 (
    echo [ERROR] %SSH% not found
    exit /b 1
)

if not exist "!SSHPASS!" (
    echo [ERROR] sshpass.exe not found: !SSHPASS!
    exit /b 1
)

set "newVmDir=!outputRoot!\!vmName!"

@REM if exist "!newVmDir!" (
@REM     echo [ERROR] destination already exists: !newVmDir!
@REM     exit /b 1
@REM )

echo [INFO] templateDir = %templateDir%
echo [INFO] templateVMX = %templateVMX%
echo [INFO] outputRoot  = %outputRoot%
echo [INFO] vmName      = %vmName%
echo [INFO] newVmDir    = %newVmDir%

REM ---------- Clone template ----------
echo [STEP] Clone template...
"!VMRUN!" -T ws clone "%templateVMX%" "%newVmDir%\%vmName%.vmx" linked -snapshot=clean -cloneName=%vmName%
if errorlevel 1 (
    echo [ERROR] VM clone failed.
    exit /b 1
)

REM ---------- Start VM ----------
echo [STEP] Start VM...
"!VMRUN!" -T ws start "%newVmDir%\%vmName%.vmx" nogui
if errorlevel 1 (
    echo [ERROR] VM start failed.
    exit /b 1
)

REM ---------- Wait OS ----------
echo [STEP] Wait for guest OS...
set /a ELAPSED=0
set /a TIMEOUTSEC=180

:wait_guest
"!VMRUN!" -T ws -gu "!templateLoginUser!" -gp "!templateLoginPass!" listProcessesInGuest "%newVmDir%\%vmName%.vmx" >nul 2>nul
if not errorlevel 1 goto guest_ready

if !ELAPSED! GEQ !TIMEOUTSEC! (
    echo [ERROR] Guest not ready within !TIMEOUTSEC! seconds
    exit /b 1
)

echo [INFO] guest not ready yet... !ELAPSED!/!TIMEOUTSEC!
timeout /t 5 /nobreak >nul
set /a ELAPSED+=5
goto wait_guest

:guest_ready
echo [INFO] guest is ready

REM ---------- Modfy ----------
echo [STEP] Start Modfy...
"!SSHPASS!" -p "!templateLoginPass!" !SSH! -o StrictHostKeyChecking=no !templateLoginUser!@vmubu2404sv ^
"echo '!templateLoginPass!' ^| sudo -S hostnamectl set-hostname '!vmName!'"
"!SSHPASS!" -p "!templateLoginPass!" !SSH! -o StrictHostKeyChecking=no !templateLoginUser!@vmubu2404sv ^
"echo '!templateLoginPass!' ^| sudo -S systemctl restart avahi-daemon"
REM Extend storage
"!SSHPASS!" -p "!templateLoginPass!" !SSH! -o StrictHostKeyChecking=no !templateLoginUser!@vmubu2404sv ^
"echo '!templateLoginPass!' ^| sudo -S lvextend -l +100%%FREE -r /dev/ubuntu-vg/ubuntu-lv"


REM ============================================================
REM Subroutines
REM ============================================================

:parseArgs
if "%~1"=="" goto :eof
:parseLoop
if "%~1"=="" goto :eof

if "%~2"=="" (
    echo [ERROR] Missing value for parameter: %~1
    exit /b 1
)

call set "%~1=%~2"
shift
shift
goto :parseLoop

:require
call set "val=%%%~1%%"
if "!val!"=="" (
    echo [ERROR] Missing required parameter: %~1
    exit /b 1
)
exit /b 0
