@echo off
setlocal
REM Windows CMD entrypoint. Git for Windows (Git Bash) is required.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-project.ps1" %*
exit /b %ERRORLEVEL%
