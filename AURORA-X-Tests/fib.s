    ADDI R21, R0, 10
    ADDI R1, R21, 0
    ADDI R21, R0, 0
    ADDI R2, R21, 0
    ADDI R21, R0, 1
    ADDI R3, R21, 0
    ADDI R21, R0, 0
    ADDI R4, R21, 0
    ADDI R21, R0, 1
    ADDI R5, R21, 0
; while_start_1:
    ADDI R22, R5, 0
    ADDI R21, R0, 1
    BRANCH.X R22, R21, 3
    ADDI R21, R0, 0
    JUMP.X R0, 2
; eq_true_3:
    ADDI R21, R0, 1
; eq_end_4:
    BRANCH.X R21, R0, 19
    ADDI R22, R2, 0
    ADD.X R21, R22, R3
    ADDI R6, R21, 0
    ADDI R2, R3, 0
    ADDI R3, R6, 0
    ADDI R22, R4, 0
    ADDI R21, R0, 1
    ADD.X R21, R22, R21
    ADDI R4, R21, 0
    ADDI R22, R4, 0
    BRANCH.X R22, R1, 3
    ADDI R21, R0, 0
    JUMP.X R0, 2
; eq_true_6:
    ADDI R21, R0, 1
; eq_end_7:
    BRANCH.X R21, R0, 3
    ADDI R21, R0, 0
    ADDI R5, R21, 0
; if_end_5:
    JUMP.X R0, -24
; while_end_2:
    CSR.WRITE R2, 0x701
    ADDI R21, R0, 0
    CSR.WRITE R21, 0x700
; end_func_8:
    JUMP.X R0, 0
