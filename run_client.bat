@echo off
setlocal
set "CLIENT_EXE=%~dp0build\Client.exe"

if not exist "%CLIENT_EXE%" (
  echo Client executable not found. Build it first.
  exit /b 1
)

set "NAME_ARG="
if not "%~1"=="" set "NAME_ARG=--name %~1"

"%CLIENT_EXE%" %NAME_ARG% --port 1909
endlocal