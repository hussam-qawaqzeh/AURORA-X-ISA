; ==============================================================================
; AURORA-X DEMO 3: Advanced AI Tensor Math
; ==============================================================================
; Proves AURORA-X's capability to run complex AI algorithms (Polynomial Evaluation)
; Equation: Y = A + X * (B + C*X)
; Inputs:
; X = [1, 2, 3, 4]
; C = [3, 3, 3, 3]
; B = [2, 2, 2, 2]
; A = [5, 5, 5, 5]

; 1. Set Vector Length to 16 bytes (4 elements)
CSR.WRITE R5, 0x508    

; 2. Load the Matrices into massive 2048-bit Vector Registers
VLOAD V1, [R6]         ; Load X
VLOAD V2, [R6+16]      ; Load C
VLOAD V3, [R6+32]      ; Load B
VLOAD V4, [R6+48]      ; Load A

; 3. Parallel SIMD Evaluation (using Fused Multiply-Add logic)
VMUL V5, V2, V1        ; V5 = C * X = [3, 6, 9, 12]
VADD V5, V3, V5        ; V5 = B + C*X = [5, 8, 11, 14]
VMUL V5, V1, V5        ; V5 = X * (B + C*X) = [5, 16, 33, 56]
VADD V5, V4, V5        ; V5 = A + X * (B + C*X) = [10, 21, 38, 61]

; 4. Store the final Tensor
VSTORE V5, [R6+64]     ; Store Result Y
