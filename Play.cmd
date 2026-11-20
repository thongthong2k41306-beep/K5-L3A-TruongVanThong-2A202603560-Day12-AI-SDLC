@echo off
cd /d "%~dp0"
python tools\manage.py play
if errorlevel 1 pause
