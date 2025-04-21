@echo off
setlocal

set USER=
set HOST=
set BOOK=deploy-entry-straight-ssl-ubuntu2404.sh
set SUDO_PASS=
set DOMAIN=
set DOMAIN_A=
set DOMAIN_EMAIL=
set GANDI_LIVEDNS_TOKEN=

call deploy.bat %USER% %HOST% %BOOK% %SUDO_PASS% %DOMAIN% %DOMAIN_A% %DOMAIN_EMAIL% %GANDI_LIVEDNS_TOKEN%

endlocal
