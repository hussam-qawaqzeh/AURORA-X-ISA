    ADDI R25, R0, 0
    ADDI R1, R25, 0
    ADDI R25, R0, 1
    ADDI R2, R25, 0
    ADDI R25, R0, 1
    ADDI R3, R25, 0
; while_start_1:
    ADDI R26, R0, 1
    BRANCH.X R3, R26, 3
    ADDI R25, R0, 0
    JUMP.X R0, 2
; eq_true_3:
    ADDI R25, R0, 1
; eq_end_4:
    BRANCH.X R25, R0, 15
    ADD.X R25, R1, R2
    ADDI R1, R25, 0
    ADDI R26, R0, 1
    ADD.X R25, R2, R26
    ADDI R2, R25, 0
    ADDI R26, R0, 11
    BRANCH.X R2, R26, 3
    ADDI R25, R0, 0
    JUMP.X R0, 2
; eq_true_6:
    ADDI R25, R0, 1
; eq_end_7:
    BRANCH.X R25, R0, 3
    ADDI R25, R0, 0
    ADDI R3, R25, 0
; if_end_5:
    JUMP.X R0, -19
; while_end_2:
    CSR.WRITE R1, 0x701
    ADDI R25, R0, 1
    CSR.WRITE R25, 0x700
; end_func_8:
    JUMP.X R0, 0
