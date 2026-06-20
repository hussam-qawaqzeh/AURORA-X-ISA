`timescale 1ns/1ps

module tb_aurora_x_soc();

    reg clk;
    reg rst_n;
    
    // Core Instruction Memory
    reg [31:0] inst_mem [0:1023];
    wire [63:0] c0_pc;
    wire [63:0] c1_pc;
    wire [31:0] c0_inst = inst_mem[c0_pc[11:2]];
    wire [31:0] c1_inst = inst_mem[c1_pc[11:2]];

    // Main Memory (Data)
    reg [63:0] data_mem [0:1023];
    wire [63:0] mem_addr;
    wire [63:0] mem_write_val;
    wire mem_we;
    wire mem_re;
    reg [63:0] mem_read_val;
    reg mem_ready;

    wire [63:0] c0_test_status;
    wire [63:0] c1_test_status;

    aurora_x_soc u_soc (
        .clk(clk),
        .rst_n(rst_n),
        .c0_pc(c0_pc),
        .c0_inst(c0_inst),
        .c1_pc(c1_pc),
        .c1_inst(c1_inst),
        .mem_addr(mem_addr),
        .mem_write_val(mem_write_val),
        .mem_we(mem_we),
        .mem_re(mem_re),
        .mem_read_val(mem_read_val),
        .mem_ready(mem_ready),
        .c0_test_status(c0_test_status),
        .c1_test_status(c1_test_status)
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
        #2000000;
        $display("Timeout!");
        $finish;
    end

    // Finish condition: Both cores report PASS
    always @(posedge clk) begin
        if (c0_test_status != 0 && c1_test_status != 0) begin
            $display("========================================");
            $display(" [MULTI-CORE HARDWARE PASS] ");
            $display(" Core 1 Final Read = 0x%02x", c1_test_status);
            $display("========================================");
            $finish;
        end
    end
    
    reg [63:0] last_c0_status = 0;
    reg [63:0] last_c1_status = 0;
    always @(posedge clk) begin
        if (c0_test_status != last_c0_status) begin
            $display("Time=%0t | Core 0 Test Status changed to: %x", $time, c0_test_status);
            last_c0_status <= c0_test_status;
        end
        if (c1_test_status != last_c1_status) begin
            $display("Time=%0t | Core 1 Test Status changed to: %x", $time, c1_test_status);
            last_c1_status <= c1_test_status;
        end
    end

    // Quick hack to catch SYS_PRINT from Core 1
    always @(posedge clk) begin
        if (u_soc.u_core1.tb_CSR_Write && u_soc.u_core1.tb_csr_addr == 12'h701) begin
            $display("[SYS_PRINT Core 1] %d (0x%016x)", u_soc.u_core1.tb_read_data1, u_soc.u_core1.tb_read_data1);
        end
        if (u_soc.u_core0.tb_CSR_Write && u_soc.u_core0.tb_csr_addr == 12'h701) begin
            $display("[SYS_PRINT Core 0] %d (0x%016x)", u_soc.u_core0.tb_read_data1, u_soc.u_core0.tb_read_data1);
        end
        // Print PC every cycle if not 0 to see where they hang
        // $display("Time=%0t | C0_PC=%x | C1_PC=%x | C0_Stall=%b | C1_Stall=%b", $time, c0_pc, c1_pc, u_soc.u_core0.Stall_Pipeline, u_soc.u_core1.Stall_Pipeline);
    end

    always @(posedge clk) begin
        if (mem_we) begin
            $display("Time=%0t | Main Memory Write to %x: %x", $time, mem_addr, mem_write_val);
        end
        if (mem_re && mem_ready) begin
            $display("Time=%0t | Main Memory Read from %x: %x", $time, mem_addr, mem_read_val);
        end
        if (u_soc.c0_data_we) begin
            $display("Time=%0t | C0_PC=%x | Core 0 Data Write to %x: %x", $time, c0_pc, u_soc.c0_data_addr, u_soc.c0_data_write_val);
        end
        if (u_soc.c1_data_we) begin
            $display("Time=%0t | C1_PC=%x | Core 1 Data Write to %x: %x", $time, c1_pc, u_soc.c1_data_addr, u_soc.c1_data_write_val);
        end
        if (u_soc.c0_data_re) begin
            $display("Time=%0t | Core 0 Data Read from %x", $time, u_soc.c0_data_addr);
        end
        if (u_soc.c1_data_re) begin
            $display("Time=%0t | Core 1 Data Read from %x", $time, u_soc.c1_data_addr);
        end
    end

endmodule
