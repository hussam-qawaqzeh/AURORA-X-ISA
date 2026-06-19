; ==============================================================================
; AURORA-X DEMO 2: SIMD Vector Addition
; ==============================================================================
; Proves the AX-Vec extension capable of scalable Single Instruction Multiple Data.
; We will load two arrays of 4 integers, add them in parallel, and store them.

; 1. Set Vector Length (VL)
; The universal testbench sets R5 = 16 (16 bytes = four 32-bit integers)
CSR.WRITE R5, 0x508    ; AX_VEC_CONTROL = 16

; 2. Load Vector Arrays from Memory (Base address in R6 is 1000)
VLOAD V1, [R6]         ; Load Array 1 into Vector Register 1: [1, 2, 3, 4]
VLOAD V2, [R6+16]      ; Load Array 2 into Vector Register 2: [3, 3, 3, 3]

; 3. Perform Parallel SIMD Addition
VADD V3, V1, V2        ; V3 = V1 + V2 = [4, 5, 6, 7]

; 4. Store Result back to Memory
VSTORE V3, [R6+32]     ; Store V3 at Memory[1032]
