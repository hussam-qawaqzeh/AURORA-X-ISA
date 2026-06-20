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

    // Slave Interface (to Shared Cache)
    output [63:0] s_addr,
    output [63:0] s_write_data,
    output s_we,
    output s_re,
    input  [63:0] s_read_data,
    input  s_ready
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
                if (s_ready) begin
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
                            (`TOTAL_CORES > 2 && m_req[2] ? 2 : 0))); // Fast combinational grant

    // MUXing inputs to Slave
    assign s_addr       = m_addr[(grant_idx*64) +: 64];
    assign s_write_data = m_write_data[(grant_idx*64) +: 64];
    assign s_we         = m_we[grant_idx];
    assign s_re         = m_re[grant_idx];

    // Demuxing outputs to Masters
    genvar g;
    generate
        for (g = 0; g < `TOTAL_CORES; g = g + 1) begin : demux_loop
            assign m_read_data[(g*64) +: 64] = s_read_data;
            assign m_ready[g] = (grant_idx == g) ? s_ready : 1'b0;

            // Snoop broadcast (everyone gets the address if someone is writing, EXCEPT the writer itself)
            assign snoop_addr[(g*64) +: 64] = (grant_idx != g && s_we) ? s_addr : 64'd0;
            assign snoop_we[g] = (grant_idx != g && s_we) ? 1'b1 : 1'b0;
        end
    endgenerate

endmodule
