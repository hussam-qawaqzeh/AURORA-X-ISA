    ; Instruction 0
    CSR.READ R1, 0xF14
    
    ; Instruction 1: If Core ID == 0, jump to inst 3
    BEQ R1, R0, 2
    
    ; Instruction 2: Core 1 jumps to inst 9
    JUMP.X R0, 7

    ; --- Core 0 Code ---
    ; Instruction 3
    ADDI R2, R0, 4096
    ; Instruction 4
    ADDI R3, R0, 42
    ; Instruction 5
    STORE.X R3, [R2]
    ; Instruction 6
    ADDI R10, R0, 1
    ; Instruction 7
    CSR.WRITE R10, 0x700
    ; Instruction 8
    JUMP.X R0, 0

    ; --- Core 1 Code ---
    ; Instruction 9
    ADDI R2, R0, 4096
    ; Instruction 10 (Loop start)
    LOAD.X R3, [R2]
    ; Instruction 11
    ADDI R4, R0, 42
    ; Instruction 12
    BNE R3, R4, -2
    ; Instruction 13
    CSR.WRITE R3, 0x701
    ; Instruction 14
    ADDI R10, R0, 1
    ; Instruction 15
    CSR.WRITE R10, 0x700
    ; Instruction 16
    JUMP.X R0, 0
