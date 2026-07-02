; Compliance Test: ECALL, EXRET, and Illegal Instruction exception routing

; 1. Set trap handler address
; PC starts at 0.
; my_trap_handler will be placed at PC = 27 * 4 = 108 (0x6C).
ADDI R1, R0, 108
CSR.WRITE R1, 0x020

; 1. ECALL test
ECALL                 ; Call trap handler (sets R3=1)

ADDI R2, R0, 1
BRANCH.X R3, R2, 2
JUMP.X R0, 0          ; Fail if ECALL trap did not run

.word 0xFFFFFFFF      ; Trigger illegal instruction exception (sets R4=1)

ADDI R2, R0, 1
BRANCH.X R4, R2, 2
JUMP.X R0, 0          ; Fail if Illegal Instruction trap did not run

; 3. Test privilege transition to PL0 and restore via EXRET
; Set EPC to PC = 64 (0x40) where user code will run
ADDI R1, R0, 64
CSR.WRITE R1, 0x018
; Clear MPP in mstatus (write 8 to mstatus)
ADDI R1, R0, 8
CSR.WRITE R1, 0x300
; EXRET to PL0
EXRET

JUMP.X R0, 0          ; Fail if EXRET did not return to 64

; User Mode (PL0) - starts at PC = 64
CSR.WRITE R0, 0x300   ; Privilege violation (should trap with cause 4)
JUMP.X R0, 0          ; Fail if we didn't trap and reached here!

; Return point after Privilege Violation (PC = 72)
ADDI R2, R0, 1
BRANCH.X R8, R2, 2
JUMP.X R0, 0          ; Fail if Privilege Violation trap did not run

; Success
ADDI R30, R0, 1
CSR.WRITE R30, 0x700
JUMP.X R0, 0

; padding to align trap handler to PC = 108
ADDI R0, R0, 0
ADDI R0, R0, 0
ADDI R0, R0, 0

; my_trap_handler (Starts at PC = 108)
CSR.READ R5, 0x008    ; Read cause (AX_CAUSE)
ADDI R6, R0, 5        ; ECALL cause code is 5
BRANCH.X R5, R6, 8    ; Skip 8 instructions to PC 148 (Handle ECALL)
ADDI R6, R0, 0        ; Illegal instruction cause code is 0
BRANCH.X R5, R6, 9    ; Skip 9 instructions to PC 160 (Handle Illegal Instruction)
ADDI R6, R0, 4        ; Privilege violation cause code is 4
BRANCH.X R5, R6, 12   ; Skip 12 instructions to PC 180 (Handle Privilege Violation)
JUMP.X R0, 0          ; Unknown cause -> Fail

ADDI R0, R0, 0        ; padding
ADDI R0, R0, 0        ; padding

; Handle ECALL (PC = 148):
ADDI R3, R0, 1
EXRET                 ; Returns to PC 12

ADDI R0, R0, 0        ; padding

; Handle Illegal Instruction (PC = 160):
ADDI R4, R0, 1
CSR.READ R7, 0x018    ; Read EPC
ADDI R7, R7, 4        ; Skip illegal instruction (EPC += 4)
CSR.WRITE R7, 0x018
EXRET                 ; Returns to PC 28

; Handle Privilege Violation (PC = 180):
ADDI R8, R0, 1
CSR.READ R7, 0x018    ; Read EPC
ADDI R7, R7, 8        ; Skip CSR.WRITE and JUMP.X (EPC += 8)
CSR.WRITE R7, 0x018
EXRET                 ; Returns to PC 72
