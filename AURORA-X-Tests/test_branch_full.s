; Test all Branch conditions: BLT, BGE, BLTU, BGEU

; 1. Test BLT (Branch Less Than, signed)
ADDI R1, R0, -5
ADDI R2, R0, 5
BLT R1, R2, 2            ; -5 < 5 -> branch
JUMP.X R0, 0             ; Fail (should have branched)

BLT R2, R1, 2            ; 5 < -5 -> no branch
JUMP.X R0, 2             ; Pass (did not branch)
JUMP.X R0, 0             ; Fail

; 2. Test BGE (Branch Greater or Equal, signed)
ADDI R1, R0, 5
ADDI R2, R0, -5
BGE R1, R2, 2            ; 5 >= -5 -> branch
JUMP.X R0, 0             ; Fail

BGE R2, R1, 2            ; -5 >= 5 -> no branch
JUMP.X R0, 2             ; Pass
JUMP.X R0, 0             ; Fail

ADDI R2, R0, 5
BGE R1, R2, 2            ; 5 >= 5 -> branch
JUMP.X R0, 0             ; Fail

; 3. Test BLTU (Branch Less Than, unsigned)
ADDI R1, R0, 5
ADDI R2, R0, -5          ; -5 is 0xFFFFFFFFFFFFFFFB (large unsigned)
BLTU R1, R2, 2           ; 5 < -5 unsigned -> branch
JUMP.X R0, 0             ; Fail

BLTU R2, R1, 2           ; -5 < 5 unsigned -> no branch
JUMP.X R0, 2             ; Pass
JUMP.X R0, 0             ; Fail

; 4. Test BGEU (Branch Greater or Equal, unsigned)
ADDI R1, R0, -5
ADDI R2, R0, 5
BGEU R1, R2, 2           ; -5 >= 5 unsigned -> branch
JUMP.X R0, 0             ; Fail

BGEU R2, R1, 2           ; 5 >= -5 unsigned -> no branch
JUMP.X R0, 2             ; Pass
JUMP.X R0, 0             ; Fail

ADDI R2, R0, -5
BGEU R1, R2, 2           ; -5 >= -5 unsigned -> branch
JUMP.X R0, 0             ; Fail

; Success
ADDI R30, R0, 1
CSR.WRITE R30, 0x700
JUMP.X R0, 0
