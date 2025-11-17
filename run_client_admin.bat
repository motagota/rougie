@echo off
setlocal
set "CLIENT_EXE=%~dp0build\Client.exe"

if not exist "%CLIENT_EXE%" (
  echo Client executable not found. Build it first.
  exit /b 1)

"%CLIENT_EXE%" --name admin --port 1909
endlocal