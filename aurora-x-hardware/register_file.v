module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [63:0] write_data,
    input  wire        thread_id_read,
    input  wire        thread_id_write,
    output wire [63:0] read_data1,
    output wire [63:0] read_data2
);

    // 64 General Purpose Registers (32 per thread), 64-bits each
    reg [63:0] registers [0:63];

    // Write Port (Synchronous with Async Reset)
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 64; i = i + 1) begin
                registers[i] <= 64'd0;
            end
        end else if (we && rd != 5'd0) begin
            registers[{thread_id_write, rd}] <= write_data;
        end
    end

    // Read Ports (Asynchronous/Combinational)
    // R0 is hardwired to 0
    assign read_data1 = (rs1 == 0) ? 64'd0 : registers[{thread_id_read, rs1}];
    assign read_data2 = (rs2 == 0) ? 64'd0 : registers[{thread_id_read, rs2}];

endmodule
