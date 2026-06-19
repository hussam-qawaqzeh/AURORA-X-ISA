use crate::cpu::Cpu;
use crate::memory::Memory;
use crate::decoder::DecodedInstruction;

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
        0x21 => {
            // LOAD.X
            let base = cpu.read_reg(dec.rs1);
            let addr = base.wrapping_add(dec.imm14 as i64 as u64);
            let val = mem.read_u64(addr as usize);
            cpu.write_reg(dec.rd, val);
        }
        0x22 => {
            // STORE.X (S-Type: rs1 is at rd position [23:19], rs2 is at rs1 position [18:14])
            let base = cpu.read_reg(dec.rd);
            let addr = base.wrapping_add(dec.imm14 as i64 as u64);
            let val = cpu.read_reg(dec.rs1);
            mem.write_u64(addr as usize, val);
        }
        0x40 => {
            // BRANCH.X (B-Type: rs1 at [23:19], rs2 at [18:14])
            // Compare rs1 and rs2, if equal branch
            let val1 = cpu.read_reg(dec.rd);
            let val2 = cpu.read_reg(dec.rs1);
            if val1 == val2 {
                cpu.pc = cpu.pc.wrapping_add((dec.imm14 as i64 * 4) as u64).wrapping_sub(4); // -4 because main loop adds 4
            }
        }
        0x41 => {
            // JUMP.X (J-Type: rd at [23:19])
            cpu.write_reg(dec.rd, cpu.pc + 4); // Save return address
            cpu.pc = cpu.pc.wrapping_add((dec.imm19 as i64 * 4) as u64).wrapping_sub(4);
        }
        0x42 => {
            // CSR.READ
            // Simple privilege check (mocked: if csr is in 0x0..0xF, needs PL3)
            let val = cpu.read_csr(dec.csr_addr);
            cpu.write_reg(dec.rd, val);
        }
        0x43 => {
            // CSR.WRITE (CSR-Type: rd_or_rs1 is at [23:19] which maps to dec.rd)
            let val = cpu.read_reg(dec.rd);
            cpu.write_csr(dec.csr_addr, val);
        }
        0x44 => {
            // ECALL
            let handler = cpu.read_csr(0x020); // AX_EXCEPTION_VECTOR
            if handler == 0 {
                eprintln!("Unhandled ECALL Exception at PC=0x{:X}", cpu.pc);
                std::process::exit(1);
            }
            cpu.write_csr(0x018, cpu.pc + 4); // AX_EPC (return to next inst)
            cpu.write_csr(0x008, 0x05); // AX_CAUSE = System Call
            cpu.pc = handler.wrapping_sub(4);
        }
        0x45 => {
            // EXRET
            let epc = cpu.read_csr(0x018);
            cpu.pc = epc.wrapping_sub(4);
        }
        0x60 => {
            // VLOAD
            let vl = cpu.read_csr(0x508); // AX_VEC_CONTROL
            let base = cpu.read_reg(dec.rs1);
            let addr = base.wrapping_add(dec.imm14 as i64 as u64);
            let mut chunk = vec![0u8; vl as usize];
            for i in 0..(vl as usize) {
                // Read byte by byte for simplicity
                chunk[i] = (mem.read_u64(addr as usize + i) & 0xFF) as u8;
            }
            cpu.vr[dec.rd][0..vl as usize].copy_from_slice(&chunk);
        }
        0x61 => {
            // VSTORE (S-Type encoding! rs1 is at [23:19] which is dec.rd, vs2 is at [18:14] which is dec.rs1)
            let vl = cpu.read_csr(0x508); // AX_VEC_CONTROL
            let base = cpu.read_reg(dec.rd);
            let addr = base.wrapping_add(dec.imm14 as i64 as u64);
            let vs2_idx = dec.rs1;
            for i in 0..(vl as usize) {
                // Write byte by byte
                let _val = cpu.vr[vs2_idx][i] as u64;
                // Read existing u64, modify byte, write back (highly unoptimized, but it's an MVP emulator)
                // Actually, just a simple memory byte write:
                mem.ram[addr as usize + i] = cpu.vr[vs2_idx][i];
            }
        }
        0x62 => {
            // VADD (32-bit elements)
            let vl = cpu.read_csr(0x508);
            let elements = (vl / 4) as usize; // 32-bit = 4 bytes
            for i in 0..elements {
                let offset = i * 4;
                let v1 = u32::from_le_bytes(cpu.vr[dec.rs1][offset..offset+4].try_into().unwrap());
                let v2 = u32::from_le_bytes(cpu.vr[dec.rs2][offset..offset+4].try_into().unwrap());
                let res = v1.wrapping_add(v2);
                cpu.vr[dec.rd][offset..offset+4].copy_from_slice(&res.to_le_bytes());
            }
        }
        0x63 => {
            // VMUL (32-bit elements)
            let vl = cpu.read_csr(0x508);
            let elements = (vl / 4) as usize;
            for i in 0..elements {
                let offset = i * 4;
                let v1 = u32::from_le_bytes(cpu.vr[dec.rs1][offset..offset+4].try_into().unwrap());
                let v2 = u32::from_le_bytes(cpu.vr[dec.rs2][offset..offset+4].try_into().unwrap());
                let res = v1.wrapping_mul(v2);
                cpu.vr[dec.rd][offset..offset+4].copy_from_slice(&res.to_le_bytes());
            }
        }
        0x64 => {
            // VFMA (32-bit elements: vd = vd + (vs1 * vs2))
            let vl = cpu.read_csr(0x508);
            let elements = (vl / 4) as usize;
            for i in 0..elements {
                let offset = i * 4;
                let vd_val = u32::from_le_bytes(cpu.vr[dec.rd][offset..offset+4].try_into().unwrap());
                let v1 = u32::from_le_bytes(cpu.vr[dec.rs1][offset..offset+4].try_into().unwrap());
                let v2 = u32::from_le_bytes(cpu.vr[dec.rs2][offset..offset+4].try_into().unwrap());
                let res = vd_val.wrapping_add(v1.wrapping_mul(v2));
                cpu.vr[dec.rd][offset..offset+4].copy_from_slice(&res.to_le_bytes());
            }
        }
        0x65 => {
            // VPERM (32-bit elements: vd[i] = vs1[vs2[i]])
            // vs2 contains indices
            let vl = cpu.read_csr(0x508);
            let elements = (vl / 4) as usize;
            let mut temp_out = vec![0u8; vl as usize];
            for i in 0..elements {
                let offset = i * 4;
                let idx = u32::from_le_bytes(cpu.vr[dec.rs2][offset..offset+4].try_into().unwrap()) as usize;
                
                // Safe bounds checking
                if idx < elements {
                    let src_offset = idx * 4;
                    temp_out[offset..offset+4].copy_from_slice(&cpu.vr[dec.rs1][src_offset..src_offset+4]);
                } else {
                    // Out of bounds permute -> 0
                    temp_out[offset..offset+4].copy_from_slice(&[0, 0, 0, 0]);
                }
            }
            cpu.vr[dec.rd][0..vl as usize].copy_from_slice(&temp_out);
        }
        _ => {
            // Illegal Instruction
            let handler = cpu.read_csr(0x020);
            if handler == 0 {
                eprintln!("Unhandled Illegal Instruction at PC=0x{:X}", cpu.pc);
                std::process::exit(1);
            }
            cpu.write_csr(0x018, cpu.pc);
            cpu.write_csr(0x008, 0x00); // 0x00 is Illegal Inst
            cpu.pc = handler.wrapping_sub(4);
        }
    }
}
