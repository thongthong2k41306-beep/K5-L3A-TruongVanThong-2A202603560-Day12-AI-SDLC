@echo off
cd /d "%~dp0"
python tools\manage.py test
pause
