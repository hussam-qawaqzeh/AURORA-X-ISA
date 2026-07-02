use std::env;
use std::fs::File;
use std::io::Read;
use ax_emu::decoder::decode;

fn disassemble(inst: u32, _pc: usize) -> String {
    let dec = decode(inst);
    match dec.opcode {
        0x01 => {
            let funct9 = inst & 0x1FF;
            if funct9 == 0 { format!("ADD.X R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2) }
            else if funct9 == 1 { format!("SUB.X R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2) }
            else { format!("UNKNOWN.01 R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2) }
        },
        0x02 => format!("AND R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2),
        0x03 => format!("OR R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2),
        0x04 => format!("XOR R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2),
        0x05 => format!("SHL R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2),
        0x06 => {
            let funct9 = inst & 0x1FF;
            if funct9 == 1 { format!("SRA R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2) }
            else { format!("SHR R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2) }
        },
        0x07 => format!("MUL.X R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2),
        0x08 => format!("DIV.X R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2),
        0x09 => format!("ADDI R{}, R{}, {}", dec.rd, dec.rs1, dec.imm14),
        0x0A => format!("SLT R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2),
        0x0B => format!("SLTU R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2),
        0x21 => {
            format!("LOAD.X R{}, [R{}{}]", dec.rd, dec.rs1, if dec.imm14 != 0 { format!("{:+}", dec.imm14) } else { "".to_string() })
        }
        0x22 => {
            // S-Type: rs1 is at rd position [23:19], rs2 is at rs1 position [18:14]
            format!("STORE.X R{}, [R{}{}]", dec.rs1, dec.rd, if dec.imm14 != 0 { format!("{:+}", dec.imm14) } else { "".to_string() })
        }
        0x40 => {
            format!("BEQ R{}, R{}, {}", dec.rd, dec.rs1, dec.imm14)
        }
        0x46 => {
            format!("BNE R{}, R{}, {}", dec.rd, dec.rs1, dec.imm14)
        }
        0x47 => {
            format!("BLT R{}, R{}, {}", dec.rd, dec.rs1, dec.imm14)
        }
        0x48 => {
            format!("BGE R{}, R{}, {}", dec.rd, dec.rs1, dec.imm14)
        }
        0x49 => {
            format!("BLTU R{}, R{}, {}", dec.rd, dec.rs1, dec.imm14)
        }
        0x4A => {
            format!("BGEU R{}, R{}, {}", dec.rd, dec.rs1, dec.imm14)
        }
        0x41 => {
            format!("JUMP.X R{}, {}", dec.rd, dec.imm19)
        }
        0x42 => {
            format!("CSR.READ R{}, 0x{:03X}", dec.rd, dec.csr_addr)
        }
        0x43 => {
            // CSR.WRITE: rs1 is at [23:19] which is decoded as rd
            format!("CSR.WRITE R{}, 0x{:03X}", dec.rd, dec.csr_addr)
        }
        0x44 => {
            format!("ECALL")
        }
        0x45 => {
            format!("EXRET")
        }
        0x50 => format!("FADD.X R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2),
        0x51 => format!("FMUL.X R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2),
        0x54 => {
            format!("VCMP.GT V{}, V{}", dec.rs1, dec.rs2)
        }
        0x60 => {
            format!("VLOAD V{}, [R{}{}]", dec.rd, dec.rs1, if dec.imm14 != 0 { format!("{:+}", dec.imm14) } else { "".to_string() })
        }
        0x61 => {
            // S-Type encoding for VSTORE: rs1 is base (dec.rd), vs2 is val (dec.rs1)
            format!("VSTORE V{}, [R{}{}]", dec.rs1, dec.rd, if dec.imm14 != 0 { format!("{:+}", dec.imm14) } else { "".to_string() })
        }
        0x62 => {
            let masked = (inst & 0x100) != 0;
            format!("VADD{} V{}, V{}, V{}", if masked { ".M" } else { "" }, dec.rd, dec.rs1, dec.rs2)
        }
        0x63 => {
            let masked = (inst & 0x100) != 0;
            format!("VMUL{} V{}, V{}, V{}", if masked { ".M" } else { "" }, dec.rd, dec.rs1, dec.rs2)
        }
        0x64 => {
            let masked = (inst & 0x100) != 0;
            format!("VFMA{} V{}, V{}, V{}", if masked { ".M" } else { "" }, dec.rd, dec.rs1, dec.rs2)
        }
        0x65 => {
            let masked = (inst & 0x100) != 0;
            format!("VPERM{} V{}, V{}, V{}", if masked { ".M" } else { "" }, dec.rd, dec.rs1, dec.rs2)
        }
        _ => format!(".WORD 0x{:08X}", inst),
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: ax-disasm <binary.bin>");
        return;
    }

    let bin_path = &args[1];
    let mut file = File::open(bin_path).expect("Failed to open binary");
    let mut data = Vec::new();
    file.read_to_end(&mut data).expect("Failed to read binary");

    if data.len() % 4 != 0 {
        eprintln!("Warning: Binary size is not a multiple of 4 bytes.");
    }

    println!("Disassembly of {}:", bin_path);
    for (i, chunk) in data.chunks(4).enumerate() {
        if chunk.len() == 4 {
            let inst = u32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
            let pc = i * 4;
            let asm = disassemble(inst, pc);
            println!("{:08X}:  {:08X}    {}", pc, inst, asm);
        }
    }
}
