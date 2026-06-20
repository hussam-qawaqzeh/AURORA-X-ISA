    ; AURORA-X PMU Test (DVFS)
    ; Core 0 runs at full speed, Core 1 runs at half speed.
    
    ; Read Core ID
    CSR.READ R1, 0xF14
    
    ; If Core ID == 1, jump to Core 1 Logic (skip 10 instructions)
    ADDI R2, R0, 1
    BEQ R1, R2, 10
    
    ; ==================================
    ; Core 0 Logic (Runs at Full Speed)
    ; ==================================
    ; Configure PMU: 0x13 = 0001_0011
    ; C0_EN=1, C1_EN=1, C0_DIV=00, C1_DIV=01 (Half speed)
    ADDI R3, R0, 19
    CSR.WRITE R3, 0x800
    
    ; Loop 10 times
    ADDI R4, R0, 10
    ADDI R5, R0, 0
    ; Core 0 Loop Start (Inst 8)
    ADDI R5, R5, 1
    BNE R5, R4, -1
    
    ; Done, write status
    ADDI R6, R0, 1
    CSR.WRITE R6, 0x700
    
    ; Infinite loop (Inst 13)
    JUMP.X R0, 0
    
    ; ==================================
    ; Core 1 Logic (Runs at Half Speed)
    ; ==================================
    ; Inst 14
    ; Loop 10 times
    ADDI R4, R0, 10
    ADDI R5, R0, 0
    ; Core 1 Loop Start (Inst 16)
    ADDI R5, R5, 1
    BNE R5, R4, -1
    
    ; Done, write status
    ADDI R6, R0, 1
    CSR.WRITE R6, 0x700
    
    ; Infinite loop
    JUMP.X R0, 0
