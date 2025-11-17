@echo off
setlocal
set "GODOT_EXE=%~dp0godot.exe"
set "SERVER_DIR=%~dp0server"
set "OUTPUT_DIR=%~dp0build"

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

"%GODOT_EXE%" --headless --path "%SERVER_DIR%" --export-release "Windows Headless Server" "%OUTPUT_DIR%\Server.exe"
if %errorlevel% neq 0 (
  echo Server build failed.
  exit /b %errorlevel%
)

echo Server build complete: %OUTPUT_DIR%\Server.exe
endlocal