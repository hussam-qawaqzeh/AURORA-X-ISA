`timescale 1ns/1ps
`include "aurora_config.vh"

module tb_aurora_x_soc();

    reg clk;
    reg rst_n;
    
    // Instruction Memory
    reg [31:0] inst_mem [0:1023];
    wire [(`TOTAL_CORES*64)-1:0] cores_pc;
    wire [(`TOTAL_CORES*32)-1:0] cores_inst;
    
    genvar g;
    generate
        for (g = 0; g < `TOTAL_CORES; g = g + 1) begin : gen_inst
            wire [63:0] pc = cores_pc[(g*64) +: 64];
            assign cores_inst[(g*32) +: 32] = inst_mem[pc[11:2]];
        end
    endgenerate

    // Main Memory (Data)
    reg [63:0] data_mem [0:1023];
    wire [63:0] mem_addr;
    wire [63:0] mem_write_val;
    wire mem_we;
    wire mem_re;
    reg [63:0] mem_read_val;
    reg mem_ready;

    wire [(`TOTAL_CORES*64)-1:0] cores_test_status;

    wire uart_tx;
    wire uart_rx = 1'b1;
    wire [`TOTAL_CORES-1:0] ext_intr = 0;
    
    wire [31:0] gpio_pins;
    wire spi_sck;
    wire spi_mosi;
    wire spi_miso = 1'b0;
    wire [3:0] spi_cs;

    aurora_x_soc u_soc (
        .clk(clk),
        .rst_n(rst_n),
        .cores_pc(cores_pc),
        .cores_inst(cores_inst),
        .mem_addr(mem_addr),
        .mem_write_val(mem_write_val),
        .mem_we(mem_we),
        .mem_re(mem_re),
        .mem_read_val(mem_read_val),
        .mem_ready(mem_ready),
        .cores_test_status(cores_test_status),
        .ext_intr(ext_intr),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .gpio_pins(gpio_pins),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs(spi_cs)
    );

    // Main Memory Logic (Simulation with 3 cycle latency)
    reg [3:0] mem_latency_counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 0;
            mem_latency_counter <= 0;
            mem_read_val <= 0;
        end else begin
            if (mem_we || mem_re) begin
                if (mem_latency_counter == 3) begin
                    mem_ready <= 1;
                    if (mem_we) data_mem[mem_addr[12:3]] <= mem_write_val;
                    if (mem_re) mem_read_val <= data_mem[mem_addr[12:3]];
                    mem_latency_counter <= 0;
                end else begin
                    mem_ready <= 0;
                    mem_latency_counter <= mem_latency_counter + 1;
                end
            end else begin
                mem_ready <= 0;
                mem_latency_counter <= 0;
            end
        end
    end

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end
    
    // Load instructions and run
    reg [8191:0] test_file;
    integer i;
    initial begin
        $dumpfile("aurora_x_soc.vcd");
        $dumpvars(0, tb_aurora_x_soc);
        
        for (i=0; i<1024; i=i+1) data_mem[i] = 0;
        
        if ($value$plusargs("TEST=%s", test_file)) begin
            $readmemh(test_file, inst_mem);
        end else begin
            $display("ERROR: No test file specified. Use +TEST=<file.hex>");
            $finish;
        end
        
        rst_n = 0;
        #20 rst_n = 1;
        
        // Timeout
        #10000; // longer timeout for testing
        $display("Timeout!");
        $finish;
    end

    // Finish condition: Core 0 (P-Core) reports PASS
    wire [63:0] c0_test_status = cores_test_status[0 +: 64];
    
    always @(posedge clk) begin
        if (c0_test_status != 0) begin
            $display("========================================");
            $display(" [MULTI-CORE HARDWARE PASS] ");
            $display(" Core 0 Final Read = 0x%02x", c0_test_status);
            $display("========================================");
            $finish;
        end
    end
    
    always @(posedge clk) begin
        if (mem_we) begin
            $display("Time=%0t | Main Memory Write to %x: %x", $time, mem_addr, mem_write_val);
        end
        if (mem_re && mem_ready) begin
            $display("Time=%0t | Main Memory Read from %x: %x", $time, mem_addr, mem_read_val);
        end
    end

endmodule
