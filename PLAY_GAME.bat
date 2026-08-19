@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel%==0 (
  start "Project Ironwright Server" cmd /k py -3 -m http.server 8000 --directory web
) else (
  start "Project Ironwright Server" cmd /k python -m http.server 8000 --directory web
)
timeout /t 1 /nobreak >nul
start "" http://localhost:8000
endlocal
