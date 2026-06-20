module alu (
    input  wire [63:0] A,
    input  wire [63:0] B,
    input  wire [3:0]  ALU_Op,
    output reg  [63:0] Result,
    output wire        Zero
);

    // ALU Operations
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SHL  = 4'b0101;
    localparam ALU_SHR  = 4'b0110;
    localparam ALU_MUL  = 4'b0111;
    localparam ALU_DIV  = 4'b1000;
    localparam ALU_SRA  = 4'b1001;
    localparam ALU_SLT  = 4'b1010;
    localparam ALU_SLTU = 4'b1011;

    always @(*) begin
        case (ALU_Op)
            ALU_ADD:  Result = A + B;
            ALU_SUB:  Result = A - B;
            ALU_AND:  Result = A & B;
            ALU_OR:   Result = A | B;
            ALU_XOR:  Result = A ^ B;
            ALU_SHL:  Result = A << B[5:0];
            ALU_SHR:  Result = A >> B[5:0];
            ALU_MUL:  Result = A * B;
            ALU_DIV:  Result = (B != 0) ? (A / B) : 64'd0; // Simple division, avoid div-by-zero
            ALU_SRA:  Result = $signed(A) >>> B[5:0];
            ALU_SLT:  Result = ($signed(A) < $signed(B)) ? 64'd1 : 64'd0;
            ALU_SLTU: Result = (A < B) ? 64'd1 : 64'd0;
            default:  Result = 64'd0;
        endcase
    end

    assign Zero = (Result == 64'd0);

endmodule
