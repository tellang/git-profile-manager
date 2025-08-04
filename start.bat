@echo off
:: 모든 환경 설정 및 실행은 PowerShell 스크립트가 직접 처리하도록 함

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0git_config_script.ps1"