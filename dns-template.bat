@echo off
setlocal

set API_KEY=
set DOMAIN=
set SUBDOMAIN=
set TTL=
set IPLOOKUP=
set TARGET_IP=

call dns.bat %API_KEY% %DOMAIN% %SUBDOMAIN% %TTL% %IPLOOKUP% %TARGET_IP%

endlocal
