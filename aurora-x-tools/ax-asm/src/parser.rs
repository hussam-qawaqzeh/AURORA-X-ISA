use crate::encoder::{Instruction, Reg};
use std::collections::HashMap;

pub fn parse_line(line: &str, labels: &HashMap<String, u32>, current_pc: u32) -> Option<Instruction> {
    let line = line.split(';').next().unwrap_or("").trim();
    if line.is_empty() || line.ends_with(':') {
        return None; // Ignore empty lines and label definitions during Pass 2
    }

    let parts: Vec<&str> = line.split(|c| c == ' ' || c == ',').filter(|s| !s.is_empty()).collect();
    if parts.is_empty() {
        return None;
    }

    let mnemonic = parts[0];
    
    match mnemonic {
        ".word" => {
            if parts.len() >= 2 {
                let val = parse_hex_or_int(parts[1]).unwrap_or(0) as u32;
                return Some(Instruction::Raw { val });
            }
        }
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
                let imm = parse_hex_or_int(parts[3]).unwrap_or(0) as i16;
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
        "SRA" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Sra { rd, rs1, rs2 });
            }
        }
        "FADD.X" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::FAdd { rd, rs1, rs2 });
            }
        }
        "FMUL.X" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::FMul { rd, rs1, rs2 });
            }
        }
        "LOAD.X" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?;
                let rs1 = Reg::parse(parts[2])?;
                let imm = parse_imm14(parts[3]);
                return Some(Instruction::LoadX { rd, rs1, imm });
            } else if parts.len() >= 3 {
                let rd = Reg::parse(parts[1])?;
                let mem_op = parts[2..].join("");
                let mem_op = mem_op.trim_start_matches('[').trim_end_matches(']');
                if let Some(plus_idx) = mem_op.find('+') {
                    let rs1 = Reg::parse(&mem_op[..plus_idx])?;
                    let imm_val = mem_op[plus_idx+1..].parse::<i32>().unwrap_or(0);
                    check_imm14_limit(imm_val);
                    return Some(Instruction::LoadX { rd, rs1, imm: imm_val as i16 });
                } else if let Some(minus_idx) = mem_op.find('-') {
                    let rs1 = Reg::parse(&mem_op[..minus_idx])?;
                    let imm_val = -mem_op[minus_idx+1..].parse::<i32>().unwrap_or(0);
                    check_imm14_limit(imm_val);
                    return Some(Instruction::LoadX { rd, rs1, imm: imm_val as i16 });
                } else {
                    let rs1 = Reg::parse(&mem_op)?;
                    return Some(Instruction::LoadX { rd, rs1, imm: 0 });
                }
            }
        }
        "STORE.X" => {
            if parts.len() >= 4 {
                let rs1 = Reg::parse(parts[1])?; // Base register
                let rs2 = Reg::parse(parts[2])?; // Data register
                let imm = parse_imm14(parts[3]);
                return Some(Instruction::StoreX { rs2, rs1, imm });
            } else if parts.len() >= 3 {
                let rs2 = Reg::parse(parts[1])?; // value to store
                let mem_op = parts[2..].join("");
                let mem_op = mem_op.trim_start_matches('[').trim_end_matches(']');
                if let Some(plus_idx) = mem_op.find('+') {
                    let rs1 = Reg::parse(&mem_op[..plus_idx])?;
                    let imm_val = mem_op[plus_idx+1..].parse::<i32>().unwrap_or(0);
                    check_imm14_limit(imm_val);
                    return Some(Instruction::StoreX { rs2, rs1, imm: imm_val as i16 });
                } else if let Some(minus_idx) = mem_op.find('-') {
                    let rs1 = Reg::parse(&mem_op[..minus_idx])?;
                    let imm_val = -mem_op[minus_idx+1..].parse::<i32>().unwrap_or(0);
                    check_imm14_limit(imm_val);
                    return Some(Instruction::StoreX { rs2, rs1, imm: imm_val as i16 });
                } else {
                    let rs1 = Reg::parse(&mem_op)?;
                    return Some(Instruction::StoreX { rs2, rs1, imm: 0 });
                }
            }
        }
        "BEQ" | "BRANCH.X" => {
            if parts.len() >= 4 {
                let rs1 = Reg::parse(parts[1])?; let rs2 = Reg::parse(parts[2])?; 
                let imm = parse_branch_target(parts[3], labels, current_pc)?;
                return Some(Instruction::BranchX { rs1, rs2, imm, btype: 0 }); // 0x40
            }
        }
        "BNE" => {
            if parts.len() >= 4 {
                let rs1 = Reg::parse(parts[1])?; let rs2 = Reg::parse(parts[2])?; 
                let imm = parse_branch_target(parts[3], labels, current_pc)?;
                return Some(Instruction::BranchX { rs1, rs2, imm, btype: 1 }); // 0x46
            }
        }
        "BLT" => {
            if parts.len() >= 4 {
                let rs1 = Reg::parse(parts[1])?; let rs2 = Reg::parse(parts[2])?; 
                let imm = parse_branch_target(parts[3], labels, current_pc)?;
                return Some(Instruction::BranchX { rs1, rs2, imm, btype: 2 }); // 0x47
            }
        }
        "BGE" => {
            if parts.len() >= 4 {
                let rs1 = Reg::parse(parts[1])?; let rs2 = Reg::parse(parts[2])?; 
                let imm = parse_branch_target(parts[3], labels, current_pc)?;
                return Some(Instruction::BranchX { rs1, rs2, imm, btype: 3 }); // 0x48
            }
        }
        "BLTU" => {
            if parts.len() >= 4 {
                let rs1 = Reg::parse(parts[1])?; let rs2 = Reg::parse(parts[2])?; 
                let imm = parse_branch_target(parts[3], labels, current_pc)?;
                return Some(Instruction::BranchX { rs1, rs2, imm, btype: 4 }); // 0x49
            }
        }
        "BGEU" => {
            if parts.len() >= 4 {
                let rs1 = Reg::parse(parts[1])?; let rs2 = Reg::parse(parts[2])?; 
                let imm = parse_branch_target(parts[3], labels, current_pc)?;
                return Some(Instruction::BranchX { rs1, rs2, imm, btype: 5 }); // 0x4A
            }
        }
        "MUL" | "MUL.X" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Mul { rd, rs1, rs2 });
            }
        }
        "DIV" | "DIV.X" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Div { rd, rs1, rs2 });
            }
        }
        "SLT" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Slt { rd, rs1, rs2 });
            }
        }
        "SLTU" => {
            if parts.len() >= 4 {
                let rd = Reg::parse(parts[1])?; let rs1 = Reg::parse(parts[2])?; let rs2 = Reg::parse(parts[3])?;
                return Some(Instruction::Sltu { rd, rs1, rs2 });
            }
        }
        "JUMP.X" => {
            if parts.len() >= 3 {
                let rd = Reg::parse(parts[1])?;
                let imm = parse_jump_target(parts[2], labels, current_pc)?;
                return Some(Instruction::JumpX { rd, imm });
            }
        }
        "CSR.READ" => {
            if parts.len() >= 3 {
                let rd = Reg::parse(parts[1])?;
                let csr_addr = parse_hex_or_int(parts[2])? as u16;
                return Some(Instruction::CsrRead { rd, csr_addr });
            }
        }
        "CSR.WRITE" => {
            if parts.len() >= 3 {
                let rs1 = Reg::parse(parts[1])?;
                let csr_addr = parse_hex_or_int(parts[2])? as u16;
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
                    let imm_val = mem_op[plus_idx+1..].parse::<i32>().unwrap_or(0);
                    check_imm14_limit(imm_val);
                    return Some(Instruction::VLoad { vd, rs1, imm: imm_val as i16 });
                } else if let Some(minus_idx) = mem_op.find('-') {
                    let rs1 = Reg::parse(&mem_op[..minus_idx])?;
                    let imm_val = -mem_op[minus_idx+1..].parse::<i32>().unwrap_or(0);
                    check_imm14_limit(imm_val);
                    return Some(Instruction::VLoad { vd, rs1, imm: imm_val as i16 });
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
                    let imm_val = mem_op[plus_idx+1..].parse::<i32>().unwrap_or(0);
                    check_imm14_limit(imm_val);
                    return Some(Instruction::VStore { vs2, rs1, imm: imm_val as i16 });
                } else if let Some(minus_idx) = mem_op.find('-') {
                    let rs1 = Reg::parse(&mem_op[..minus_idx])?;
                    let imm_val = -mem_op[minus_idx+1..].parse::<i32>().unwrap_or(0);
                    check_imm14_limit(imm_val);
                    return Some(Instruction::VStore { vs2, rs1, imm: imm_val as i16 });
                } else {
                    let rs1 = Reg::parse(&mem_op)?;
                    return Some(Instruction::VStore { vs2, rs1, imm: 0 });
                }
            }
        }
        "VADD" | "VADD.M" => {
            if parts.len() >= 4 {
                let vd = Reg::parse(parts[1])?;
                let vs1 = Reg::parse(parts[2])?;
                let vs2 = Reg::parse(parts[3])?;
                return Some(Instruction::VAdd { vd, vs1, vs2, masked: parts[0] == "VADD.M" });
            }
        }
        "VMUL" | "VMUL.M" => {
            if parts.len() >= 4 {
                let vd = Reg::parse(parts[1])?;
                let vs1 = Reg::parse(parts[2])?;
                let vs2 = Reg::parse(parts[3])?;
                return Some(Instruction::VMul { vd, vs1, vs2, masked: parts[0] == "VMUL.M" });
            }
        }
        "VFMA" | "VFMA.M" => {
            if parts.len() >= 4 {
                let vd = Reg::parse(parts[1])?;
                let vs1 = Reg::parse(parts[2])?;
                let vs2 = Reg::parse(parts[3])?;
                return Some(Instruction::VFma { vd, vs1, vs2, masked: parts[0] == "VFMA.M" });
            }
        }
        "VPERM" | "VPERM.M" => {
            if parts.len() >= 4 {
                let vd = Reg::parse(parts[1])?;
                let vs1 = Reg::parse(parts[2])?;
                let vs2 = Reg::parse(parts[3])?;
                return Some(Instruction::VPerm { vd, vs1, vs2, masked: parts[0] == "VPERM.M" });
            }
        }
        "VCMP.GT" => {
            if parts.len() >= 3 {
                let vs1 = Reg::parse(parts[1])?;
                let vs2 = Reg::parse(parts[2])?;
                return Some(Instruction::VCmpGt { vs1, vs2 });
            }
        }
        _ => {}
    }
    
    None
}

fn parse_hex_or_int(s: &str) -> Option<i32> {
    let res = if s.starts_with("0x") || s.starts_with("0X") {
        u32::from_str_radix(&s[2..], 16).map(|v| v as i32).ok()
    } else {
        s.parse::<i32>().ok()
    };
    if res.is_none() {
        println!("Failed to parse imm: '{}' (len={}, bytes={:?})", s, s.len(), s.as_bytes());
    }
    res
}

fn check_imm14_limit(val: i32) {
    if val < -8192 || val > 8191 {
        eprintln!("[Warning] Immediate value {} exceeds signed 14-bit range (-8192 to 8191)", val);
    }
}

fn parse_imm14(s: &str) -> i16 {
    let val = parse_hex_or_int(s).unwrap_or(0);
    check_imm14_limit(val);
    val as i16
}

fn parse_branch_target(s: &str, labels: &HashMap<String, u32>, current_pc: u32) -> Option<i16> {
    let val = if let Some(&target_pc) = labels.get(s) {
        let diff = target_pc as i32 - current_pc as i32;
        diff / 4
    } else {
        parse_hex_or_int(s).unwrap_or(0)
    };
    check_imm14_limit(val);
    Some(val as i16)
}

fn parse_jump_target(s: &str, labels: &HashMap<String, u32>, current_pc: u32) -> Option<i32> {
    let val = if let Some(&target_pc) = labels.get(s) {
        let diff = target_pc as i32 - current_pc as i32;
        diff / 4
    } else {
        if s.starts_with("0x") || s.starts_with("0X") {
            i32::from_str_radix(&s[2..], 16).unwrap_or(0)
        } else {
            s.parse::<i32>().unwrap_or(0)
        }
    };
    if val < -262144 || val > 262143 {
        eprintln!("[Warning] Jump target/offset {} exceeds signed 19-bit range (-262144 to 262143)", val);
    }
    Some(val)
}
