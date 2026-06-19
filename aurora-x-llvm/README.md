# AURORA-X LLVM Compiler Backend

This directory contains the Out-of-Tree LLVM Target definitions for the AURORA-X architecture.

## Overview
To compile high-level languages (C, C++, Rust) down to AURORA-X machine code, LLVM requires a formal specification of the hardware. This is provided using LLVM's `TableGen` (`.td`) domain-specific language.

## Architecture Files (`lib/Target/AuroraX/`)
1. **`AuroraXRegisterInfo.td`**: Defines the GPRs (64-bit) and Scalable VRs (2048-bit), establishing `R30` as SP and `R31` as RA.
2. **`AuroraXInstrFormats.td`**: Specifies the precise 32-bit bitfield layouts for opcode slicing.
3. **`AuroraXInstrInfo.td`**: Maps abstract LLVM SelectionDAG nodes (like `add`, `sub`, `load`, `store`) to AURORA-X hardware opcodes.
4. **`AuroraXCallingConv.td`**: Implements the official v1.9 ABI, assigning function arguments to `R1-R8` and return values to `R1-R2`.
5. **`AuroraX.td`**: The top-level Target Machine definition.

## Integration
These files represent the foundational logic required to build a custom LLVM toolchain. They are designed to be copied into an LLVM source tree (`llvm-project/llvm/lib/Target/AuroraX`) and compiled using CMake.
