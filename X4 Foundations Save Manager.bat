@ECHO OFF

REM this is a simple wrapper batch file which will call backup_saves.ps1 in the current directory

powershell -NoLogo -ExecutionPolicy Unrestricted -File "%CD%\backup_saves.ps1"
