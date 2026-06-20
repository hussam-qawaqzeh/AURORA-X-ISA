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
    always @(posedge clk or negedge rst_n) begin
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
    
    always @(*) begin
        bus_ready = 1;
        next_state = state;
        mem_we = 0;
        mem_re = 0;
        mem_addr = bus_addr;
        mem_write_data = bus_write_data;
        bus_read_data = 64'd0;
        
        case (state)
            IDLE: begin
                if (bus_re) begin
                    if (cache_valid[index] && cache_tag[index] == tag) begin
                        bus_read_data = cache_data[index];
                    end else begin
                        bus_ready = 0;
                        mem_re = 1;
                        next_state = FETCH;
                    end
                end else if (bus_we) begin
                    mem_we = 1;
                    if (!mem_ready) begin
                        bus_ready = 0;
                        next_state = WRITE;
                    end
                end
            end
            FETCH: begin
                bus_ready = 0;
                mem_re = 1;
                if (mem_ready) begin
                    bus_ready = 1; 
                    bus_read_data = mem_read_data; 
                    next_state = IDLE;
                end
            end
            WRITE: begin
                bus_ready = 0;
                mem_we = 1;
                if (mem_ready) begin
                    bus_ready = 1;
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end
endmodule
