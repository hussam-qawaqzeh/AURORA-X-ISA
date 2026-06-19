module l1_cache (
    input clk,
    input rst_n,
    
    // CPU Interface
    input [63:0] cpu_addr,
    input [63:0] cpu_write_data,
    input cpu_we,
    input cpu_re,
    output reg [63:0] cpu_read_data,
    output reg stall,
    
    // Main Memory Interface
    output reg [63:0] mem_addr,
    output reg [63:0] mem_write_data,
    output reg mem_we,
    output reg mem_re,
    input [63:0] mem_read_data,
    input mem_ready
);
    parameter CACHE_LINES = 16;
    
    reg [63:0] cache_data [0:CACHE_LINES-1];
    reg [56:0] cache_tag [0:CACHE_LINES-1];
    reg cache_valid [0:CACHE_LINES-1];
    
    wire [3:0] index = cpu_addr[6:3];
    wire [56:0] tag = cpu_addr[63:7];
    
    reg [1:0] state, next_state;
    localparam IDLE = 2'b00, FETCH = 2'b01;
    
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
            end else if (state == IDLE && cpu_we && (cache_valid[index] && cache_tag[index] == tag)) begin
                cache_data[index] <= cpu_write_data;
            end
        end
    end
    
    always @(*) begin
        stall = 0;
        next_state = state;
        mem_we = 0;
        mem_re = 0;
        mem_addr = cpu_addr;
        mem_write_data = cpu_write_data;
        cpu_read_data = 64'd0;
        
        case (state)
            IDLE: begin
                if (cpu_re) begin
                    if (cache_valid[index] && cache_tag[index] == tag) begin
                        cpu_read_data = cache_data[index];
                    end else begin
                        stall = 1;
                        mem_re = 1;
                        next_state = FETCH;
                    end
                end else if (cpu_we) begin
                    mem_we = 1;
                    if (!mem_ready) stall = 1;
                end
            end
            FETCH: begin
                stall = 1;
                mem_re = 1;
                if (mem_ready) begin
                    next_state = IDLE;
                end
            end
        endcase
    end
endmodule
