; Compliance Test: ECALL, EXRET, and Illegal Instruction exception routing

; 1. Set trap handler address
; PC starts at 0.
; my_trap_handler will be placed at PC = 15 * 4 = 60 (0x3C).
ADDI R1, R0, 60
CSR.WRITE R1, 0x020

ECALL                 ; Call trap handler (sets R3=1)

ADDI R2, R0, 1
BRANCH.X R3, R2, 2
JUMP.X R0, 0          ; Fail if ECALL trap did not run

.word 0xFFFFFFFF      ; Trigger illegal instruction exception (sets R4=1)

ADDI R2, R0, 1
BRANCH.X R4, R2, 2
JUMP.X R0, 0          ; Fail if Illegal Instruction trap did not run

; Success
ADDI R30, R0, 1
CSR.WRITE R30, 0x700
JUMP.X R0, 0

; padding
ADDI R0, R0, 0
ADDI R0, R0, 0

; my_trap_handler (Starts at PC = 60)
CSR.READ R5, 0x008    ; Read cause (AX_CAUSE)
ADDI R6, R0, 5        ; ECALL cause code is 5
BRANCH.X R5, R6, 4
ADDI R6, R0, 0        ; Illegal instruction cause code is 0
BRANCH.X R5, R6, 4
JUMP.X R0, 0          ; Unknown cause -> Fail

; Handle ECALL:
ADDI R3, R0, 1
EXRET                 ; Returns to PC+4 (emulator already added 4 to EPC for ECALL)

; Handle Illegal Instruction:
ADDI R4, R0, 1
CSR.READ R7, 0x018    ; Read EPC
ADDI R7, R7, 4        ; Skip illegal instruction (EPC += 4)
CSR.WRITE R7, 0x018
EXRET                 ; Returns to PC+4
