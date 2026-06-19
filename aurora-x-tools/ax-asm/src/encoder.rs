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
    /// R-Type: ADD.X rd, rs1, rs2
    AddX { rd: Reg, rs1: Reg, rs2: Reg },
    /// R-Type: SUB.X rd, rs1, rs2
    SubX { rd: Reg, rs1: Reg, rs2: Reg },
    /// I-Type: LOAD.X rd, [rs1 + imm]
    LoadX { rd: Reg, rs1: Reg, imm: i16 },
    /// S-Type: STORE.X rs2, [rs1 + imm]
    StoreX { rs2: Reg, rs1: Reg, imm: i16 },
    /// B-Type: BRANCH.X rs1, rs2, imm
    BranchX { rs1: Reg, rs2: Reg, imm: i16 },
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
            Instruction::AddX { rd, rs1, rs2 } => {
                let opcode: u32 = 0x01; // Integer Op
                let funct9: u32 = 0x00; // 64-bit ADD
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
            Instruction::SubX { rd, rs1, rs2 } => {
                let opcode: u32 = 0x01; // Integer Op
                let funct9: u32 = 0x01; // 64-bit SUB
                let rd_val = match rd { Reg::R(v) => *v as u32 };
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                
                (opcode << 24) | (rd_val << 19) | (rs1_val << 14) | (rs2_val << 9) | funct9
            }
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
            Instruction::BranchX { rs1, rs2, imm } => {
                let opcode: u32 = 0x40; // BRANCH.X
                let rs1_val = match rs1 { Reg::R(v) => *v as u32 };
                let rs2_val = match rs2 { Reg::R(v) => *v as u32 };
                let imm_val = (*imm as u32) & 0x3FFF; // 14-bit mask
                (opcode << 24) | (rs1_val << 19) | (rs2_val << 14) | imm_val
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
