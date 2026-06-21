; Initialize R1 to 10
ADDI R1, R0, 10
; Initialize R2 to 0
ADDI R2, R0, 0

loop_start:
; Add 5 to R2
ADDI R2, R2, 5
; Subtract 1 from R1
ADDI R1, R1, -1
; If R1 != 0, jump back to loop_start
BNE R1, R0, loop_start

; Once loop finishes, just end execution
ECALL
