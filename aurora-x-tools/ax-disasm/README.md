# AURORA-X Disassembler (`ax-disasm`)

A reverse-engineering tool for the AURORA-X architecture. `ax-disasm` reads raw binary files and decodes the 32-bit machine code back into human-readable assembly instructions.

## Features
- Validates binary file integrity.
- Decodes R-Type, I-Type, S-Type, B-Type, U-Type, and J-Type encodings.
- Fully supports decoding the advanced AI Tensor instructions (`VFMA`, `VMUL`, `VPERM`).
- Displays Memory Offsets alongside Opcodes.

## Usage
```bash
cargo run -- <input_binary.bin>
```

### Example Output
```text
Disassembly of my_program.bin:
00000000:  432A8400    CSR.WRITE R5, 0x508
00000004:  60098000    VLOAD V1, [R6]
00000008:  62184400    VADD V3, V1, V2
```
