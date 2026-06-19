module vector_alu (
    input  wire [2047:0] A,
    input  wire [2047:0] B,
    input  wire [2047:0] C, // Accumulator (vd)
    input  wire [2:0]    VALU_Op,
    output reg  [2047:0] Result
);

    localparam VALU_ADD  = 3'b000;
    localparam VALU_MUL  = 3'b001;
    localparam VALU_FMA  = 3'b010;
    localparam VALU_PERM = 3'b011;

    integer i;
    reg signed [31:0] a_elem, b_elem, c_elem, res_elem;
    
    // Array representation for dynamic indexing in VPERM
    reg [31:0] A_arr [0:63];

    always @(*) begin
        // Populate array
        for (i = 0; i < 64; i = i + 1) begin
            A_arr[i] = A[i*32 +: 32];
        end

        for (i = 0; i < 64; i = i + 1) begin
            a_elem = A[i*32 +: 32];
            b_elem = B[i*32 +: 32];
            c_elem = C[i*32 +: 32];
            
            case (VALU_Op)
                VALU_ADD:  res_elem = a_elem + b_elem;
                VALU_MUL:  res_elem = a_elem * b_elem;
                VALU_FMA:  res_elem = c_elem + (a_elem * b_elem);
                VALU_PERM: begin
                    if (b_elem >= 0 && b_elem < 64) begin
                        res_elem = A_arr[b_elem];
                    end else begin
                        res_elem = 32'd0;
                    end
                end
                default: res_elem = 32'd0;
            endcase
            
            Result[i*32 +: 32] = res_elem;
        end
    end

endmodule
