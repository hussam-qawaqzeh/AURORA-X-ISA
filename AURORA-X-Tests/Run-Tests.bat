@echo off
setlocal enabledelayedexpansion

echo ========================================
echo  AURORA-X Automated Compliance Suite
echo ========================================
echo.

set FAIL_COUNT=0
set PASS_COUNT=0

for %%f in (*.s) do (
    echo [RUNNING] %%f...
    
    rem 1. Assemble
    ..\aurora-x-tools\target\debug\ax-asm.exe "%%f" -o "%%~nf.bin" >nul 2>&1
    if !errorlevel! neq 0 (
        echo   [ERROR] Assembly failed for %%f
        set /a FAIL_COUNT+=1
        continue
    )
    
    rem 2. Run Emulator in Test Mode
    ..\aurora-x-tools\target\debug\ax-emu.exe --test "%%~nf.bin" >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [PASS]  %%f
        set /a PASS_COUNT+=1
    ) else (
        echo   [FAIL]  %%f
        set /a FAIL_COUNT+=1
    )
    
    rem Cleanup
    del "%%~nf.bin" >nul 2>&1
)

echo.
echo ========================================
echo  RESULTS: !PASS_COUNT! PASSED, !FAIL_COUNT! FAILED
echo ========================================

if !FAIL_COUNT! equ 0 (
    exit /b 0
) else (
    exit /b 1
)
