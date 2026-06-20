    ADDI R1, R0, 10
    ADDI R2, R0, 20
    MUL R3, R1, R2
    DIV R4, R3, R1
    
    ; Vector Initialization
    ADDI R5, R0, 0
    ADDI R6, R0, 256
    
    ; Setup memory with test values
    ADDI R7, R0, 5
    STORE.X R7, [R5]
    ADDI R7, R0, 10
    STORE.X R7, [R6]
    
    ; Vector ops
    VLOAD V1, [R5]
    VLOAD V2, [R6]
    VADD V3, V1, V2
    VMUL V4, V1, V2
    VSTORE V3, [R5]
    VSTORE V4, [R6]
    
    ; Check scalar result (print 20)
    CSR.WRITE R4, 0x701
    
    ; End test
    ADDI R10, R0, 1
    CSR.WRITE R10, 0x700
    JUMP.X R0, 0
