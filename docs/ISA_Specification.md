# AURORA-X Instruction Set Architecture (ISA) v1.9

This document defines the formal Instruction Set Architecture (ISA) specification for the **AURORA-X (Aurora eXtreme Adaptive Architecture)**.

---

## 1. Profiles & Architectural Layers

AURORA-X defines three primary system profiles to target different domains:
- **AX-E Profile (MCU/Embedded):** Base 64-bit scalar core, optional AX16C compressed instruction mode, memory protection unit (MPU), and light-weight secure boot.
- **AX-C Profile (Client/Mobile):** Base 64-bit scalar core, vector math extension (AX-Vec), full security architecture, and virtualization.
- **AX-H Profile (HPC/Server):** Base 64-bit scalar core, AX-Vec, Matrix Accelerator (AX-Mat), Neural Processing Unit (AX-NPU), hardware virtualization, and multi-socket AMCA chiplet communications.

---

## 2. Register Architecture & ABI (v1.1)

The CPU contains four register files:
1. **General Purpose Registers (GPR):** 32x 64-bit registers (`R0-R31`). `R0` is hardwired to zero.
2. **Floating-Point Registers (FPR):** 32x 128-bit registers (`F0-F31`). IEEE 754-2019 compliant.
3. **Vector Registers (VR):** 32x scalable registers (`V0-V31`). Hardware-agnostic width from 128-bit to 2048-bit.
4. **Matrix Registers (MR):** 32x Tile registers (`M0-M31`) for matrix multiplication.

### ABI Register Classification

| Register | Name | Classification | Saver | Description |
|---|---|---|---|---|
| `R0` | `zero` | Hardwired Zero | — | Hardwired to 0 |
| `R1-R7` | `a1-a7` | Arguments / Return Values | Caller | Arguments 1-7, `R1` holds return value |
| `R8-R15` | `t0-t7` | Temporaries | Caller | Scratchpad temporaries |
| `R16-R23`| `s0-s7` | Saved Registers | Callee | Must be preserved across function calls |
| `R24-R27`| `t8-t11`| Temporaries | Caller | Additional scratchpad registers |
| `R28` | `tp` | Thread Pointer | Callee | Thread-local storage pointer |
| `R29` | `fp` | Frame Pointer | Callee | Base address of the stack frame |
| `R30` | `sp` | Stack Pointer | Callee | Stack pointer (16-byte aligned) |
| `R31` | `ra` | Return Address | Caller | Return address for function calls |

---

## 3. Bit-Level Instruction Formats

AURORA-X utilizes a fixed-length **32-bit instruction encoding** (except when AX16C compression is enabled).

```text
R-Type:  [31:24 opcode] [23:19 rd] [18:14 rs1] [13:9 rs2] [8:0 funct9]
I-Type:  [31:24 opcode] [23:19 rd] [18:14 rs1] [13:0 imm14]
S-Type:  [31:24 opcode] [23:19 rs1] [18:14 rs2] [13:0 imm14]
B-Type:  [31:24 opcode] [23:19 rs1] [18:14 rs2] [13:0 imm14]
J-Type:  [31:24 opcode] [23:19 rd] [18:0 imm19]
CSR-Type:[31:24 opcode] [23:19 rd_or_rs1] [18:7 csr_addr] [6:0 reserved]
```

### Instruction Field Descriptions
- **`opcode` (8 bits):** Defines the primary instruction class.
- **`rd` / `rs1` / `rs2` (5 bits each):** Selects one of the 32 registers.
- **`funct9` (9 bits):** Specifies sub-operations or data types (e.g. integer width, arithmetic vs logic).
- **`imm14` / `imm19` (14/19 bits):** Signed, sign-extended immediate values.
- **`csr_addr` (12 bits):** Addresses up to 4096 control and status registers.

---

## 4. Instruction Opcode Map

The 8-bit `opcode` space `[31:24]` determines the operation class:

### Opcode Table

| Opcode | Mnemonic | Type | Description |
|---|---|---|---|
| **0x01** | `ADD.X` / `SUB.X` | R | 64-bit Integer Add (funct9=0) / Subtract (funct9=1) |
| **0x02** | `AND` | R | Bitwise AND |
| **0x03** | `OR` | R | Bitwise OR |
| **0x04** | `XOR` | R | Bitwise XOR |
| **0x05** | `SHL` | R | Shift Left Logical |
| **0x06** | `SHR` / `SRA` | R | Shift Right Logical (funct9=2) / Arithmetic (funct9=1) |
| **0x07** | `MUL` | R | Integer Multiplication |
| **0x08** | `DIV` | R | Integer Division |
| **0x09** | `ADDI` | I | 64-bit Add Immediate |
| **0x0A** | `SLT` | R | Set Less Than (signed) |
| **0x0B** | `SLTU` | R | Set Less Than Unsigned |
| **0x21** | `LOAD.X` | I | 64-bit Memory Load |
| **0x22** | `STORE.X` | S | 64-bit Memory Store |
| **0x40** | `BEQ` / `BRANCH.X` | B | Branch if Equal |
| **0x46** | `BNE` | B | Branch if Not Equal |
| **0x47** | `BLT` | B | Branch if Less Than (signed) |
| **0x48** | `BGE` | B | Branch if Greater than or Equal (signed) |
| **0x49** | `BLTU` | B | Branch if Less Than (unsigned) |
| **0x4A** | `BGEU` | B | Branch if Greater than or Equal (unsigned) |
| **0x41** | `JUMP.X` | J | Jump and Link |
| **0x42** | `CSR.READ` | CSR | Read Control Status Register |
| **0x43** | `CSR.WRITE` | CSR | Write Control Status Register |
| **0x44** | `ECALL` | CSR | Environment Call (System Call) |
| **0x45** | `EXRET` | CSR | Exception Return |
| **0x50** | `FADD.X` | R | Floating-point Add |
| **0x51** | `FMUL.X` | R | Floating-point Multiply |
| **0x60** | `VLOAD` | R/I | Load Vector Register |
| **0x61** | `VSTORE` | R/S | Store Vector Register |
| **0x62** | `VADD` | R | Vector SIMD Addition (funct9[8]=mask) |
| **0x63** | `VMUL` | R | Vector SIMD Multiplication (funct9[8]=mask) |
| **0x64** | `VFMA` | R | Vector Fused Multiply-Add (funct9[8]=mask) |
| **0x65** | `VPERM` | R | Vector Element Permute (funct9[8]=mask) |
| **0x54** | `VCMP.GT` | R | Vector Compare Greater Than |

---

## 5. Control & Status Registers (CSR)

CSRs are accessed exclusively via `CSR.READ` and `CSR.WRITE` instructions. **MMIO access to CSRs is strictly prohibited.**

| CSR Address | Register Name | Privilege | Reset Value | Description |
|---|---|---|---|---|
| **0x000** | `AX_STATUS` | PL3 (Machine) | `0x0` | Core status register |
| **0x008** | `AX_CAUSE` | PL3 (Machine) | `0x0` | Trap cause code |
| **0x010** | `AX_MACHINE_CONFIG`| PL3 (Machine) | Impl-defined | Core capability configuration |
| **0x018** | `AX_EPC` | PL3/PL1 | `0x0` | Exception Program Counter |
| **0x020** | `AX_EXCEPTION_VECTOR`| PL3 (Machine) | Impl-defined | Trap handler base address |
| **0x200** | `AX_MMU_CONTROL` | PL1 (Supervisor) | `0x0` | MMU translation control |
| **0x208** | `AX_PAGE_TABLE_BASE`| PL1 (Supervisor) | `0x0` | Physical address of root page table |
| **0x300** | `AX_TRUST_STATE` | PL3 (Machine) | `0x1` | Enclave encryption status |
| **0x508** | `AX_VEC_CONTROL` | PL0/PL1 | `0x0` | Vector Length (VL) |
| **0x700** | `AX_TEST_EXIT` | PL0+ | `0x0` | Simulation exit flag |
| **0x701** | `AX_TEST_PRINT` | PL0+ | `0x0` | Virtual simulator terminal print |

---

## 6. Interrupts & Exceptions

Upon a trap, the CPU:
1. Saves the current program counter into `AX_EPC`.
2. Writes the cause code to `AX_CAUSE`.
3. Jumps to the address in `AX_EXCEPTION_VECTOR`.
4. Restores state and PC upon executing `EXRET`.

### Trap Cause Codes (`AX_CAUSE`)

| Code | Trap Classification | Description |
|---|---|---|
| **0x00** | Illegal Instruction | Opcode not recognized or illegal fields |
| **0x01** | Memory Access Fault | Invalid memory access address |
| **0x02** | Alignment Fault | Address not properly aligned for transfer size |
| **0x03** | Page Fault | Translation page not present or privileged |
| **0x04** | Privileged Instruction | Accessing higher-privilege opcode or CSR |
| **0x05** | System Call | Triggered by the `ECALL` instruction |
| **0x06** | Breakpoint | Debug breakpoint |
| **0x07** | Security Violation | Attempting unauthorized access to secure enclave |

### AIC Interrupt Sources

The AURORA-X Advanced Interrupt Controller (AX-AIC) handles asynchronous events with an 8-bit priority value (0-255):

| Vector | Source | Typical Priority | Privilege Target |
|---|---|---|---|
| **0x00** | Timer Interrupt | Normal (128) | PL1 (Supervisor) |
| **0x01** | Inter-Processor Interrupt (IPI) | High (192) | PL1 (Supervisor) / PL3 |
| **0x02** | NPU Completion | Normal (100) | PL1 (Supervisor) |
| **0x0E** | Security Violation | Critical (240) | PL3 (Machine) |
| **0x0F** | Debug Hardware Breakpoint | Critical (255) | PL3 (Machine) |

---

## 7. Memory & Accelerator Model

### Memory Consistency
AURORA-X employs a **Weakly Ordered Memory Model**. Load/Store operations can be reordered by the pipeline or cache controllers. Memory barriers must be used:
- `FENCE.R`: Restrict load reordering.
- `FENCE.W`: Restrict store reordering.
- `FENCE.RW` / `FENCE.SEQ`: Strict memory synchronization barrier.
- **Acquire/Release:** `LOAD.ACQ` and `STORE.REL` instructions ensure memory fence semantics.

### Integer Division Behavior
- **Division-by-Zero:** In integer division (`DIV`), if the divisor register is zero, the division does not trigger a hardware exception. Instead, it returns `0` to the destination register (consistent with RISC-V conventions).
- **Signed vs Unsigned:** Integer division behaves as unsigned division.

### Vector Execution (AX-Vec)
Vector operations execute across 32 registers (`V0-V31`). Vector length is configured via the `AX_VEC_CONTROL` register. The vector ALU executes arithmetic, logic, and permutation (`VPERM`) operations.
- **Vector Masking:** If the mask bit (`funct9[8]`, bit 8 of `funct9` in vector opcode format) is set, operations behave as masked vector instructions (e.g. `VADD.M`, `VMUL.M`, `VFMA.M`, `VPERM.M`). In this mode, each element `i` is processed only if the bit `i` in the `vmask` register (derived from comparison instructions like `VCMP.GT`) is set.

### Neural Processing Unit (AX-NPU)
The NPU handles matrix arithmetic and tensor layer activations:
- Supported types: INT8, FP16, and BF16.
- The CPU sets up command descriptors in shared system memory, dispatches them using `NPU.RUN`, and monitors completion via the interrupt controller or by polling `NPU.STATUS`.
