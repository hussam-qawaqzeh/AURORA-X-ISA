    ADDI R25, R0, 10
    ADDI R1, R25, 0
    ADDI R25, R0, 0
    ADDI R2, R25, 0
    ADDI R25, R0, 1
    ADDI R3, R25, 0
    ADDI R25, R0, 0
    ADDI R4, R25, 0
    ADDI R25, R0, 1
    ADDI R5, R25, 0
; while_start_1:
    ADDI R26, R0, 1
    BRANCH.X R5, R26, 3
    ADDI R25, R0, 0
    JUMP.X R0, 2
; eq_true_3:
    ADDI R25, R0, 1
; eq_end_4:
    BRANCH.X R25, R0, 16
    ADD.X R25, R2, R3
    ADDI R6, R25, 0
    ADDI R2, R3, 0
    ADDI R3, R6, 0
    ADDI R26, R0, 1
    ADD.X R25, R4, R26
    ADDI R4, R25, 0
    BRANCH.X R4, R1, 3
    ADDI R25, R0, 0
    JUMP.X R0, 2
; eq_true_6:
    ADDI R25, R0, 1
; eq_end_7:
    BRANCH.X R25, R0, 3
    ADDI R25, R0, 0
    ADDI R5, R25, 0
; if_end_5:
    JUMP.X R0, -20
; while_end_2:
    CSR.WRITE R2, 0x701
    ADDI R25, R0, 1
    CSR.WRITE R25, 0x700
; end_func_8:
    JUMP.X R0, 0
