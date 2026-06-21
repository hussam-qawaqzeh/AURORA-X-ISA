module vector_register_file (
    input  wire          clk,
    input  wire          we,
    input  wire          mask_we,
    input  wire          use_mask,
    input  wire [4:0]    rs1,
    input  wire [4:0]    rs2,
    input  wire [4:0]    rd_write,
    input  wire [4:0]    vd_read,
    input  wire [2047:0] write_data,
    input  wire [63:0]   mask_data,
    output wire [2047:0] read_data1,
    output wire [2047:0] read_data2,
    output wire [2047:0] read_data_vd
);

    // 32 Vector Registers, 2048-bits (256 bytes) each
    reg [2047:0] vr [0:31];
    
    // Execution Mask Register
    reg [63:0] vmask;

    integer i;
    initial begin
        vmask = 64'hFFFFFFFFFFFFFFFF;
        for (i = 0; i < 32; i = i + 1) begin
            vr[i] = 2048'd0;
        end
    end

    // Write Port (Synchronous)
    always @(posedge clk) begin
        if (mask_we) begin
            vmask <= mask_data;
        end
        if (we) begin
            for (i = 0; i < 64; i = i + 1) begin
                if (!use_mask || vmask[i]) begin
                    vr[rd_write][i*32 +: 32] <= write_data[i*32 +: 32];
                end
            end
        end
    end

    // Read Ports (Combinational)
    // Internal forwarding for Write-Before-Read hazard
    assign read_data1 = (we && rd_write == rs1) ? write_data : vr[rs1];
    assign read_data2 = (we && rd_write == rs2) ? write_data : vr[rs2];
    assign read_data_vd = (we && rd_write == vd_read) ? write_data : vr[vd_read]; // For VFMA accumulator

endmodule
