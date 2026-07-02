use crate::cpu::Cpu;
use crate::memory::Memory;
use crate::decoder::DecodedInstruction;

pub fn translate(cpu: &mut Cpu, mem: &mut Memory, vaddr: u64, is_write: bool) -> Result<u64, u8> {
    let mmu_control = cpu.read_csr(0x200);
    if mmu_control == 0 {
        return Ok(vaddr);
    }
    
    // Single-level paging (4KB pages = 12 bit offset)
    let page_table_base = cpu.read_csr(0x208);
    let vpn = vaddr >> 12;
    let offset = vaddr & 0xFFF;
    
    // PTE address
    let pte_addr = page_table_base + (vpn * 8);
    if pte_addr + 8 > mem.ram.len() as u64 {
        return Err(0x03); // Page Fault
    }
    
    let pte = mem.read_u64(pte_addr as usize);
    let valid = (pte & 0x1) != 0;
    let writeable = (pte & 0x2) != 0;
    
    if !valid || (is_write && !writeable) {
        return Err(0x03); // Page Fault
    }
    
    let ppn = pte >> 12;
    Ok((ppn << 12) | offset)
}

fn enter_trap(cpu: &mut Cpu, cause: u64) {
    let handler = cpu.read_csr(0x020);
    if handler != 0 {
        cpu.write_csr(0x018, cpu.pc);
        cpu.write_csr(0x008, cause);
        cpu._pl = 3; // Elevate privilege to PL3
        cpu.pc = handler.wrapping_sub(4);
    }
}

pub fn execute(cpu: &mut Cpu, mem: &mut Memory, dec: &DecodedInstruction) {
    match dec.opcode {
        0x01 => {
            if dec.funct9 == 0x00 {
                // ADD.X
                let val1 = cpu.read_reg(dec.rs1);
                let val2 = cpu.read_reg(dec.rs2);
                cpu.write_reg(dec.rd, val1.wrapping_add(val2));
            } else if dec.funct9 == 0x01 {
                // SUB.X
                let val1 = cpu.read_reg(dec.rs1);
                let val2 = cpu.read_reg(dec.rs2);
                cpu.write_reg(dec.rd, val1.wrapping_sub(val2));
            } else {
                eprintln!("Unknown funct9 {:02X} for opcode 0x01", dec.funct9);
                std::process::exit(1);
            }
        }
        0x02 => {
            let val1 = cpu.read_reg(dec.rs1);
            let val2 = cpu.read_reg(dec.rs2);
            cpu.write_reg(dec.rd, val1 & val2);
        }
        0x03 => {
            let val1 = cpu.read_reg(dec.rs1);
            let val2 = cpu.read_reg(dec.rs2);
            cpu.write_reg(dec.rd, val1 | val2);
        }
        0x04 => {
            let val1 = cpu.read_reg(dec.rs1);
            let val2 = cpu.read_reg(dec.rs2);
            cpu.write_reg(dec.rd, val1 ^ val2);
        }
        0x05 => {
            let val1 = cpu.read_reg(dec.rs1);
            let val2 = cpu.read_reg(dec.rs2);
            // shift left by lower 6 bits of val2
            cpu.write_reg(dec.rd, val1 << (val2 & 0x3F));
        }
        0x06 => {
            let val1 = cpu.read_reg(dec.rs1);
            let val2 = cpu.read_reg(dec.rs2);
            if dec.funct9 == 1 {
                // SRA (Arithmetic shift right)
                cpu.write_reg(dec.rd, ((val1 as i64) >> (val2 & 0x3F)) as u64);
            } else {
                // SHR (Logical shift right)
                cpu.write_reg(dec.rd, val1 >> (val2 & 0x3F));
            }
        }
        0x07 => {
            let val1 = cpu.read_reg(dec.rs1);
            let val2 = cpu.read_reg(dec.rs2);
            cpu.write_reg(dec.rd, val1.wrapping_mul(val2));
        }
        0x08 => {
            let val1 = cpu.read_reg(dec.rs1);
            let val2 = cpu.read_reg(dec.rs2);
            let res = if val2 != 0 { val1 / val2 } else { 0 };
            cpu.write_reg(dec.rd, res);
        }
        0x09 => {
            let val1 = cpu.read_reg(dec.rs1);
            let imm = dec.imm14 as i64 as u64;
            cpu.write_reg(dec.rd, val1.wrapping_add(imm));
        }
        0x0A => {
            let val1 = cpu.read_reg(dec.rs1) as i64;
            let val2 = cpu.read_reg(dec.rs2) as i64;
            cpu.write_reg(dec.rd, if val1 < val2 { 1 } else { 0 });
        }
        0x0B => {
            let val1 = cpu.read_reg(dec.rs1);
            let val2 = cpu.read_reg(dec.rs2);
            cpu.write_reg(dec.rd, if val1 < val2 { 1 } else { 0 });
        }
        0x21 => {
            // LOAD.X
            let base = cpu.read_reg(dec.rs1);
            let vaddr = base.wrapping_add(dec.imm14 as i64 as u64);
            if vaddr % 8 != 0 {
                enter_trap(cpu, 0x02);
            } else {
                match translate(cpu, mem, vaddr, false) {
                    Ok(paddr) => {
                        let val = mem.read_u64(paddr as usize);
                        cpu.write_reg(dec.rd, val);
                    }
                    Err(cause) => {
                        enter_trap(cpu, cause as u64);
                    }
                }
            }
        }
        0x22 => {
            // STORE.X
            let base = cpu.read_reg(dec.rd);
            let vaddr = base.wrapping_add(dec.imm14 as i64 as u64);
            if vaddr % 8 != 0 {
                enter_trap(cpu, 0x02);
            } else {
                match translate(cpu, mem, vaddr, true) {
                    Ok(paddr) => {
                        let val = cpu.read_reg(dec.rs1);
                        mem.write_u64(paddr as usize, val);
                    }
                    Err(cause) => {
                        enter_trap(cpu, cause as u64);
                    }
                }
            }
        }
        0x40 => {
            // BRANCH.X / BEQ
            let val1 = cpu.read_reg(dec.rd);
            let val2 = cpu.read_reg(dec.rs1);
            if val1 == val2 {
                let offset = (dec.imm14 as i64) << 2;
                cpu.pc = cpu.pc.wrapping_add(offset as u64).wrapping_sub(4);
            }
        }
        0x46 => {
            // BNE
            let val1 = cpu.read_reg(dec.rd);
            let val2 = cpu.read_reg(dec.rs1);
            if val1 != val2 {
                let offset = (dec.imm14 as i64) << 2;
                cpu.pc = cpu.pc.wrapping_add(offset as u64).wrapping_sub(4);
            }
        }
        0x47 => {
            // BLT
            let val1 = cpu.read_reg(dec.rd) as i64;
            let val2 = cpu.read_reg(dec.rs1) as i64;
            if val1 < val2 {
                let offset = (dec.imm14 as i64) << 2;
                cpu.pc = cpu.pc.wrapping_add(offset as u64).wrapping_sub(4);
            }
        }
        0x48 => {
            // BGE
            let val1 = cpu.read_reg(dec.rd) as i64;
            let val2 = cpu.read_reg(dec.rs1) as i64;
            if val1 >= val2 {
                let offset = (dec.imm14 as i64) << 2;
                cpu.pc = cpu.pc.wrapping_add(offset as u64).wrapping_sub(4);
            }
        }
        0x49 => {
            // BLTU
            let val1 = cpu.read_reg(dec.rd);
            let val2 = cpu.read_reg(dec.rs1);
            if val1 < val2 {
                let offset = (dec.imm14 as i64) << 2;
                cpu.pc = cpu.pc.wrapping_add(offset as u64).wrapping_sub(4);
            }
        }
        0x4A => {
            // BGEU
            let val1 = cpu.read_reg(dec.rd);
            let val2 = cpu.read_reg(dec.rs1);
            if val1 >= val2 {
                let offset = (dec.imm14 as i64) << 2;
                cpu.pc = cpu.pc.wrapping_add(offset as u64).wrapping_sub(4);
            }
        }
        0x41 => {
            // JUMP.X
            cpu.write_reg(dec.rd, cpu.pc + 4); 
            let offset = (dec.imm19 as i64) * 4;
            cpu.pc = cpu.pc.wrapping_add(offset as u64).wrapping_sub(4);
        }
        0x42 => {
            // CSR.READ
            let required_pl = if dec.csr_addr < 0x200 {
                3 // Machine mode required
            } else if dec.csr_addr < 0x300 {
                1 // Supervisor mode required
            } else {
                0 // User mode required
            };
            if cpu._pl < required_pl {
                enter_trap(cpu, 0x04);
            } else {
                let val = cpu.read_csr(dec.csr_addr);
                cpu.write_reg(dec.rd, val);
            }
        }
        0x43 => {
            // CSR.WRITE
            let required_pl = if dec.csr_addr < 0x200 {
                3
            } else if dec.csr_addr < 0x300 {
                1
            } else {
                0
            };
            if cpu._pl < required_pl {
                enter_trap(cpu, 0x04);
            } else {
                let val = cpu.read_reg(dec.rd);
                if dec.csr_addr == 0x701 {
                    println!("[AX-EMU] SYS_PRINT: {}", val);
                }
                cpu.write_csr(dec.csr_addr, val);
            }
        }
        0x44 => {
            // ECALL
            let ret_pc = cpu.pc + 4;
            enter_trap(cpu, 0x05);
            cpu.write_csr(0x018, ret_pc);
        }
        0x45 => {
            // EXRET
            if cpu._pl < 3 {
                enter_trap(cpu, 0x04);
            } else {
                let epc = cpu.read_csr(0x018);
                cpu._pl = 0; // Drop Privilege
                cpu.pc = epc.wrapping_sub(4);
            }
        }
        0x50 => {
            // FADD.X
            let val1 = f64::from_bits(cpu.read_reg(dec.rs1));
            let val2 = f64::from_bits(cpu.read_reg(dec.rs2));
            cpu.write_reg(dec.rd, (val1 + val2).to_bits());
        }
        0x51 => {
            // FMUL.X
            let val1 = f64::from_bits(cpu.read_reg(dec.rs1));
            let val2 = f64::from_bits(cpu.read_reg(dec.rs2));
            cpu.write_reg(dec.rd, (val1 * val2).to_bits());
        }
        0x54 => {
            // VCMP.GT (Vector Compare Greater Than)
            let vl = cpu.read_csr(0x508);
            let elements = (vl / 4) as usize;
            let mut mask = 0u64;
            for i in 0..elements {
                let offset = i * 4;
                let v1 = i32::from_le_bytes(cpu.vr[dec.rs1][offset..offset+4].try_into().unwrap());
                let v2 = i32::from_le_bytes(cpu.vr[dec.rs2][offset..offset+4].try_into().unwrap());
                if v1 > v2 {
                    mask |= 1 << i;
                }
            }
            cpu.vmask = mask;
        }
        0x60 => {
            // VLOAD
            let vl = cpu.read_csr(0x508); // AX_VEC_CONTROL
            let base = cpu.read_reg(dec.rs1);
            let vaddr = base.wrapping_add(dec.imm14 as i64 as u64);
            if vaddr % 8 != 0 {
                enter_trap(cpu, 0x02);
            } else {
                match translate(cpu, mem, vaddr, false) {
                    Ok(paddr) => {
                        let p = paddr as usize;
                        let end = p + (vl as usize);
                        if end <= mem.ram.len() {
                            cpu.vr[dec.rd][0..vl as usize].copy_from_slice(&mem.ram[p..end]);
                        } else {
                            panic!("VLOAD out of bounds: paddr {} + vl {} > mem size {}", p, vl, mem.ram.len());
                        }
                    }
                    Err(cause) => {
                        enter_trap(cpu, cause as u64);
                    }
                }
            }
        }
        0x61 => {
            // VSTORE (S-Type encoding! rs1 is at [23:19] which is dec.rd, vs2 is at [18:14] which is dec.rs1)
            let vl = cpu.read_csr(0x508); // AX_VEC_CONTROL
            let base = cpu.read_reg(dec.rd);
            let vaddr = base.wrapping_add(dec.imm14 as i64 as u64);
            if vaddr % 8 != 0 {
                enter_trap(cpu, 0x02);
            } else {
                match translate(cpu, mem, vaddr, true) {
                    Ok(paddr) => {
                        let vs2_idx = dec.rs1;
                        let p = paddr as usize;
                        if p + (vl as usize) <= mem.ram.len() {
                            for i in 0..(vl as usize) {
                                mem.ram[p + i] = cpu.vr[vs2_idx][i];
                            }
                        } else {
                            panic!("VSTORE out of bounds: paddr {} + vl {} > mem size {}", p, vl, mem.ram.len());
                        }
                    }
                    Err(cause) => {
                        enter_trap(cpu, cause as u64);
                    }
                }
            }
        }
        0x62 => {
            // VADD (32-bit elements)
            let vl = cpu.read_csr(0x508);
            let elements = (vl / 4) as usize; // 32-bit = 4 bytes
            let use_mask = (dec.funct9 & 0x100) != 0;
            for i in 0..elements {
                if !use_mask || (cpu.vmask & (1 << i)) != 0 {
                    let offset = i * 4;
                    let v1 = u32::from_le_bytes(cpu.vr[dec.rs1][offset..offset+4].try_into().unwrap());
                    let v2 = u32::from_le_bytes(cpu.vr[dec.rs2][offset..offset+4].try_into().unwrap());
                    let res = v1.wrapping_add(v2);
                    cpu.vr[dec.rd][offset..offset+4].copy_from_slice(&res.to_le_bytes());
                }
            }
        }
        0x63 => {
            // VMUL (32-bit elements)
            let vl = cpu.read_csr(0x508);
            let elements = (vl / 4) as usize;
            let use_mask = (dec.funct9 & 0x100) != 0;
            for i in 0..elements {
                if !use_mask || (cpu.vmask & (1 << i)) != 0 {
                    let offset = i * 4;
                    let v1 = u32::from_le_bytes(cpu.vr[dec.rs1][offset..offset+4].try_into().unwrap());
                    let v2 = u32::from_le_bytes(cpu.vr[dec.rs2][offset..offset+4].try_into().unwrap());
                    let res = v1.wrapping_mul(v2);
                    cpu.vr[dec.rd][offset..offset+4].copy_from_slice(&res.to_le_bytes());
                }
            }
        }
        0x64 => {
            // VFMA (32-bit elements: vd = vd + (vs1 * vs2))
            let vl = cpu.read_csr(0x508);
            let elements = (vl / 4) as usize;
            let use_mask = (dec.funct9 & 0x100) != 0;
            for i in 0..elements {
                if !use_mask || (cpu.vmask & (1 << i)) != 0 {
                    let offset = i * 4;
                    let vd_val = u32::from_le_bytes(cpu.vr[dec.rd][offset..offset+4].try_into().unwrap());
                    let v1 = u32::from_le_bytes(cpu.vr[dec.rs1][offset..offset+4].try_into().unwrap());
                    let v2 = u32::from_le_bytes(cpu.vr[dec.rs2][offset..offset+4].try_into().unwrap());
                    let res = vd_val.wrapping_add(v1.wrapping_mul(v2));
                    cpu.vr[dec.rd][offset..offset+4].copy_from_slice(&res.to_le_bytes());
                }
            }
        }
        0x65 => {
            // VPERM (32-bit elements: vd[i] = vs1[vs2[i]])
            let vl = cpu.read_csr(0x508);
            let elements = (vl / 4) as usize;
            let use_mask = (dec.funct9 & 0x100) != 0;
            let mut temp_out = vec![0u8; vl as usize];
            temp_out[0..vl as usize].copy_from_slice(&cpu.vr[dec.rd][0..vl as usize]);
            for i in 0..elements {
                if !use_mask || (cpu.vmask & (1 << i)) != 0 {
                    let offset = i * 4;
                    let idx = u32::from_le_bytes(cpu.vr[dec.rs2][offset..offset+4].try_into().unwrap()) as usize;
                    if idx < elements {
                        let src_offset = idx * 4;
                        temp_out[offset..offset+4].copy_from_slice(&cpu.vr[dec.rs1][src_offset..src_offset+4]);
                    } else {
                        temp_out[offset..offset+4].copy_from_slice(&[0, 0, 0, 0]);
                    }
                }
            }
            cpu.vr[dec.rd][0..vl as usize].copy_from_slice(&temp_out);
        }
        _ => {
            // Illegal Instruction
            enter_trap(cpu, 0x00);
        }
    }
}
