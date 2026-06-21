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
    output [(`TOTAL_CORES*64)-1:0] cores_test_status,
    
    // External Interrupts
    input  [`TOTAL_CORES-1:0] ext_intr,
    
    // UART Interface
    output uart_tx,
    input  uart_rx,
    
    // GPIO Interface
    inout [31:0] gpio_pins,
    
    // SPI Interface
    output spi_sck,
    output spi_mosi,
    input  spi_miso,
    output [3:0] spi_cs
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
    
    // Interrupt Arrays from CLINT
    wire [`TOTAL_CORES-1:0] timer_intr;
    wire [`TOTAL_CORES-1:0] sw_intr;

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
                .snoop_we(snoop_we[g]),
                .ext_intr(ext_intr[g]),
                .timer_intr(timer_intr[g]),
                .sw_intr(sw_intr[g])
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
                .snoop_we(snoop_we[idx]),
                .ext_intr(ext_intr[idx]),
                .timer_intr(timer_intr[idx]),
                .sw_intr(sw_intr[idx])
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
                .snoop_we(snoop_we[idx]),
                .ext_intr(ext_intr[idx]),
                .timer_intr(timer_intr[idx]),
                .sw_intr(sw_intr[idx])
            );
        end
    endgenerate

    // AX-Bus Scalable Interface (Slave side)
    // Slave 0: Cache/Memory
    wire [63:0] bus_s0_addr;
    wire [63:0] bus_s0_write_data;
    wire bus_s0_we;
    wire bus_s0_re;
    wire [63:0] bus_s0_read_data;
    wire bus_s0_ready;
    
    // Slave 1: CLINT
    wire [63:0] bus_s1_addr;
    wire [63:0] bus_s1_write_data;
    wire bus_s1_we;
    wire bus_s1_re;
    wire [63:0] bus_s1_read_data;
    wire bus_s1_ready;
    
    // Slave 2: UART
    wire [63:0] bus_s2_addr;
    wire [63:0] bus_s2_write_data;
    wire bus_s2_we;
    wire bus_s2_re;
    wire [63:0] bus_s2_read_data;
    wire bus_s2_ready;

    // Slave 3: GPIO
    wire [63:0] bus_s3_addr;
    wire [63:0] bus_s3_write_data;
    wire bus_s3_we;
    wire bus_s3_re;
    wire [63:0] bus_s3_read_data;
    wire bus_s3_ready;

    // Slave 4: SPI
    wire [63:0] bus_s4_addr;
    wire [63:0] bus_s4_write_data;
    wire bus_s4_we;
    wire bus_s4_re;
    wire [63:0] bus_s4_read_data;
    wire bus_s4_ready;

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
        .s0_addr(bus_s0_addr),
        .s0_write_data(bus_s0_write_data),
        .s0_we(bus_s0_we),
        .s0_re(bus_s0_re),
        .s0_read_data(bus_s0_read_data),
        .s0_ready(bus_s0_ready),
        .s1_addr(bus_s1_addr),
        .s1_write_data(bus_s1_write_data),
        .s1_we(bus_s1_we),
        .s1_re(bus_s1_re),
        .s1_read_data(bus_s1_read_data),
        .s1_ready(bus_s1_ready),
        .s2_addr(bus_s2_addr),
        .s2_write_data(bus_s2_write_data),
        .s2_we(bus_s2_we),
        .s2_re(bus_s2_re),
        .s2_read_data(bus_s2_read_data),
        .s2_ready(bus_s2_ready),
        .s3_addr(bus_s3_addr),
        .s3_write_data(bus_s3_write_data),
        .s3_we(bus_s3_we),
        .s3_re(bus_s3_re),
        .s3_read_data(bus_s3_read_data),
        .s3_ready(bus_s3_ready),
        .s4_addr(bus_s4_addr),
        .s4_write_data(bus_s4_write_data),
        .s4_we(bus_s4_we),
        .s4_re(bus_s4_re),
        .s4_read_data(bus_s4_read_data),
        .s4_ready(bus_s4_ready)
    );
    
    // Instantiate CLINT
    ax_clint u_clint (
        .clk(clk),
        .rst_n(rst_n),
        .addr(bus_s1_addr),
        .write_data(bus_s1_write_data),
        .we(bus_s1_we),
        .re(bus_s1_re),
        .read_data(bus_s1_read_data),
        .ready(bus_s1_ready),
        .timer_intr(timer_intr),
        .sw_intr(sw_intr)
    );
    
    // Instantiate UART
    ax_uart #(
        .CLK_FREQ(100000000), // 100 MHz default for now
        .BAUD_RATE(115200)
    ) u_uart (
        .clk(clk),
        .rst_n(rst_n),
        .addr(bus_s2_addr),
        .write_data(bus_s2_write_data),
        .we(bus_s2_we),
        .re(bus_s2_re),
        .read_data(bus_s2_read_data),
        .ready(bus_s2_ready),
        .rx(uart_rx),
        .tx(uart_tx)
    );

    // Instantiate GPIO
    ax_gpio u_gpio (
        .clk(clk),
        .rst_n(rst_n),
        .addr(bus_s3_addr[31:0]),
        .write_data(bus_s3_write_data[31:0]),
        .we(bus_s3_we),
        .re(bus_s3_re),
        .read_data(bus_s3_read_data[31:0]),
        .ready(bus_s3_ready),
        .gpio_pins(gpio_pins)
    );
    assign bus_s3_read_data[63:32] = 32'd0;

    // Instantiate SPI
    ax_spi u_spi (
        .clk(clk),
        .rst_n(rst_n),
        .addr(bus_s4_addr[31:0]),
        .write_data(bus_s4_write_data[31:0]),
        .we(bus_s4_we),
        .re(bus_s4_re),
        .read_data(bus_s4_read_data[31:0]),
        .ready(bus_s4_ready),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs(spi_cs)
    );
    assign bus_s4_read_data[63:32] = 32'd0;

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
        .bus_addr(bus_s0_addr),
        .bus_write_data(bus_s0_write_data),
        .bus_we(bus_s0_we),
        .bus_re(bus_s0_re),
        .bus_read_data(bus_s0_read_data),
        .bus_ready(bus_s0_ready),
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
