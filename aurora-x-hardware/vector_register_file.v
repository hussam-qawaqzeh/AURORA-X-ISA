module vector_register_file (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          we,
    input  wire          mask_we,
    input  wire          use_mask,
    input  wire [4:0]    rs1,
    input  wire [4:0]    rs2,
    input  wire [4:0]    rd_write,
    input  wire [4:0]    vd_read,
    input  wire [2047:0] write_data,
    input  wire [63:0]   mask_data,
    input  wire          thread_id_read,
    input  wire          thread_id_write,
    output wire [2047:0] read_data1,
    output wire [2047:0] read_data2,
    output wire [2047:0] read_data_vd
);

    // 64 Vector Registers (32 per thread)
    reg [2047:0] vr [0:63];
    
    // Execution Mask Register (1 per thread)
    reg [63:0] vmask [0:1];

    integer i;

    // Write Port (Synchronous with Async Reset)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vmask[0] <= 64'hFFFFFFFFFFFFFFFF;
            vmask[1] <= 64'hFFFFFFFFFFFFFFFF;
            for (i = 0; i < 64; i = i + 1) begin
                vr[i] <= 2048'd0;
            end
        end else begin
            if (mask_we) begin
                vmask[thread_id_write] <= mask_data;
            end
            if (we) begin
                for (i = 0; i < 64; i = i + 1) begin
                    if (!use_mask || vmask[thread_id_write][i]) begin
                        vr[{thread_id_write, rd_write}][i*32 +: 32] <= write_data[i*32 +: 32];
                    end
                end
            end
        end
    end

    // Read Ports (Combinational)
    assign read_data1 = vr[{thread_id_read, rs1}];
    assign read_data2 = vr[{thread_id_read, rs2}];
    assign read_data_vd = vr[{thread_id_read, vd_read}]; // For VFMA accumulator

endmodule
