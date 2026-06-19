; ==============================================================================
; AURORA-X DEMO 4: OS Kernel (MMU, Virtual Memory, and Exceptions)
; ==============================================================================

; --- KERNEL BOOT (Runs in PL=3 Machine Mode) ---

; 1. Setup Exception Handler Address (PC=120)
ADDI R1, R0, 120       
CSR.WRITE R1, 0x020    

; 2. Setup Page Table in Physical Memory (Base = 1000)
ADDI R2, R0, 1000     
CSR.WRITE R2, 0x208    

; Map Virtual Address 0x4000 (VPN = 4) to Physical Address 0x2000 (PPN = 2)
; PTE Address = 1000 + (4 * 8) = 1032
; PTE Value = (2 << 12) | 0x3 (Valid & Writeable) = 8195
ADDI R3, R0, 2         
ADDI R8, R0, 12        
SHL R3, R3, R8         ; R3 = 8192
ADDI R3, R3, 3         ; R3 = 8195
STORE.X R3, [R2+32]    

; Write a secret value (999) to Physical Address 0x2000 to prove translation works
ADDI R5, R0, 2         
SHL R5, R5, R8         ; R5 = 8192
ADDI R4, R0, 999      
STORE.X R4, [R5+0]     

; 3. Enable the MMU
ADDI R6, R0, 1        
CSR.WRITE R6, 0x200    

; 4. Drop Privilege and jump to User Mode (PC=72)
ADDI R7, R0, 72       
CSR.WRITE R7, 0x018    
EXRET                  

; --- USER MODE APPLICATION (Runs in PL=0 User Mode) ---
; PC = 72

; 5. Test Bitwise Logic Instructions
ADDI R10, R0, 5       
ADDI R11, R0, 3       
XOR R12, R10, R11      ; R12 = 5 XOR 3 = 6
SHL R13, R12, R11      ; R13 = 6 << 3 = 48

; 6. Test MMU Virtual Memory Translation
ADDI R14, R0, 4        
SHL R14, R14, R8       ; R14 = 16384 (0x4000)
LOAD.X R15, [R14+0]    ; Hardware translates to 0x2000, loads 999!

; 7. Test Exception Handling (Alignment Fault)
ADDI R14, R14, 1       ; R14 = 16385 (Not divisible by 8)
LOAD.X R16, [R14+0]    ; Hardware catches this, traps to Exception Handler!
JUMP.X R0, 0

; --- EXCEPTION HANDLER (Runs in PL=3 Machine Mode) ---
; PC = 120
CSR.READ R20, 0x008    ; Read AX_CAUSE (Will be 0x02 for Alignment Fault)
CSR.READ R21, 0x018    ; Read AX_EPC (Address of faulting instruction: 104)
JUMP.X R0, 0         ; Infinite Loop (End of Demo)
