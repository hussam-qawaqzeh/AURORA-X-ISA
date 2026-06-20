pub enum Reg {
    R(u8),
}

impl Reg {
    pub fn parse(s: &str) -> Option<Self> {
        if s.starts_with('R') || s.starts_with('V') {
            if let Ok(num) = s[1..].parse::<u8>() {
                if num < 32 {
                    return Some(Reg::R(num)); // We store as R internally, the instruction type defines if it's GPR or VR
                }
            }
        }
        None
    }
}

pub enum Instruction {
    /// Arithmetic: ADD.X rd, rs1, rs2
    Add { rd: Reg, rs1: Reg, rs2: Reg },
    /// Arithmetic: ADDI rd, rs1, imm
    AddI { rd: Reg, rs1: Reg, imm: i16 },
    /// Arithmetic: SUB.X rd, rs1, rs2
    Sub { rd: Reg, rs1: Reg, rs2: Reg },
    /// Logic: AND rd, rs1, rs2
    And { rd: Reg, rs1: Reg, rs2: Reg },
    /// Logic: OR rd, rs1, rs2
    Or { rd: Reg, rs1: Reg, rs2: Reg },
    /// Logic: XOR rd, rs1, rs2
    Xor { rd: Reg, rs1: Reg, rs2: Reg },
    /// Logic: SHL rd, rs1, rs2
    Shl { rd: Reg, rs1: Reg, rs2: Reg },
    /// Logic: SHR rd, rs1, rs2
    Shr { rd: Reg, rs1: Reg, rs2: Reg },
    /// I-Type: LOAD.X rd, [rs1 + imm]
    LoadX { rd: Reg, rs1: Reg, imm: i16 },
    /// S-Type: STORE.X rs2, [rs1 + imm]
    StoreX { rs2: Reg, rs1: Reg, imm: i16 },
    /// B-Type: BRANCH.X rs1, rs2, imm
    BranchX { rs1: Reg, rs2: Reg, imm: i16, btype: u8 },
    /// Arithmetic: MUL rd, rs1, rs2
    Mul { rd: Reg, rs1: Reg, rs2: Reg },
    /// Arithmetic: DIV rd, rs1, rs2
    Div { rd: Reg, rs1: Reg, rs2: Reg },
    /// Comparison: SLT rd, rs1, rs2
    Slt { rd: Reg, rs1: Reg, rs2: Reg },
    /// Comparison: SLTU rd, rs1, rs2
    Sltu { rd: Reg, rs1: Reg, rs2: Reg },
    /// J-Type: JUMP.X rd, imm
    JumpX { rd: Reg, imm: i32 },
    /// CSR-Type: CSR.READ rd, csr_addr
    CsrRead { rd: Reg, csr_addr: u16 },
    /// CSR-Type: CSR.WRITE rs1, csr_addr
    CsrWrite { rs1: Reg, csr_addr: u16 },
    /// System: ECALL
    Ecall,
    /// System: EXRET
    Exret,
    /// Vector: VLOAD vd, [rs1 + imm]
    VLoad { vd: Reg, rs1: Reg, imm: i16 },
    /// Vector: VSTORE vs2, [rs1 + imm]
    VStore { vs2: Reg, rs1: Reg, imm: i16 },
    /// Vector: VADD vd, vs1, vs2
    VAdd { vd: Reg, vs1: Reg, vs2: Reg },
    /// Vector: VMUL vd, vs1, vs2
    VMul { vd: Reg, vs1: Reg, vs2: Reg },
    /// Vector: VFMA vd, vs1, vs2
    VFma { vd: Reg, vs1: Reg, vs2: Reg },
    /// Vector: VPERM vd, vs1, vs2
    VPerm { vd: Reg, vs1: Reg, vs2: Reg },
}

impl Instruction {
    pub fn encode(&self) -> u32 {
        match self {
            Instruction::LoadX { rd, rs1, imm } => {
                let opcode: u32 = 0x21; // LOAD.X
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let imm_val = (*imm as u32) & 0x3FFF; // 14-bit mask
                
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | imm_val
            }
            Instruction::StoreX { rs2, rs1, imm } => {
                let opcode: u32 = 0x22; // STORE.X
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                let imm_val = (*imm as u32) & 0x3FFF; // 14-bit mask
                
                // S-Type: [31:24 opcode] [23:19 rs1] [18:14 rs2] [13:0 imm14]
                (opcode << 24) | (rs1_val << 19) | (rs2_val << 14) | imm_val
            }
            Instruction::BranchX { rs1, rs2, imm, btype } => {
                let opcode: u32 = match btype {
                    0 => 0x40, // BNE
                    1 => 0x46, // BEQ
                    2 => 0x47, // BLT
                    3 => 0x48, // BGE
                    4 => 0x49, // BLTU
                    5 => 0x4A, // BGEU
                    _ => 0x40,
                };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                let imm_val = (*imm as u32) & 0x3FFF; // 14-bit mask
                (opcode << 24) | (rs1_val << 19) | (rs2_val << 14) | imm_val
            }
            Instruction::Mul { rd, rs1, rs2 } => {
                let opcode: u32 = 0x07; // MUL.X
                let funct9: u32 = 0x00;
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::Div { rd, rs1, rs2 } => {
                let opcode: u32 = 0x08; // DIV.X
                let funct9: u32 = 0x00;
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::Slt { rd, rs1, rs2 } => {
                let opcode: u32 = 0x0A; // SLT
                let funct9: u32 = 0x00;
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::Sltu { rd, rs1, rs2 } => {
                let opcode: u32 = 0x0B; // SLTU
                let funct9: u32 = 0x00;
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::JumpX { rd, imm } => {
                let opcode: u32 = 0x41; // JUMP.X
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let imm_val = (*imm as u32) & 0x7FFFF; // 19-bit mask
                (opcode << 24) | (rd_val << 19) | imm_val
            }
            Instruction::CsrRead { rd, csr_addr } => {
                let opcode: u32 = 0x42; // CSR.READ
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let addr_val = (*csr_addr as u32) & 0xFFF; // 12-bit
                (opcode << 24) | (rd_val << 19) | (addr_val << 7)
            }
            Instruction::CsrWrite { rs1, csr_addr } => {
                let opcode: u32 = 0x43; // CSR.WRITE
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let addr_val = (*csr_addr as u32) & 0xFFF; // 12-bit
                (opcode << 24) | (rs1_val << 19) | (addr_val << 7)
            }
            Instruction::Ecall => {
                let opcode: u32 = 0x44; // ECALL
                opcode << 24
            }
            Instruction::Exret => {
                let opcode: u32 = 0x45; // EXRET
                opcode << 24
            }
            Instruction::VLoad { vd, rs1, imm } => {
                let opcode: u32 = 0x60; // VLOAD
                let rd_val = match vd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let imm_val = (*imm as u32) & 0x3FFF;
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | imm_val
            }
            Instruction::VStore { vs2, rs1, imm } => {
                let opcode: u32 = 0x61; // VSTORE
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match vs2 { Reg::R(v) => *v as u32 };
                let imm_val = (*imm as u32) & 0x3FFF;
                (opcode << 24) | (rs1_val << 19) | (rs2_val << 14) | imm_val
            }
            Instruction::Add { rd, rs1, rs2 } => {
                let opcode: u32 = 0x01; // ADD.X
                let funct9: u32 = 0x00; // 64-bit add
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::AddI { rd, rs1, imm } => {
                let opcode: u32 = 0x09; // ADDI
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let imm_val = (*imm as u32) & 0x3FFF;
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | imm_val
            }
            Instruction::Sub { rd, rs1, rs2 } => {
                let opcode: u32 = 0x01; // SUB.X
                let funct9: u32 = 0x01; // 64-bit sub
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::And { rd, rs1, rs2 } => {
                let opcode: u32 = 0x02; let funct9: u32 = 0x00;
                let rd_val = match rd { Reg::R(v) => *v as u32 }; let rs1_val = match rs1 { Reg::R(v) => *v as u32 }; let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::Or { rd, rs1, rs2 } => {
                let opcode: u32 = 0x03; let funct9: u32 = 0x00;
                let rd_val = match rd { Reg::R(v) => *v as u32 }; let rs1_val = match rs1 { Reg::R(v) => *v as u32 }; let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::Xor { rd, rs1, rs2 } => {
                let opcode: u32 = 0x04; let funct9: u32 = 0x00;
                let rd_val = match rd { Reg::R(v) => *v as u32 }; let rs1_val = match rs1 { Reg::R(v) => *v as u32 }; let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::Shl { rd, rs1, rs2 } => {
                let opcode: u32 = 0x05; let funct9: u32 = 0x00;
                let rd_val = match rd { Reg::R(v) => *v as u32 }; let rs1_val = match rs1 { Reg::R(v) => *v as u32 }; let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::Shr { rd, rs1, rs2 } => {
                let opcode: u32 = 0x06; let funct9: u32 = 0x00;
                let rd_val = match rd { Reg::R(v) => *v as u32 }; let rs1_val = match rs1 { Reg::R(v) => *v as u32 }; let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::VAdd { vd, vs1, vs2 } => {
                let opcode: u32 = 0x62; // VADD
                let funct9: u32 = 0x00; // 32-bit element
                let rd_val = match vd { Reg::R(v) => *v as u32 };
                let rs1_val = match vs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match vs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::VMul { vd, vs1, vs2 } => {
                let opcode: u32 = 0x63; // VMUL
                let funct9: u32 = 0x00;
                let rd_val = match vd { Reg::R(v) => *v as u32 };
                let rs1_val = match vs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match vs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::VFma { vd, vs1, vs2 } => {
                let opcode: u32 = 0x64; // VFMA
                let funct9: u32 = 0x00;
                let rd_val = match vd { Reg::R(v) => *v as u32 };
                let rs1_val = match vs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match vs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::VPerm { vd, vs1, vs2 } => {
                let opcode: u32 = 0x65; // VPERM
                let funct9: u32 = 0x00;
                let rd_val = match vd { Reg::R(v) => *v as u32 };
                let rs1_val = match vs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match vs2 { Reg::R(v) => *v as u32 };
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
        }
    }
}
