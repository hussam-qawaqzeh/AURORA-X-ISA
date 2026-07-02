; Test Vector Compare (VCMP.GT) and Vector Masked Operations (VADD.M)

; 1. Setup Base Address and Vector Length
ADDI R1, R0, 1000     ; Base for V1
ADDI R2, R0, 1032     ; Base for V2
ADDI R3, R0, 1064     ; Base for Output V3
ADDI R4, R0, 32       ; Shift amount = 32

; Initialize memory for V1 = [10, 20, 30, 40]
ADDI R5, R0, 10
ADDI R6, R0, 20
SHL R6, R6, R4
ADD.X R5, R5, R6      ; R5 = (20 << 32) | 10
STORE.X R5, [R1]

ADDI R5, R0, 30
ADDI R6, R0, 40
SHL R6, R6, R4
ADD.X R5, R5, R6      ; R5 = (40 << 32) | 30
STORE.X R5, [R1+8]

; Initialize memory for V2 = [15, 15, 35, 35]
ADDI R5, R0, 15
ADDI R6, R0, 15
SHL R6, R6, R4
ADD.X R5, R5, R6
STORE.X R5, [R2]

ADDI R5, R0, 35
ADDI R6, R0, 35
SHL R6, R6, R4
ADD.X R5, R5, R6
STORE.X R5, [R2+8]

; Initialize output memory V3 to [0, 0, 0, 0]
STORE.X R0, [R3]
STORE.X R0, [R3+8]

; Setup VL = 16 (4 elements)
ADDI R7, R0, 16
CSR.WRITE R7, 0x508

; 2. Load into V1 and V2
VLOAD V1, [R1]
VLOAD V2, [R2]
VLOAD V3, [R3]        ; V3 is [0, 0, 0, 0]

; 3. Compare V1 > V2
VCMP.GT V1, V2        ; vmask should be 2'b1010 (10) since 20>15 (el 1) and 40>35 (el 3)

; 4. Masked VADD
VADD.M V3, V1, V2     ; V3 = V1 + V2 only where mask is 1
; V3[0] = remain 0
; V3[1] = 20 + 15 = 35
; V3[2] = remain 0
; V3[3] = 40 + 35 = 75

; 5. Store and Verify
VSTORE V3, [R3]

; Verify V3[0] and V3[1] (should be 35 << 32 | 0)
LOAD.X R8, [R3]
ADDI R9, R0, 35
SHL R9, R9, R4        ; 35 << 32
BRANCH.X R8, R9, 2
JUMP.X R0, 0          ; Fail

; Verify V3[2] and V3[3] (should be 75 << 32 | 0)
LOAD.X R8, [R3+8]
ADDI R9, R0, 75
SHL R9, R9, R4        ; 75 << 32
BRANCH.X R8, R9, 2
JUMP.X R0, 0          ; Fail

; Success
ADDI R30, R0, 1
CSR.WRITE R30, 0x700
JUMP.X R0, 0
