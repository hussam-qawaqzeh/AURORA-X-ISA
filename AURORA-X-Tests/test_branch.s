; AURORA-X Compliance Test: Branching and Jumping
; Tests: BRANCH.X, JUMP.X

; 1. Test Forward Branch
ADDI R1, R0, 5
ADDI R2, R0, 5
BRANCH.X R1, R2, 2    ; Should branch over the JUMP (skip 1 instruction)
JUMP.X R0, 0          ; Fail (if didn't branch)

; 2. Test Not Equal Branch
ADDI R2, R0, 6
BRANCH.X R1, R2, 2    ; R1 (5) != R2 (6), should NOT branch
JUMP.X R0, 2          ; Skip over the fail jump
JUMP.X R0, 0          ; Fail

; 3. Test JUMP.X Forward
JUMP.X R3, 2          ; Jump forward 2 (skip 1 instruction)
JUMP.X R0, 0          ; Fail

; 4. Test Backward Branch
ADDI R1, R0, 3        ; Loop counter
ADDI R2, R0, 0        ; Zero
; loop_start:
ADDI R1, R1, -1       ; Decrement
BRANCH.X R1, R2, 2    ; If R1 == 0, break loop (jump forward 2)
JUMP.X R0, -2         ; Else, loop back! (jump back 2 instructions to ADDI)
JUMP.X R0, 2          ; Skip fail if broke loop correctly
JUMP.X R0, 0          ; Fail (should not reach here unless loop broke incorrectly)

; All tests passed
ADDI R30, R0, 1
CSR.WRITE R30, 0x700  ; Signal success
JUMP.X R0, 0          ; Infinite Loop
