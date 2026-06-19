module vector_register_file (
    input  wire          clk,
    input  wire          we,
    input  wire [4:0]    rs1,
    input  wire [4:0]    rs2,
    input  wire [4:0]    rd,
    input  wire [2047:0] write_data,
    output wire [2047:0] read_data1,
    output wire [2047:0] read_data2,
    output wire [2047:0] read_data_vd
);

    // 32 Vector Registers, 2048-bits (256 bytes) each
    reg [2047:0] vr [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            vr[i] = 2048'd0;
        end
    end

    // Write Port (Synchronous)
    always @(posedge clk) begin
        if (we) begin
            vr[rd] <= write_data;
        end
    end

    // Read Ports (Combinational)
    assign read_data1 = vr[rs1];
    assign read_data2 = vr[rs2];
    assign read_data_vd = vr[rd]; // For VFMA accumulator

endmodule
