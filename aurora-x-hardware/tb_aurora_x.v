`timescale 1ns / 1ps

module tb_aurora_x;

    reg clk;
    reg rst_n;
    
    // Memory
    reg [31:0] rom [0:1023]; // 4KB instruction memory
    reg [63:0] ram [0:1023]; // 8KB data memory

    // Core outputs
    wire [63:0] pc;
    wire [63:0] data_addr;
    wire [63:0] data_write_val;
    wire data_we;
    wire data_re;
    wire [63:0] test_status;

    // Core inputs
    wire [31:0] inst;
    reg  [63:0] data_read_val;

    // Instantiate Core
    aurora_x_core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .pc(pc),
        .inst(inst),
        .data_addr(data_addr),
        .data_write_val(data_write_val),
        .data_read_val(data_read_val),
        .data_we(data_we),
        .data_re(data_re),
        .test_status(test_status)
    );

    // ROM Logic
    // PC is in bytes, rom is word-addressed (4 bytes per word)
    assign inst = rom[pc[11:2]];

    // RAM Logic
    always @(posedge clk) begin
        if (data_we) begin
            ram[data_addr[12:3]] <= data_write_val;
        end
    end
    always @(*) begin
        if (data_re) begin
            data_read_val = ram[data_addr[12:3]];
        end else begin
            data_read_val = 64'd0;
        end
    end

    // Clock Generation
    always #5 clk = ~clk;

    // Test Control
    reg [2047:0] test_hex;
    initial begin
        $dumpfile("aurora_x.vcd");
        $dumpvars(0, tb_aurora_x);

        // Load Compliance Test Hex
        // Initialize memory with 0s first to avoid X propagation
        for (integer i=0; i<1024; i=i+1) begin
            rom[i] = 32'd0;
            ram[i] = 64'd0;
        end

        if ($value$plusargs("TEST=%s", test_hex)) begin
            $readmemh(test_hex, rom);
        end else begin
            $readmemh("../AURORA-X-Tests/fib.hex", rom);
        end

        clk = 0;
        rst_n = 0;
        
        #20 rst_n = 1; // Release reset

        // Wait for test_status
        wait(test_status != 0);

        // Check for test completion via CSR 0x700
        if (test_status == 64'd1) begin
            $display("========================================");
            $display(" [HARDWARE PASS]");
            $display("========================================");
        end else begin
            $display("========================================");
            $display(" [HARDWARE FAIL] test_status = %d", test_status);
            $display("========================================");
        end

        #20 $finish;
    end

    // SYS_PRINT Interception
    always @(posedge clk) begin
        if (u_core.tb_CSR_Write && u_core.tb_csr_addr == 12'h701) begin
            $display("[SYS_PRINT] %d (0x%016x)", u_core.tb_read_data1, u_core.tb_read_data1);
            // We no longer finish the simulation here. It finishes via test_status.
        end
    end

    // Timeout watchdog
    initial begin
        #50000; // Increased timeout for larger tests
        $display("========================================");
        $display(" [HARDWARE TIMEOUT] PC = %x", pc);
        $display("========================================");
        $finish;
    end

endmodule
