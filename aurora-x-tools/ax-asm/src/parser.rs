use crate::encoder::{Instruction, Reg};

pub fn parse_line(line: &str) -> Option<Instruction> {
    let line = line.split(';').next().unwrap_or("").trim();
    if line.is_empty() {
        return None;
    }

    let parts: Vec<&str> = line.split(|c| c == ' ' || c == ',').filter(|s| !s.is_empty()).collect();
    if parts.is_empty() {
        return None;
    }

    let mnemonic = parts[0];
    
    match mnemonic {
        "ADD.X" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?;
                let rs1 = Reg::parse(parts[2])?;
                let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Add { rd, rs1, rs2 });
            }
        }
        "ADDI" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?;
                let rs1 = Reg::parse(parts[2])?;
                let imm = parts[3].parse::<i16>().unwrap_or(0);
                return Some(Instruction::AddI { rd, rs1, imm });
            }
        }
        "SUB.X" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?;
                let rs1 = Reg::parse(parts[2])?;
                let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Sub { rd, rs1, rs2 });
            }
        }
        "AND" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::And { rd, rs1, rs2 });
            }
        }
        "OR" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Or { rd, rs1, rs2 });
            }
        }
        "XOR" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Xor { rd, rs1, rs2 });
            }
        }
        "SHL" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Shl { rd, rs1, rs2 });
            }
        }
        "SHR" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Shr { rd, rs1, rs2 });
            }
        }
        "LOAD.X" => {
            // LOAD.X R5, [R6]  or LOAD.X R5, [R6+10]
            if parts.len() >= 3 {
                let rd = Reg::parse(parts[1])?;
                let mem_op = parts[2..].join("");
                let mem_op = mem_op.trim_start_matches('[').trim_end_matches(']');
                
                // parse R6 or R6+10
                if let Some(plus_idx) = mem_op.find('+') {
                    let rs1 = Reg::parse(&mem_op[..plus_idx])?;
                    let imm = mem_op[plus_idx+1..].parse::<i16>().unwrap_or(0);
                    return Some(Instruction::LoadX { rd, rs1, imm });
                } else {
                    let rs1 = Reg::parse(&mem_op)?;
                    return Some(Instruction::LoadX { rd, rs1, imm: 0 });
                }
            }
        }
        "STORE.X" => {
            if parts.len() >= 3 {
                let rs2 = Reg::parse(parts[1])?; // value to store
                let mem_op = parts[2..].join("");
                let mem_op = mem_op.trim_start_matches('[').trim_end_matches(']');
                
                if let Some(plus_idx) = mem_op.find('+') {
                    let rs1 = Reg::parse(&mem_op[..plus_idx])?;
                    let imm = mem_op[plus_idx+1..].parse::<i16>().unwrap_or(0);
                    return Some(Instruction::StoreX { rs2, rs1, imm });
                } else {
                    let rs1 = Reg::parse(&mem_op)?;
                    return Some(Instruction::StoreX { rs2, rs1, imm: 0 });
                }
            }
        }
        "BRANCH.X" => {
            if parts.len() >= 4 {
                let rs1 = Reg::parse(parts[1])?;
                let rs2 = Reg::parse(parts[2])?;
                let imm = parts[3].parse::<i16>().unwrap_or(0);
                return Some(Instruction::BranchX { rs1, rs2, imm });
            }
        }
        "JUMP.X" => {
            if parts.len() >= 3 {
                let rd = Reg::parse(parts[1])?;
                let imm = parts[2].parse::<i32>().unwrap_or(0);
                return Some(Instruction::JumpX { rd, imm });
            }
        }
        "CSR.READ" => {
            if parts.len() >= 3 {
                let rd = Reg::parse(parts[1])?;
                let csr_addr = parse_hex_or_int(parts[2])?;
                return Some(Instruction::CsrRead { rd, csr_addr });
            }
        }
        "CSR.WRITE" => {
            if parts.len() >= 3 {
                let rs1 = Reg::parse(parts[1])?;
                let csr_addr = parse_hex_or_int(parts[2])?;
                return Some(Instruction::CsrWrite { rs1, csr_addr });
            }
        }
        "ECALL" => {
            return Some(Instruction::Ecall);
        }
        "EXRET" => {
            return Some(Instruction::Exret);
        }
        "VLOAD" => {
            if parts.len() >= 3 {
                let vd = Reg::parse(parts[1])?;
                let mem_op = parts[2..].join("");
                let mem_op = mem_op.trim_start_matches('[').trim_end_matches(']');
                if let Some(plus_idx) = mem_op.find('+') {
                    let rs1 = Reg::parse(&mem_op[..plus_idx])?;
                    let imm = mem_op[plus_idx+1..].parse::<i16>().unwrap_or(0);
                    return Some(Instruction::VLoad { vd, rs1, imm });
                } else {
                    let rs1 = Reg::parse(&mem_op)?;
                    return Some(Instruction::VLoad { vd, rs1, imm: 0 });
                }
            }
        }
        "VSTORE" => {
            if parts.len() >= 3 {
                let vs2 = Reg::parse(parts[1])?;
                let mem_op = parts[2..].join("");
                let mem_op = mem_op.trim_start_matches('[').trim_end_matches(']');
                if let Some(plus_idx) = mem_op.find('+') {
                    let rs1 = Reg::parse(&mem_op[..plus_idx])?;
                    let imm = mem_op[plus_idx+1..].parse::<i16>().unwrap_or(0);
                    return Some(Instruction::VStore { vs2, rs1, imm });
                } else {
                    let rs1 = Reg::parse(&mem_op)?;
                    return Some(Instruction::VStore { vs2, rs1, imm: 0 });
                }
            }
        }
        "VADD" => {
            if parts.len() >= 4 {
                let vd = Reg::parse(parts[1])?;
                let vs1 = Reg::parse(parts[2])?;
                let vs2 = Reg::parse(parts[3])?;
                return Some(Instruction::VAdd { vd, vs1, vs2 });
            }
        }
        "VMUL" => {
            if parts.len() >= 4 {
                let vd = Reg::parse(parts[1])?;
                let vs1 = Reg::parse(parts[2])?;
                let vs2 = Reg::parse(parts[3])?;
                return Some(Instruction::VMul { vd, vs1, vs2 });
            }
        }
        "VFMA" => {
            if parts.len() >= 4 {
                let vd = Reg::parse(parts[1])?;
                let vs1 = Reg::parse(parts[2])?;
                let vs2 = Reg::parse(parts[3])?;
                return Some(Instruction::VFma { vd, vs1, vs2 });
            }
        }
        "VPERM" => {
            if parts.len() >= 4 {
                let vd = Reg::parse(parts[1])?;
                let vs1 = Reg::parse(parts[2])?;
                let vs2 = Reg::parse(parts[3])?;
                return Some(Instruction::VPerm { vd, vs1, vs2 });
            }
        }
        _ => {}
    }
    
    None
}

fn parse_hex_or_int(s: &str) -> Option<u16> {
    if s.starts_with("0x") || s.starts_with("0X") {
        u16::from_str_radix(&s[2..], 16).ok()
    } else {
        s.parse::<u16>().ok()
    }
}
