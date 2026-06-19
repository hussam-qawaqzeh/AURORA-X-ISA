; AURORA-X Compliance Test: ALU Operations
; Tests: ADD.X, SUB.X, AND, OR, XOR, SHL, SHR, ADDI
; Expected behavior: All operations produce correct results. If any fails, loop infinitely (fail). If all pass, write 1 to 0x700 (pass).

; Initialize
ADDI R1, R0, 10
ADDI R2, R0, 5

; 1. Test ADD.X
ADD.X R3, R1, R2      ; R3 = 10 + 5 = 15
ADDI R4, R0, 15
BRANCH.X R3, R4, 2    ; If R3 == 15, jump +1 (skip fail)
JUMP.X R0, 0          ; Fail (Infinite Loop)

; 2. Test SUB.X
SUB.X R3, R1, R2      ; R3 = 10 - 5 = 5
ADDI R4, R0, 5
BRANCH.X R3, R4, 2
JUMP.X R0, 0          ; Fail

; 3. Test AND
ADDI R5, R0, 12       ; 1100
ADDI R6, R0, 10       ; 1010
AND R3, R5, R6        ; R3 = 1000 (8)
ADDI R4, R0, 8
BRANCH.X R3, R4, 2
JUMP.X R0, 0          ; Fail

; 4. Test OR
OR R3, R5, R6         ; R3 = 1110 (14)
ADDI R4, R0, 14
BRANCH.X R3, R4, 2
JUMP.X R0, 0          ; Fail

; 5. Test XOR
XOR R3, R5, R6        ; R3 = 0110 (6)
ADDI R4, R0, 6
BRANCH.X R3, R4, 2
JUMP.X R0, 0          ; Fail

; 6. Test SHL
ADDI R7, R0, 2
SHL R3, R5, R7        ; R3 = 12 << 2 = 48
ADDI R4, R0, 48
BRANCH.X R3, R4, 2
JUMP.X R0, 0          ; Fail

; 7. Test SHR
SHR R3, R5, R7        ; R3 = 12 >> 2 = 3
ADDI R4, R0, 3
BRANCH.X R3, R4, 2
JUMP.X R0, 0          ; Fail

; All tests passed
ADDI R30, R0, 1
CSR.WRITE R30, 0x700  ; Signal success
JUMP.X R0, 0          ; Infinite Loop (will be halted by test mode)
