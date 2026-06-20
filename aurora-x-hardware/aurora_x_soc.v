module aurora_x_soc (
    input clk,
    input rst_n,

    // Core 0 Instruction Interface (assuming shared ROM or separate ROMs)
    output [63:0] c0_pc,
    input  [31:0] c0_inst,

    // Core 1 Instruction Interface
    output [63:0] c1_pc,
    input  [31:0] c1_inst,

    // Main Memory Data Interface (Master from L2)
    output [63:0] mem_addr,
    output [63:0] mem_write_val,
    output mem_we,
    output mem_re,
    input  [63:0] mem_read_val,
    input  mem_ready,
    
    // Core Status
    output [63:0] c0_test_status,
    output [63:0] c1_test_status
);

    // Core 0 Data Interface
    wire [63:0] c0_data_addr;
    wire [63:0] c0_data_write_val;
    wire [63:0] c0_data_read_val;
    wire c0_data_we;
    wire c0_data_re;
    wire c0_data_ready;

    // Core 0 PMU Interface
    wire c0_pmu_req;
    wire [63:0] c0_pmu_write_data;
    
    // Core 1 PMU Interface
    wire c1_pmu_req;
    wire [63:0] c1_pmu_write_data;

    // PMU Generated Clocks
    wire clk_c0;
    wire clk_c1;

    ax_pmu u_pmu (
        .clk(clk),
        .rst_n(rst_n),
        .c0_pmu_req(c0_pmu_req),
        .c0_pmu_write_data(c0_pmu_write_data),
        .c1_pmu_req(c1_pmu_req),
        .c1_pmu_write_data(c1_pmu_write_data),
        .clk_c0(clk_c0),
        .clk_c1(clk_c1)
    );

    aurora_x_core u_core0 (
        .clk(clk_c0),
        .rst_n(rst_n),
        .pc(c0_pc),
        .inst(c0_inst),
        .data_addr(c0_data_addr),
        .data_write_val(c0_data_write_val),
        .data_read_val(c0_data_read_val),
        .data_we(c0_data_we),
        .data_re(c0_data_re),
        .data_ready(c0_data_ready),
        .core_id(4'd0),
        .test_status(c0_test_status),
        .pmu_req(c0_pmu_req),
        .pmu_write_data(c0_pmu_write_data),
        .snoop_addr(m0_snoop_addr),
        .snoop_we(m0_snoop_we)
    );

    // Core 1 Data Interface
    wire [63:0] c1_data_addr;
    wire [63:0] c1_data_write_val;
    wire [63:0] c1_data_read_val;
    wire c1_data_we;
    wire c1_data_re;
    wire c1_data_ready;

    aurora_x_core u_core1 (
        .clk(clk_c1),
        .rst_n(rst_n),
        .pc(c1_pc),
        .inst(c1_inst),
        .data_addr(c1_data_addr),
        .data_write_val(c1_data_write_val),
        .data_read_val(c1_data_read_val),
        .data_we(c1_data_we),
        .data_re(c1_data_re),
        .data_ready(c1_data_ready),
        .core_id(4'd1),
        .test_status(c1_test_status),
        .pmu_req(c1_pmu_req),
        .pmu_write_data(c1_pmu_write_data),
        .snoop_addr(m1_snoop_addr),
        .snoop_we(m1_snoop_we)
    );

    // AX-Bus Interface (Slave side)
    wire [63:0] bus_addr;
    wire [63:0] bus_write_data;
    wire bus_we;
    wire bus_re;
    wire [63:0] bus_read_data;
    wire bus_ready;

    // Snoop signals
    wire [63:0] m0_snoop_addr;
    wire m0_snoop_we;
    wire [63:0] m1_snoop_addr;
    wire m1_snoop_we;

    ax_bus u_ax_bus (
        .clk(clk),
        .rst_n(rst_n),
        .m0_req(c0_data_we || c0_data_re),
        .m0_addr(c0_data_addr),
        .m0_write_data(c0_data_write_val),
        .m0_we(c0_data_we),
        .m0_re(c0_data_re),
        .m0_read_data(c0_data_read_val),
        .m0_ready(c0_data_ready),
        
        .m1_req(c1_data_we || c1_data_re),
        .m1_addr(c1_data_addr),
        .m1_write_data(c1_data_write_val),
        .m1_we(c1_data_we),
        .m1_re(c1_data_re),
        .m1_read_data(c1_data_read_val),
        .m1_ready(c1_data_ready),

        .m0_snoop_addr(m0_snoop_addr),
        .m0_snoop_we(m0_snoop_we),
        .m1_snoop_addr(m1_snoop_addr),
        .m1_snoop_we(m1_snoop_we),

        .s_addr(bus_addr),
        .s_write_data(bus_write_data),
        .s_we(bus_we),
        .s_re(bus_re),
        .s_read_data(bus_read_data),
        .s_ready(bus_ready)
    );

    // L2 Cache
    l2_cache u_l2_cache (
        .clk(clk),
        .rst_n(rst_n),
        .bus_addr(bus_addr),
        .bus_write_data(bus_write_data),
        .bus_we(bus_we),
        .bus_re(bus_re),
        .bus_read_data(bus_read_data),
        .bus_ready(bus_ready),
        .mem_addr(mem_addr),
        .mem_write_data(mem_write_val),
        .mem_we(mem_we),
        .mem_re(mem_re),
        .mem_read_data(mem_read_val),
        .mem_ready(mem_ready)
    );

endmodule
