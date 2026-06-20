module register_file (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [63:0] write_data,
    output wire [63:0] read_data1,
    output wire [63:0] read_data2
);

    // 32 General Purpose Registers, 64-bits each
    reg [63:0] registers [0:31];

    // Initialize all registers to 0 (important for simulation)
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] = 64'd0;
        end
    end

    // Write Port (Synchronous)
    always @(posedge clk) begin
        if (we && rd != 5'd0) begin
            registers[rd] <= write_data;
        end
    end

    // Read Ports (Asynchronous/Combinational)
    // R0 is hardwired to 0
    // Internal forwarding for Write-Before-Read hazard
    assign read_data1 = (rs1 == 0) ? 64'd0 : ((we && rd == rs1) ? write_data : registers[rs1]);
    assign read_data2 = (rs2 == 0) ? 64'd0 : ((we && rd == rs2) ? write_data : registers[rs2]);
    assign R31_out = registers[31];

endmodule
