module ax_bus (
    input clk,
    input rst_n,

    // Master 0 (Core 0)
    input m0_req,
    input [63:0] m0_addr,
    input [63:0] m0_write_data,
    input m0_we,
    input m0_re,
    output [63:0] m0_read_data,
    output m0_ready,

    // Master 1 (Core 1)
    input m1_req,
    input [63:0] m1_addr,
    input [63:0] m1_write_data,
    input m1_we,
    input m1_re,
    output [63:0] m1_read_data,
    output m1_ready,

    // Snoop Port to Master 0
    output [63:0] m0_snoop_addr,
    output m0_snoop_we,

    // Snoop Port to Master 1
    output [63:0] m1_snoop_addr,
    output m1_snoop_we,

    // Slave (Shared L2 Cache / Memory)
    output [63:0] s_addr,
    output [63:0] s_write_data,
    output s_we,
    output s_re,
    input [63:0] s_read_data,
    input s_ready
);

    localparam IDLE       = 2'b00;
    localparam SERVING_M0 = 2'b01;
    localparam SERVING_M1 = 2'b10;

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (m0_req) begin
                    if (!s_ready) next_state = SERVING_M0;
                end else if (m1_req) begin
                    if (!s_ready) next_state = SERVING_M1;
                end
            end
            SERVING_M0: begin
                if (s_ready) begin
                    // Transaction finished. Check if M1 is waiting to ensure fairness (simple round robin hint)
                    if (m1_req && !m0_req) next_state = SERVING_M1;
                    else next_state = IDLE;
                end
            end
            SERVING_M1: begin
                if (s_ready) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // MUXing
    wire grant_m0 = (state == SERVING_M0) || (state == IDLE && m0_req);
    wire grant_m1 = (state == SERVING_M1) || (state == IDLE && !m0_req && m1_req);

    assign s_addr       = grant_m0 ? m0_addr : (grant_m1 ? m1_addr : 64'd0);
    assign s_write_data = grant_m0 ? m0_write_data : (grant_m1 ? m1_write_data : 64'd0);
    assign s_we         = grant_m0 ? m0_we : (grant_m1 ? m1_we : 1'b0);
    assign s_re         = grant_m0 ? m0_re : (grant_m1 ? m1_re : 1'b0);

    assign m0_read_data = s_read_data;
    assign m1_read_data = s_read_data;

    assign m0_ready     = grant_m0 ? s_ready : 1'b0;
    assign m1_ready     = grant_m1 ? s_ready : 1'b0;

    // Snooping: Broadcast write address of M1 to M0
    assign m0_snoop_addr = grant_m1 ? m1_addr : 64'd0;
    assign m0_snoop_we   = grant_m1 ? m1_we : 1'b0;

    // Snooping: Broadcast write address of M0 to M1
    assign m1_snoop_addr = grant_m0 ? m0_addr : 64'd0;
    assign m1_snoop_we   = grant_m0 ? m0_we : 1'b0;

endmodule
