# AURORA-X Emulator (`ax-emu`)

The software heart of the AURORA-X project. `ax-emu` is a high-performance software simulator that mimics the hardware execution of the AURORA-X architecture.

## Architecture Simulated
- **CPU State**: Maintains PC, Privilege Level, 32 GPRs (64-bit), and 32 Vector Registers (2048-bit).
- **CSRs**: Maintains Control and Status Registers like `AX_CAUSE`, `AX_EPC`, `AX_EXCEPTION_VECTOR`, and `AX_VEC_CONTROL`.
- **Memory**: 4MB Flat RAM model.

## Universal Testbench
By default, the emulator's `main.rs` initializes a Universal Testbench in memory to allow running pre-compiled AI and Exception demos without needing an external linker or OS loader.
- Base `100`: Exception Handler Vector.
- Base `1000`: Vector/Matrix Data for AI tests.

## Usage
```bash
cargo run -- <input_binary.bin>
```
Upon execution completion, the emulator dumps the hardware state, including Accumulator values, Exception registers, and Vector memory outputs to verify mathematical correctness.
