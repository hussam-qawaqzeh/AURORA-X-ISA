`include "aurora_config.vh"

module ax_bus_scalable (
    input clk,
    input rst_n,

    // Flat arrays for N masters
    input  [`TOTAL_CORES-1:0] m_req,
    input  [(`TOTAL_CORES*64)-1:0] m_addr,
    input  [(`TOTAL_CORES*64)-1:0] m_write_data,
    input  [`TOTAL_CORES-1:0] m_we,
    input  [`TOTAL_CORES-1:0] m_re,
    output [(`TOTAL_CORES*64)-1:0] m_read_data,
    output [`TOTAL_CORES-1:0] m_ready,

    // Snoop out arrays (each master receives snoop broadcast)
    output [(`TOTAL_CORES*64)-1:0] snoop_addr,
    output [`TOTAL_CORES-1:0] snoop_we,

    // Slave 0 Interface (to Shared Cache / Memory)
    output [63:0] s0_addr,
    output [63:0] s0_write_data,
    output s0_we,
    output s0_re,
    input  [63:0] s0_read_data,
    input  s0_ready,
    
    // Slave 1 Interface (to CLINT)
    output [63:0] s1_addr,
    output [63:0] s1_write_data,
    output s1_we,
    output s1_re,
    input  [63:0] s1_read_data,
    input  s1_ready,
    
    // Slave 2 Interface (to UART)
    output [63:0] s2_addr,
    output [63:0] s2_write_data,
    output s2_we,
    output s2_re,
    input  [63:0] s2_read_data,
    input  s2_ready,

    // Slave 3 Interface (GPIO)
    output [63:0] s3_addr,
    output [63:0] s3_write_data,
    output s3_we,
    output s3_re,
    input  [63:0] s3_read_data,
    input  s3_ready,

    // Slave 4 Interface (SPI)
    output [63:0] s4_addr,
    output [63:0] s4_write_data,
    output s4_we,
    output s4_re,
    input  [63:0] s4_read_data,
    input  s4_ready
);

    reg [31:0] current_master; // Index of the currently granted master
    reg serving;

    integer i;

    // Arbitration logic (Simple Priority / Round Robin)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_master <= 0;
            serving <= 0;
        end else begin
            if (serving) begin
                if (s0_ready || s1_ready || s2_ready || s3_ready || s4_ready) begin
                    serving <= 0; // Transaction finished
                end
            end else begin
                // Priority arbiter (Core 0 has highest priority)
                // In a real design, this would be Round-Robin.
                serving <= 0;
                for (i = `TOTAL_CORES-1; i >= 0; i = i - 1) begin
                    if (m_req[i]) begin
                        current_master <= i;
                        serving <= 1;
                    end
                end
            end
        end
    end

    wire [31:0] grant_idx = (serving) ? current_master : 
                            (m_req[0] ? 0 : 
                            (m_req[1] ? 1 : 
                            (m_req[2] ? 2 : 
                            (m_req[3] ? 3 : 
                            (m_req[4] ? 4 : 
                            (m_req[5] ? 5 : 
                            (m_req[6] ? 6 : 
                            (m_req[7] ? 7 : 
                            (m_req[8] ? 8 : 0))))))))); // Fast combinational grant

    wire [63:0] active_addr = m_addr[(grant_idx*64) +: 64];
    wire is_clint = (active_addr >= 64'h02000000 && active_addr < 64'h02010000);
    wire is_uart  = (active_addr >= 64'h10000000 && active_addr < 64'h10001000);
    wire is_gpio  = (active_addr >= 64'h20000000 && active_addr < 64'h20001000);
    wire is_spi   = (active_addr >= 64'h30000000 && active_addr < 64'h30001000);
    
    wire is_mem = (!is_clint && !is_uart && !is_gpio && !is_spi);

    // MUXing inputs to Slaves
    assign s0_addr       = active_addr;
    assign s0_write_data = m_write_data[(grant_idx*64) +: 64];
    assign s0_we         = is_mem ? m_we[grant_idx] : 1'b0;
    assign s0_re         = is_mem ? m_re[grant_idx] : 1'b0;
    
    assign s1_addr       = active_addr - 64'h02000000; // Local offset for CLINT
    assign s1_write_data = m_write_data[(grant_idx*64) +: 64];
    assign s1_we         = is_clint ? m_we[grant_idx] : 1'b0;
    assign s1_re         = is_clint ? m_re[grant_idx] : 1'b0;
    
    assign s2_addr       = active_addr - 64'h10000000; // Local offset for UART
    assign s2_write_data = m_write_data[(grant_idx*64) +: 64];
    assign s2_we         = is_uart ? m_we[grant_idx] : 1'b0;
    assign s2_re         = is_uart ? m_re[grant_idx] : 1'b0;

    assign s3_addr       = active_addr - 64'h20000000; // Local offset for GPIO
    assign s3_write_data = m_write_data[(grant_idx*64) +: 64];
    assign s3_we         = is_gpio ? m_we[grant_idx] : 1'b0;
    assign s3_re         = is_gpio ? m_re[grant_idx] : 1'b0;

    assign s4_addr       = active_addr - 64'h30000000; // Local offset for SPI
    assign s4_write_data = m_write_data[(grant_idx*64) +: 64];
    assign s4_we         = is_spi ? m_we[grant_idx] : 1'b0;
    assign s4_re         = is_spi ? m_re[grant_idx] : 1'b0;

    // Demuxing outputs to Masters
    genvar g;
    generate
        for (g = 0; g < `TOTAL_CORES; g = g + 1) begin : demux_loop
            assign m_read_data[(g*64) +: 64] = is_clint ? s1_read_data : (is_uart ? s2_read_data : (is_gpio ? s3_read_data : (is_spi ? s4_read_data : s0_read_data)));
            assign m_ready[g] = (grant_idx == g) ? (is_clint ? s1_ready : (is_uart ? s2_ready : (is_gpio ? s3_ready : (is_spi ? s4_ready : s0_ready)))) : 1'b0;

            // Snoop broadcast (everyone gets the address if someone is writing, EXCEPT the writer itself)
            assign snoop_addr[(g*64) +: 64] = (grant_idx != g && s0_we) ? s0_addr : 64'd0;
            assign snoop_we[g] = (grant_idx != g && s0_we) ? 1'b1 : 1'b0;
        end
    endgenerate

endmodule
