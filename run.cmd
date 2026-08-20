@echo off
REM Atalho para quem abre o cmd: `run bet` / `run ecommerce`.
REM Repassa tudo para o run.ps1, que e quem tem a logica.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1" %*
