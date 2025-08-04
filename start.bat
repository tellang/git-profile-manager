@echo off
:: 이 파일은 ANSI 또는 UTF-8(BOM) 어느쪽으로 저장해도 괜찮습니다.

:: 1. 콘솔 환경 설정 (폰트, 코드페이지)
REG ADD HKCU\CONSOLE /V FaceName /T REG_SZ /D Consolas /F >NUL
chcp 65001 > nul

:: 2. 메인 파워쉘 스크립트 실행
powershell -ExecutionPolicy Bypass -File "%~dp0git_config_script.ps1"

echo.
echo 스크립트가 종료되었습니다.
pause
exit