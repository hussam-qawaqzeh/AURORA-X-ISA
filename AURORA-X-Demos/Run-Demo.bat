@echo off
if "%~1"=="" (
    echo Usage: Run-Demo.bat [DemoFileName.s]
    echo Example: Run-Demo.bat 03_AI_Polynomial.s
    exit /b 1
)
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Run-Demo.ps1" "%~1"
