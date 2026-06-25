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
    input mem_ready,
    // Snoop Interface
    input [63:0] snoop_addr,
    input snoop_we
);
    parameter CACHE_LINES = 16;
    
    reg [63:0] cache_data [0:CACHE_LINES-1];
    reg [56:0] cache_tag [0:CACHE_LINES-1];
    reg cache_valid [0:CACHE_LINES-1];
    
    wire [3:0] index = cpu_addr[6:3];
    wire [56:0] tag = cpu_addr[63:7];

    wire [3:0] snoop_index = snoop_addr[6:3];
    wire [56:0] snoop_tag = snoop_addr[63:7];
    
    reg [1:0] state, next_state;
    localparam IDLE = 2'b00, FETCH = 2'b01, WRITE = 2'b10;
    
    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            for (i=0; i<CACHE_LINES; i=i+1) cache_valid[i] <= 0;
        end else begin
            state <= next_state;
            
            // Handle updates to cache_valid array
            for (i=0; i<CACHE_LINES; i=i+1) begin
                if (snoop_we && i == snoop_index && cache_tag[i] == snoop_tag) begin
                    cache_valid[i] <= 0; // Snoop Invalidate!
                end else if (state == FETCH && mem_ready && i == index) begin
                    cache_valid[i] <= 1; // Fetch Fill
                end
            end

            // Handle updates to cache_data and cache_tag
            if (state == FETCH && mem_ready) begin
                cache_tag[index] <= tag;
                cache_data[index] <= mem_read_data;
            end else if (state == IDLE && cpu_we && (cache_valid[index] && cache_tag[index] == tag)) begin
                // Update on Write-Through hit
                // Only update if it wasn't just invalidated by a snoop in the same cycle
                if (!(snoop_we && index == snoop_index && cache_tag[index] == snoop_tag)) begin
                    cache_data[index] <= cpu_write_data;
                end
            end
        end
    end
    
    reg stall_v;
    reg [1:0] next_state_v;
    reg mem_we_v;
    reg mem_re_v;
    reg [63:0] mem_addr_v;
    reg [63:0] mem_write_data_v;
    reg [63:0] cpu_read_data_v;

    always @(*) begin
        stall_v = 0;
        next_state_v = state;
        mem_we_v = 0;
        mem_re_v = 0;
        mem_addr_v = cpu_addr;
        mem_write_data_v = cpu_write_data;
        cpu_read_data_v = 64'd0;
        
        case (state)
            IDLE: begin
                if (cpu_re) begin
                    if (cache_valid[index] && cache_tag[index] == tag) begin
                        // Hit
                        cpu_read_data_v = cache_data[index];
                    end else begin
                        // Miss
                        stall_v = 1;
                        mem_re_v = 1;
                        next_state_v = FETCH;
                    end
                end else if (cpu_we) begin
                    // Write-Through
                    mem_we_v = 1;
                    if (!mem_ready) begin
                        stall_v = 1;
                        next_state_v = WRITE;
                    end
                end
            end
            FETCH: begin
                stall_v = 1;
                mem_re_v = 1;
                if (mem_ready) begin
                    stall_v = 0; 
                    cpu_read_data_v = mem_read_data; 
                    next_state_v = IDLE;
                end
            end
            WRITE: begin
                stall_v = 1;
                mem_we_v = 1;
                if (mem_ready) begin
                    stall_v = 0;
                    next_state_v = IDLE;
                end
            end
            default: next_state_v = IDLE;
        endcase

        stall = stall_v;
        next_state = next_state_v;
        mem_we = mem_we_v;
        mem_re = mem_re_v;
        mem_addr = mem_addr_v;
        mem_write_data = mem_write_data_v;
        cpu_read_data = cpu_read_data_v;
    end
endmodule
