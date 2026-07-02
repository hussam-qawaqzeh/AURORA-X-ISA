pub struct Memory {
    pub ram: Vec<u8>,
}

impl Memory {
    pub fn new(size: usize) -> Self {
        Self {
            ram: vec![0; size],
        }
    }

    pub fn load_binary(&mut self, data: &[u8], offset: usize) {
        let end = offset + data.len();
        if end <= self.ram.len() {
            self.ram[offset..end].copy_from_slice(data);
        } else {
            panic!("Binary too large for memory");
        }
    }

    pub fn read_u32(&self, addr: usize) -> u32 {
        if addr + 4 > self.ram.len() {
            return 0;
        }
        let b0 = self.ram[addr] as u32;
        let b1 = self.ram[addr + 1] as u32;
        let b2 = self.ram[addr + 2] as u32;
        let b3 = self.ram[addr + 3] as u32;
        // strictly Little-Endian
        b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    pub fn read_u64(&self, addr: usize) -> u64 {
        if addr + 8 > self.ram.len() {
            return 0;
        }
        let mut val = 0;
        for i in 0..8 {
            val |= (self.ram[addr + i] as u64) << (i * 8);
        }
        val
    }

    pub fn write_u64(&mut self, addr: usize, val: u64) {
        if addr + 8 > self.ram.len() {
            return;
        }
        for i in 0..8 {
            self.ram[addr + i] = ((val >> (i * 8)) & 0xFF) as u8;
        }
    }
}
