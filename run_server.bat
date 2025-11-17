@echo off
setlocal
set "SERVER_EXE=%~dp0build\Server.exe"

if not exist "%SERVER_EXE%" (
  echo Server executable not found. Build it first.
  exit /b 1
)

"%SERVER_EXE%" --server --port 1909
endlocal