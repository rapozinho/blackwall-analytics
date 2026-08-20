@echo off
REM Atalho: roda o dev.ps1 sem depender da execution policy da maquina.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev.ps1" %*
