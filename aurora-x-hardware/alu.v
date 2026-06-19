module alu (
    input  wire [63:0] A,
    input  wire [63:0] B,
    input  wire [2:0]  ALU_Op,
    output reg  [63:0] Result,
    output wire        Zero
);

    // ALU Operations
    localparam ALU_ADD = 3'b000;
    localparam ALU_SUB = 3'b001;
    localparam ALU_AND = 3'b010;
    localparam ALU_OR  = 3'b011;
    localparam ALU_XOR = 3'b100;
    localparam ALU_SHL = 3'b101;
    localparam ALU_SHR = 3'b110;

    always @(*) begin
        case (ALU_Op)
            ALU_ADD: Result = A + B;
            ALU_SUB: Result = A - B;
            ALU_AND: Result = A & B;
            ALU_OR:  Result = A | B;
            ALU_XOR: Result = A ^ B;
            ALU_SHL: Result = A << B[5:0];
            ALU_SHR: Result = A >> B[5:0];
            default: Result = 64'd0;
        endcase
    end

    assign Zero = (Result == 64'd0);

endmodule
