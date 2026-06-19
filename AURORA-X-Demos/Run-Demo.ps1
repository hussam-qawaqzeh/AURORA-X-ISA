# AURORA-X Universal Demo Runner
# This script compiles, executes, and disassembles the provided AURORA-X assembly demo.

param(
    [Parameter(Mandatory=$true)]
    [string]$DemoName
)

$ToolsDir = "..\aurora-x-tools"

if (-Not (Test-Path "$DemoName")) {
    Write-Host "Error: File $DemoName not found." -ForegroundColor Red
    exit 1
}

$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($DemoName)
$BinName = "$BaseName.bin"

Write-Host "`n=== [1/3] Assembling $DemoName ===" -ForegroundColor Cyan
cargo run --manifest-path "$ToolsDir\Cargo.toml" -p ax-asm -- "$DemoName" -o "$BinName"

Write-Host "`n=== [2/3] Executing in AURORA-X Emulator ===" -ForegroundColor Green
cargo run --manifest-path "$ToolsDir\Cargo.toml" -p ax-emu -- "$BinName"

Write-Host "`n=== [3/3] Disassembling Binary ===" -ForegroundColor Yellow
cargo run --manifest-path "$ToolsDir\Cargo.toml" -p ax-disasm -- "$BinName"

Write-Host "`nDone!" -ForegroundColor Cyan
