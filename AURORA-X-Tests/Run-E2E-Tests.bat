@echo off
setlocal enabledelayedexpansion

echo ========================================
echo  AURORA-X C Compiler End-to-End Suite
echo ========================================
echo.

set FAIL_COUNT=0
set PASS_COUNT=0

for %%f in (*.c) do (
    echo [RUNNING] %%f...
    
    rem 1. Compile C to Assembly (.s)
    ..\aurora-x-tools\target\debug\ax-cc.exe "%%f" -o "%%~nf.s" >nul 2>&1
    if !errorlevel! neq 0 (
        echo   [ERROR] Compilation failed for %%f
        set /a FAIL_COUNT+=1
    ) else (
        rem 2. Assemble (.s) to Binary (.bin)
        ..\aurora-x-tools\target\debug\ax-asm.exe "%%~nf.s" -o "%%~nf.bin" >nul 2>&1
        if !errorlevel! neq 0 (
            echo   [ERROR] Assembly failed for %%~nf.s
            set /a FAIL_COUNT+=1
        ) else (
            rem 3. Run Emulator in Test Mode
            ..\aurora-x-tools\target\debug\ax-emu.exe --test "%%~nf.bin" >nul 2>&1
            if !errorlevel! equ 0 (
                echo   [PASS]  %%f
                set /a PASS_COUNT+=1
            ) else (
                echo   [FAIL]  %%f
                set /a FAIL_COUNT+=1
            )
            
            rem Cleanup temporary files
            del "%%~nf.bin" >nul 2>&1
            del "%%~nf.s" >nul 2>&1
        )
    )
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
