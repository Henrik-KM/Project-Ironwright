@echo off
where godot >nul 2>nul
if %errorlevel%==0 (
  godot --path "%~dp0game"
  exit /b %errorlevel%
)
where godot4 >nul 2>nul
if %errorlevel%==0 (
  godot4 --path "%~dp0game"
  exit /b %errorlevel%
)
echo Godot 4.7.1 is required and was not found on PATH.
pause
exit /b 1
