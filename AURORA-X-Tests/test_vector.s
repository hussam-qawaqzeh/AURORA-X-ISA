; AURORA-X Compliance Test: Vector Operations
; Tests: VLOAD, VSTORE, VADD, VMUL, VFMA, VPERM

; 1. Setup Base Address and Vector Length
ADDI R1, R0, 1000     ; R1 = Base Address for Vector A (V1)
ADDI R2, R0, 1032     ; R2 = Base Address for Vector B (V2)
ADDI R3, R0, 1064     ; R3 = Base Address for Output C (V3)
ADDI R4, R0, 32       ; Shift amount
ADDI R7, R0, 16       ; VL = 16 (4 elements)
CSR.WRITE R7, 0x508

; Initialize memory for V1 = [2, 3, 4, 5]
ADDI R5, R0, 2
ADDI R6, R0, 3
SHL R6, R6, R4
ADD.X R5, R5, R6
STORE.X R5, [R1]      ; Elements 0, 1

ADDI R5, R0, 4
ADDI R6, R0, 5
SHL R6, R6, R4
ADD.X R5, R5, R6
STORE.X R5, [R1+8]    ; Elements 2, 3

; Initialize memory for V2 = [10, 20, 30, 40]
ADDI R5, R0, 10
ADDI R6, R0, 20
SHL R6, R6, R4
ADD.X R5, R5, R6
STORE.X R5, [R2]

ADDI R5, R0, 30
ADDI R6, R0, 40
SHL R6, R6, R4
ADD.X R5, R5, R6
STORE.X R5, [R2+8]

; Load V1 and V2
VLOAD V1, [R1]
VLOAD V2, [R2]

; ---------------------------------------------------
; 2. Test VADD (V3 = V1 + V2)
; Expected: V3 = [12, 23, 34, 45]
VADD V3, V1, V2
VSTORE V3, [R3]

LOAD.X R8, [R3]       ; R8 = (23 << 32) | 12
ADDI R9, R0, 23
SHL R9, R9, R4
ADDI R10, R0, 12
ADD.X R9, R9, R10
BRANCH.X R8, R9, 2
JUMP.X R0, 0          ; Fail

; ---------------------------------------------------
; 3. Test VMUL (V3 = V1 * V2)
; Expected: V3 = [20, 60, 120, 200]
VMUL V3, V1, V2
VSTORE V3, [R3]

LOAD.X R8, [R3]       ; R8 = (60 << 32) | 20
ADDI R9, R0, 60
SHL R9, R9, R4
ADDI R10, R0, 20
ADD.X R9, R9, R10
BRANCH.X R8, R9, 2
JUMP.X R0, 0          ; Fail

; ---------------------------------------------------
; 4. Test VFMA (V3 = V1 * V2 + V3)
; V3 starts with [20, 60, 120, 200]
; VFMA V3, V1, V2 => V3 = [2*10+20, 3*20+60, ...] = [40, 120, 240, 400]
VFMA V3, V1, V2
VSTORE V3, [R3]

LOAD.X R8, [R3]       ; R8 = (120 << 32) | 40
ADDI R9, R0, 120
SHL R9, R9, R4
ADDI R10, R0, 40
ADD.X R9, R9, R10
BRANCH.X R8, R9, 2
JUMP.X R0, 0          ; Fail

; ---------------------------------------------------
; 5. Test VPERM (V3 = V1 permuted by V2)
; We need indices in V2. Let's make V2 = [3, 2, 1, 0]
ADDI R5, R0, 3
ADDI R6, R0, 2
SHL R6, R6, R4
ADD.X R5, R5, R6
STORE.X R5, [R2]

ADDI R5, R0, 1
ADDI R6, R0, 0
SHL R6, R6, R4
ADD.X R5, R5, R6
STORE.X R5, [R2+8]

VLOAD V2, [R2]        ; Load new indices
VPERM V3, V1, V2      ; V3[i] = V1[V2[i]] -> V3 = [5, 4, 3, 2]
VSTORE V3, [R3]

LOAD.X R8, [R3]       ; R8 = (4 << 32) | 5
ADDI R9, R0, 4
SHL R9, R9, R4
ADDI R10, R0, 5
ADD.X R9, R9, R10
BRANCH.X R8, R9, 2
JUMP.X R0, 0          ; Fail

; Success
ADDI R30, R0, 1
CSR.WRITE R30, 0x700
JUMP.X R0, 0
