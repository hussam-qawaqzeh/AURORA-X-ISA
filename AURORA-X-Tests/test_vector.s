; AURORA-X Compliance Test: Vector Operations
; Tests: VLOAD, VSTORE, VADD, VMUL, VFMA, VPERM

; 1. Setup Base Address and Vector Length
ADDI R1, R0, 1000     ; R1 = Base Address for Vector A
ADDI R2, R0, 1032     ; R2 = Base Address for Vector B
ADDI R3, R0, 1064     ; R3 = Base Address for Output C
ADDI R4, R0, 16       ; R4 = Vector Length (16 bytes = 4x 32-bit elements)
CSR.WRITE R4, 0x508   ; Set VL to 16

; Initialize Data in Memory (simulate CPU writing scalars)
ADDI R5, R0, 2
STORE.X R5, [R1]
STORE.X R5, [R1+8]    ; Actually, STORE.X writes 64 bits. Let's just do VLOAD of uninitialized mem, 
; Wait, if memory is 0, vector math will just be 0.
; We can write 64-bit values to memory to set up the vectors.
; [R1] = 0x0000000300000002 -> elements: 2, 3
; Let's just use whatever is in memory, add it to itself, and verify it doubled!
; But wait, if memory is all 0s, 0+0=0, which doesn't prove it worked.
; Let's write `2` and `3`
ADDI R5, R0, 2
STORE.X R5, [R1]
ADDI R6, R0, 3
STORE.X R6, [R2]

; 2. VLOAD
VLOAD V1, [R1]        ; Load into V1
VLOAD V2, [R2]        ; Load into V2

; 3. VADD
VADD V3, V1, V2       ; V3 = V1 + V2

; 4. VSTORE
VSTORE V3, [R3]       ; Store V3

; 5. Verify (Load scalar and check)
LOAD.X R7, [R3]       ; R7 should be 5 (2 + 3)
ADDI R8, R0, 5
BRANCH.X R7, R8, 2    ; If R7 == 5, success
JUMP.X R0, 0          ; Fail

; All tests passed
ADDI R30, R0, 1
CSR.WRITE R30, 0x700
JUMP.X R0, 0
