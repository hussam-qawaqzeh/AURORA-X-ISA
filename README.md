# AURORA-X ISA (Instruction Set Architecture) v1.9

Welcome to the **AURORA-X** project! This repository contains the complete specification, synthesizable Verilog RTL implementation, software ecosystem, and compiler backend architecture for a next-generation, high-performance, and scalable heterogeneous processor designed for AI, HPC, and general-purpose computing.

The project is **fully verified and stable**, establishing a complete, conflict-free compiler-to-silicon pipeline.

---

## 🌟 Vision & Key Architectural Highlights

AURORA-X is a clean-slate, 32-bit fixed-length instruction architecture with a massive focus on **Vectorized Math (SIMD)** and **Neural Network Inference**. It is built from the ground up to eliminate legacy bloat while providing unparalleled throughput for modern computational workloads.

### Features
1. **Heterogeneous Multi-Core Target:** Fully configured 9-core SoC target consisting of:
   - **3 P-Cores** (Performance)
   - **3 E-Cores** (Efficiency)
   - **3 AG-Cores** (AI & Vector Acceleration)
2. **64-bit Scalar Execution:** 32x 64-bit General Purpose Registers (`R0-R31`), where `R0` is hardwired to zero.
3. **AX-Vec (Vector Extension):** 32x 2048-bit Vector Registers (`V0-V31`) with a hardware-agnostic vector length configuration and vector element masking.
4. **AI Tensor Math:** Native hardware support for Fused Multiply-Add (`VFMA`) and Vector Permutation (`VPERM`).
5. **Memory Hierarchy & Coherence:** Multi-level cache hierarchy featuring private L1 Instruction & Data caches, shared L2 cache, and a large shared L3 cache (configurable up to 64MB with 3D V-Cache). Cache coherence is maintained across cores using the snoop-based MESI protocol.
6. **Robust Control Logic:**
   - Zero-cycle forwarding for CSR reads and EX-to-EX / MEM-to-EX hazard resolution.
   - Core pipeline freeze on memory stalls and selective thread flushes to prevent multicore deadlocks.
   - Glitch-free clock-gating and Dynamic Voltage & Frequency Scaling (DVFS) managed by a dedicated Power Management Unit (PMU).

---

## 📂 Repository Layout

```
AURORA-X ISA/
├── docs/                  # Official Technical Documentation Suite
│   ├── Getting_Started.md      # Installation & Simulation Guide
│   ├── ISA_Specification.md    # Instruction set & register specifications
│   ├── Hardware_Architecture.md # RTL, Pipeline, Caches, & PMU specifications
│   └── Software_Toolchain.md   # Compiler, Assembler, Emulator, & Disassembler specs
├── aurora-x-hardware/     # Verilog RTL Implementation (SoC, Cores, PMU, Caches)
├── aurora-x-tools/        # Rust Software Toolchain (Compiler, Assembler, Emulator, Disassembler)
│   ├── ax-cc/             # C Compiler (C -> Assembly)
│   ├── ax-asm/            # Assembler (Assembly -> Bin/Hex)
│   ├── ax-emu/            # Cycle-Accurate Simulator/Emulator
│   └── ax-disasm/         # Disassembler (Bin -> Assembly)
├── aurora-x-llvm/         # LLVM Compiler Backend TableGen specifications
├── AURORA-X-Tests/        # Verification assembly, hex, and C test scripts
└── AURORA-X-Demos/        # Complex demos (AI Polynomial, Vector Math, Exception)
```

---

## 📖 Project Documentation

A comprehensive documentation set is available in the [docs/](file:///c:/Users/hussam/Desktop/AURORA-X%20ISA/docs) directory:
- 🚀 **[Getting Started Guide](file:///c:/Users/hussam/Desktop/AURORA-X%20ISA/docs/Getting_Started.md):** Detailed environment setup instructions, C compilation flows, and Verilog simulation commands.
- 📐 **[ISA Specification Reference](file:///c:/Users/hussam/Desktop/AURORA-X%20ISA/docs/ISA_Specification.md):** Bit-level instruction formats, registers, ABI, exception cause codes, and opcode mappings.
- 🏗️ **[Hardware Architecture Guide](file:///c:/Users/hussam/Desktop/AURORA-X%20ISA/docs/Hardware_Architecture.md):** Details on the 5-stage pipeline, hazard/forwarding units, cache hierarchy, scalable bus, and PMU.
- 💻 **[Software Toolchain Reference](file:///c:/Users/hussam/Desktop/AURORA-X%20ISA/docs/Software_Toolchain.md):** Information on compiling C programs, compiler register stacks, assembler passes, and emulator execution.

---

## 🛠️ Quick Start

### 1. Build the Rust Toolchain
Prerequisites: Rust (`cargo`).
```bash
cd aurora-x-tools
cargo build --workspace
```

### 2. Compile, Assemble, and Emulate
Compile a C program into assembly, assemble it to binary, and execute it on the emulator:
```bash
# Compile C to Assembly
cargo run -p ax-cc -- ../AURORA-X-Tests/fib.c -o fib.s

# Assemble to Binary
cargo run -p ax-asm -- fib.s -o fib.bin

# Run on Emulator
cargo run -p ax-emu -- fib.bin
```
*Example Emulator Output:*
```text
Starting execution...
[AX-EMU] SYS_PRINT: 55
Infinite loop detected at PC=0x88. Halting emulator.
```

### 3. Run Hardware RTL Simulation
Prerequisites: Icarus Verilog (`iverilog`) and `vvp`.
```bash
cd aurora-x-hardware

# Compile RTL and Testbench
iverilog -o soc_sim.vvp tb_aurora_x_soc.v aurora_x_soc.v aurora_x_core.v ax_bus_scalable.v l1_cache.v l2_cache.v l3_cache.v mmu.v bpu.v vector_alu.v vector_register_file.v register_file.v decoder.v hazard_unit.v forwarding_unit.v alu.v ax_clint.v ax_uart.v ax_pmu.v ax_gpio.v ax_spi.v ax_fpu.v

# Run Simulation loaded with multicore test hex
vvp soc_sim.vvp +TEST=../AURORA-X-Tests/test_multicore.hex
```
*Expected Simulation Output:*
```text
========================================
 [MULTI-CORE HARDWARE PASS] 
 Core 0 Final Read = 0x0000000000000001
========================================
```

---

## 🧪 Compliance Testing

To verify the functional compliance of the compiler, assembler, and emulator against the instruction set, execute the test suite in the tests folder:
```bash
cd AURORA-X-Tests
Run-Tests.bat
```
*Results:* **9 PASSED, 0 FAILED**.

---
*Architected and developed with absolute precision.*
#   A U R O R A - X - I S A  