@echo off
setlocal
set "GODOT_EXE=%~dp0godot.exe"
set "CLIENT_DIR=%~dp0client"
set "OUTPUT_DIR=%~dp0build"

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

"%GODOT_EXE%" --headless --path "%CLIENT_DIR%" --export-release "Windows Desktop Client" "%OUTPUT_DIR%\Client.exe"
if %errorlevel% neq 0 (
  echo Client build failed.
  exit /b %errorlevel%
)

echo Client build complete: %OUTPUT_DIR%\Client.exe
endlocal