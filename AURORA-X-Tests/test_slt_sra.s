; Test SLT, SLTU, and SRA compliance

; 1. Test SLT (Signed Less Than)
ADDI R1, R0, 5
ADDI R2, R0, 10
SLT R3, R1, R2           ; 5 < 10 -> 1
ADDI R4, R0, 1
BRANCH.X R3, R4, 2
JUMP.X R0, 0             ; Fail

SLT R3, R2, R1           ; 10 < 5 -> 0
BRANCH.X R3, R0, 2
JUMP.X R0, 0             ; Fail

; Negative tests for signed comparison
ADDI R1, R0, -5
ADDI R2, R0, 5
SLT R3, R1, R2           ; -5 < 5 -> 1
ADDI R4, R0, 1
BRANCH.X R3, R4, 2
JUMP.X R0, 0             ; Fail

SLT R3, R2, R1           ; 5 < -5 -> 0
BRANCH.X R3, R0, 2
JUMP.X R0, 0             ; Fail

; 2. Test SLTU (Unsigned Less Than)
ADDI R1, R0, -5          ; -5 is large unsigned
ADDI R2, R0, 5
SLTU R3, R1, R2          ; unsigned -5 < 5 -> 0
BRANCH.X R3, R0, 2
JUMP.X R0, 0             ; Fail

SLTU R3, R2, R1          ; unsigned 5 < -5 -> 1
ADDI R4, R0, 1
BRANCH.X R3, R4, 2
JUMP.X R0, 0             ; Fail

; 3. Test SRA (Arithmetic Shift Right)
ADDI R1, R0, -8          ; R1 = -8
ADDI R2, R0, 2           ; R2 = 2
SRA R3, R1, R2           ; R3 = -8 >>> 2 = -2
ADDI R4, R0, -2
BRANCH.X R3, R4, 2
JUMP.X R0, 0             ; Fail

ADDI R1, R0, 8           ; R1 = 8
SRA R3, R1, R2           ; R3 = 8 >>> 2 = 2
ADDI R4, R0, 2
BRANCH.X R3, R4, 2
JUMP.X R0, 0             ; Fail

; Success
ADDI R30, R0, 1
CSR.WRITE R30, 0x700
JUMP.X R0, 0
