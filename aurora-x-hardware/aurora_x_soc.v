`include "aurora_config.vh"

module aurora_x_soc (
    input clk,
    input rst_n,

    // Instruction Interface for ALL cores
    output [(`TOTAL_CORES*64)-1:0] cores_pc,
    input  [(`TOTAL_CORES*32)-1:0] cores_inst,

    // Main Memory Data Interface (Master from L3/L2)
    output [63:0] mem_addr,
    output [63:0] mem_write_val,
    output mem_we,
    output mem_re,
    input  [63:0] mem_read_val,
    input  mem_ready,
    
    // Core Status
    output [(`TOTAL_CORES*64)-1:0] cores_test_status
);

    // PMU Interface Arrays
    wire [`TOTAL_CORES-1:0] pmu_req;
    wire [(`TOTAL_CORES*64)-1:0] pmu_write_data;
    wire [`TOTAL_CORES-1:0] clk_cores;

    ax_pmu u_pmu (
        .clk(clk),
        .rst_n(rst_n),
        .pmu_req(pmu_req),
        .pmu_write_data(pmu_write_data),
        .clk_cores(clk_cores)
    );

    // Data Interface Arrays
    wire [(`TOTAL_CORES*64)-1:0] core_data_addr;
    wire [(`TOTAL_CORES*64)-1:0] core_data_write_val;
    wire [(`TOTAL_CORES*64)-1:0] core_data_read_val;
    wire [`TOTAL_CORES-1:0] core_data_we;
    wire [`TOTAL_CORES-1:0] core_data_re;
    wire [`TOTAL_CORES-1:0] core_data_ready;

    // Snoop Interface Arrays
    wire [(`TOTAL_CORES*64)-1:0] snoop_addr;
    wire [`TOTAL_CORES-1:0] snoop_we;

    // Instantiate Cores based on Configuration
    genvar g;
    generate
        // P-Cores
        for (g = 0; g < `NUM_P_CORES; g = g + 1) begin : gen_p_cores
            aurora_x_core #(.CORE_TYPE(0)) u_core (
                .clk(clk_cores[g]),
                .rst_n(rst_n),
                .pc(cores_pc[(g*64) +: 64]),
                .inst(cores_inst[(g*32) +: 32]),
                .data_addr(core_data_addr[(g*64) +: 64]),
                .data_write_val(core_data_write_val[(g*64) +: 64]),
                .data_read_val(core_data_read_val[(g*64) +: 64]),
                .data_we(core_data_we[g]),
                .data_re(core_data_re[g]),
                .data_ready(core_data_ready[g]),
                .core_id(g[3:0]),
                .test_status(cores_test_status[(g*64) +: 64]),
                .pmu_req(pmu_req[g]),
                .pmu_write_data(pmu_write_data[(g*64) +: 64]),
                .snoop_addr(snoop_addr[(g*64) +: 64]),
                .snoop_we(snoop_we[g])
            );
        end

        // E-Cores
        for (g = 0; g < `NUM_E_CORES; g = g + 1) begin : gen_e_cores
            localparam idx = `NUM_P_CORES + g;
            aurora_x_core #(.CORE_TYPE(1)) u_core (
                .clk(clk_cores[idx]),
                .rst_n(rst_n),
                .pc(cores_pc[(idx*64) +: 64]),
                .inst(cores_inst[(idx*32) +: 32]),
                .data_addr(core_data_addr[(idx*64) +: 64]),
                .data_write_val(core_data_write_val[(idx*64) +: 64]),
                .data_read_val(core_data_read_val[(idx*64) +: 64]),
                .data_we(core_data_we[idx]),
                .data_re(core_data_re[idx]),
                .data_ready(core_data_ready[idx]),
                .core_id(idx[3:0]),
                .test_status(cores_test_status[(idx*64) +: 64]),
                .pmu_req(pmu_req[idx]),
                .pmu_write_data(pmu_write_data[(idx*64) +: 64]),
                .snoop_addr(snoop_addr[(idx*64) +: 64]),
                .snoop_we(snoop_we[idx])
            );
        end

        // AG-Cores (AI & Graphics)
        for (g = 0; g < `NUM_AG_CORES; g = g + 1) begin : gen_ag_cores
            localparam idx = `NUM_P_CORES + `NUM_E_CORES + g;
            aurora_x_core #(.CORE_TYPE(2)) u_core (
                .clk(clk_cores[idx]),
                .rst_n(rst_n),
                .pc(cores_pc[(idx*64) +: 64]),
                .inst(cores_inst[(idx*32) +: 32]),
                .data_addr(core_data_addr[(idx*64) +: 64]),
                .data_write_val(core_data_write_val[(idx*64) +: 64]),
                .data_read_val(core_data_read_val[(idx*64) +: 64]),
                .data_we(core_data_we[idx]),
                .data_re(core_data_re[idx]),
                .data_ready(core_data_ready[idx]),
                .core_id(idx[3:0]),
                .test_status(cores_test_status[(idx*64) +: 64]),
                .pmu_req(pmu_req[idx]),
                .pmu_write_data(pmu_write_data[(idx*64) +: 64]),
                .snoop_addr(snoop_addr[(idx*64) +: 64]),
                .snoop_we(snoop_we[idx])
            );
        end
    endgenerate

    // AX-Bus Scalable Interface (Slave side)
    wire [63:0] bus_addr;
    wire [63:0] bus_write_data;
    wire bus_we;
    wire bus_re;
    wire [63:0] bus_read_data;
    wire bus_ready;

    wire [`TOTAL_CORES-1:0] bus_req;
    assign bus_req = core_data_we | core_data_re;

    ax_bus_scalable u_ax_bus (
        .clk(clk),
        .rst_n(rst_n),
        .m_req(bus_req),
        .m_addr(core_data_addr),
        .m_write_data(core_data_write_val),
        .m_we(core_data_we),
        .m_re(core_data_re),
        .m_read_data(core_data_read_val),
        .m_ready(core_data_ready),
        .snoop_addr(snoop_addr),
        .snoop_we(snoop_we),
        .s_addr(bus_addr),
        .s_write_data(bus_write_data),
        .s_we(bus_we),
        .s_re(bus_re),
        .s_read_data(bus_read_data),
        .s_ready(bus_ready)
    );

    // L2 Cache (Shared Middle Tier)
    wire [63:0] l2_to_l3_addr;
    wire [63:0] l2_to_l3_write_data;
    wire l2_to_l3_we;
    wire l2_to_l3_re;
    wire [63:0] l3_to_l2_read_data;
    wire l3_to_l2_ready;

    l2_cache u_l2_cache (
        .clk(clk),
        .rst_n(rst_n),
        .bus_addr(bus_addr),
        .bus_write_data(bus_write_data),
        .bus_we(bus_we),
        .bus_re(bus_re),
        .bus_read_data(bus_read_data),
        .bus_ready(bus_ready),
        .mem_addr(l2_to_l3_addr),
        .mem_write_data(l2_to_l3_write_data),
        .mem_we(l2_to_l3_we),
        .mem_re(l2_to_l3_re),
        .mem_read_data(l3_to_l2_read_data),
        .mem_ready(l3_to_l2_ready)
    );

    // L3 Cache (Massive Last Level Cache with 3D V-Cache capabilities)
    generate
        if (`ENABLE_L3_CACHE) begin : gen_l3_cache
            l3_cache u_l3_cache (
                .clk(clk),
                .rst_n(rst_n),
                .bus_addr(l2_to_l3_addr),
                .bus_write_data(l2_to_l3_write_data),
                .bus_we(l2_to_l3_we),
                .bus_re(l2_to_l3_re),
                .bus_read_data(l3_to_l2_read_data),
                .bus_ready(l3_to_l2_ready),
                .mem_addr(mem_addr),
                .mem_write_data(mem_write_val),
                .mem_we(mem_we),
                .mem_re(mem_re),
                .mem_read_data(mem_read_val),
                .mem_ready(mem_ready)
            );
        end else begin : gen_no_l3_cache
            assign mem_addr = l2_to_l3_addr;
            assign mem_write_val = l2_to_l3_write_data;
            assign mem_we = l2_to_l3_we;
            assign mem_re = l2_to_l3_re;
            assign l3_to_l2_read_data = mem_read_val;
            assign l3_to_l2_ready = mem_ready;
        end
    endgenerate

endmodule
