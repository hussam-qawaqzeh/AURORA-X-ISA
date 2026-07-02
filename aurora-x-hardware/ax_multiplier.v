module ax_multiplier (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] A,
    input  wire [63:0] B,
    output wire [63:0] Result,
    output reg         ready
);
    reg [63:0] a_stage1, b_stage1;
    reg [63:0] res_stage2;
    reg [63:0] res_stage3;
    reg [2:0]  valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_stage1   <= 0;
            b_stage1   <= 0;
            res_stage2 <= 0;
            res_stage3 <= 0;
            valid      <= 0;
            ready      <= 0;
        end else begin
            // Stage 1
            if (start) begin
                a_stage1 <= A;
                b_stage1 <= B;
                valid[0] <= 1;
            end else begin
                valid[0] <= 0;
            end
            
            // Stage 2
            if (valid[0]) begin
                res_stage2 <= a_stage1 * b_stage1;
                valid[1]   <= 1;
            end else begin
                valid[1]   <= 0;
            end
            
            // Stage 3
            if (valid[1]) begin
                res_stage3 <= res_stage2;
                valid[2]   <= 1;
                ready      <= 1;
            end else begin
                valid[2]   <= 0;
                ready      <= 0;
            end
        end
    end

    assign Result = res_stage3;
endmodule
