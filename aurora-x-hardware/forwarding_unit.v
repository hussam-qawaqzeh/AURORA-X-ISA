module forwarding_unit (
    input [4:0] rs1_E,
    input [4:0] rs2_E,
    input [4:0] rd_M,
    input RegWrite_M,
    input [4:0] rd_W,
    input RegWrite_W,
    
    output reg [1:0] ForwardA,
    output reg [1:0] ForwardB
);
    always @(*) begin
        // Forward A
        if (RegWrite_M && (rd_M != 0) && (rd_M == rs1_E))
            ForwardA = 2'b10; // Forward from EX/MEM
        else if (RegWrite_W && (rd_W != 0) && (rd_W == rs1_E))
            ForwardA = 2'b01; // Forward from MEM/WB
        else
            ForwardA = 2'b00; // No forwarding

        // Forward B
        if (RegWrite_M && (rd_M != 0) && (rd_M == rs2_E))
            ForwardB = 2'b10;
        else if (RegWrite_W && (rd_W != 0) && (rd_W == rs2_E))
            ForwardB = 2'b01;
        else
            ForwardB = 2'b00;
    end
endmodule
