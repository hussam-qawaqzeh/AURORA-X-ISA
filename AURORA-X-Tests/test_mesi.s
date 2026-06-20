    ; AURORA-X MESI Snoop Test
    
    ; Read Core ID
    CSR.READ R1, 0xF14
    
    ; If Core ID == 1, jump to Core 1 Logic (skip 17 instructions)
    ADDI R2, R0, 1
    BEQ R1, R2, 17
    
    ; ==================================
    ; Core 0 Logic (Inst 3)
    ; ==================================
    ; Write 0x55 to 0x2000
    ADDI R3, R0, 0x55
    ADDI R4, R0, 0x20
    ADDI R2, R0, 8
    SHL R4, R4, R2
    STORE.X R4, R3, 0
    
    ; Signal Core 1 (Write 1 to 0x1000)
    ADDI R5, R0, 1
    STORE.X R0, R5, 0x1000
    
    ; Wait for Core 1 (Read 0x1008 until == 1)
    ; Inst 10
    LOAD.X R6, R0, 0x1008
    BNE R6, R5, -1
    
    ; Core 1 has cached 0x2000. Write 0xAA to 0x2000!
    ADDI R3, R0, 0xAA
    STORE.X R4, R3, 0
    
    ; Signal Core 1 (Write 2 to 0x1000)
    ADDI R5, R0, 2
    STORE.X R0, R5, 0x1000
    
    ; Done
    ADDI R6, R0, 1
    CSR.WRITE R6, 0x700
    JUMP.X R0, 0
    
    ; ==================================
    ; Core 1 Logic (Inst 17)
    ; ==================================
    ; Wait for Core 0 (Read 0x1000 until == 1)
    ADDI R5, R0, 1
    ; Inst 18
    LOAD.X R6, R0, 0x1000
    BNE R6, R5, -1
    
    ; Read 0x2000 (Caches 0x55 in L1)
    ADDI R4, R0, 0x20
    ADDI R2, R0, 8
    SHL R4, R4, R2
    LOAD.X R7, R4, 0
    
    ; Signal Core 0 (Write 1 to 0x1008)
    STORE.X R0, R5, 0x1008
    
    ; Wait for Core 0 (Read 0x1000 until == 2)
    ADDI R5, R0, 2
    ; Inst 27
    LOAD.X R6, R0, 0x1000
    BNE R6, R5, -1
    
    ; Read 0x2000 AGAIN (If Snoop failed, gets 0x55. If Snoop passed, gets 0xAA)
    LOAD.X R8, R4, 0
    
    ; Write to test status (We want this to be 0xAA!)
    CSR.WRITE R8, 0x700
    JUMP.X R0, 0
