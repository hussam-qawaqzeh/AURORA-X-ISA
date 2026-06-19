use std::collections::HashMap;

pub struct Cpu {
    pub gpr: [u64; 32],
    pub vr: [[u8; 256]; 32], // 2048-bit Vector Registers
    pub pc: u64,
    pub _pl: u8, // Privilege Level (0 to 3)
    pub csr: HashMap<u16, u64>,
}

impl Cpu {
    pub fn new() -> Self {
        Self {
            gpr: [0; 32],
            vr: [[0; 256]; 32],
            pc: 0,
            _pl: 3, // Start in Machine Mode
            csr: HashMap::new(),
        }
    }

    pub fn read_reg(&self, reg: usize) -> u64 {
        if reg == 0 {
            0 // R0 is hardwired to 0
        } else {
            self.gpr[reg]
        }
    }

    pub fn write_reg(&mut self, reg: usize, val: u64) {
        if reg != 0 {
            self.gpr[reg] = val;
        }
    }

    pub fn read_csr(&self, addr: u16) -> u64 {
        *self.csr.get(&addr).unwrap_or(&0)
    }

    pub fn write_csr(&mut self, addr: u16, val: u64) {
        self.csr.insert(addr, val);
    }
}
