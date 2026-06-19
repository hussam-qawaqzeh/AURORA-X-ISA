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
    
    // imm14 is signed
    let mut imm14_raw = (inst & 0x3FFF) as u16;
    // sign extend 14 bit to 16 bit
    if (imm14_raw & 0x2000) != 0 {
        imm14_raw |= 0xC000;
    }
    let imm14 = imm14_raw as i16;
    
    // imm19 is signed
    let mut imm19_raw = (inst & 0x7FFFF) as i32;
    if (imm19_raw & 0x40000) != 0 {
        imm19_raw |= -0x80000; // Sign extend to i32
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
