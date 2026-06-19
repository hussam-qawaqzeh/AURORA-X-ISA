; AURORA-X Compliance Test: Memory Operations
; Tests: LOAD.X, STORE.X, Alignment Fault

; 1. Test Basic Store / Load
ADDI R1, R0, 1000     ; Address 1000 (not divisible by 8... wait, 1000 % 8 = 0. Yes! 1000 / 8 = 125. Good.)
ADDI R2, R0, 555      ; Value 555
STORE.X R2, [R1]      ; Store 555 at 1000
LOAD.X R3, [R1]       ; Load from 1000 to R3

BRANCH.X R2, R3, 2    ; If R2 == R3, jump +1 (success)
JUMP.X R0, 0          ; Fail

; 2. Test Alignment Fault
; To test exceptions, we need to set up the exception handler.
ADDI R4, R0, 13       ; Address of the exception handler below (instruction 13? Let's count later, better to use JUMP)
; Wait, we can't easily set handler dynamically without counting instructions.
; Let's count:
; 1: ADDI R1, R0, 1000
; 2: ADDI R2, R0, 555
; 3: STORE.X R2, [R1]
; 4: LOAD.X R3, [R1]
; 5: BRANCH.X R2, R3, 2
; 6: JUMP.X R0, 0
; 7: ADDI R4, R0, 48   ; Address of Exception Handler (12 instructions * 4 = 48)
; 8: CSR.WRITE R4, 0x020
; 9: ADDI R1, R1, 1    ; Address 1001 (unaligned)
; 10: LOAD.X R3, [R1]  ; Causes Exception -> jumps to 48
; 11: JUMP.X R0, 0     ; Fail (Should not be reached)

; 12: Exception Handler (PC = 48)
; 13: CSR.READ R5, 0x008   ; Read Cause
; 14: ADDI R6, R0, 2       ; Alignment fault cause = 2
; 15: BRANCH.X R5, R6, 2   ; If cause == 2, pass
; 16: JUMP.X R0, 0         ; Fail

; All tests passed
; 17: ADDI R30, R0, 1
; 18: CSR.WRITE R30, 0x700
; 19: JUMP.X R0, 0

; Now let's write it with correct padding if needed.
ADDI R4, R0, 48       ; Handler at PC=48 (instruction index 12)
CSR.WRITE R4, 0x020
ADDI R1, R1, 1        ; R1 = 1001 (unaligned)
LOAD.X R3, [R1]       ; TRAP!
JUMP.X R0, 0          ; Fail

; --- Exception Handler (PC = 48) ---
CSR.READ R5, 0x008    ; Read cause
ADDI R6, R0, 2        ; Expected cause = 2
BRANCH.X R5, R6, 2    
JUMP.X R0, 0          ; Fail

; All tests passed
ADDI R30, R0, 1
CSR.WRITE R30, 0x700
JUMP.X R0, 0
