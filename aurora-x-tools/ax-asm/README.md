# AURORA-X Assembler (`ax-asm`)

The official assembler for the AURORA-X ISA. It translates human-readable assembly code into raw machine binaries (`.bin`).

## Syntax Rules
- **Comments**: Start with a semicolon `;`.
- **Registers**: General purpose (`R0`-`R31`), Vector (`V0`-`V31`).
- **Immediates**: Decimal integers.
- **Memory Addressing**: `[BaseRegister + ImmediateOffset]` (e.g., `[R6+16]`).

## Supported Instructions
- **Arithmetic**: `ADD.X`, `SUB.X`
- **Memory**: `LOAD.X`, `STORE.X`
- **Control Flow**: `BRANCH.X`, `JUMP.X`
- **System**: `ECALL`, `EXRET`, `CSR.READ`, `CSR.WRITE`, `CSR.SET`, `CSR.CLEAR`
- **Vectors**: `VLOAD`, `VSTORE`, `VADD`, `VMUL`, `VFMA`, `VPERM`

## Usage
```bash
cargo run -- <input_file.s> -o <output_file.bin>
```

### Example
```assembly
CSR.WRITE R5, 0x508    ; Set Vector Length
VLOAD V1, [R6]         ; Load memory into V1
VADD V3, V1, V2        ; Add V1 and V2 into V3
VSTORE V3, [R6+32]     ; Store Result
```
