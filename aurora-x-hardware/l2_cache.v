module l2_cache (
    input clk,
    input rst_n,
    
    // AX-Bus Interface (Slave)
    input [63:0] bus_addr,
    input [63:0] bus_write_data,
    input bus_we,
    input bus_re,
    output reg [63:0] bus_read_data,
    output reg bus_ready,
    
    // Main Memory Interface (Master)
    output reg [63:0] mem_addr,
    output reg [63:0] mem_write_data,
    output reg mem_we,
    output reg mem_re,
    input [63:0] mem_read_data,
    input mem_ready
);
    parameter CACHE_LINES = 256;
    
    reg [63:0] cache_data [0:CACHE_LINES-1];
    reg [52:0] cache_tag [0:CACHE_LINES-1];
    reg cache_valid [0:CACHE_LINES-1];
    
    wire [7:0] index = bus_addr[10:3];
    wire [52:0] tag = bus_addr[63:11];
    
    reg [1:0] state, next_state;
    localparam IDLE = 2'b00, FETCH = 2'b01, WRITE = 2'b10;
    
    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            for (i=0; i<CACHE_LINES; i=i+1) cache_valid[i] <= 0;
        end else begin
            state <= next_state;
            if (state == FETCH && mem_ready) begin
                cache_valid[index] <= 1;
                cache_tag[index] <= tag;
                cache_data[index] <= mem_read_data;
            end else if (state == IDLE && bus_we && (cache_valid[index] && cache_tag[index] == tag)) begin
                cache_data[index] <= bus_write_data;
            end
        end
    end
    
    reg bus_ready_v;
    reg [1:0] next_state_v;
    reg mem_we_v;
    reg mem_re_v;
    reg [63:0] mem_addr_v;
    reg [63:0] mem_write_data_v;
    reg [63:0] bus_read_data_v;

    always @(*) begin
        bus_ready_v = 1;
        next_state_v = state;
        mem_we_v = 0;
        mem_re_v = 0;
        mem_addr_v = bus_addr;
        mem_write_data_v = bus_write_data;
        bus_read_data_v = 64'd0;
        
        case (state)
            IDLE: begin
                if (bus_re) begin
                    if (cache_valid[index] && cache_tag[index] == tag) begin
                        // Cache Hit
                        bus_read_data_v = cache_data[index];
                    end else begin
                        // Cache Miss
                        bus_ready_v = 0;
                        mem_re_v = 1;
                        next_state_v = FETCH;
                    end
                end else if (bus_we) begin
                    // Write-Through policy
                    mem_we_v = 1;
                    if (!mem_ready) begin
                        bus_ready_v = 0;
                        next_state_v = WRITE;
                    end
                end
            end
            FETCH: begin
                bus_ready_v = 0;
                mem_re_v = 1;
                if (mem_ready) begin
                    bus_ready_v = 1; 
                    bus_read_data_v = mem_read_data; 
                    next_state_v = IDLE;
                end
            end
            WRITE: begin
                bus_ready_v = 0;
                mem_we_v = 1;
                if (mem_ready) begin
                    bus_ready_v = 1;
                    next_state_v = IDLE;
                end
            end
            default: next_state_v = IDLE;
        endcase

        bus_ready = bus_ready_v;
        next_state = next_state_v;
        mem_we = mem_we_v;
        mem_re = mem_re_v;
        mem_addr = mem_addr_v;
        mem_write_data = mem_write_data_v;
        bus_read_data = bus_read_data_v;
    end
endmodule
