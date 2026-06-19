; ==============================================================================
; AURORA-X DEMO 1: System Calls & Exception ABI
; ==============================================================================
; This demo proves the Privilege Level transitioning and Exception handling.
; It sets up a handler, triggers a System Call (ECALL), handles it, and returns.

; 1. Set the Exception Handler Address (CSR 0x020: AX_EXCEPTION_VECTOR)
; We read the address from memory (Base address in R6 is 100)
LOAD.X R1, [R6]        ; R1 = Memory[100] = 64 (Address of the handler)
CSR.WRITE R1, 0x020    ; Write R1 to AX_EXCEPTION_VECTOR

; 2. Trigger the System Call
ECALL                  ; CPU jumps to address 64, sets AX_CAUSE = 0x05, sets AX_EPC = PC+4

; 3. Main program continues here after EXRET
ADD.X R10, R10, R5     ; Accumulate value
JUMP.X R0, 20          ; Infinite loop at PC=20

; ------------------------------------------------------------------------------
; EXCEPTION HANDLER (Located at PC = 64 / 0x40)
; ------------------------------------------------------------------------------
; When ECALL is executed, the CPU jumps here.
ADD.X R10, R10, R5     ; Prove we are in the handler (R10 = 1000)
CSR.READ R2, 0x008     ; Read AX_CAUSE to R2 (will be 0x05 for ECALL)
STORE.X R2, [R6+8]     ; Store AX_CAUSE to Memory[108]
EXRET                  ; Return to the instruction after ECALL
