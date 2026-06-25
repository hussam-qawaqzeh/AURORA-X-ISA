`include "aurora_config.vh"

module ax_pmu (
    input clk,
    input rst_n,
    
    // Flat arrays for PMU Interface
    input  [`TOTAL_CORES-1:0] pmu_req,
    input  [(`TOTAL_CORES*64)-1:0] pmu_write_data,
    
    // Output clocks
    output [`TOTAL_CORES-1:0] clk_cores
);

    reg [63:0] pmu_ctrl;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Enable all cores by default (lower 32 bits = all 1s)
            pmu_ctrl[31:0] <= 32'hFFFFFFFF; 
            
            // Set hardware clock dividers based on aurora_config.vh
            for (i = 0; i < `NUM_P_CORES; i = i + 1) begin
                pmu_ctrl[32 + (i*2) +: 2] <= `FREQ_DIV_P_CORE;
            end
            for (i = 0; i < `NUM_E_CORES; i = i + 1) begin
                pmu_ctrl[32 + ((`NUM_P_CORES + i)*2) +: 2] <= `FREQ_DIV_E_CORE;
            end
            for (i = 0; i < `NUM_AG_CORES; i = i + 1) begin
                pmu_ctrl[32 + ((`NUM_P_CORES + `NUM_E_CORES + i)*2) +: 2] <= `FREQ_DIV_AG_CORE;
            end
        end else begin
            // Any core can write to the PMU control register
            for (i = 0; i < `TOTAL_CORES; i = i + 1) begin
                if (pmu_req[i]) begin
                    pmu_ctrl <= pmu_write_data[(i*64) +: 64];
                end
            end
        end
    end

    // Clock divider counters
    reg [2:0] div_counter [`TOTAL_CORES-1:0];

    // Use negedge to avoid glitches when driving a posedge clock
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < `TOTAL_CORES; i = i + 1) begin
                div_counter[i] <= 0;
            end
        end else begin
            for (i = 0; i < `TOTAL_CORES; i = i + 1) begin
                div_counter[i] <= div_counter[i] + 1;
            end
        end
    end

    genvar g;
    generate
        for (g = 0; g < `TOTAL_CORES; g = g + 1) begin : clk_gen
            wire core_en = pmu_ctrl[g]; // 1 bit enable per core
            // Use 2 bits per core for divider, starting from bit 32
            wire [1:0] core_div = pmu_ctrl[32 + (g*2) +: 2];

            // Glitch-free clock gating and division select
            reg [1:0] div_sel_sync;
            reg       core_en_sync;
            
            always @(negedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    div_sel_sync <= 2'b00;
                    core_en_sync <= 1'b0;
                end else begin
                    div_sel_sync <= core_div;
                    core_en_sync <= core_en;
                end
            end
            
            wire clk_div = (div_sel_sync == 2'b00) ? clk :
                           (div_sel_sync == 2'b01) ? div_counter[g][0] :
                           (div_sel_sync == 2'b10) ? div_counter[g][1] :
                                                     div_counter[g][2];
                                                     
            assign clk_cores[g] = clk_div & core_en_sync;
        end
    endgenerate

endmodule
