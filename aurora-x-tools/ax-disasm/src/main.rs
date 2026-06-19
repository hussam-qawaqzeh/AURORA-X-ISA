use std::env;
use std::fs::File;
use std::io::Read;

pub struct DecodedInstruction {
    pub opcode: u8,
    pub rd: usize,
    pub rs1: usize,
    pub rs2: usize,
    pub imm14: i16,
    pub imm19: i32,
    pub csr_addr: u16,
    pub funct9: u16,
}

pub fn decode(inst: u32) -> DecodedInstruction {
    let opcode = ((inst >> 24) & 0xFF) as u8;
    let rd = ((inst >> 19) & 0x1F) as usize;
    let rs1 = ((inst >> 14) & 0x1F) as usize;
    let rs2 = ((inst >> 9) & 0x1F) as usize;
    
    let mut imm14_raw = (inst & 0x3FFF) as u16;
    if (imm14_raw & 0x2000) != 0 {
        imm14_raw |= 0xC000;
    }
    let imm14 = imm14_raw as i16;
    
    let mut imm19_raw = (inst & 0x7FFFF) as i32;
    if (imm19_raw & 0x40000) != 0 {
        imm19_raw |= -0x80000;
    }
    let imm19 = imm19_raw;
    
    let csr_addr = ((inst >> 7) & 0xFFF) as u16;
    let funct9 = (inst & 0x1FF) as u16;

    DecodedInstruction {
        opcode,
        rd,
        rs1,
        rs2,
        imm14,
        imm19,
        csr_addr,
        funct9,
    }
}

fn disassemble(inst: u32, _pc: usize) -> String {
    let dec = decode(inst);
    match dec.opcode {
        0x01 => {
            if dec.funct9 == 0x00 {
                format!("ADD.X R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2)
            } else if dec.funct9 == 0x01 {
                format!("SUB.X R{}, R{}, R{}", dec.rd, dec.rs1, dec.rs2)
            } else {
                format!(".UNKNOWN_INT_OP")
            }
        }
        0x21 => {
            format!("LOAD.X R{}, [R{}{}]", dec.rd, dec.rs1, if dec.imm14 != 0 { format!("{:+}", dec.imm14) } else { "".to_string() })
        }
        0x22 => {
            // S-Type: rs1 is at rd position [23:19], rs2 is at rs1 position [18:14]
            format!("STORE.X R{}, [R{}{}]", dec.rs1, dec.rd, if dec.imm14 != 0 { format!("{:+}", dec.imm14) } else { "".to_string() })
        }
        0x40 => {
            format!("BRANCH.X R{}, R{}, {}", dec.rd, dec.rs1, dec.imm14)
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
        0x60 => {
            format!("VLOAD V{}, [R{}{}]", dec.rd, dec.rs1, if dec.imm14 != 0 { format!("{:+}", dec.imm14) } else { "".to_string() })
        }
        0x61 => {
            // S-Type encoding for VSTORE: rs1 is base (dec.rd), vs2 is val (dec.rs1)
            format!("VSTORE V{}, [R{}{}]", dec.rs1, dec.rd, if dec.imm14 != 0 { format!("{:+}", dec.imm14) } else { "".to_string() })
        }
        0x62 => {
            format!("VADD V{}, V{}, V{}", dec.rd, dec.rs1, dec.rs2)
        }
        0x63 => {
            format!("VMUL V{}, V{}, V{}", dec.rd, dec.rs1, dec.rs2)
        }
        0x64 => {
            format!("VFMA V{}, V{}, V{}", dec.rd, dec.rs1, dec.rs2)
        }
        0x65 => {
            format!("VPERM V{}, V{}, V{}", dec.rd, dec.rs1, dec.rs2)
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
