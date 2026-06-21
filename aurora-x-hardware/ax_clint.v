`include "aurora_config.vh"

module ax_clint (
    input clk,
    input rst_n,
    
    // Bus Interface (Simple Slave)
    input [63:0] addr,
    input [63:0] write_data,
    input we,
    input re,
    output reg [63:0] read_data,
    output reg ready,
    
    // Interrupt Outputs to Cores
    output [`TOTAL_CORES-1:0] timer_intr,
    output [`TOTAL_CORES-1:0] sw_intr
);

    // mtime counter
    reg [63:0] mtime;
    
    // mtimecmp and msip per core
    reg [63:0] mtimecmp [`TOTAL_CORES-1:0];
    reg [31:0] msip [`TOTAL_CORES-1:0];
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime <= 64'd0;
            for (i = 0; i < `TOTAL_CORES; i = i + 1) begin
                mtimecmp[i] <= 64'hFFFFFFFFFFFFFFFF;
                msip[i] <= 32'd0;
            end
            ready <= 1'b0;
            read_data <= 64'd0;
        end else begin
            // Increment mtime every cycle
            mtime <= mtime + 1;
            
            // Default ready pulse
            ready <= 1'b0;
            
            if (we) begin
                ready <= 1'b1;
                // mtimecmp base is 0x4000
                if (addr >= 64'h4000 && addr < 64'h4000 + (`TOTAL_CORES * 8)) begin
                    mtimecmp[(addr - 64'h4000) >> 3] <= write_data;
                end
                // msip base is 0x0000
                else if (addr >= 64'h0000 && addr < 64'h0000 + (`TOTAL_CORES * 4)) begin
                    msip[(addr - 64'h0000) >> 2] <= write_data[31:0];
                end
                // mtime is at 0xBFF8
                else if (addr == 64'hBFF8) begin
                    mtime <= write_data;
                end
            end else if (re) begin
                ready <= 1'b1;
                if (addr >= 64'h4000 && addr < 64'h4000 + (`TOTAL_CORES * 8)) begin
                    read_data <= mtimecmp[(addr - 64'h4000) >> 3];
                end
                else if (addr >= 64'h0000 && addr < 64'h0000 + (`TOTAL_CORES * 4)) begin
                    read_data <= {32'd0, msip[(addr - 64'h0000) >> 2]};
                end
                else if (addr == 64'hBFF8) begin
                    read_data <= mtime;
                end else begin
                    read_data <= 64'd0;
                end
            end
        end
    end

    // Generate interrupts
    genvar g;
    generate
        for (g = 0; g < `TOTAL_CORES; g = g + 1) begin : clint_intr_gen
            assign timer_intr[g] = (mtime >= mtimecmp[g]) ? 1'b1 : 1'b0;
            assign sw_intr[g]    = msip[g][0];
        end
    endgenerate

endmodule
