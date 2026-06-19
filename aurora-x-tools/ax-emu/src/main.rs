mod cpu;
mod memory;
mod decoder;
mod executor;

use std::env;
use std::fs::File;
use std::io::Read;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: ax-emu <binary.bin>");
        return;
    }

    let bin_path = &args[1];
    let mut file = File::open(bin_path).expect("Failed to open binary");
    let mut data = Vec::new();
    file.read_to_end(&mut data).expect("Failed to read binary");

    let mut cpu = cpu::Cpu::new();
    let mut mem = memory::Memory::new(1024 * 1024); // 1MB RAM for now

    // Load binary at offset 0
    mem.load_binary(&data, 0);

    // ==========================================
    // AURORA-X UNIVERSAL TESTBENCH MEMORY SETUP
    // ==========================================

    // --- Demo 1: Exception/Syscall Setup ---
    // Memory[100] = 64 (Address of the exception handler)
    mem.write_u64(100, 64);
    cpu.write_reg(10, 0); // Accumulator for the exception test

    // --- Demo 2 & 3: Vector & AI Setup ---
    // R6 = Base Address for both tests
    cpu.write_reg(6, 1000);
    // R5 = Vector Length or Exception Adder (16 bytes = 4 integers, OR 16 for addition)
    cpu.write_reg(5, 16);
    
    // X = [1, 2, 3, 4]
    mem.write_u64(1000, 1 | (2u64 << 32));
    mem.write_u64(1008, 3 | (4u64 << 32));
    
    // C = [3, 3, 3, 3]
    mem.write_u64(1016, 3 | (3u64 << 32));
    mem.write_u64(1024, 3 | (3u64 << 32));

    // B = [2, 2, 2, 2]
    mem.write_u64(1032, 2 | (2u64 << 32));
    mem.write_u64(1040, 2 | (2u64 << 32));
    
    // A = [5, 5, 5, 5]
    mem.write_u64(1048, 5 | (5u64 << 32));
    mem.write_u64(1056, 5 | (5u64 << 32));

    println!("Starting execution...");

    // Basic loop
    loop {
        if cpu.pc as usize >= data.len() {
            break; // Finished executing loaded binary
        }

        let inst = mem.read_u32(cpu.pc as usize);
        let dec = decoder::decode(inst);
        
        executor::execute(&mut cpu, &mut mem, &dec);
        
        cpu.pc += 4;
    }

    println!("Execution complete.");
    println!("--- Hardware State Dump ---");
    println!("R5 (VL/Add)   = {}", cpu.read_reg(5));
    println!("R6 (Base)     = {}", cpu.read_reg(6));
    println!("R10 (Accum)   = {}", cpu.read_reg(10));
    println!("AX_EPC (0x018)   = {}", cpu.read_csr(0x018));
    println!("AX_CAUSE (0x008) = {}", cpu.read_csr(0x008));
    println!("Mem[108] (Cause) = {}", mem.read_u64(108));
    
    // Read the output array for Demo 2 (Result is at 1032)
    let out2_0 = mem.read_u64(1032) & 0xFFFFFFFF;
    let out2_1 = mem.read_u64(1032) >> 32;
    let out2_2 = mem.read_u64(1040) & 0xFFFFFFFF;
    let out2_3 = mem.read_u64(1040) >> 32;
    
    // Read the output array for Demo 3 (Result Y is at 1064)
    let out3_0 = mem.read_u64(1064) & 0xFFFFFFFF;
    let out3_1 = mem.read_u64(1064) >> 32;
    let out3_2 = mem.read_u64(1072) & 0xFFFFFFFF;
    let out3_3 = mem.read_u64(1072) >> 32;
    
    println!("\n--- Vector Memory Output ---");
    if out2_0 != 2 && out2_0 != 0 { // Just heuristic to show demo 2 output if modified
        println!("Demo 2 Vector Output (Mem[1032]): [{}, {}, {}, {}]", out2_0, out2_1, out2_2, out2_3);
    }
    if out3_0 != 0 {
        println!("Demo 3 Vector Output (Mem[1064]): [{}, {}, {}, {}]", out3_0, out3_1, out3_2, out3_3);
    }
}
