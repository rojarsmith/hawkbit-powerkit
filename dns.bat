@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    set /p API_KEY="VPS account: "
) else (
    set API_KEY=%~1
)
if "%~2"=="" (
    set /p DOMAIN="VPS account: "
) else (
    set DOMAIN=%~2
)
if "%~3"=="" (
    set /p SUBDOMAIN="VPS account: "
) else (
    set SUBDOMAIN=%~3
)
if "%~4"=="" (
    set /p TTL="VPS account: "
) else (
    set TTL=%~4
)
if "%~5"=="" (
    set /p IPLOOKUP="VPS account: "
) else (
    set IPLOOKUP=%~5
)
if "%~6"=="" (
    set /p TARGET_IP="VPS account: "
) else (
    set TARGET_IP=%~6
)
set BODY=
set HTTP_CODE=

echo.
echo Via the Gandi API

echo.
echo [ACT] Fetch HTTP code
curl -s -w "%%{http_code}" -o __tmp_body.json ^
     -X GET "https://api.gandi.net/v5/livedns/domains/%DOMAIN%/records/%SUBDOMAIN%/A" ^
     -H "authorization: Bearer %API_KEY%" > __tmp_http_code.txt

set /p HTTP_CODE=<__tmp_http_code.txt
echo HTTP status code: !HTTP_CODE!

if "%HTTP_CODE%" EQU "404" (
    echo [ACT] Create Type A
    curl -s -w "%%{http_code}" -o __tmp_body.json ^
        -X POST "https://api.gandi.net/v5/livedns/domains/%DOMAIN%/records/%SUBDOMAIN%/A" ^
        -d {\"rrset_values\":[\"%TARGET_IP%\"],\"rrset_ttl\":%TTL%} ^
        -H "authorization: Bearer %API_KEY%" ^
        -H "content-type: application/json" > __tmp_http_code.txt
    set /p HTTP_CODE=<__tmp_http_code.txt
    echo HTTP status code: !HTTP_CODE!
) else (
    echo [ACT] Update Type A
    curl -s -w "%%{http_code}" -o __tmp_body.json ^
        -X PUT "https://api.gandi.net/v5/livedns/domains/%DOMAIN%/records/%SUBDOMAIN%/A" ^
        -d {\"rrset_values\":[\"%TARGET_IP%\"],\"rrset_ttl\":%TTL%} ^
        -H "authorization: Bearer %API_KEY%" ^
        -H "content-type: application/json" > __tmp_http_code.txt
    set /p HTTP_CODE=<__tmp_http_code.txt
    echo HTTP status code: !HTTP_CODE!
)

echo [ACT] Get the IP address and TTL of the DNS A record
for /f "delims=" %%i in ('curl -s -X ^
    GET "https://api.gandi.net/v5/livedns/domains/%DOMAIN%/records/%SUBDOMAIN%/A" ^
    -H "authorization: Bearer %API_KEY%"') do set DNS_INFO=%%i

curl -s -X GET ^
    "https://api.gandi.net/v5/livedns/domains/%DOMAIN%/records/%SUBDOMAIN%/A" ^
    -H "authorization: Bearer %API_KEY%" > __tmp_body.json

set /p DNS_INFO=<__tmp_body.json

echo RES: %DNS_INFO%

for /f "delims=" %%a in ('jq -r ".rrset_values[0]" __tmp_body.json') do (
    set DNS_IP=%%a
)

echo [ACT] IP from DNS record: !DNS_IP!

del __tmp_body.json
del __tmp_http_code.txt

echo.
pause
endlocal
