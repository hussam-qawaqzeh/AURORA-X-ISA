module ax_divider (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [63:0] A, // Dividend
    input  wire [63:0] B, // Divisor
    output reg  [63:0] Quotient,
    output reg         ready
);
    reg [5:0]  count;
    reg [127:0] temp_A;
    reg [63:0]  temp_B;
    reg        busy;

    wire [127:0] shifted_A = temp_A << 1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count    <= 0;
            temp_A   <= 0;
            temp_B   <= 0;
            Quotient <= 0;
            ready    <= 0;
            busy     <= 0;
        end else begin
            if (start && !busy) begin
                if (B == 0) begin
                    // Division by zero
                    Quotient <= 0;
                    ready    <= 1;
                    busy     <= 0;
                end else begin
                    temp_A   <= {64'd0, A};
                    temp_B   <= B;
                    count    <= 63;
                    busy     <= 1;
                    ready    <= 0;
                end
            end else if (busy) begin
                if (shifted_A[127:64] >= temp_B) begin
                    temp_A <= {shifted_A[127:64] - temp_B, shifted_A[63:0] | 64'd1};
                end else begin
                    temp_A <= shifted_A;
                end

                if (count == 0) begin
                    Quotient <= (shifted_A[127:64] >= temp_B) ? (shifted_A[63:0] | 64'd1) : shifted_A[63:0];
                    ready    <= 1;
                    busy     <= 0;
                end else begin
                    count <= count - 1;
                end
            end else begin
                ready <= 0;
            end
        end
    end
endmodule
