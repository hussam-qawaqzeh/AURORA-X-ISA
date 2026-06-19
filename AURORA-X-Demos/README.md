# AURORA-X Interactive Demos

Welcome to the AURORA-X Interactive Prototype! 
This folder contains practical examples of the AURORA-X ISA (Instruction Set Architecture) v1.9 running on the official software toolchain (Assembler, Emulator, Disassembler).

## How to Run
Open a PowerShell terminal in this folder and run the execution script with the name of the demo you want to test:

```powershell
.\Run-Demo.ps1 01_Exception_Syscall.s
.\Run-Demo.ps1 02_Vector_Math.s
.\Run-Demo.ps1 03_AI_Polynomial.s
```

## Demos Explained

### `01_Exception_Syscall.s`
Demonstrates how AURORA-X handles System Calls (`ECALL`). The processor stops execution, jumps to a designated exception handler in memory, changes the Privilege Level, records the trap cause in the `AX_CAUSE` register, and safely returns using `EXRET`.

### `02_Vector_Math.s`
Demonstrates the **AX-Vec** extension. It loads two arrays into massive 2048-bit Vector Registers (`V1`, `V2`) and uses a single SIMD instruction (`VADD`) to perform parallel addition across all elements simultaneously.

### `03_AI_Polynomial.s`
The ultimate AI benchmark. It evaluates a mathematical polynomial `y = A + X * (B + C*X)` on an array of numbers using Fused Multiply-Add (`VFMA`) and Vector Multiply (`VMUL`), proving the architecture's readiness for Neural Network processing.
