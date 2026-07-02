; Compliance Test: R0 Hardwired to Zero Enforcement

ADDI R1, R0, 42
ADDI R2, R0, 10
ADDI R15, R0, 0       ; R15 remains 0

; 1. Try ADDI write to R0
ADDI R0, R0, 42
BRANCH.X R0, R15, 2
JUMP.X R0, 0

; 2. Try ADD.X write to R0
ADD.X R0, R1, R2
BRANCH.X R0, R15, 2
JUMP.X R0, 0

; 3. Try SUB.X write to R0
SUB.X R0, R1, R2
BRANCH.X R0, R15, 2
JUMP.X R0, 0

; 4. Try XOR write to R0
XOR R0, R1, R2
BRANCH.X R0, R15, 2
JUMP.X R0, 0

; 5. Try MUL.X write to R0
MUL.X R0, R1, R2
BRANCH.X R0, R15, 2
JUMP.X R0, 0

; 6. Try SLT write to R0
SLT R0, R1, R2
BRANCH.X R0, R15, 2
JUMP.X R0, 0

; Success
ADDI R30, R0, 1
CSR.WRITE R30, 0x700
JUMP.X R0, 0
