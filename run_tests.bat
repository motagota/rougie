@echo off
setlocal
set "GODOT=%~dp0Godot.exe"
"%GODOT%" --path "%~dp0." --headless --no-window --quiet --script res://tests/run_tests.gd
endlocal