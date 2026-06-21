module decoder (
    input  wire [31:0] inst,
    
    // Extracted Fields
    output wire [7:0]  opcode,
    output wire [4:0]  rd,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [13:0] imm14,
    output wire [18:0] imm19,
    output wire [11:0] csr_addr,
    output wire [8:0]  funct9,

    // Sign Extended Immediates
    output wire [63:0] imm14_sext,
    output wire [63:0] imm19_sext,

    // Control Signals
    output reg         RegWrite,
    output reg         ALUSrc_B,     // 0 = rs2, 1 = imm14_sext
    output reg  [3:0]  ALU_Op,
    output reg         MemRead,
    output reg         MemWrite,
    output reg         Branch,
    output reg  [2:0]  Branch_Type,  // 0:BEQ, 1:BNE, 2:BLT, 3:BGE, 4:BLTU, 5:BGEU
    output reg         Jump,
    output reg         CSR_Write,
    output reg         CSR_Read,
    output reg  [1:0]  MemtoReg,      // 00=ALU, 01=Mem, 10=PC+4, 11=CSR
    output reg         Ecall,
    output reg         Exret,

    // Vector Control Signals
    output reg         VectorOp,
    output reg         VectorRegWrite,
    output reg         VectorMemRead,
    output reg         VectorMemWrite,
    output reg  [2:0]  VALU_Op,
    output reg         VectorMaskWe,
    output reg         VectorUseMask
);

    assign opcode   = inst[31:24];
    assign rd       = inst[23:19];
    // For STORE.X (0x22), BRANCHes (0x40-0x4A), CSR.WRITE (0x43), and VSTORE (0x61), rs1 is in 23:19
    assign rs1      = (opcode == 8'h22 || (opcode >= 8'h40 && opcode <= 8'h4A) || opcode == 8'h61) ? inst[23:19] : inst[18:14];
    // For STORE.X (0x22), BRANCHes (0x40-0x4A), and VSTORE (0x61), rs2 is in 18:14
    assign rs2      = (opcode == 8'h22 || (opcode >= 8'h40 && opcode <= 8'h4A) || opcode == 8'h61) ? inst[18:14] : inst[13:9];
    assign imm14    = inst[13:0];
    assign imm19    = inst[18:0];
    assign csr_addr = inst[18:7]; // 12-bit CSR address
    assign funct9   = inst[8:0];

    // Sign extension
    assign imm14_sext = {{50{imm14[13]}}, imm14};
    assign imm19_sext = {{45{imm19[18]}}, imm19};

    always @(*) begin
        // Default values
        RegWrite  = 0;
        ALUSrc_B  = 0;
        ALU_Op    = 4'b0000;
        MemRead   = 0;
        MemWrite  = 0;
        Branch    = 0;
        Branch_Type = 3'b000;
        Jump      = 0;
        CSR_Write = 0;
        CSR_Read  = 0;
        MemtoReg  = 2'b00;
        Ecall     = 0;
        Exret     = 0;
        VectorOp = 0; VectorRegWrite = 0; VectorMemRead = 0; VectorMemWrite = 0; VALU_Op = 0;
        VectorMaskWe = 0; VectorUseMask = 0;

        case (opcode)
            8'h01: begin // ADD.X / SUB.X
                RegWrite = 1;
                ALUSrc_B = 0;
                ALU_Op   = (funct9 == 9'd1) ? 4'b0001 : 4'b0000;
            end
            8'h02: begin // AND
                RegWrite = 1; ALUSrc_B = 0; ALU_Op = 4'b0010;
            end
            8'h03: begin // OR
                RegWrite = 1; ALUSrc_B = 0; ALU_Op = 4'b0011;
            end
            8'h04: begin // XOR
                RegWrite = 1; ALUSrc_B = 0; ALU_Op = 4'b0100;
            end
            8'h05: begin // SHL
                RegWrite = 1; ALUSrc_B = 0; ALU_Op = 4'b0101;
            end
            8'h06: begin // SHR / SRA
                RegWrite = 1; ALUSrc_B = 0; 
                ALU_Op = (funct9 == 9'd1) ? 4'b1001 : 4'b0110; // SRA if funct9=1
            end
            8'h07: begin // MUL.X
                RegWrite = 1; ALUSrc_B = 0; ALU_Op = 4'b0111;
            end
            8'h08: begin // DIV.X
                RegWrite = 1; ALUSrc_B = 0; ALU_Op = 4'b1000;
            end
            8'h09: begin // ADDI
                RegWrite = 1; ALUSrc_B = 1; ALU_Op = 4'b0000; // ADD
            end
            8'h21: begin // LOAD.X
                RegWrite = 1; ALUSrc_B = 1; ALU_Op = 4'b0000; // rs1 + imm14
                MemRead  = 1; MemtoReg = 2'b01;
            end
            8'h22: begin // STORE.X 
                MemWrite = 1; ALUSrc_B = 1; ALU_Op = 4'b0000;
            end
            8'h0A: begin // SLT
                RegWrite = 1; ALUSrc_B = 0; ALU_Op = 4'b1011;
            end
            8'h0B: begin // SLTU
                RegWrite = 1; ALUSrc_B = 0; ALU_Op = 4'b1100;
            end
            8'h40: begin // BNE (Legacy BRANCH.X)
                Branch = 1; Branch_Type = 3'b001; // BNE is type 1
            end
            8'h46: begin // BEQ
                Branch = 1; Branch_Type = 3'b000; // BEQ is type 0
            end
            8'h47: begin // BLT
                Branch = 1; Branch_Type = 3'b010;
            end
            8'h48: begin // BGE
                Branch = 1; Branch_Type = 3'b011;
            end
            8'h49: begin // BLTU
                Branch = 1; Branch_Type = 3'b100;
            end
            8'h4A: begin // BGEU
                Branch = 1; Branch_Type = 3'b101;
            end
            8'h41: begin // JUMP.X
                Jump = 1; RegWrite = 1; MemtoReg = 2'b10; // PC+4
            end
            8'h42: begin // CSR.READ
                CSR_Read = 1; RegWrite = 1; MemtoReg = 2'b11;
            end
            8'h43: begin // CSR.WRITE
                CSR_Write = 1;
            end
            8'h44: begin // ECALL
                Ecall = 1;
            end
            8'h45: begin // EXRET
                Exret = 1;
            end
            8'h60: begin // VLOAD
                ALUSrc_B = 1; ALU_Op = 4'b0000; // rs1 + imm14
                VectorMemRead = 1; VectorRegWrite = 1;
            end
            8'h61: begin // VSTORE
                ALUSrc_B = 1; ALU_Op = 4'b0000;
                VectorMemWrite = 1;
            end
            8'h62: begin // VADD
                VectorOp = 1; VALU_Op = 3'b000; VectorRegWrite = 1;
                VectorUseMask = funct9[8];
            end
            8'h63: begin // VMUL
                VectorOp = 1; VALU_Op = 3'b001; VectorRegWrite = 1;
                VectorUseMask = funct9[8];
            end
            8'h64: begin // VFMA
                VectorOp = 1; VALU_Op = 3'b010; VectorRegWrite = 1;
                VectorUseMask = funct9[8];
            end
            8'h53: begin // VPERM (Vector Permute)
                VectorOp = 1;
                VectorRegWrite = 1;
                VALU_Op = 3'b011;
                VectorUseMask = funct9[8]; // MSB of funct9 enables mask
            end
            8'h54: begin // VCMP.GT (Vector Compare Greater Than)
                VectorOp = 1;
                VectorMaskWe = 1; // Write to Mask Register, not Vector Register
                VALU_Op = 3'b100;
            end
            default: ; // NOP or Unknown
        endcase
    end
endmodule
