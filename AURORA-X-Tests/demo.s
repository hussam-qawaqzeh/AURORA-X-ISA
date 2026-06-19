    ADDI R21, R0, 0
    ADDI R1, R21, 0
    ADDI R21, R0, 1
    ADDI R2, R21, 0
    ADDI R21, R0, 1
    ADDI R3, R21, 0
; while_start_1:
    ADDI R22, R3, 0
    ADDI R21, R0, 1
    BRANCH.X R22, R21, 3
    ADDI R21, R0, 0
    JUMP.X R0, 2
; eq_true_3:
    ADDI R21, R0, 1
; eq_end_4:
    BRANCH.X R21, R0, 18
    ADDI R22, R1, 0
    ADD.X R21, R22, R2
    ADDI R1, R21, 0
    ADDI R22, R2, 0
    ADDI R21, R0, 1
    ADD.X R21, R22, R21
    ADDI R2, R21, 0
    ADDI R22, R2, 0
    ADDI R21, R0, 11
    BRANCH.X R22, R21, 3
    ADDI R21, R0, 0
    JUMP.X R0, 2
; eq_true_6:
    ADDI R21, R0, 1
; eq_end_7:
    BRANCH.X R21, R0, 3
    ADDI R21, R0, 0
    ADDI R3, R21, 0
; if_end_5:
    JUMP.X R0, -23
; while_end_2:
    CSR.WRITE R1, 0x701
    ADDI R21, R0, 0
    CSR.WRITE R21, 0x700
; end_func_8:
    JUMP.X R0, 0
